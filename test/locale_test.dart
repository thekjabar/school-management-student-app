// Proves the app survives every language, and redraws when one is chosen.
//
// Two real failures came from this area and neither was catchable by reading
// the code carefully:
//
//   1. Flutter ships no Kurdish translations, so GlobalMaterialLocalizations
//      refuses 'ku'. Any widget needing MaterialLocalizations then throws —
//      a text field's selection handles, the date picker, a Scaffold — and the
//      app crashed the moment Kurdish was applied.
//
//   2. `home: const _Gate()` meant the widget was canonicalised to one
//      instance, and Flutter skips a subtree whose widget is identical to the
//      one mounted. The language changed and nothing redrew until a new route
//      was pushed.
//
// Both are invisible in analyze and in an API test. Only pumping the widgets
// finds them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/i18n/delegates.dart';
import 'package:student_app/i18n/strings.dart';

/// main.dart's localisation setup, sharing its actual delegate list — a test
/// that assembles a shorter list of its own proves nothing about the app.
///
/// [screen] is a builder, not a widget, and that is the point: a widget built
/// once outside is canonicalised to a single instance, and Flutter skips a
/// subtree whose widget is identical to the mounted one. Passing a ready-made
/// child here reproduces the very bug this file exists to catch.
Widget harness({required Widget Function() screen}) {
  return ValueListenableBuilder<Lang>(
    valueListenable: AppLocale.current,
    builder: (context, current, _) => MaterialApp(
      locale: Locale(current.code),
      supportedLocales: Lang.values.map((l) => Locale(l.code)),
      localizationsDelegates: appLocalizationsDelegates,
      builder: (context, inner) => Directionality(
        textDirection: current.direction,
        child: inner ?? const SizedBox.shrink(),
      ),
      home: screen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  for (final lang in Lang.values) {
    testWidgets('a screen with Material widgets builds in ${lang.code}', (tester) async {
      AppLocale.current.value = lang;

      // A Scaffold with a text field and a date button is the shape of the
      // leave form, and it is exactly what needs MaterialLocalizations.
      await tester.pumpWidget(
        harness(
          screen: () => Scaffold(
            appBar: AppBar(title: Text(t('leave.title'))),
            body: Column(
              children: [
                TextField(decoration: InputDecoration(hintText: t('login.phoneHint'))),
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      initialDate: DateTime(2026, 8, 28),
                    ),
                    child: Text(t('leave.from')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'building threw in ${lang.code}');
      expect(find.text(t('leave.title')), findsOneWidget);
    });

    testWidgets('the date picker opens in ${lang.code}', (tester) async {
      AppLocale.current.value = lang;

      await tester.pumpWidget(
        harness(
          screen: () => Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDate: DateTime(2026, 8, 28),
                  ),
                  child: const Text('pick'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();

      // This is the call that used to throw: the picker asks for
      // MaterialLocalizations, and nothing supported 'ku'.
      expect(tester.takeException(), isNull, reason: 'the date picker threw in ${lang.code}');
    });

    testWidgets('${lang.code} lays out in the right direction', (tester) async {
      AppLocale.current.value = lang;
      await tester.pumpWidget(harness(screen: () => const Scaffold(body: Text('x'))));
      await tester.pumpAndSettle();

      final direction = Directionality.of(tester.element(find.text('x')));
      expect(direction, lang.direction, reason: '${lang.code} was laid out the wrong way round');
    });
  }

  testWidgets('changing language redraws without navigating away', (tester) async {
    AppLocale.current.value = Lang.en;

    await tester.pumpWidget(
      harness(screen: () => Scaffold(body: Text(t('nav.home')))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);

    await AppLocale.set(Lang.ckb);
    await tester.pumpAndSettle();

    // The same screen, no navigation, now in Kurdish.
    expect(find.text('Home'), findsNothing, reason: 'the old language is still on screen');
    expect(find.text(tableFor(Lang.ckb)['nav.home']!), findsOneWidget);
  });
}
