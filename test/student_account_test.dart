import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/student_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/login_screen.dart' show LanguagePicker;
import 'package:student_app/screens/student/id_card.dart';
import 'package:student_app/screens/student/profile_tab.dart';
import 'package:student_app/ui/settings_widgets.dart';

const _me = {
  'id': 'cmstudent00000000000000001',
  'code': 'S-2031',
  'name': 'Lana Karim',
  'names': {'ckb': 'لانا کەریم', 'ar': 'لانا كريم', 'en': 'Lana Karim'},
  'gender': 'FEMALE',
  'dob': '2012-04-09T00:00:00.000Z',
  'photoUrl': null,
  'lastLoginAt': '2026-09-20T07:15:00.000Z',
  'school': {
    'name': 'Erbil Demo School',
    'names': {'ckb': 'قوتابخانەی نموونەیی هەولێر', 'ar': 'مدرسة أربيل', 'en': 'Erbil Demo School'},
  },
  'schoolClass': {
    'id': 'cmclass000000000000000001',
    'name': 'Grade 6 B',
    'names': {'ckb': 'پۆلی ٦ ب', 'ar': 'الصف السادس ب', 'en': 'Grade 6 B'},
    'gradeLevel': 6,
    'section': 'B',
  },
};

http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _card(String token, int seconds) => {
      'token': token,
      'expiresAt': DateTime.now().add(Duration(seconds: seconds)).toIso8601String(),
      'expiresIn': seconds,
    };

void _tallPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 2400);
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, Widget body) async {
  _tallPhone(tester);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.current.value = Lang.en;
  });

  testWidgets('a student reaches appearance, language, password and sign out', (tester) async {
    ApiClient.instance.httpForTest = MockClient((_) async => _json(200, _me));
    await _open(tester, const StudentProfileTab());
    await tester.pumpAndSettle();

    expect(find.text('Lana Karim'), findsOneWidget);
    expect(find.text('Erbil Demo School'), findsOneWidget);
    expect(find.text('Grade 6 B'), findsOneWidget);
    expect(find.text('S-2031'), findsWidgets);
    expect(find.byType(ThemePicker), findsOneWidget);
    expect(find.byType(LanguagePicker), findsOneWidget);
    expect(find.text(t('more.changePassword')), findsOneWidget);
    expect(find.text(t('more.signOut')), findsOneWidget);

    await tester.tap(find.text(t('more.signOut')));
    await tester.pumpAndSettle();
    expect(find.text(t('more.signOutAsk')), findsOneWidget);
  });

  testWidgets('a student whose profile will not load can still sign out', (tester) async {
    ApiClient.instance.httpForTest = MockClient((_) async => _json(500, {'message': 'no'}));
    await _open(tester, const StudentProfileTab());
    await tester.pumpAndSettle();

    expect(find.text(t('more.signOut')), findsOneWidget,
        reason: 'a student who is offline is locked into the app');
    expect(find.text(t('more.changePassword')), findsOneWidget);
    expect(find.byType(ThemePicker), findsOneWidget);
    expect(find.byType(LanguagePicker), findsOneWidget);
  });

  testWidgets('the ID card shows the code the server gave, and says when it changes',
      (tester) async {
    ApiClient.instance.httpForTest = MockClient((request) async =>
        request.url.path.endsWith('/student/id-card')
            ? _json(200, _card('token-live', 120))
            : _json(200, _me));

    _tallPhone(tester);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StudentIdCardSheet())));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining(t('student.idCardExpires').split('{n}').first), findsOneWidget);
  });

  testWidgets('a code that has run out is replaced without the student asking', (tester) async {
    final tokens = <String>[];
    ApiClient.instance.httpForTest = MockClient((request) async {
      if (!request.url.path.endsWith('/student/id-card')) return _json(200, _me);
      tokens.add('token-${tokens.length + 1}');
      return _json(200, _card(tokens.last, tokens.length == 1 ? -1 : 120));
    });

    _tallPhone(tester);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StudentIdCardSheet())));
    await tester.pumpAndSettle();

    expect(tokens, ['token-1']);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(tokens, ['token-1', 'token-2'], reason: 'a dead code was left on the screen');
  });

  testWidgets('an ID card that cannot be fetched offers a way to try again', (tester) async {
    var calls = 0;
    ApiClient.instance.httpForTest = MockClient((request) async {
      if (request.url.path.endsWith('/student/id-card')) {
        calls += 1;
        return calls == 1 ? _json(500, {'message': 'no'}) : _json(200, _card('token-ok', 120));
      }
      return _json(200, _me);
    });

    _tallPhone(tester);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StudentIdCardSheet())));
    await tester.pumpAndSettle();

    expect(find.text(t('common.tryAgain')), findsOneWidget);

    await tester.tap(find.text(t('common.tryAgain')));
    await tester.pumpAndSettle();

    expect(find.text(t('common.tryAgain')), findsNothing);
    expect(find.text('Lana Karim'), findsOneWidget);
  });

  test('an ID card with no expiry date still counts down from what the server said', () {
    final card = IdCardToken.fromJson({'token': 'abc', 'expiresIn': 90});
    expect(card.remaining, const Duration(seconds: 90));

    final spent = IdCardToken.fromJson({
      'token': 'abc',
      'expiresAt': DateTime.now().subtract(const Duration(seconds: 5)).toIso8601String(),
      'expiresIn': 120,
    });
    expect(spent.remaining, Duration.zero, reason: 'a dead code would be shown as live');
  });
}
