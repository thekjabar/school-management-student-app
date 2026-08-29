// The driver home screen, against the real platform, to a PNG.
//
//   flutter test test/driver_golden_test.dart --update-goldens
//
// then open test/goldens/driver_light.png and teacher_dark.png.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/session.dart';
import 'package:student_app/i18n/delegates.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/driver/driver_app.dart';
import 'package:student_app/theme/app_theme.dart';
import 'package:student_app/ui/nav_glyphs.dart';

import 'font_loader.dart';

const phone = '07701100001';
const password = 'School@123';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await loadRealFonts();
    final result = await Session.instance.signIn(phone, password);
    expect(result.me.role, 'DRIVER');
  });

  for (final dark in [false, true]) {
    testWidgets('driver home — ${dark ? 'dark' : 'light'}', (tester) async {
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
            theme: AppTheme.build(tint: Role.driver.tint),
            home: const DriverApp(),
          ),
        );
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 120));
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      });

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/driver_${dark ? 'dark' : 'light'}.png'),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  // The other three destinations, in the light theme. Each one loads its own
  // data, and a screen that throws on load is exactly what the user should
  // never be the one to find.
  for (final tab in ['route', 'students', 'profile']) {
    testWidgets('driver $tab', (tester) async {
      AppTheme.dark = false;
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
            theme: AppTheme.build(tint: Role.driver.tint),
            home: const DriverApp(),
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 120));
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }

        // By the bar's own mark, not by its word: "Students" is also a figure
        // label on the home screen, and find.text matched both.
        final glyph = switch (tab) {
          'route' => NavGlyph.route,
          'students' => NavGlyph.students,
          _ => NavGlyph.profile,
        };
        await tester.tap(
          find.byWidgetPredicate((w) => w is NavGlyphIcon && w.glyph == glyph),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 120));
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      });

      // Anything the framework caught while those screens built.
      expect(tester.takeException(), isNull, reason: 'the $tab tab threw');

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/driver_$tab.png'),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
