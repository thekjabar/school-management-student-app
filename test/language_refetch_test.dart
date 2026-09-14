import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/language_refresh.dart';
import 'package:student_app/api/offline_cache.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/api/session.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/driver/run_order.dart';
import 'package:student_app/screens/driver/run_route_cache.dart';
import 'package:student_app/ui/async.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

class _Server {
  final List<({String method, String path, String? lang})> calls = [];
  bool offline = false;
  final Map<String, Object? Function(String lang)> answers = {};

  http.Client client() => MockClient((request) async {
        final path = request.url.path + (request.url.hasQuery ? '?${request.url.query}' : '');
        final lang = request.headers['X-Lang'];
        calls.add((method: request.method, path: path, lang: lang));
        if (offline) throw const SocketException('no network');
        final answer = answers[request.url.path];
        if (answer == null) return http.Response('{"message":"not here"}', 404);
        return http.Response.bytes(
          utf8.encode(jsonEncode(answer(lang ?? ''))),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

  List<String?> langsFor(String path) => [
        for (final c in calls)
          if (c.path == path) c.lang,
      ];
}

Map<String, Object?> _announcementPage(String title) => {
      'rows': [
        {'id': 'ckannouncement0001', 'title': title},
      ],
      'total': 1,
      'page': 1,
      'pages': 1,
    };

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(done(), isTrue, reason: 'the expected request never happened');
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

class _Nested extends StatefulWidget {
  const _Nested({required this.fetches});

  final List<Lang> fetches;

  @override
  State<_Nested> createState() => _NestedState();
}

class _NestedState extends State<_Nested> with FollowsReload<_Nested> {
  @override
  void initState() {
    super.initState();
    widget.fetches.add(AppLocale.current.value);
  }

  @override
  void refetch() => widget.fetches.add(AppLocale.current.value);

  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Server server;
  late Directory temp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('ksp_lang_refetch');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathChannel, (call) async => temp.path);
    await OfflineCache.instance.clear();
    AppLocale.current.value = Lang.en;
    AppLocale.onChanged = null;
    server = _Server();
    ApiClient.instance.httpForTest = server.client();
  });

