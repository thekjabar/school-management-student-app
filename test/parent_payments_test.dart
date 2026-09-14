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
import 'package:student_app/screens/parent/app_fee_screen.dart';
import 'package:student_app/screens/parent/alert_routes.dart';
import 'package:student_app/screens/parent/payment_notices.dart';
import 'package:student_app/screens/parent/school_fees_screen.dart';
import 'package:student_app/ui/kit.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

const _ari = 'ckstudentari000000000001';
const _sara = 'ckstudentsara00000000001';
const _schoolA = 'cktenantschoola000000001';
const _schoolB = 'cktenantschoolb000000001';

typedef _Call = ({String method, String path, String? lang, String? tenant, Object? body});

class _Server {
  final List<_Call> calls = [];
  final Map<String, Object? Function(String lang)> gets = {};
  final Map<String, (int, Object?) Function(Object? body)> posts = {};

  http.Client client() => MockClient((request) async {
        final path = request.url.path + (request.url.hasQuery ? '?${request.url.query}' : '');
        final body = request.body.isEmpty ? null : jsonDecode(request.body);
        calls.add((
          method: request.method,
          path: path,
          lang: request.headers['X-Lang'],
          tenant: request.headers['X-Tenant-Id'],
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
        return _json(200, answer(request.headers['X-Lang'] ?? ''));
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

const _methods = ['CASH', 'BANK_TRANSFER', 'FIB', 'FASTPAY', 'ZAINCASH', 'ASIAHAWALA', 'OTHER'];

Map<String, Object?> _names(String en, String ar, String ckb) => {'en': en, 'ar': ar, 'ckb': ckb};

Map<String, Object?> _packageChild(
  String id,
  String en, {
  String status = 'NONE',
  String? since,
  String? until,
  List<Map<String, Object?>> pending = const [],
}) =>
    {
      'studentId': id,
      'studentName': en,
      'studentNames': _names(en, 'عربي $en', 'کوردی $en'),
      'schoolId': _schoolA,
      'schoolName': 'Erbil Demo School',
      'schoolNames': _names('Erbil Demo School', 'مدرسة أربيل النموذجية', 'قوتابخانەی نموونەیی هەولێر'),
      'status': status,
      'subscribed': status == 'ACTIVE',
      'since': since,
      'until': until,
      'pendingNotices': pending,
    };

Map<String, Object?> _notice(
  String id, {
  String payee = 'KSP',
  String studentId = _ari,
  String schoolId = _schoolA,
  String status = 'PENDING',
  int amount = 75000,
  String? rejectedReason,
  String? coverFrom,
  String? coverUntil,
  String? decidedAt,
  bool sentByMe = true,
}) =>
    {
      'id': id,
      'payee': payee,
      'studentId': studentId,
      'schoolId': schoolId,
      'studentName': 'Ari Ahmed',
      'studentNames': _names('Ari Ahmed', 'آري أحمد', 'ئاری ئەحمەد'),
      'amountIqd': amount,
      'currencyCode': 'IQD',
      'method': 'FIB',
      'paidOn': '2026-09-10',
      'reference': 'TX-1',
      'senderName': 'Ahmed',
      'notes': null,
      'hasProof': true,
      'status': status,
      'decidedAt': decidedAt,
      'rejectedReason': rejectedReason,
      'withdrawnAt': null,
      'coverFrom': coverFrom,
      'coverUntil': coverUntil,
      'sentByMe': sentByMe,
      'createdAt': '2026-09-10T08:00:00.000Z',
    };

Map<String, Object?> _page(List<Map<String, Object?>> rows, {bool more = false}) =>
    {'rows': rows, 'hasMore': more, 'nextCursor': more ? 'cursor-1' : null};

Map<String, Object?> _statement() => {
      'level': 'GRADE',
      'planIds': ['ckplan000000000000000001'],
      'baseIqd': 900000,
      'discountIqd': 100000,
      'exempt': false,
      'dueIqd': 800000,
      'paidIqd': 300000,
      'pendingIqd': 50000,
      'balanceIqd': 500000,
      'overdueIqd': 100000,
      'nextDue': {'dueOn': '2026-09-01', 'amountIqd': 100000},
      'instalments': [
        {
          'planId': 'ckplan000000000000000001',
          'termId': null,
          'sequenceNo': 1,
          'dueOn': '2026-06-01',
          'amountIqd': 300000,
          'discountIqd': 0,
          'payableIqd': 300000,
          'paidIqd': 300000,
          'remainingIqd': 0,
          'state': 'PAID',
        },
        {
          'planId': 'ckplan000000000000000001',
          'termId': null,
          'sequenceNo': 2,
          'dueOn': '2026-09-01',
          'amountIqd': 300000,
          'discountIqd': 0,
          'payableIqd': 300000,
          'paidIqd': 200000,
          'remainingIqd': 100000,
          'state': 'OVERDUE',
        },
        {
          'planId': 'ckplan000000000000000001',
          'termId': null,
          'sequenceNo': 3,
          'dueOn': '2027-02-01',
          'amountIqd': 300000,
          'discountIqd': 100000,
          'payableIqd': 200000,
          'paidIqd': 0,
          'remainingIqd': 200000,
          'state': 'DUE',
        },
      ],
    };

Map<String, Object?> _schoolFeesOverview() => {
      'currencyCode': 'IQD',
      'methods': _methods,
      'children': [
        {
          'studentId': _ari,
          'studentName': 'Ari Ahmed',
          'studentNames': _names('Ari Ahmed', 'آري أحمد', 'ئاری ئەحمەد'),
          'schoolId': _schoolA,
          'schoolName': 'Erbil Demo School',
          'schoolNames': _names('Erbil Demo School', 'مدرسة أربيل النموذجية', 'قوتابخانەی نموونەیی هەولێر'),
          'schoolAllowsAppPayment': true,
          'code': null,
          'message': null,
          'messages': null,
          'year': {'id': 'ckyear000000000000000001', 'name': '2026–2027'},
          'statement': _statement(),
        },
        {
          'studentId': _sara,
          'studentName': 'Sara Ahmed',
          'studentNames': _names('Sara Ahmed', 'سارا أحمد', 'سارا ئەحمەد'),
          'schoolId': _schoolB,
          'schoolName': 'Hawler Hills School',
          'schoolNames': _names('Hawler Hills School', 'مدرسة تلال هولير', 'قوتابخانەی گردەکانی هەولێر'),
          'schoolAllowsAppPayment': false,
          'code': 'SCHOOL_FEES_NOT_IN_APP',
          'message': "Hawler Hills School doesn't take fee payments through the app. Please pay at the school office.",
          'messages': {
            'en': "Hawler Hills School doesn't take fee payments through the app. Please pay at the school office.",
            'ar': 'مدرسة تلال هولير لا تستقبل دفع الرسوم عبر التطبيق. يرجى الدفع في مكتب المدرسة.',
            'ckb': 'قوتابخانەی گردەکانی هەولێر پارەی قوتابخانە لە ڕێگەی ئەپەکەوە وەرناگرێت. تکایە لە نووسینگەی قوتابخانە پارە بدە.',
          },
          'year': null,
          'statement': null,
        },
      ],
    };

final _digits = RegExp(r'[0-9٠-٩۰-۹]');

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 2600);
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, [int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester, Widget screen) async {
  _phone(tester);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(home: screen));
  });
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Server server;
  late Directory temp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('ksp_payments');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathChannel, (call) async => temp.path);
    await OfflineCache.instance.clear();
    AppLocale.current.value = Lang.en;
    AppLocale.onChanged = null;
    server = _Server();
    ApiClient.instance.httpForTest = server.client();
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

