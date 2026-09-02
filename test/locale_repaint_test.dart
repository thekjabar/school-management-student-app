// Changing the language has to change the page you changed it ON.
//
// Every other screen already updated, because the root rebuilds on
// AppLocale.current and most of the tree rebuilds with it. The settings page
// did not, and it is the one page where the setting lives — so the person who
// just tapped "English" watched the Kurdish around the button stay Kurdish, and
// only saw it take effect after navigating away and coming back.
//
// The cause is that `t()` is a plain function call rather than an
// InheritedWidget lookup, so Flutter has no idea which widgets depend on the
// language and skips any subtree it is entitled to skip. KspApp already carries
// the cure for exactly this, written for the theme: mark every mounted element
// dirty after the frame. These tests hold that mechanism to the language too.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/i18n/strings.dart';

/// A widget that is const-constructible, and so is a candidate for the skip.
class _Label extends StatelessWidget {
  const _Label();

  @override
  Widget build(BuildContext context) => Text(t('settings.language'));
}

/// A stand-in for the app root: it rebuilds on the language, and marks the tree
/// dirty afterwards, which is what main.dart does.
class _Root extends StatefulWidget {
  const _Root({required this.repaint});

  /// Whether to run the mark-dirty pass. False reproduces the bug.
  final bool repaint;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  Lang? _painted;

  void _repaintEverything() {
    void mark(Element el) {
      el.markNeedsBuild();
      el.visitChildren(mark);
    }

    context.visitChildElements(mark);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Lang>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) {
        if (widget.repaint && _painted != null && _painted != lang) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _repaintEverything());
        }
        _painted = lang;
        // const, and therefore canonicalised to one instance: the widget the
        // parent hands down is identical every time, which is precisely when
        // Flutter skips the child.
        return const MaterialApp(home: Scaffold(body: _Label()));
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    await AppLocale.set(Lang.ckb);
  });

  testWidgets('a const subtree keeps the old language without the repaint', (tester) async {
    await tester.pumpWidget(const _Root(repaint: false));
    await tester.pumpAndSettle();
    expect(find.text(tableFor(Lang.ckb)['settings.language']!), findsOneWidget);

    await AppLocale.set(Lang.en);
    await tester.pumpAndSettle();

    // This is the bug, asserted so that the fix below is not a coincidence: the
    // English label never appears, because the const child was skipped.
    expect(
      find.text(tableFor(Lang.en)['settings.language']!),
      findsNothing,
      reason: 'if this now passes, Flutter stopped skipping and the guard below is untested',
    );
  });

  testWidgets('the repaint carries the new language into it', (tester) async {
    await tester.pumpWidget(const _Root(repaint: true));
    await tester.pumpAndSettle();
    expect(find.text(tableFor(Lang.ckb)['settings.language']!), findsOneWidget);

    await AppLocale.set(Lang.en);
    await tester.pumpAndSettle();

    expect(find.text(tableFor(Lang.en)['settings.language']!), findsOneWidget,
        reason: 'the page the language was changed on stayed in the old language');
    expect(find.text(tableFor(Lang.ckb)['settings.language']!), findsNothing);
  });

  testWidgets('a pushed route follows too', (tester) async {
    // The real shape of the bug: the settings screen is pushed as
    // `MaterialPageRoute(builder: (_) => const SettingsScreen())`, and a
    // pushed route's subtree is held by the Navigator rather than rebuilt by
    // whatever rebuilt the app above it. That is the second way a page can be
    // skipped, and the one the person actually met.
    await tester.pumpWidget(const _Root(repaint: true));
    await tester.pumpAndSettle();

    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => const _Label())));
    await tester.pumpAndSettle();
    expect(find.text(tableFor(Lang.ckb)['settings.language']!), findsWidgets);

    await AppLocale.set(Lang.en);
    await tester.pumpAndSettle();

    expect(find.text(tableFor(Lang.en)['settings.language']!), findsWidgets,
        reason: 'the pushed page stayed in the old language');
    expect(find.text(tableFor(Lang.ckb)['settings.language']!), findsNothing);
  });

  testWidgets('and back again, in Arabic', (tester) async {
    await tester.pumpWidget(const _Root(repaint: true));
    await tester.pumpAndSettle();

    await AppLocale.set(Lang.ar);
    await tester.pumpAndSettle();
    expect(find.text(tableFor(Lang.ar)['settings.language']!), findsOneWidget);

    await AppLocale.set(Lang.ckb);
    await tester.pumpAndSettle();
    expect(find.text(tableFor(Lang.ckb)['settings.language']!), findsOneWidget);
  });
}
