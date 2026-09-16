import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/driver/profile_tab.dart';
import 'package:student_app/screens/login_screen.dart' show LanguagePicker;
import 'package:student_app/screens/teacher/profile_tab.dart';
import 'package:student_app/theme/app_theme.dart';
import 'package:student_app/ui/kit.dart';
import 'package:student_app/ui/settings_widgets.dart';

const _teacherMe = {
  'person': {'name': 'Ari Ahmed', 'phone': '+9647501100002'},
  'school': {'name': 'Erbil Demo School'},
  'classCount': 3,
  'subjectCount': 2,
  'studentCount': 61,
  'homeroomClassIds': <String>[],
};

http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void _tallPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 2200);
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, Widget body) async {
  _tallPhone(tester);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Widget _header(Role role, {Widget? trailing, VoidCallback? onAvatar, VoidCallback? onBell}) =>
    MaterialApp(
      home: Scaffold(
        body: RoleHeader(
          role: role,
          greeting: 'Good morning',
          name: 'Ari Ahmed',
          notificationCount: 2,
          onBell: onBell,
          onAvatar: onAvatar,
          trailing: trailing,
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.current.value = Lang.en;
  });

  group('the header keeps the way into the account', () {
    for (final role in [Role.driver, Role.teacher]) {
      testWidgets('${role.name}: a date pill beside the name does not take the menu away',
          (tester) async {
        var opened = false;
        await tester.pumpWidget(_header(
          role,
          trailing: Pill('Tue 16 Sep', color: role.tint),
          onBell: () {},
          onAvatar: () => opened = true,
        ));
        await tester.pump();

        expect(find.text('Tue 16 Sep'), findsOneWidget);
        expect(find.byIcon(Icons.menu_rounded), findsOneWidget,
            reason: '${role.name} cannot open the account');
        expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget,
            reason: '${role.name} cannot open notifications');

        await tester.tap(find.byIcon(Icons.menu_rounded));
        await tester.pump();
        expect(opened, isTrue);
      });
    }

    testWidgets('the parent header, which carries no pill, is unchanged', (tester) async {
      await tester.pumpWidget(_header(Role.parent, onBell: () {}, onAvatar: () {}));
      await tester.pump();

      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    });
  });

  testWidgets('the driver reaches papers, appearance, language, password and sign out',
      (tester) async {
    await _open(tester, const DriverProfile());

    expect(find.text(t('driver.papers')), findsWidgets);
    expect(find.byType(ThemePicker), findsOneWidget);
    expect(find.byType(LanguagePicker), findsOneWidget);
    expect(find.text(t('more.changePassword')), findsOneWidget);
    expect(find.text(t('more.signOut')), findsOneWidget);

    await tester.tap(find.text(t('more.signOut')));
    await tester.pumpAndSettle();
    expect(find.text(t('more.signOutAsk')), findsOneWidget);
  });

  testWidgets('the teacher reaches appearance, language, password and sign out', (tester) async {
    ApiClient.instance.httpForTest = MockClient((_) async => _json(200, _teacherMe));
    await _open(tester, const TeacherProfileTab());
    await tester.pumpAndSettle();

    expect(find.text('Ari Ahmed'), findsOneWidget);
    expect(find.text(t('teacher.roleLabel')), findsOneWidget);
    expect(find.text('61'), findsOneWidget);
    expect(find.byType(ThemePicker), findsOneWidget);
    expect(find.byType(LanguagePicker), findsOneWidget);
    expect(find.text(t('more.changePassword')), findsOneWidget);
    expect(find.text(t('more.signOut')), findsOneWidget);

    await tester.tap(find.text(t('more.signOut')));
    await tester.pumpAndSettle();
    expect(find.text(t('more.signOutAsk')), findsOneWidget);
  });

  testWidgets('a teacher whose profile will not load can still sign out', (tester) async {
    ApiClient.instance.httpForTest = MockClient((_) async => _json(500, {'message': 'no'}));
    await _open(tester, const TeacherProfileTab());
    await tester.pumpAndSettle();

    expect(find.text(t('more.signOut')), findsOneWidget,
        reason: 'a teacher who is offline is locked into the app');
    expect(find.text(t('more.changePassword')), findsOneWidget);
    expect(find.byType(ThemePicker), findsOneWidget);
    expect(find.byType(LanguagePicker), findsOneWidget);
    expect(find.text(t('teacher.roleLabel')), findsOneWidget);
  });
}
