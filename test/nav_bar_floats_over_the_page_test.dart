import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/theme/app_theme.dart';
import 'package:student_app/ui/kit.dart';

const _gesture = EdgeInsets.only(bottom: 24, top: 40);

void _ignore(int _) {}

void _nothing() {}

Widget _shell(Widget body) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), padding: _gesture, viewPadding: _gesture),
        child: Scaffold(
          backgroundColor: AppTheme.canvas,
          extendBody: true,
          body: body,
          bottomNavigationBar: CenterActionNav(
            items: const [
              NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
              NavItem(Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Messages'),
              NavItem(Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'Calendar'),
              NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
            ],
            index: 0,
            tint: Colors.deepPurple,
            onChanged: _ignore,
            centerIcon: Icons.add_rounded,
            centerLabel: 'Leave',
            onCenter: _nothing,
          ),
        ),
      ),
    );

void main() {
  testWidgets('the page runs under the bar, and the bar floats clear of the edges', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell(const SizedBox.expand(key: Key('page'))));

    final screen = tester.getRect(find.byType(Scaffold));
    final page = tester.getRect(find.byKey(const Key('page')));
    expect(page.bottom, screen.bottom, reason: 'the page stops above the bar instead of running under it');

    final pill = tester
        .widgetList<Container>(find.descendant(of: find.byType(CenterActionNav), matching: find.byType(Container)))
        .firstWhere((c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).color == AppTheme.surface);
    final bar = tester.getRect(find.byWidget(pill));

    expect(bar.left, greaterThan(screen.left), reason: 'the bar touches the left edge instead of floating');
    expect(bar.right, lessThan(screen.right), reason: 'the bar touches the right edge instead of floating');
    expect(bar.bottom, lessThan(screen.bottom - _gesture.bottom),
        reason: 'the bar reaches into the gesture area instead of floating above it');

    final corners = (pill.decoration as BoxDecoration).borderRadius! as BorderRadius;
    expect(corners.bottomLeft.x, greaterThan(0), reason: 'the bar lost its rounded bottom corners');
  });

  testWidgets('a list is given room to scroll clear of the floating bar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late double roomBelow;
    await tester.pumpWidget(_shell(Builder(builder: (context) {
      roomBelow = MediaQuery.paddingOf(context).bottom;
      return const SizedBox.expand();
    })));

    expect(roomBelow, greaterThan(_gesture.bottom),
        reason: 'a list padded with the bottom inset would still end behind the bar');
  });
}
