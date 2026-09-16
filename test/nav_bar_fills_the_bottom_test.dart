import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/theme/app_theme.dart';
import 'package:student_app/ui/kit.dart';

const _gesture = EdgeInsets.only(bottom: 24, top: 40);

void _ignore(int _) {}

void _nothing() {}

Widget _shell() => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), padding: _gesture, viewPadding: _gesture),
        child: Scaffold(
          backgroundColor: AppTheme.canvas,
          body: const SizedBox.expand(),
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
  testWidgets('the white of the bar reaches both edges and the bottom of the screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell());

    final screen = tester.getRect(find.byType(Scaffold));
    final painted = tester
        .widgetList<Container>(find.descendant(of: find.byType(CenterActionNav), matching: find.byType(Container)))
        .firstWhere((c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).color == AppTheme.surface);
    final white = tester.getRect(find.byWidget(painted));

    expect(white.bottom, screen.bottom, reason: 'the page shows below the bar');
    expect(white.left, screen.left, reason: 'the page shows at the left of the bar');
    expect(white.right, screen.right, reason: 'the page shows at the right of the bar');

    final corners = (painted.decoration as BoxDecoration).borderRadius! as BorderRadius;
    expect(corners.topLeft.x, greaterThan(0), reason: 'the bar lost its rounded top');
    expect(corners.bottomLeft.x, 0, reason: 'a rounded bottom corner leaves the page showing');

    final home = tester.getRect(find.text('Home'));
    expect(screen.bottom - home.bottom, greaterThanOrEqualTo(_gesture.bottom),
        reason: 'a label sits within the gesture area');
  });
}
