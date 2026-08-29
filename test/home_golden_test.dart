// Renders the parent home screen, against the real platform, to a PNG.
//
// Not an assertion — a camera. "It matches the design" is a claim about pixels,
// and the only honest way to make it is to look at the pixels. Everything else
// is reading the source and hoping.
//
//   flutter test test/home_golden_test.dart --update-goldens
//
// then open test/goldens/home_light.png and home_dark.png.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/api/session.dart';
import 'package:student_app/i18n/delegates.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/parent/parent_app.dart';
import 'package:student_app/screens/parent/assignments_screen.dart';
import 'package:student_app/screens/parent/attendance_screen.dart';
import 'package:student_app/screens/parent/attitude_screen.dart';
import 'package:student_app/screens/parent/bus_screen.dart';
import 'package:student_app/screens/parent/leave_screen.dart';
import 'package:student_app/screens/parent/timetable_screen.dart';
import 'package:student_app/theme/app_theme.dart';

import 'font_loader.dart';

const phone = '07501100001';
const password = 'School@123';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  late Child child;

  setUpAll(() async {
    await loadRealFonts();
    final result = await Session.instance.signIn(phone, password);
    expect(result.me.role, 'GUARDIAN');
    final children = await ParentApi.instance.children();
    expect(children, isNotEmpty);
    child = children.first;
  });

  for (final dark in [false, true]) {
    testWidgets('parent home — ${dark ? 'dark' : 'light'}', (tester) async {
      AppTheme.dark = dark;
      AppLocale.current.value = Lang.en;

      await binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => binding.setSurfaceSize(null));

      // Real HTTP has to happen on the real clock: pumpAndSettle drives a fake
      // one, so the loaders would spin for ever inside it.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            supportedLocales: Lang.values.map((l) => Locale(l.code)),
            localizationsDelegates: appLocalizationsDelegates,
            theme: AppTheme.build(tint: Role.parent.tint),
            home: const ParentApp(),
          ),
        );

        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 120));
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      });

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_${dark ? 'dark' : 'light'}.png'),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('timetable — ${dark ? 'dark' : 'light'}', (tester) async {
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
            theme: AppTheme.build(tint: Role.parent.tint),
            home: TimetableScreen(child: child),
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 120));
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      });

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/timetable_${dark ? 'dark' : 'light'}.png'),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('drawer — ${dark ? 'dark' : 'light'}', (tester) async {
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
            theme: AppTheme.build(tint: Role.parent.tint),
            home: const ParentApp(),
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 120));
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
        // The menu button is the first square in the header.
        await tester.tap(find.byIcon(Icons.menu_rounded));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 60));
          await Future<void>.delayed(const Duration(milliseconds: 60));
        }
      });

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/drawer_${dark ? 'dark' : 'light'}.png'),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  // Every parent screen rebuilt against the designs, rendered once each in the
  // light theme. The point is not the picture — it is that the screen builds
  // with real data and throws nothing.
  final screens = <String, Widget Function(Child)>{
    'attendance': (c) => AttendanceScreen(child: c),
    'assignments': (c) => AssignmentsScreen(child: c),
    'attitude': (c) => AttitudeScreen(child: c),
    'leave': (c) => LeaveScreen(child: c),
    'bus': (c) => BusScreen(child: c),
  };

  screens.forEach((name, build) {
    testWidgets('parent screens — $name', (tester) async {
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
            theme: AppTheme.build(tint: Role.parent.tint),
            home: build(child),
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 120));
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      });

      expect(tester.takeException(), isNull, reason: '$name threw');

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/parent_$name.png'),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
