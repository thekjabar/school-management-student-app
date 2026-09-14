import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/driver/run_driving.dart';
import 'package:student_app/screens/driver/trip_screen.dart';
import 'package:student_app/screens/parent/settings_screen.dart';
import 'package:student_app/screens/teacher/homework_tab.dart';
import 'package:student_app/ui/async.dart';
import 'package:student_app/ui/kit.dart';
import 'package:student_app/ui/pickers.dart';
import 'package:student_app/ui/screen_kit.dart';
import 'package:student_app/ui/settings_widgets.dart';
import 'package:student_app/ui/sheets.dart';

const _portrait = Size(390, 844);
const _landscape = Size(844, 390);

const _notchTop = 47.0;
const _gestureBottom = 34.0;
const _cutoutSide = 44.0;
const _keyboard = 300.0;

void _phone(
  WidgetTester tester, {
  Size size = _portrait,
  FakeViewPadding padding = const FakeViewPadding(top: _notchTop, bottom: _gestureBottom),
  FakeViewPadding insets = FakeViewPadding.zero,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  tester.view.viewInsets = insets;
  addTearDown(tester.view.reset);
}

Rect _safeRegion(WidgetTester tester, {bool keyboard = false}) {
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;
  final pad = view.viewPadding;
  final bottom = keyboard ? view.viewInsets.bottom : pad.bottom;
  return Rect.fromLTRB(pad.left, pad.top, size.width - pad.right, size.height - bottom);
}

void _expectInside(WidgetTester tester, Finder finder, Rect safe, {String? reason}) {
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(safe.top - 0.01), reason: '${reason ?? finder} top $rect vs $safe');
  expect(rect.left, greaterThanOrEqualTo(safe.left - 0.01), reason: '${reason ?? finder} left $rect vs $safe');
  expect(rect.right, lessThanOrEqualTo(safe.right + 0.01), reason: '${reason ?? finder} right $rect vs $safe');
  expect(rect.bottom, lessThanOrEqualTo(safe.bottom + 0.01), reason: '${reason ?? finder} bottom $rect vs $safe');
}

Future<void> _app(WidgetTester tester, Widget home) async {
  AppLocale.current.value = Lang.en;
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pump();
}

List<NavItem> get _items => const [
      NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
      NavItem(Icons.sms_rounded, Icons.sms_outlined, 'Messages'),
      NavItem(Icons.event_rounded, Icons.event_outlined, 'Calendar'),
      NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
    ];

Widget _shell({required Widget body}) => Scaffold(
      body: body,
      bottomNavigationBar: CenterActionNav(
        items: _items,
        index: 0,
        tint: Colors.teal,
        onChanged: (_) {},
        centerIcon: Icons.add_rounded,
        centerLabel: 'Leave',
        onCenter: () {},
      ),
    );

