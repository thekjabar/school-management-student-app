// Dark mode, tested where it can actually be wrong.
//
// The palette is a set of getters reading one global flag, chosen over
// Theme.of(context) at ~250 call sites. That trade is only safe if the flag is
// definitely set before anything paints and definitely flips everything — so
// those are the two things asserted here, plus the specific mistakes the
// approach invites: a surface that stayed white, and text that stopped being
// readable against its background.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/theme/app_theme.dart';

/// Contrast ratio per WCAG 2.1. Used to check the dark palette is legible
/// rather than merely dark.
double contrast(Color a, Color b) {
  double channel(double c) {
    c = c / 255.0;
    return c <= 0.03928 ? c / 12.92 : _pow((c + 0.055) / 1.055, 2.4);
  }

  double luminance(Color c) =>
      0.2126 * channel((c.r * 255).roundToDouble()) +
      0.7152 * channel((c.g * 255).roundToDouble()) +
      0.0722 * channel((c.b * 255).roundToDouble());

  final l1 = luminance(a);
  final l2 = luminance(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

double _pow(double x, double e) {
  // Small integer-free pow, so the test carries no dependency for one call.
  return _expApprox(e * _lnApprox(x));
}

double _lnApprox(double x) {
  var result = 0.0;
  while (x > 2) {
    x /= 2.718281828459045;
    result += 1;
  }
  while (x < 0.5) {
    x *= 2.718281828459045;
    result -= 1;
  }
  final z = (x - 1) / (x + 1);
  var term = z;
  var sum = 0.0;
  for (var n = 1; n <= 21; n += 2) {
    sum += term / n;
    term *= z * z;
  }
  return result + 2 * sum;
}

double _expApprox(double x) {
  var sum = 1.0;
  var term = 1.0;
  for (var i = 1; i < 30; i++) {
    term *= x / i;
    sum += term;
  }
  return sum;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  tearDown(() => AppTheme.dark = false);

  test('the palette actually changes with the flag', () {
    AppTheme.dark = false;
    final lightCanvas = AppTheme.canvas;
    final lightSurface = AppTheme.surface;
    final lightText = AppTheme.text;

    AppTheme.dark = true;
    expect(AppTheme.canvas, isNot(lightCanvas));
    expect(AppTheme.surface, isNot(lightSurface));
    expect(AppTheme.text, isNot(lightText));
  });

  test('cards sit above the canvas in both themes', () {
    // Dark is not the light palette inverted. A card must read as lifted off
    // the page in both, so surface is always the lighter of the two in dark
    // and the lighter in light too.
    for (final dark in [false, true]) {
      AppTheme.dark = dark;
      final canvasLum = AppTheme.canvas.computeLuminance();
      final surfaceLum = AppTheme.surface.computeLuminance();
      expect(surfaceLum, greaterThan(canvasLum),
          reason: 'in ${dark ? "dark" : "light"} the card is darker than the page behind it');
    }
  });

  test('body text is legible on both surfaces, in both themes', () {
    for (final dark in [false, true]) {
      AppTheme.dark = dark;
      final where = dark ? 'dark' : 'light';
      // WCAG AA for body text is 4.5:1.
      expect(contrast(AppTheme.text, AppTheme.surface), greaterThan(4.5),
          reason: '$where: body text on a card is below AA');
      expect(contrast(AppTheme.text, AppTheme.canvas), greaterThan(4.5),
          reason: '$where: body text on the page is below AA');
      // Muted text carries real content — a class name, a bus stop — so it is
      // held to the same bar rather than the 3:1 large-text one.
      expect(contrast(AppTheme.textMuted, AppTheme.surface), greaterThan(4.5),
          reason: '$where: muted text on a card is below AA');
    }
  });

  test('soft accent backings stay distinct from the surface', () {
    // A soft tint that works on white is nearly white; reused unchanged on a
    // dark canvas it becomes a glowing block. Each must differ from the
    // surface it sits on, in both themes.
    for (final dark in [false, true]) {
      AppTheme.dark = dark;
      final softs = {
        'violet': AppTheme.violetSoft,
        'green': AppTheme.greenSoft,
        'amber': AppTheme.amberSoft,
        'blue': AppTheme.blueSoft,
        'rose': AppTheme.roseSoft,
      };
      softs.forEach((name, soft) {
        expect(soft, isNot(AppTheme.surface),
            reason: '${dark ? "dark" : "light"}: $name soft is the same as the surface');
      });
    }
  });

  test('accent text is legible on its own soft backing', () {
    for (final dark in [false, true]) {
      AppTheme.dark = dark;
      final pairs = {
        'green': (AppTheme.green, AppTheme.greenSoft),
        'amber': (AppTheme.amber, AppTheme.amberSoft),
        'blue': (AppTheme.blue, AppTheme.blueSoft),
        'rose': (AppTheme.rose, AppTheme.roseSoft),
        'violet': (AppTheme.violet, AppTheme.violetSoft),
      };
      pairs.forEach((name, pair) {
        // 3:1 — these are pills and figures, not paragraphs.
        expect(contrast(pair.$1, pair.$2), greaterThan(3.0),
            reason: '${dark ? "dark" : "light"}: $name on its soft backing is unreadable');
      });
    }
  });

  test('the system bars invert with the theme', () {
    AppTheme.dark = false;
    expect(AppTheme.systemOverlay.statusBarIconBrightness, Brightness.dark);
    AppTheme.dark = true;
    // Light icons on a dark bar. Getting this backwards makes the clock
    // invisible, which is the most-reported "the app broke my phone" bug.
    expect(AppTheme.systemOverlay.statusBarIconBrightness, Brightness.light);
  });

  test('ThemeData follows the flag', () {
    AppTheme.dark = false;
    expect(AppTheme.build().brightness, Brightness.light);
    AppTheme.dark = true;
    expect(AppTheme.build().brightness, Brightness.dark);
    expect(AppTheme.build().scaffoldBackgroundColor, AppTheme.canvas);
  });

  testWidgets('a screen paints dark surfaces when the flag is set', (tester) async {
    AppTheme.dark = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: Container(
            key: const Key('card'),
            color: AppTheme.surface,
            child: Text('x', style: TextStyle(color: AppTheme.text)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<Container>(find.byKey(const Key('card')));
    expect(card.color, AppTheme.surface);
    expect((card.color as Color).computeLuminance(), lessThan(0.5),
        reason: 'the card painted light while the app was in dark mode');
  });

  test('the stored setting round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    await AppThemeSetting.set(AppThemeMode.dark);
    expect(AppThemeSetting.current.value, AppThemeMode.dark);

    AppThemeSetting.current.value = AppThemeMode.system;
    await AppThemeSetting.restore();
    expect(AppThemeSetting.current.value, AppThemeMode.dark,
        reason: 'the choice did not survive a restart');
  });
}