  group('models', () {
    test('the package overview reads every status, its dates and the notices waiting for KSP', () {
      final overview = PackageOverview.fromJson({
        'payee': 'KSP',
        'methods': _methods,
        'children': [
          _packageChild(_ari, 'Ari', status: 'ACTIVE', since: '2026-09-01', until: '2027-08-31', pending: [
            {'id': 'n1', 'amountIqd': 75000, 'method': 'CASH', 'paidOn': '2026-09-10', 'createdAt': '2026-09-10T08:00:00.000Z'},
          ]),
          _packageChild(_sara, 'Sara', status: 'STARTS_LATER', since: '2026-10-01'),
          _packageChild('ckstudentthird00000000001', 'Third', status: 'EXPIRED'),
          _packageChild('ckstudentfourth0000000001', 'Fourth', status: 'SOMETHING_NEW'),
        ],
      });
      expect(overview.methods, _methods);
      expect(overview.children.map((c) => c.status), [
        PackageStatus.active,
        PackageStatus.startsLater,
        PackageStatus.expired,
        PackageStatus.none,
      ]);
      final ari = overview.children.first;
      expect(ari.since, DateTime(2026, 9, 1));
      expect(ari.until, DateTime(2027, 8, 31));
      expect(ari.pendingNotices.single.amountIqd, 75000);
      expect(ari.school, 'Erbil Demo School');
    });

    test('school fees read an allowed child with a statement and a switched-off school with its message', () {
      final fees = SchoolFeesOverview.fromJson(_schoolFeesOverview());
      final ari = fees.children[0];
      expect(ari.allowsAppPayment, isTrue);
      expect(ari.year!.name, '2026–2027');
      final s = ari.statement!;
      expect(s.hasPlan, isTrue);
      expect((s.dueIqd, s.paidIqd, s.pendingIqd, s.balanceIqd, s.overdueIqd), (800000, 300000, 50000, 500000, 100000));
      expect(s.nextDueOn, DateTime(2026, 9, 1));
      expect(s.nextDueIqd, 100000);
      expect(s.instalments.map((i) => i.state), [InstalmentState.paid, InstalmentState.overdue, InstalmentState.due]);

      final sara = fees.children[1];
      expect(sara.allowsAppPayment, isFalse);
      expect(sara.code, SchoolFeesCode.notInApp);
      expect(sara.statement, isNull);
      AppLocale.current.value = Lang.ar;
      expect(sara.notInAppText(), startsWith('مدرسة تلال هولير'));
      expect(sara.childName, 'سارا أحمد');
    });

    test('a notice page, a single notice and the submit reply parse', () {
      final page = NoticePage.fromJson(_page([
        _notice('n1', status: 'CONFIRMED', coverFrom: '2026-09-01', coverUntil: '2027-08-31', decidedAt: '2026-09-11T10:00:00.000Z'),
        _notice('n2', payee: 'SCHOOL', status: 'REJECTED', rejectedReason: 'No such transfer'),
      ], more: true));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'cursor-1');
      final confirmed = page.rows[0];
      expect(confirmed.payee, PaymentPayee.ksp);
      expect(confirmed.confirmed, isTrue);
      expect(confirmed.coverUntil, DateTime(2027, 8, 31));
      expect(confirmed.paidOn, DateTime(2026, 9, 10));
      expect(confirmed.hasProof, isTrue);
      final rejected = page.rows[1];
      expect(rejected.payee, PaymentPayee.school);
      expect(rejected.rejectedReason, 'No such transfer');

      final sent = NoticeSent.fromJson({
        'replayed': false,
        'notice': _notice('n3'),
        'message': 'Thank you.',
        'messages': {'en': 'Thank you.', 'ar': 'شكراً.', 'ckb': 'سوپاس.'},
      });
      expect(sent.notice!.pending, isTrue);
      AppLocale.current.value = Lang.ckb;
      expect(sent.text('fallback'), 'سوپاس.');
    });

    test('an amount typed with Arabic or Persian digits is read, and out-of-range amounts are refused', () {
      expect(parseAmountIqd('٥٠٬٠٠٠'), 50000);
      expect(parseAmountIqd('۷۵۰۰۰'), 75000);
      expect(parseAmountIqd('1,250,000 IQD'), 1250000);
      expect(parseAmountIqd(''), isNull);
      expect(parseAmountIqd('9999999999999999999999'), greaterThan(kNoticeMaxIqd));
      expect(amountProblem(PaymentPayee.ksp, 249), t('payments.amountFloor'));
      expect(amountProblem(PaymentPayee.ksp, kNoticeMaxIqd + 1), t('appFee.ceiling'));
      expect(amountProblem(PaymentPayee.school, kNoticeMaxIqd + 1), t('schoolFees.ceiling'));
      expect(amountProblem(PaymentPayee.school, 250), isNull);
    });
  });

  group('copy', () {
    test('no payment wording in any language carries a figure, so no price can be hard-coded', () {
      for (final lang in Lang.values) {
        tableFor(lang).forEach((key, value) {
          if (!RegExp(r'^(appFee|schoolFees|payments)\.').hasMatch(key)) return;
          expect(_digits.hasMatch(value), isFalse, reason: '$key in ${lang.code} carries a figure: "$value"');
        });
      }
    });

    test('the KSP package wording never sends the family to the school', () {
      for (final lang in Lang.values) {
        tableFor(lang).forEach((key, value) {
          if (!key.startsWith('appFee.')) return;
          expect(value.toLowerCase(), isNot(contains('school')), reason: '$key in ${lang.code}');
          expect(value, isNot(contains('قوتابخانە')), reason: '$key in ${lang.code}');
          expect(value, isNot(contains('مدرسة')), reason: '$key in ${lang.code}');
          expect(value, isNot(contains('المدرسة')), reason: '$key in ${lang.code}');
        });
      }
    });

    test('package and school-fee alerts open their own screens', () {
      expect(alertDestinationFor('billing.payment_confirmed', null), AlertDestination.appFee);
      expect(alertDestinationFor('package_payment.confirmed', null), AlertDestination.appFee);
      expect(alertDestinationFor('school_fees.payment.rejected', null), AlertDestination.schoolFees);
      expect(alertDestinationFor('school_fees.something_new', null), AlertDestination.schoolFees);
      expect(alertDestinationFor(null, 'BILLING'), AlertDestination.appFee);
    });
  });

  group('App fee & payment', () {
    void answerPackage({List<Map<String, Object?>> notices = const []}) {
      server.gets['/parent/package'] = (lang) => {
            'payee': 'KSP',
            'currencyCode': 'IQD',
            'methods': _methods,
            'children': [
              _packageChild(_ari, 'Ari Ahmed', status: 'ACTIVE', since: '2026-09-01', until: '2027-08-31', pending: [
                {'id': 'np', 'amountIqd': 75000, 'method': 'FIB', 'paidOn': '2026-09-10', 'createdAt': '2026-09-10T08:00:00.000Z'},
              ]),
              _packageChild(_sara, 'Sara Ahmed'),
            ],
          };
      server.gets['/parent/package/notices'] = (lang) => _page(notices);
    }

    testWidgets('each child shows its package status, dates, waiting badge and history; only pending notices can be withdrawn',
        (tester) async {
      answerPackage(notices: [
        _notice('np'),
        _notice('nc', status: 'CONFIRMED', coverFrom: '2026-09-01', coverUntil: '2027-08-31', decidedAt: '2026-09-11T10:00:00.000Z'),
        _notice('nr', status: 'REJECTED', rejectedReason: 'We could not find this transfer.'),
      ]);
      await _open(tester, const AppFeeScreen());

      expect(find.text('App fee & payment'), findsOneWidget);
      expect(find.byKey(const ValueKey('appFee.child.$_ari')), findsOneWidget);
      expect(find.byKey(const ValueKey('appFee.child.$_sara')), findsOneWidget);
      expect(find.text(t('appFee.statusActive')), findsOneWidget);
      expect(find.text(t('appFee.statusNone')), findsOneWidget);
      expect(find.text(t('appFee.noneLine')), findsOneWidget);
      expect(find.textContaining('2027'), findsWidgets);
      expect(find.text(tn('appFee.waiting', 1)), findsOneWidget);
      expect(find.byKey(const ValueKey('appFee.pay.$_ari')), findsOneWidget);
      expect(find.byKey(const ValueKey('appFee.pay.$_sara')), findsOneWidget);

      expect(find.byKey(const ValueKey('payments.withdraw.np')), findsOneWidget);
      expect(find.byKey(const ValueKey('payments.withdraw.nc')), findsNothing);
      expect(find.byKey(const ValueKey('payments.withdraw.nr')), findsNothing);
      expect(find.text('We could not find this transfer.'), findsOneWidget);
      expect(find.text(t('appFee.reason')), findsOneWidget);
      expect(find.textContaining('Package from'), findsOneWidget);
      expect(find.text(tv('appFee.historyEmpty', {'name': 'Sara Ahmed'})), findsOneWidget);
      expect(find.textContaining('school', findRichText: true), findsNothing);
    });

    testWidgets('a child with no package and no payments shows no figure anywhere', (tester) async {
      server.gets['/parent/package'] = (lang) => {
            'methods': _methods,
            'children': [_packageChild(_sara, 'Sara Ahmed')],
          };
      server.gets['/parent/package/notices'] = (lang) => _page(const []);
      await _open(tester, const AppFeeScreen());

      final texts = tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').toList();
      expect(texts, contains(t('appFee.statusNone')));
      for (final text in texts) {
        expect(_digits.hasMatch(text), isFalse, reason: 'a figure reached the screen: "$text"');
      }
    });

    testWidgets('telling KSP: send stays off until the amount and the method are valid, then confirms and posts the notice',
        (tester) async {
      answerPackage();
      server.posts['/parent/package/notices'] = (body) => (201, {
            'replayed': false,
            'notice': _notice('nnew', studentId: _sara),
            'message': 'Thank you. KSP will check this payment.',
            'messages': {'en': 'Thank you. KSP will check this payment.', 'ar': 'شكراً.', 'ckb': 'سوپاس.'},
          });
      await _open(tester, const AppFeeScreen());

      await tester.tap(find.byKey(const ValueKey('appFee.pay.$_sara')));
      await _settle(tester);

      BigButton send() => tester.widget<BigButton>(find.byKey(const ValueKey('payments.send')));
      expect(find.text(t('appFee.sheetTitle')), findsOneWidget);
      expect(send().onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('payments.amount')), '100');
      await tester.pump();
      expect(find.text(t('payments.amountFloor')), findsOneWidget);
      expect(send().onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('payments.amount')), '50000');
      await tester.pump();
      expect(find.text(t('payments.amountFloor')), findsNothing);
      expect(send().onPressed, isNull, reason: 'no method chosen yet');

      await tester.ensureVisible(find.byKey(const ValueKey('payments.method.ZAINCASH')));
      await tester.tap(find.byKey(const ValueKey('payments.method.ZAINCASH')));
      await tester.pump();
      expect(send().onPressed, isNotNull);

      await tester.ensureVisible(find.byKey(const ValueKey('payments.send')));
      await tester.tap(find.byKey(const ValueKey('payments.send')));
      await _settle(tester);
      expect(find.text(t('appFee.confirmTitle')), findsOneWidget);
      expect(server.hits('POST', '/parent/package/notices'), isEmpty, reason: 'posted before the family confirmed');

      await tester.tap(find.text(t('payments.send')).last);
      await _settle(tester, 10);

      final posted = server.hits('POST', '/parent/package/notices').single;
      final body = posted.body as Map<String, dynamic>;
      expect(body['studentId'], _sara);
      expect(body['amountIqd'], 50000);
      expect(body['method'], 'ZAINCASH');
      expect(body['paidOn'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect((body['idempotencyKey'] as String).length, greaterThanOrEqualTo(8));
      expect(body.containsKey('reference'), isFalse);
      expect(posted.tenant, _schoolA);
      expect(posted.lang, 'en');
      expect(find.text(t('appFee.sheetTitle')), findsNothing);
      expect(find.text('Thank you. KSP will check this payment.'), findsOneWidget);
      expect(server.hits('GET', '/parent/package/notices').length, greaterThanOrEqualTo(2), reason: 'the screen did not reload');
    });

    testWidgets('withdrawing a pending notice asks first, then posts the withdrawal', (tester) async {
      answerPackage(notices: [_notice('np')]);
      server.posts['/parent/package/notices/np/withdraw'] = (body) => (200, {'withdrawn': true, 'id': 'np'});
      await _open(tester, const AppFeeScreen());

      await tester.ensureVisible(find.byKey(const ValueKey('payments.withdraw.np')));
      await tester.tap(find.byKey(const ValueKey('payments.withdraw.np')));
      await _settle(tester);
      expect(find.text(t('payments.withdrawTitle')), findsOneWidget);
      expect(find.text(t('appFee.withdrawBody')), findsOneWidget);

      await tester.tap(find.text(t('payments.withdraw')).last);
      await _settle(tester, 10);
      expect(server.hits('POST', '/parent/package/notices/np/withdraw'), hasLength(1));
    });
  });

  group('School fees', () {
    void answerFees({List<Map<String, Object?>> notices = const []}) {
      server.gets['/parent/school-fees'] = (lang) => _schoolFeesOverview();
      server.gets['/parent/school-fees/notices'] = (lang) => _page(notices);
    }

    testWidgets('an allowed child shows the statement and a pay button; a switched-off school shows its message and no pay action',
        (tester) async {
      answerFees(notices: [_notice('ns', payee: 'SCHOOL', amount: 50000)]);
      await _open(tester, const SchoolFeesScreen());

      expect(find.text('School fees'), findsOneWidget);
      expect(find.byKey(const ValueKey('schoolFees.statement.$_ari')), findsOneWidget);
      expect(find.text('500,000 IQD'), findsOneWidget);
      expect(find.text('800,000 IQD'), findsOneWidget);
      expect(find.text('300,000 IQD'), findsWidgets);
      expect(find.text(t('schoolFees.pending')), findsWidgets);
      expect(find.text(t('schoolFees.overdue')), findsWidgets);
      expect(find.text(t('schoolFees.discount')), findsOneWidget);
      expect(find.byKey(const ValueKey('schoolFees.instalment.$_ari.2')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('schoolFees.instalment.$_ari.0')), matching: find.text(t('schoolFees.statePaid'))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('schoolFees.instalment.$_ari.1')), matching: find.text(t('schoolFees.stateOverdue'))),
        findsOneWidget,
      );
      expect(find.text(t('schoolFees.stateDue')), findsOneWidget);
      expect(find.textContaining(tn('schoolFees.remaining', '100,000 IQD')), findsOneWidget);
      expect(find.byKey(const ValueKey('schoolFees.pay.$_ari')), findsOneWidget);
      expect(find.byKey(const ValueKey('payments.withdraw.ns')), findsOneWidget);

      expect(find.byKey(const ValueKey('schoolFees.notInApp.$_sara')), findsOneWidget);
      expect(
        find.text("Hawler Hills School doesn't take fee payments through the app. Please pay at the school office."),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('schoolFees.pay.$_sara')), findsNothing);
      expect(find.byKey(const ValueKey('schoolFees.statement.$_sara')), findsNothing);
    });

    testWidgets('the switched-off message and the names follow the reader\'s language, right to left', (tester) async {
      AppLocale.current.value = Lang.ar;
      answerFees();
      await _open(tester, const SchoolFeesScreen());

      expect(find.text('مدرسة تلال هولير لا تستقبل دفع الرسوم عبر التطبيق. يرجى الدفع في مكتب المدرسة.'), findsOneWidget);
      expect(find.text('سارا أحمد'), findsOneWidget);
      expect(find.text('آري أحمد'), findsOneWidget);
      expect(server.hits('GET', '/parent/school-fees').first.lang, 'ar');
    });

    testWidgets('a notice refused because the school switched payments off closes the form and reloads the fees', (tester) async {
      answerFees();
      server.posts['/parent/school-fees/notices'] = (body) => (403, {
            'statusCode': 403,
            'code': 'SCHOOL_FEES_NOT_IN_APP',
            'message': "Erbil Demo School doesn't take fee payments through the app. Please pay at the school office.",
            'messages': {'en': 'x', 'ar': 'x', 'ckb': 'x'},
          });
      await _open(tester, const SchoolFeesScreen());
      final loadsBefore = server.hits('GET', '/parent/school-fees').where((c) => !c.path.contains('notices')).length;

      await tester.ensureVisible(find.byKey(const ValueKey('schoolFees.pay.$_ari')));
      await tester.tap(find.byKey(const ValueKey('schoolFees.pay.$_ari')));
      await _settle(tester);
      expect(find.text(t('schoolFees.sheetTitle')), findsOneWidget);
      final amount = tester.widget<TextField>(find.byKey(const ValueKey('payments.amount')));
      expect(amount.controller!.text, '100000', reason: 'the next instalment due was not offered');

      await tester.ensureVisible(find.byKey(const ValueKey('payments.method.CASH')));
      await tester.tap(find.byKey(const ValueKey('payments.method.CASH')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('payments.send')));
      await tester.tap(find.byKey(const ValueKey('payments.send')));
      await _settle(tester);
      expect(find.text(t('schoolFees.confirmTitle')), findsOneWidget);
      await tester.tap(find.text(t('payments.send')).last);
      await _settle(tester, 10);

      final posted = server.hits('POST', '/parent/school-fees/notices').single;
      expect(posted.tenant, _schoolA);
      expect(find.text(t('schoolFees.sheetTitle')), findsNothing);
      expect(
        find.text("Erbil Demo School doesn't take fee payments through the app. Please pay at the school office."),
        findsOneWidget,
      );
      final loadsAfter = server.hits('GET', '/parent/school-fees').where((c) => !c.path.contains('notices')).length;
      expect(loadsAfter, greaterThan(loadsBefore));
    });
  });
}