  tearDown(() async {
    AppLocale.onChanged = null;
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

  Widget announcementsLoader({List<Lang>? nested}) => MaterialApp(
        home: Scaffold(
          body: Loader<List<Announcement>>(
            load: ParentApi.instance.announcements,
            builder: (context, rows) => Column(
              children: [
                for (final row in rows) Text(row.title),
                if (nested != null) _Nested(fetches: nested),
              ],
            ),
          ),
        ),
      );

  testWidgets('a mounted loader refetches with the new X-Lang when the language changes',
      (tester) async {
    server.answers['/parent/announcements'] = (lang) => _announcementPage('notice in $lang');

    await tester.runAsync(() async {
      await tester.pumpWidget(announcementsLoader());
      await _until(() => server.calls.isNotEmpty);
    });
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _settle(tester);
    expect(find.text('notice in en'), findsOneWidget);

    await tester.runAsync(() async {
      await AppLocale.set(Lang.ar);
      await _until(() => server.calls.length == 2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await _settle(tester);

    expect(server.langsFor('/parent/announcements?pageSize=50'), ['en', 'ar']);
    expect(find.text('notice in ar'), findsOneWidget);
    expect(find.text('notice in en'), findsNothing);
  });

  testWidgets('pull-to-refresh goes to the network past a saved copy and refreshes what sits inside',
      (tester) async {
    var edition = 'first';
    server.answers['/parent/announcements'] = (lang) => _announcementPage('$edition edition');
    await tester.runAsync(() => OfflineCache.instance.write(
          OfflineCache.languageKey(Lang.en, '/parent/announcements?pageSize=50'),
          _announcementPage('saved edition'),
        ));
    final nested = <Lang>[];

    await tester.runAsync(() async {
      await tester.pumpWidget(announcementsLoader(nested: nested));
      await _until(() => server.calls.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await _settle(tester);
    expect(find.text('first edition'), findsOneWidget);
    expect(nested, [Lang.en]);

    edition = 'second';
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      await _until(() => server.calls.length == 2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await _settle(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('second edition'), findsOneWidget);
    expect(find.text('saved edition'), findsNothing);
    expect(nested, [Lang.en, Lang.en], reason: 'the widget inside the pulled loader did not refetch');
  });

  test('offline, a saved copy is only served in the language it was fetched in', () async {
    server.answers['/parent/announcements'] = (lang) => _announcementPage('notice in $lang');

    final online = await ParentApi.instance.announcements();
    expect(online.single.title, 'notice in en');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    server.offline = true;
    AppLocale.current.value = Lang.ar;
    await expectLater(ParentApi.instance.announcements(), throwsA(isA<OfflineException>()));

    AppLocale.current.value = Lang.en;
    final saved = await ParentApi.instance.announcements();
    expect(saved.single.title, 'notice in en');
  });

  test('switching language tells the server, then reloads the account and the package catalogue',
      () async {
    server.answers['/auth/me'] = (lang) => {
          'person': {
            'id': 'ckperson00000001',
            'name': 'name in $lang',
            'phoneE164': '+9647500000000',
            'locale': lang == 'ar' ? 'AR' : 'EN',
          },
          'active': {'tenantId': 'cktenant00000001', 'role': 'GUARDIAN'},
          'memberships': [
            {'tenantId': 'cktenant00000001', 'tenantName': 'school in $lang', 'role': 'GUARDIAN'},
          ],
        };
    server.answers['/auth/locale'] = (lang) => {'ok': true};
    server.answers['/parent/entitlements'] = (lang) => {
          'sections': [
            {'key': ParentSection.marks, 'paid': true, 'name': {'en': 'Marks', 'ar': 'الدرجات'}},
          ],
          'children': [
            {'studentId': 'ckstudent0000001', 'lockedSections': <String>[]},
          ],
        };

    await ApiClient.instance.saveSession(access: 'token');
    await Session.instance.refresh();
    expect(Session.instance.me!.name, 'name in en');
    await Entitlements.instance.refresh();
    expect(Entitlements.instance.current.value.loaded, isTrue);

    final revision = Session.instance.revision.value;
    server.calls.clear();
    AppLocale.onChanged = LanguageRefresh.apply;
    await AppLocale.set(Lang.ar);

    await _until(() => Session.instance.me?.name == 'name in ar');
    await _until(() => server.langsFor('/parent/entitlements').contains('ar'));

    final order = [for (final c in server.calls) c.path];
    expect(order.indexOf('/auth/locale'), lessThan(order.indexOf('/auth/me')));
    expect(server.langsFor('/auth/me'), ['ar']);
    expect(Session.instance.me!.schoolName, 'school in ar');
    expect(Session.instance.revision.value, greaterThan(revision));
    expect(
      server.calls.where((c) => c.path == '/auth/locale').length,
      1,
      reason: 'the locale was posted twice',
    );
  });

  test('a language change keeps the driver route book and the school gate position', () async {
    const trip = 'cktrip0000000001';
    server.answers['/crew/trips/$trip/pack'] = (lang) => {
          'campus': {'name': 'campus in $lang', 'lat': 36.19, 'lon': 44.01},
          'stopProgress': <Object>[],
        };

    final book = await RunRouteCache.open(trip);
    book.putRoute('OUT', [
      [const LatLng(36.1, 44.0), const LatLng(36.2, 44.1)],
    ]);
    RunRouteCache.keepOrder(
      trip,
      'OUT',
      const PinnedOrder(order: ['ckstop0000000001'], basis: RunBasis.office, road: true),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final english = await RunOrder.school(trip);
    expect(english!.name, 'campus in en');

    AppLocale.onChanged = LanguageRefresh.apply;
    await AppLocale.set(Lang.ar);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(identical(RunRouteCache.peek(trip), book), isTrue);
    expect(RunRouteCache.peek(trip)!.hasRoute('OUT'), isTrue);
    expect(RunRouteCache.peek(trip)!.orders['OUT']!.order, ['ckstop0000000001']);
    expect(await OfflineCache.instance.read('driver_route.$trip'), isNotNull);

    final arabic = await RunOrder.school(trip);
    expect(arabic!.name, 'campus in ar');

    server.offline = true;
    await AppLocale.set(Lang.en);
    final offline = await RunOrder.school(trip);
    expect(offline, isNotNull, reason: 'going offline after a switch lost the school position');
    expect(offline!.lat, 36.19);
  });
}
