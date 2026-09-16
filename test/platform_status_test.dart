import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/status.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/theme/app_theme.dart';
import 'package:student_app/ui/platform_status.dart';

const _key = 'test-status-key-24-characters';

const _homeText = 'the app itself';

class _StatusServer {
  _StatusServer(this.answers);

  final List<Object?> answers;

  final List<Uri> asked = [];

  final List<String?> keys = [];

  int _next = 0;

  http.Client client() => MockClient((request) async {
        asked.add(request.url);
        keys.add(request.headers['X-Status-Key']);
        final answer = answers[_next < answers.length ? _next : answers.length - 1];
        _next++;
        if (answer is int) return http.Response('{"message":"no"}', answer);
        return http.Response.bytes(
          utf8.encode(jsonEncode(answer)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
}

Map<String, Object?> _notice({
  String id = 'ckstatusnotice0000000001',
  String? title = 'Short break tonight',
  String? message = 'The bus map will be off between 22:00 and 22:30.',
  String? startsAt,
  String? endsAt,
}) =>
    {
      'state': 'notice',
      'id': id,
      'title': title,
      'message': message,
      'startsAt': startsAt,
      'endsAt': endsAt,
      'dismissible': true,
      'retryAfterSeconds': 300,
    };

Map<String, Object?> _maintenance({
  String id = 'ckstatusblocking00000001',
  String? title = 'We are working on the system',
  String? message = 'The platform is being upgraded.',
  String? endsAt,
}) =>
    {
      'state': 'maintenance',
      'id': id,
      'title': title,
      'message': message,
      'startsAt': '2026-09-16T20:00:00.000Z',
      'endsAt': endsAt,
      'dismissible': false,
      'retryAfterSeconds': 120,
    };

Widget _app({Role role = Role.parent}) => MaterialApp(
      home: const Scaffold(body: Center(child: Text(_homeText))),
      builder: (context, child) => StatusGate(
        role: role,
        child: child ?? const SizedBox.shrink(),
      ),
    );

Future<_StatusServer> _serve(List<Object?> answers) async {
  final server = _StatusServer(answers);
  PlatformStatusService.instance
    ..resetForTest()
    ..keyForTest = _key
    ..httpForTest = server.client();
  await PlatformStatusService.instance.start('parent');
  return server;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.current.value = Lang.en;
    AppTheme.dark = false;
    PlatformStatusService.instance.resetForTest();
  });

  tearDown(() {
    PlatformStatusService.instance.resetForTest();
  });

  testWidgets('ok leaves the app alone, and asks with this app name, language and key',
      (tester) async {
    final server = await _serve([
      {'state': 'ok'},
    ]);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text(_homeText), findsOneWidget);
    expect(find.byType(MaintenanceScreen), findsNothing);
    expect(find.byType(StatusNotice), findsNothing);

    expect(server.asked, hasLength(1));
    expect(server.asked.single.path, '/api/status');
    expect(server.asked.single.queryParameters['app'], 'parent');
    expect(server.asked.single.queryParameters['lang'], 'en');
    expect(server.keys.single, _key);
  });

  testWidgets('the service being unreachable is not allowed to keep anybody out',
      (tester) async {
    PlatformStatusService.instance
      ..resetForTest()
      ..keyForTest = _key
      ..httpForTest = MockClient((_) async => throw const SocketishFailure());
    await PlatformStatusService.instance.start('parent');

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text(_homeText), findsOneWidget);
    expect(find.byType(MaintenanceScreen), findsNothing);
    expect(find.byType(StatusNotice), findsNothing);
  });

  testWidgets('a notice is a modal that closes, and the same window never shows twice',
      (tester) async {
    await _serve([_notice()]);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text(_homeText), findsOneWidget);
    expect(find.text('Short break tonight'), findsOneWidget);
    expect(find.text('The bus map will be off between 22:00 and 22:30.'), findsOneWidget);

    await tester.tap(find.text(t('common.close')));
    await tester.pumpAndSettle();

    expect(find.byType(StatusNotice), findsNothing);
    expect(find.text(_homeText), findsOneWidget);
    expect(
      SharedPreferences.getInstance().then((p) => p.getString('sm_status_dismissed')),
      completion('ckstatusnotice0000000001'),
    );

    await _serve([_notice()]);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(StatusNotice), findsNothing);

