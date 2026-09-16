import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/offline_cache.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/parent/assistant_screen.dart';
import 'package:student_app/ui/assistant_kit.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

const _lana = 'cmstudent000000000000001';
const _dara = 'cmstudent000000000000002';
const _grumble = 'You exceeded your current quota, please check your plan and billing details.';

typedef _Call = ({String method, String path, Object? body});

class _Server {
  final List<_Call> calls = [];
  final Map<String, Object? Function(String query)> gets = {};
  final Map<String, (int, Object?) Function(Object? body)> posts = {};

  http.Client client() => MockClient((request) async {
        final query = request.url.hasQuery ? request.url.query : '';
        final body = request.body.isEmpty ? null : jsonDecode(request.body);
        calls.add((
          method: request.method,
          path: request.url.path + (query.isEmpty ? '' : '?$query'),
          body: body,
        ));
        if (request.method == 'POST') {
          final answer = posts[request.url.path];
          if (answer == null) return http.Response('{"message":"not here"}', 404);
          final (status, json) = answer(body);
          return _json(status, json);
        }
        final answer = gets[request.url.path];
        if (answer == null) return http.Response('{"message":"not here"}', 404);
        return _json(200, answer(query));
      });

  static http.Response _json(int status, Object? json) => http.Response.bytes(
        utf8.encode(jsonEncode(json)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  List<_Call> hits(String method, String pathPrefix) => [
        for (final c in calls)
          if (c.method == method && c.path.startsWith(pathPrefix)) c,
      ];
}

Map<String, Object?> _names(String en) => {'en': en, 'ar': 'عربي $en', 'ckb': 'کوردی $en'};

Map<String, Object?> _row(
  String id,
  String question, {
  String outcome = 'ANSWERED',
  String kind = 'CHILD_REPORT',
  String studentId = _lana,
  String childName = 'Lana Aram Kaka',
}) =>
    {
      'id': id,
      'at': '2026-09-16T09:00:00.000Z',
      'kind': kind,
      'outcome': outcome,
      'lang': 'en',
      'question': question,
      'truncated': false,
      'child': {'studentId': studentId, 'name': childName, 'names': _names(childName)},
      'schoolClass': {'id': 'cmclass000000000000000a1', 'name': 'Grade 4', 'names': _names('Grade 4')},
      'subject': null,
    };

Map<String, Object?> _overview({int children = 2, int remaining = 7}) => {
      'available': true,
      'children': [
        {
          'studentId': _lana,
          'name': 'Lana Aram Kaka',
          'limit': 10,
          'remaining': remaining,
          'resetsOn': null,
        },
        if (children > 1)
          {
            'studentId': _dara,
            'name': 'Dara Sami Baban',
            'limit': 10,
            'remaining': 10,
            'resetsOn': null,
          },
      ],
    };

Child _child() => Child.fromJson({
      'studentId': _lana,
      'code': 'S-1',
      'name': 'Lana Aram Kaka',
      'gradeLevel': 4,
      'className': 'Grade 4',
      'classId': 'cmclass000000000000000a1',
      'relationship': 'MOTHER',
      'isPrimary': true,
    });

String? _after(_Call call) =>
    Uri.splitQueryString(call.path.contains('?') ? call.path.split('?').last : '')['after'];

String? _studentId(_Call call) =>
    Uri.splitQueryString(call.path.contains('?') ? call.path.split('?').last : '')['studentId'];

void _phone(WidgetTester tester, {double height = 900}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(420, height);
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, [int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester, {double height = 900}) async {
  _phone(tester, height: height);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(home: AssistantScreen(child: _child())));
  });
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.runAsync(() => tester.tap(target));
  await _settle(tester);
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  position.jumpTo(position.maxScrollExtent);
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Server server;
  late Directory temp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('ksp_assistant');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathChannel, (call) async => temp.path);
    await OfflineCache.instance.clear();
    AppLocale.current.value = Lang.en;
    AppLocale.onChanged = null;
    server = _Server();
    ApiClient.instance.httpForTest = server.client();
    server.gets['/parent/ai'] = (_) => _overview();
  });

  tearDown(() async {
    AppLocale.current.value = Lang.en;
    await OfflineCache.instance.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathChannel, null);
    try {
      if (await temp.exists()) await temp.delete(recursive: true);
    } on FileSystemException {
      return;
    }
  });

  testWidgets('opening the assistant shows what was asked before, without asking anything new',
      (tester) async {
    server.gets['/parent/ai/history'] = (_) => {
          'rows': [_row('a1', 'How is my child doing?'), _row('a2', 'What is the homework?')],
          'hasMore': false,
          'nextCursor': null,
        };

    await _open(tester);

    expect(find.text('How is my child doing?'), findsOneWidget);
    expect(find.text('What is the homework?'), findsOneWidget);
    expect(server.hits('POST', '/parent/ai').isEmpty, isTrue,
        reason: 'merely opening the screen spent one of the day’s questions');
  });

  testWidgets('the screen asks only for this family’s own history', (tester) async {
    server.gets['/parent/ai/history'] = (_) =>
        {'rows': [_row('a1', 'How is my child doing?')], 'hasMore': false, 'nextCursor': null};

    await _open(tester);

    final asked = server.hits('GET', '/parent/ai/history');
    expect(asked, isNotEmpty);
    expect(_studentId(asked.first), _lana,
        reason: 'the screen asked for every child instead of the one it was opened for');
  });

  testWidgets('the answer stays folded until the reader asks for it', (tester) async {
    server.gets['/parent/ai/history'] = (_) =>
        {'rows': [_row('a1', 'How is my child doing?')], 'hasMore': false, 'nextCursor': null};
    server.gets['/parent/ai/history/a1'] =
        (_) => {..._row('a1', 'How is my child doing?'), 'answer': 'She is doing well.'};

    await _open(tester);

    expect(find.text('She is doing well.'), findsNothing);
    expect(server.hits('GET', '/parent/ai/history/a1'), isEmpty,
        reason: 'the whole answer was fetched before anyone asked to read it');

    await _tap(tester, find.text('How is my child doing?'));

    expect(find.text('She is doing well.'), findsOneWidget);
    expect(server.hits('GET', '/parent/ai/history/a1').length, 1);
  });

  testWidgets('a second tap folds it away and a third does not fetch it again', (tester) async {
    server.gets['/parent/ai/history'] = (_) =>
        {'rows': [_row('a1', 'How is my child doing?')], 'hasMore': false, 'nextCursor': null};
    server.gets['/parent/ai/history/a1'] =
        (_) => {..._row('a1', 'How is my child doing?'), 'answer': 'She is doing well.'};

    await _open(tester);
    await _tap(tester, find.text('How is my child doing?'));
    expect(find.text('She is doing well.'), findsOneWidget);

    await _tap(tester, find.text('How is my child doing?'));
    expect(find.text('She is doing well.'), findsNothing);

    await _tap(tester, find.text('How is my child doing?'));
    expect(find.text('She is doing well.'), findsOneWidget);
    expect(server.hits('GET', '/parent/ai/history/a1').length, 1,
        reason: 'the same answer was fetched twice');
  });

  testWidgets('a question that got no answer shows the outcome, never the provider’s complaint',
      (tester) async {
    server.gets['/parent/ai/history'] = (_) => {
          'rows': [_row('a1', 'How is my child doing?', outcome: 'PROVIDER_ERROR')],
          'hasMore': false,
          'nextCursor': null,
        };
    server.gets['/parent/ai/history/a1'] = (_) => {
          ..._row('a1', 'How is my child doing?', outcome: 'PROVIDER_ERROR'),
          'answer': null,
          'failure': _grumble,
        };

    await _open(tester);
    await _tap(tester, find.text('How is my child doing?'));

    expect(find.text(t('aih.outcome.PROVIDER_ERROR')), findsWidgets);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final shown = text.data ?? '';
      expect(shown.contains('quota'), isFalse, reason: 'the provider’s words reached the reader');
      expect(shown.contains(_grumble), isFalse);
    }
  });

  testWidgets('a family with two children can look at either, or at both', (tester) async {
    server.gets['/parent/ai/history'] = (query) => {
          'rows': [
            if (!query.contains(_dara)) _row('a1', 'How is my child doing?'),
            if (!query.contains(_lana))
              _row('a2', 'How is my son doing?', studentId: _dara, childName: 'Dara Sami Baban'),
          ],
          'hasMore': false,
          'nextCursor': null,
        };

    await _open(tester);

    expect(find.text('How is my child doing?'), findsOneWidget);
    expect(find.text('How is my son doing?'), findsNothing);

    await _tap(tester, find.text(t('aih.allChildren')));

    expect(find.text('How is my child doing?'), findsOneWidget);
    expect(find.text('How is my son doing?'), findsOneWidget);
    expect(_studentId(server.hits('GET', '/parent/ai/history').last), isNull,
        reason: 'asking for every child still narrowed to one');

    await _tap(tester, find.text('Dara Sami Baban'));

    expect(find.text('How is my child doing?'), findsNothing);
    expect(_studentId(server.hits('GET', '/parent/ai/history').last), _dara);
  });

  testWidgets('a family with one child is not offered a choice of children', (tester) async {
    server.gets['/parent/ai'] = (_) => _overview(children: 1);
    server.gets['/parent/ai/history'] = (_) =>
        {'rows': [_row('a1', 'How is my child doing?')], 'hasMore': false, 'nextCursor': null};

    await _open(tester);

    expect(find.text(t('aih.allChildren')), findsNothing);
    expect(find.byType(AssistantFilterPills), findsNothing);
  });

  testWidgets('older questions come in as the reader scrolls down', (tester) async {
    server.gets['/parent/ai/history'] = (query) {
      final after = Uri.splitQueryString(query)['after'];
      if (after == null) {
        return {
          'rows': [for (var i = 0; i < 8; i++) _row('n$i', 'Newest question $i')],
          'hasMore': true,
          'nextCursor': 'page2',
        };
      }
      return {
        'rows': [for (var i = 0; i < 4; i++) _row('o$i', 'Older question $i')],
        'hasMore': false,
        'nextCursor': null,
      };
    };

    await _open(tester, height: 700);

    expect(find.text('Older question 0'), findsNothing);

    await _scrollToEnd(tester);

    final paged = server.hits('GET', '/parent/ai/history').where((c) => _after(c) == 'page2');
    expect(paged, isNotEmpty, reason: 'scrolling to the end never asked for older questions');

    await _scrollToEnd(tester);

    expect(find.text('Older question 0'), findsOneWidget);
  });

  testWidgets('the same older page is never asked for twice', (tester) async {
    server.gets['/parent/ai/history'] = (query) {
      final after = Uri.splitQueryString(query)['after'];
      if (after == null) {
        return {
          'rows': [for (var i = 0; i < 8; i++) _row('n$i', 'Newest question $i')],
          'hasMore': true,
          'nextCursor': 'page2',
        };
      }
      return {
        'rows': [for (var i = 0; i < 4; i++) _row('o$i', 'Older question $i')],
        'hasMore': false,
        'nextCursor': null,
      };
    };

    await _open(tester, height: 700);

    for (var i = 0; i < 3; i++) {
      await _scrollToEnd(tester);
    }

    expect(server.hits('GET', '/parent/ai/history').where((c) => _after(c) == 'page2').length, 1,
        reason: 'the same older page was fetched more than once');
    expect(find.text('Older question 0'), findsOneWidget,
        reason: 'an older question was listed twice');
  });

  testWidgets('the family is told how many questions are left today', (tester) async {
    server.gets['/parent/ai/history'] =
        (_) => {'rows': const [], 'hasMore': false, 'nextCursor': null};

    await _open(tester);

    expect(find.text(tv('ai.left', {'left': 7, 'limit': 10})), findsOneWidget);
  });

  testWidgets('a family that has asked nothing is told so, and told what may be asked',
      (tester) async {
    server.gets['/parent/ai/history'] =
        (_) => {'rows': const [], 'hasMore': false, 'nextCursor': null};

    await _open(tester);

    expect(find.text(t('ai.nothingAsked')), findsOneWidget);
    expect(find.text(t('ai.scopeNote')), findsOneWidget);
  });

  testWidgets('history that will not load says so, and does not pretend nothing was asked',
      (tester) async {
    await _open(tester);

    expect(find.text(t('aih.failed')), findsOneWidget);
    expect(find.text(t('ai.nothingAsked')), findsNothing);
  });
}
