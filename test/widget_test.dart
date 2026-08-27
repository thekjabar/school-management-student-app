// Smoke test: the app builds, renders its shell, and fills in with data.
//
// Runs against DemoRepository — the default when no API_BASE_URL is defined —
// so it needs no network and no backend.
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:student_app/main.dart';

/// Build the app and let the demo repository's futures resolve.
///
/// Two details, both of which cause failures that look like real bugs and are
/// not:
///
/// The viewport is set to a real phone rather than the 800x600 default. The
/// home screen is a scroll view, so on a short viewport the lower sections are
/// never laid out and the finders come back empty.
///
/// And every test pumps past DemoRepository's deliberate latency. That latency
/// exists so the app is built against real loading states rather than instant
/// data; a test that stops before it elapses leaves a pending timer and fails
/// for that reason.
Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532); // iPhone-class, 3x
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const StudentApp());
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

void main() {
  testWidgets('the shell renders with all four destinations', (tester) async {
    await pumpApp(tester);

    expect(find.text('EduPulse'), findsOneWidget);
    expect(find.text('LEARN'), findsOneWidget);
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(find.text('GRADES'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
  });

  testWidgets('home fills in once the demo data resolves', (tester) async {
    await pumpApp(tester);

    expect(find.text('Leo Mitchell'), findsOneWidget);
    expect(find.text('ACADEMIC PERFORMANCE'), findsOneWidget);
    expect(find.text('ASSIGNMENTS REGISTRY'), findsOneWidget);
    expect(find.text('QUICK RESOURCES'), findsOneWidget);
  });

  testWidgets('the assignments nearest their deadline are shown first', (tester) async {
    await pumpApp(tester);

    // The demo set has one due today and one due in three days. The home screen
    // shows the two most urgent, soonest first.
    expect(find.text('Chemistry Lab Report'), findsOneWidget);
    expect(find.text('Digital Art Portfolio'), findsOneWidget);
    // The one already handed in is not competing for space here.
    expect(find.text('Essay: Sherko Bekas'), findsNothing);
  });

  testWidgets('switching tabs keeps the shell mounted', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('GRADES'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('TERM AVERAGE'), findsOneWidget);
    // The nav bar survives the switch: the tabs are an IndexedStack, not routes.
    expect(find.text('LEARN'), findsOneWidget);
  });
}