    await _serve([_notice(id: 'ckstatusnotice0000000002', title: 'A different evening')]);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(StatusNotice), findsOneWidget);
    expect(find.text('A different evening'), findsOneWidget);
  });

  testWidgets('maintenance covers everything, back does not escape it, and Refresh clears it',
      (tester) async {
    final popped = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') popped.add(call.method);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final server = await _serve([
      _maintenance(endsAt: '2026-09-16T21:30:00.000Z'),
      {'state': 'ok'},
    ]);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceScreen), findsOneWidget);
    expect(find.text('We are working on the system'), findsOneWidget);
    expect(find.text('The platform is being upgraded.'), findsOneWidget);
    expect(find.text(_homeText), findsNothing);
    expect(find.byType(Navigator), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(MaintenanceScreen), findsOneWidget);
    expect(find.text(_homeText), findsNothing);
    expect(popped, isEmpty);

    expect(server.asked, hasLength(1));
    await tester.tap(find.text(t('status.refresh')));
    await tester.pumpAndSettle();

    expect(server.asked, hasLength(2));
    expect(find.byType(MaintenanceScreen), findsNothing);
    expect(find.text(_homeText), findsOneWidget);
  });

  testWidgets('maintenance with no wording of its own falls back to the app\'s own sentence',
      (tester) async {
    await _serve([_maintenance(title: null, message: null)]);

    await tester.pumpWidget(_app(role: Role.driver));
    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceScreen), findsOneWidget);
    for (final lang in Lang.values) {
      expect(tableFor(lang)['status.maintenanceTitle'], isNotNull);
      expect(tableFor(lang)['status.maintenanceBody'], isNotNull);
    }
    expect(find.text(t('status.maintenanceTitle')), findsOneWidget);
    expect(find.text(t('status.maintenanceBody')), findsOneWidget);

    PlatformStatusService.instance.resetForTest();
  });

  testWidgets('a blocked app lets itself back in without anybody tapping Refresh',
      (tester) async {
    final server = await _serve([
      _maintenance(),
      _maintenance(),
      {'state': 'ok'},
    ]);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(MaintenanceScreen), findsOneWidget);
    expect(server.asked, hasLength(1));

    await tester.pump(const Duration(seconds: 119));
    expect(server.asked, hasLength(1));

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(server.asked, hasLength(2));
    expect(find.byType(MaintenanceScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 120));
    await tester.pumpAndSettle();
    expect(server.asked, hasLength(3));
    expect(find.byType(MaintenanceScreen), findsNothing);
    expect(find.text(_homeText), findsOneWidget);
  });

  testWidgets('waiting is never longer than a quarter of an hour, whatever the service asks',
      (tester) async {
    final server = await _serve([
      {..._maintenance(), 'retryAfterSeconds': 86_400},
      {'state': 'ok'},
    ]);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(server.asked, hasLength(1));

    await tester.pump(const Duration(minutes: 15));
    await tester.pumpAndSettle();
    expect(server.asked, hasLength(2));
    expect(find.text(_homeText), findsOneWidget);
  });

  testWidgets('coming back to the app asks again, so nobody works on a screen that is already down',
      (tester) async {
    final server = await _serve([
      {'state': 'ok'},
      _maintenance(),
    ]);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text(_homeText), findsOneWidget);
    expect(server.asked, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(server.asked, hasLength(2));
    expect(find.byType(MaintenanceScreen), findsOneWidget);
    expect(find.text(_homeText), findsNothing);

    PlatformStatusService.instance.resetForTest();
  });

  testWidgets('a platform request that fails asks the status service again',
      (tester) async {
    final server = await _serve([
      {'state': 'ok'},
      _maintenance(),
    ]);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(server.asked, hasLength(1));
    expect(find.text(_homeText), findsOneWidget);

    ApiClient.instance.httpForTest = MockClient(
      (_) async => http.Response('{"message":"upstream is down"}', 503),
    );
    await expectLater(ApiClient.instance.get('/parent/home'), throwsA(isA<ApiException>()));
    await tester.pumpAndSettle();

    expect(server.asked, hasLength(2));
    expect(find.byType(MaintenanceScreen), findsOneWidget);
    expect(find.text(_homeText), findsNothing);

    PlatformStatusService.instance.resetForTest();
  });

  testWidgets('a network error asks too, but never more than once a minute',
      (tester) async {
    final server = await _serve([
      {'state': 'ok'},
    ]);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(server.asked, hasLength(1));

    ApiClient.instance.httpForTest =
        MockClient((_) async => throw const SocketishFailure());

    await expectLater(ApiClient.instance.get('/parent/home'), throwsA(isA<ApiException>()));
    await tester.pumpAndSettle();
    expect(server.asked, hasLength(2));

    for (var i = 0; i < 4; i++) {
      await expectLater(ApiClient.instance.get('/parent/home'), throwsA(isA<ApiException>()));
      await tester.pumpAndSettle();
    }
    expect(server.asked, hasLength(2));
    expect(PlatformStatusService.quietPeriod, const Duration(minutes: 1));
  });

  test('an answer nobody can read is treated as all clear', () {
    expect(PlatformStatus.fromJson({'state': 'something new'}), isNull);
    expect(PlatformStatus.fromJson({'state': 'ok'})!.state, PlatformState.ok);
    expect(PlatformStatus.fromJson({'state': 'ok'})!.blocks, isFalse);
  });

  test('maintenance is never dismissible, whatever the answer says', () {
    final answer = PlatformStatus.fromJson({'state': 'maintenance', 'id': 'x'})!;
    expect(answer.blocks, isTrue);
    expect(answer.dismissible, isFalse);
  });
}

class SocketishFailure implements Exception {
  const SocketishFailure();
}
