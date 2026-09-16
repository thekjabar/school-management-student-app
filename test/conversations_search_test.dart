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
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/parent/conversations_screen.dart';
import 'package:student_app/ui/assistant_kit.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

const _lana = 'cmstudent000000000000001';
const _dara = 'cmstudent000000000000002';

typedef _Call = ({String method, String path, String query});

class _Server {
  final List<_Call> calls = [];
  final Map<String, Object? Function(Map<String, String> query)> gets = {};

  http.Client client() => MockClient((request) async {
        calls.add((
          method: request.method,
          path: request.url.path,
          query: request.url.hasQuery ? request.url.query : '',
        ));
        final answer = gets[request.url.path];
        if (answer == null) return http.Response('{"message":"not here"}', 404);
        return http.Response.bytes(
          utf8.encode(jsonEncode(answer(request.url.queryParameters))),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

  List<_Call> hits(String path) => [
        for (final c in calls)
          if (c.path == path) c,
      ];
}

Map<String, String> _q(_Call call) => Uri.splitQueryString(call.query);

Map<String, Object?> _thread(
  String id,
  String subject, {
  String studentId = _lana,
  String studentName = 'Lana Kaka',
  String status = 'OPEN',
}) =>
    {
      'id': id,
      'subject': subject,
      'topic': 'GENERAL',
      'status': status,
      'studentId': studentId,
      'studentName': studentName,
      'lastMessageAt': '2026-09-16T09:00:00.000Z',
      'lastMessageBy': 'SCHOOL',
      'messageCount': 2,
      'unread': false,
    };

Map<String, Object?> _page(List<Object?> rows, {int page = 1, int pages = 1, int? total}) => {
      'rows': rows,
      'total': total ?? rows.length,
      'page': page,
      'pages': pages,
    };

Object? _twoPages(Map<String, String> q) {
  if (q['page'] == '2') {
    return _page([_thread('t9', 'An older matter')], page: 2, pages: 2, total: 9);
  }
  return _page(
    [
      _thread('t0', 'Newest of all'),
      for (var i = 1; i < 8; i++) _thread('t$i', 'Conversation number $i'),
    ],
    page: 1,
    pages: 2,
    total: 9,
  );
}

Map<String, Object?> _kid(String studentId, String name) => {
      'studentId': studentId,
      'code': 'S-$studentId',
      'name': name,
      'gradeLevel': 4,
      'className': 'Grade 4',
      'classId': 'cmclass000000000000000a1',
      'relationship': 'MOTHER',
      'isPrimary': true,
    };

void _phone(WidgetTester tester, {double height = 900}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(420, height);
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, [int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _open(WidgetTester tester, {double height = 900}) async {
  _phone(tester, height: height);
  await tester.runAsync(() async {
    await tester.pumpWidget(const MaterialApp(home: ConversationsScreen()));
  });
  await _settle(tester);
}

Future<void> _type(WidgetTester tester, String term) async {
  await tester.runAsync(() => tester.enterText(find.byType(TextField).first, term));
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
    temp = await Directory.systemTemp.createTemp('ksp_conversations');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathChannel, (call) async => temp.path);
    await OfflineCache.instance.clear();
    AppLocale.current.value = Lang.en;
    AppLocale.onChanged = null;
    server = _Server();
    ApiClient.instance.httpForTest = server.client();
    server.gets['/parent/children'] = (_) => [_kid(_lana, 'Lana Kaka'), _kid(_dara, 'Dara Kaka')];
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

  testWidgets('the list opens on the first page and asks for no search', (tester) async {
    server.gets['/parent/messages'] =
        (_) => _page([_thread('t1', 'The bus was late'), _thread('t2', 'Homework')]);

    await _open(tester);

    expect(find.text('The bus was late'), findsOneWidget);
    expect(find.text('Homework'), findsOneWidget);

    final asked = server.hits('/parent/messages');
    expect(asked, isNotEmpty);
    expect(_q(asked.first)['page'], '1');
    expect(_q(asked.first).containsKey('q'), isFalse,
        reason: 'the list searched for something nobody typed');
  });

  testWidgets('a typed word is sent to the school and narrows the list', (tester) async {
    server.gets['/parent/messages'] = (q) {
      if (q['q'] == 'bus') return _page([_thread('t1', 'The bus was late')]);
      return _page([_thread('t1', 'The bus was late'), _thread('t2', 'Homework')]);
    };

    await _open(tester);
    expect(find.text('Homework'), findsOneWidget);

    await _type(tester, 'bus');

    final searched = [
      for (final c in server.hits('/parent/messages'))
        if (_q(c)['q'] == 'bus') c,
    ];
    expect(searched, isNotEmpty, reason: 'the typed word never reached the school');
    expect(find.text('The bus was late'), findsOneWidget);
    expect(find.text('Homework'), findsNothing,
        reason: 'the list still showed a conversation the search ruled out');
  });

  testWidgets('a single stray letter is not treated as a search', (tester) async {
    server.gets['/parent/messages'] =
        (_) => _page([_thread('t1', 'The bus was late'), _thread('t2', 'Homework')]);

    await _open(tester);
    await _type(tester, 'b');

    for (final call in server.hits('/parent/messages')) {
      expect(_q(call).containsKey('q'), isFalse,
          reason: 'one keystroke was sent as a search');
    }
    expect(find.text('Homework'), findsOneWidget);
  });

  testWidgets('clearing the box brings the whole list back', (tester) async {
    server.gets['/parent/messages'] = (q) {
      if (q['q'] == 'bus') return _page([_thread('t1', 'The bus was late')]);
      return _page([_thread('t1', 'The bus was late'), _thread('t2', 'Homework')]);
    };

    await _open(tester);
    await _type(tester, 'bus');
    expect(find.text('Homework'), findsNothing);

    await _type(tester, '');

    expect(find.text('Homework'), findsOneWidget,
        reason: 'emptying the search box left the list filtered');
  });

  testWidgets('the search rides alongside the child and the open-or-closed filter',
      (tester) async {
    server.gets['/parent/messages'] = (_) => _page([_thread('t1', 'The bus was late')]);

    await _open(tester);
    await _type(tester, 'bus');
    await _tap(tester, find.text('Dara Kaka'));
    await _tap(tester, find.text(t('conv.open')));

    final last = _q(server.hits('/parent/messages').last);
    expect(last['q'], 'bus', reason: 'choosing a filter threw the search away');
    expect(last['studentId'], _dara);
    expect(last['status'], 'OPEN');
  });

  testWidgets('a family with one child is not offered a pointless choice', (tester) async {
    server.gets['/parent/children'] = (_) => [_kid(_lana, 'Lana Kaka')];
    server.gets['/parent/messages'] = (_) => _page([_thread('t1', 'The bus was late')]);

    await _open(tester);

    expect(find.text(t('conv.allChildren')), findsNothing);
    expect(find.text(t('conv.allStatus')), findsOneWidget,
        reason: 'the open-or-closed filter disappeared along with the child filter');
  });

  testWidgets('scrolling to the end brings older conversations', (tester) async {
    server.gets['/parent/messages'] = _twoPages;

    await _open(tester, height: 620);
    expect(find.text('An older matter'), findsNothing);

    await _scrollToEnd(tester);

    expect(find.text('An older matter'), findsOneWidget);
    expect(find.text('Newest of all'), findsOneWidget,
        reason: 'the older page replaced the newer one instead of joining it');
  });

  testWidgets('the same page is never fetched twice', (tester) async {
    server.gets['/parent/messages'] = _twoPages;

    await _open(tester, height: 620);
    await _scrollToEnd(tester);
    await _scrollToEnd(tester);
    await _scrollToEnd(tester);

    final second = [
      for (final c in server.hits('/parent/messages'))
        if (_q(c)['page'] == '2') c,
    ];
    expect(second.length, 1, reason: 'the same older page was fetched ${second.length} times');
  });

  testWidgets('a search that matches nothing says so, and says it differently from an empty list',
      (tester) async {
    server.gets['/parent/messages'] = (q) {
      if (q.containsKey('q')) return _page(const []);
      return _page([_thread('t1', 'The bus was late')]);
    };

    await _open(tester);
    expect(find.text(t('conv.noMatch')), findsNothing);

    await _type(tester, 'zebra');

    expect(find.text(t('conv.noMatch')), findsOneWidget);
    expect(find.text(t('conv.none')), findsNothing,
        reason: 'a fruitless search was reported as having no messages at all');
  });

  testWidgets('a family with no conversations is not told its search failed', (tester) async {
    server.gets['/parent/messages'] = (_) => _page(const []);

    await _open(tester);

    expect(find.text(t('conv.none')), findsOneWidget);
    expect(find.text(t('conv.noMatch')), findsNothing);
  });

  testWidgets('a school that cannot answer is reported without its own words', (tester) async {
    await _open(tester);

    expect(find.text(t('conv.failed')), findsOneWidget);
    expect(find.textContaining('not here'), findsNothing,
        reason: 'the server’s own complaint was shown to the parent');
  });

  testWidgets('the filters are pills, not a browser control', (tester) async {
    server.gets['/parent/messages'] = (_) => _page([_thread('t1', 'The bus was late')]);

    await _open(tester);

    expect(find.byType(AssistantFilterPills), findsNWidgets(2));
    expect(find.byType(DropdownButton<String>), findsNothing);
  });
}
