// The teacher home screen, against the real platform, to a PNG.
//
//   flutter test test/teacher_golden_test.dart --update-goldens
//
// then open test/goldens/teacher_light.png and teacher_dark.png.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/session.dart';
import 'package:student_app/i18n/delegates.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/teacher/teacher_app.dart';
import 'package:student_app/theme/app_theme.dart';

import 'font_loader.dart';

const phone = '07511100001';
const password = 'School@123';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await loadRealFonts();
    final result = await Session.instance.signIn(phone, password);
    expect(result.me.role, 'TEACHER');
  });

  for (final dark in [false, true]) {
    testWidgets('teacher home — ${dark ? 'dark' : 'light'}', (tester) async {
      AppTheme.dark = dark;
      AppLocale.current.value = Lang.en;

      await binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            supportedLocales: Lang.values.map((l) => Locale(l.code)),
            localizationsDelegates: appLocalizationsDelegates,
            theme: AppTheme.build(tint: Role.teacher.tint),
            home: const TeacherApp(),
          ),
        );
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 120));
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      });

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/teacher_${dark ? 'dark' : 'light'}.png'),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