void main() {
  group('ScreenHeader', () {
    testWidgets('keeps the back button and title below the status bar and notch', (tester) async {
      _phone(tester);
      await _app(tester, const Scaffold(body: Column(children: [ScreenHeader(title: 'Fees')])));

      final safe = _safeRegion(tester);
      _expectInside(tester, find.byIcon(Icons.arrow_back_rounded), safe);
      _expectInside(tester, find.text('Fees'), safe);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not pad twice when the screen already has a SafeArea', (tester) async {
      _phone(tester);
      await _app(
        tester,
        const Scaffold(body: SafeArea(child: Column(children: [ScreenHeader(title: 'Fees')]))),
      );

      final top = tester.getRect(find.byIcon(Icons.arrow_back_rounded)).top;
      expect(top, lessThan(_notchTop + 20));
    });

    testWidgets('stays clear of a landscape display cutout on either side', (tester) async {
      _phone(
        tester,
        size: _landscape,
        padding: const FakeViewPadding(left: _cutoutSide, right: _cutoutSide, bottom: 21),
      );
      await _app(
        tester,
        Scaffold(
          body: Column(
            children: [
              ScreenHeader(
                title: 'Fees',
                action: IconButton(icon: const Icon(Icons.sos_rounded), onPressed: () {}),
              ),
            ],
          ),
        ),
      );

      final safe = _safeRegion(tester);
      _expectInside(tester, find.byIcon(Icons.arrow_back_rounded), safe);
      _expectInside(tester, find.byIcon(Icons.sos_rounded), safe);
    });
  });

  group('CenterActionNav', () {
    testWidgets('bar and the floating centre button sit above the gesture bar', (tester) async {
      _phone(tester);
      await _app(tester, _shell(body: const SizedBox.expand()));

      final safe = _safeRegion(tester);
      _expectInside(tester, find.text('Leave'), safe);
      _expectInside(tester, find.byIcon(Icons.add_rounded), safe);
      for (final label in ['Home', 'Messages', 'Calendar', 'Profile']) {
        _expectInside(tester, find.text(label), safe);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays inside the cutouts in landscape', (tester) async {
      _phone(
        tester,
        size: _landscape,
        padding: const FakeViewPadding(left: _cutoutSide, right: _cutoutSide, bottom: 21),
      );
      await _app(tester, _shell(body: const SizedBox.expand()));

      final safe = _safeRegion(tester);
      _expectInside(tester, find.text('Home'), safe);
      _expectInside(tester, find.text('Profile'), safe);
      _expectInside(tester, find.byIcon(Icons.add_rounded), safe);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 3-button navigation bar does not cover the tabs', (tester) async {
      _phone(tester, padding: const FakeViewPadding(top: 24, bottom: 48));
      await _app(tester, _shell(body: const SizedBox.expand()));

      _expectInside(tester, find.text('Profile'), _safeRegion(tester));
    });
  });

  group('Loader', () {
    Widget page() => Scaffold(
          body: SafeArea(
            bottom: false,
            child: Loader<int>(
              load: () async => 1,
              builder: (context, _) => Column(
                children: [
                  for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('row $i')),
                ],
              ),
            ),
          ),
        );

    testWidgets('the last row scrolls fully clear of the gesture bar', (tester) async {
      _phone(tester);
      await _app(tester, page());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      _expectInside(tester, find.text('row 29'), _safeRegion(tester));
    });

    testWidgets('adds nothing extra behind a bottom navigation bar', (tester) async {
      _phone(tester);
      await _app(tester, _shell(body: page()));
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.padding!.resolve(TextDirection.ltr).bottom, 28);
    });
  });

  group('showAppSheet', () {
    testWidgets('an option sheet keeps its last choice above the gesture bar', (tester) async {
      _phone(tester);
      await _app(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => pickOne<int>(
                  context,
                  tint: Colors.teal,
                  title: 'Pick',
                  options: [for (var i = 0; i < 3; i++) PickOption(value: i, label: 'choice $i')],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      _expectInside(tester, find.text('choice 2'), _safeRegion(tester));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a form sheet keeps its button clear of the gesture bar and the keyboard', (tester) async {
      _phone(tester);
      late BuildContext host;
      await _app(
        tester,
        Scaffold(
          body: Builder(builder: (context) {
            host = context;
            return const SizedBox.expand();
          }),
        ),
      );
      showAppSheet<void>(host, builder: (_) => const ChangePasswordSheet(tint: Colors.teal));
      await tester.pumpAndSettle();

      final save = find.text(t('common.save'));
      _expectInside(tester, save, _safeRegion(tester));

      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      tester.view.padding = const FakeViewPadding(top: _notchTop);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final scroller = find.descendant(
        of: find.byType(ChangePasswordSheet),
        matching: find.byType(Scrollable),
      );
      final above = _safeRegion(tester, keyboard: true);
      _expectInside(tester, scroller.first, above);

      await tester.drag(scroller.first, const Offset(0, -600));
      await tester.pumpAndSettle();
      _expectInside(tester, save, above);
    });
  });

  group('showNote', () {
    testWidgets('a floating note on a screen without a bottom bar clears the gesture bar', (tester) async {
      _phone(tester);
      late BuildContext host;
      await _app(
        tester,
        Scaffold(
          body: Builder(builder: (context) {
            host = context;
            return const SizedBox.expand();
          }),
        ),
      );
      showNote(host, 'Saved');
      await tester.pumpAndSettle();

      _expectInside(tester, find.byType(SnackBar), _safeRegion(tester));
    });

    testWidgets('a floating note in a shell sits above the bottom navigation', (tester) async {
      _phone(tester);
      late BuildContext host;
      await _app(
        tester,
        _shell(
          body: Builder(builder: (context) {
            host = context;
            return const SizedBox.expand();
          }),
        ),
      );
      showNote(host, 'Saved');
      await tester.pumpAndSettle();

      final note = tester.getRect(find.byType(SnackBar));
      final nav = tester.getRect(find.byType(CenterActionNav));
      expect(note.bottom, lessThanOrEqualTo(nav.top + 0.01));
    });
  });

  group('parent Settings screen', () {
    for (final landscape in [false, true]) {
      testWidgets('header and the last row stay inside the safe region${landscape ? ' in landscape' : ''}',
          (tester) async {
        _phone(
          tester,
          size: landscape ? _landscape : const Size(390, 560),
          padding: landscape
              ? const FakeViewPadding(left: _cutoutSide, right: _cutoutSide, bottom: 21)
              : const FakeViewPadding(top: _notchTop, bottom: _gestureBottom),
        );
        await _app(tester, const SettingsScreen());
        await tester.pumpAndSettle();

        final safe = _safeRegion(tester);
        _expectInside(tester, find.byIcon(Icons.arrow_back_rounded), safe);

        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        _expectInside(
          tester,
          find.ancestor(of: find.text(t('more.changePasswordSub')), matching: find.byType(Card16)),
          safe,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('teacher Homework screen', () {
    testWidgets('header and the Set homework button stay inside, and the list clears both', (tester) async {
      _phone(tester);
      await _app(tester, const HomeworkTab());
      await tester.pumpAndSettle();

      final safe = _safeRegion(tester);
      _expectInside(tester, find.byIcon(Icons.arrow_back_rounded), safe);
      _expectInside(tester, find.byType(FloatingActionButton), safe);

      final list = tester.widget<ListView>(find.byType(ListView).first);
      final fab = tester.getRect(find.byType(FloatingActionButton));
      final bottomRoom = list.padding!.resolve(TextDirection.ltr).bottom;
      expect(_portrait.height - bottomRoom, lessThanOrEqualTo(fab.top));
      expect(tester.takeException(), isNull);
    });
  });

  group('driver map', () {
    Widget fullScreenMap() {
      final driving = RunDriving(
        stopPanel: (_, _, _) => const SizedBox.shrink(),
        schoolPanel: (_, _) => null,
        runBar: (_, _) => SizedBox(
          height: 56,
          child: FilledButton(onPressed: () {}, child: const Text('Arrived')),
        ),
        sos: (_, _) => null,
      )..publish(const RunSnapshot(trip: null, leg: 'OUT', stops: [], planStops: [], school: null));

      return Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.green)),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: RunMapSheet(driving: driving, selection: null, onClose: () {}),
            ),
          ],
        ),
      );
    }

    testWidgets('the action panel sits on the map but above the gesture bar', (tester) async {
      _phone(tester);
      await _app(tester, fullScreenMap());

      final safe = _safeRegion(tester);
      _expectInside(tester, find.text('Arrived'), safe);
      _expectInside(tester, find.text(t('driver.map.tapStopHint')), safe);
      expect(tester.getRect(find.byType(RunMapSheet)).bottom, _portrait.height);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the action panel clears landscape cutouts', (tester) async {
      _phone(
        tester,
        size: _landscape,
        padding: const FakeViewPadding(left: _cutoutSide, right: _cutoutSide, bottom: 21),
      );
      await _app(tester, fullScreenMap());

      _expectInside(tester, find.text('Arrived'), _safeRegion(tester));
      expect(tester.takeException(), isNull);
    });

    Future<void> openSkip(WidgetTester tester) async {
      late BuildContext host;
      await _app(
        tester,
        Scaffold(
          body: Builder(builder: (context) {
            host = context;
            return const SizedBox.expand();
          }),
        ),
      );
      showAppSheet<String>(host, builder: (_) => const SkipStopSheet());
      await tester.pumpAndSettle();
    }

    testWidgets('the skip-stop sheet keeps its button above the gesture bar and the keyboard', (tester) async {
      _phone(tester);
      await openSkip(tester);
      final skip = find.text(t('driver.skipConfirm'));
      _expectInside(tester, skip, _safeRegion(tester));

      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      tester.view.padding = const FakeViewPadding(top: _notchTop);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      _expectInside(tester, skip, _safeRegion(tester, keyboard: true));
    });

    testWidgets('the skip-stop sheet does not overflow with a keyboard in landscape', (tester) async {
      _phone(
        tester,
        size: _landscape,
        padding: const FakeViewPadding(left: _cutoutSide, right: _cutoutSide, bottom: 21),
      );
      await openSkip(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      tester.view.padding = const FakeViewPadding(left: _cutoutSide, right: _cutoutSide);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final sheet = tester.getRect(find.byType(SkipStopSheet));
      expect(sheet.left, greaterThanOrEqualTo(_cutoutSide));
      expect(sheet.right, lessThanOrEqualTo(_landscape.width - _cutoutSide));
    });
  });

  group('confirmDialog', () {
    testWidgets('stays inside the safe region in landscape', (tester) async {
      _phone(
        tester,
        size: _landscape,
        padding: const FakeViewPadding(left: _cutoutSide, right: _cutoutSide, bottom: 21),
      );
      late BuildContext host;
      await _app(
        tester,
        Scaffold(
          body: Builder(builder: (context) {
            host = context;
            return const SizedBox.expand();
          }),
        ),
      );
      confirmDialog(
        host,
        icon: Icons.warning_rounded,
        title: 'End the run?',
        body: 'Every child is off the bus.',
        confirmLabel: 'End',
      );
      await tester.pumpAndSettle();

      final safe = _safeRegion(tester);
      _expectInside(tester, find.byType(Dialog), safe);
    });
  });
}
