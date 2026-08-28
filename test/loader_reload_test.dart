// The loader must refetch when the language changes.
//
// The server answers in whatever language the request asked for, so data on
// screen belongs to the language it was fetched in. Before this, changing
// language flipped the labels and left the content in the old language until
// the parent thought to pull down — which reads as the setting not having
// worked, and was exactly the bug reported.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/ui/async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  /// A Loader whose load() records the language it was called in.
  Widget harness(List<Lang> calls) {
    return MaterialApp(
      home: Scaffold(
        body: Loader<String>(
          load: () async {
            calls.add(AppLocale.current.value);
            return 'loaded in ${AppLocale.current.value.code}';
          },
          builder: (context, data) => Text(data),
        ),
      ),
    );
  }

  testWidgets('loads once on first build', (tester) async {
    AppLocale.current.value = Lang.en;
    final calls = <Lang>[];

    await tester.pumpWidget(harness(calls));
    await tester.pumpAndSettle();

    expect(calls, [Lang.en]);
    expect(find.text('loaded in en'), findsOneWidget);
  });

  testWidgets('refetches when the language changes', (tester) async {
    AppLocale.current.value = Lang.en;
    final calls = <Lang>[];

    await tester.pumpWidget(harness(calls));
    await tester.pumpAndSettle();
    expect(find.text('loaded in en'), findsOneWidget);

    await AppLocale.set(Lang.ckb);
    await tester.pumpAndSettle();

    // A second call, in the new language — and the content on screen is the
    // result of THAT call, not the old one relabelled.
    expect(calls, [Lang.en, Lang.ckb]);
    // Lang.ckb.code is 'ku' — the tag Flutter and the API use for Sorani.
    expect(find.text('loaded in ${Lang.ckb.code}'), findsOneWidget);
    expect(find.text('loaded in en'), findsNothing);
  });

  testWidgets('does not refetch when the language is set to what it already is', (tester) async {
    AppLocale.current.value = Lang.en;
    final calls = <Lang>[];

    await tester.pumpWidget(harness(calls));
    await tester.pumpAndSettle();

    // Re-selecting the current language is a no-op. Refetching here would cost
    // a parent on a metered connection a round trip for nothing.
    await AppLocale.set(Lang.en);
    await tester.pumpAndSettle();

    expect(calls, [Lang.en]);
  });

  testWidgets('stops listening once disposed', (tester) async {
    AppLocale.current.value = Lang.en;
    final calls = <Lang>[];

    await tester.pumpWidget(harness(calls));
    await tester.pumpAndSettle();

    // Replace the whole tree, then change language. A loader that kept its
    // listener would call setState after dispose and throw.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('gone'))));
    await tester.pumpAndSettle();

    await AppLocale.set(Lang.ar);
    await tester.pumpAndSettle();

    expect(calls, [Lang.en], reason: 'a disposed loader refetched');
    expect(tester.takeException(), isNull);
  });

  tearDown(() => AppLocale.current.value = Lang.en);
}
