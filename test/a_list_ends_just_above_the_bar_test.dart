import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/theme/app_theme.dart';
import 'package:student_app/ui/async.dart';
import 'package:student_app/ui/insets.dart';
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
  testWidgets('scrolled to the end, the last card stops just above the bar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell(Builder(builder: (context) => Loader<int>(
      tint: Colors.deepPurple,
      padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(14, 0, 14, 18)),
      load: () async => 12,
      builder: (context, rows) => Column(
        children: [
          for (var i = 0; i < rows; i++)
            Container(key: ValueKey('card$i'), height: 120, margin: const EdgeInsets.only(bottom: 10)),
        ],
      ),
    ))));
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -3000));
    await tester.pumpAndSettle();

    final pill = tester
        .widgetList<Container>(find.descendant(of: find.byType(CenterActionNav), matching: find.byType(Container)))
        .firstWhere((c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).color == AppTheme.surface);
    final bar = tester.getRect(find.byWidget(pill));
    final lastCard = tester.getRect(find.byKey(const ValueKey('card11')));

    final gap = bar.top - lastCard.bottom;
    expect(gap, greaterThanOrEqualTo(0), reason: 'the last card is hidden behind the bar');
    expect(gap, lessThan(40), reason: 'there is a hole of ${gap.round()} pixels above the bar');
  });
}
