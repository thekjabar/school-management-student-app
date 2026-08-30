// The splash has to cover the app underneath it. All of it.
//
// It did not: the curtain was laid out with loose constraints, FittedBox sized
// itself to the clip's aspect ratio rather than to the screen, and a 9:16 clip
// on a 9:19.5 phone left the bottom quarter of the app showing — bottom bar and
// all — behind the opening animation. Reported by the user, which is the wrong
// way to find out.
//
// No video decodes inside a test binding, so the frame that carried the bug
// cannot be rendered here. What CAN be pinned is the thing that caused it: the
// Stack must hand its children tight constraints, and the pre-roll must fill
// the screen rather than collapse. Both are asserted below.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/screens/splash_screen.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the curtain is given the whole screen', (tester) async {
    await binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SplashGate(
          // The role colour the curtain paints while the clip decodes. Green
          // here so a failure to cover shows as magenta rather than as this.
          tint: Color(0xFF149447),
          // Something unmistakable underneath: if any of it shows, the curtain
          // is not doing its job.
          child: ColoredBox(color: Color(0xFFFF00FF)),
        ),
      ),
    );
    await tester.pump();

    final stack = tester.widget<Stack>(
      find.descendant(of: find.byType(SplashGate), matching: find.byType(Stack)).first,
    );
    expect(
      stack.fit,
      StackFit.expand,
      reason: 'loose constraints let FittedBox size the curtain to the clip, not the screen',
    );

    final curtain = tester.renderObject<RenderBox>(
      find.descendant(
        of: find.byType(IgnorePointer),
        matching: find.byType(ColoredBox).last,
      ),
    );
    expect(curtain.size, const Size(390, 844), reason: 'the pre-roll does not cover the app');
  });
}
