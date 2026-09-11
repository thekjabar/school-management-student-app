import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/ui/signature_pad.dart';

Widget _pad(SignatureInk ink) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 160,
            child: SignaturePad(ink: ink, colour: const Color(0xFF111827)),
          ),
        ),
      ),
    );

Future<void> _draw(WidgetTester tester) async {
  final centre = tester.getCenter(find.byType(SignaturePad));
  final gesture = await tester.startGesture(centre - const Offset(90, 20));
  for (var step = 1; step <= 8; step++) {
    await gesture.moveBy(Offset(22, step.isEven ? 14 : -14));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('an untouched pad has nothing to send', (tester) async {
    final ink = SignatureInk();
    addTearDown(ink.dispose);

    await tester.pumpWidget(_pad(ink));

    expect(ink.isEmpty, isTrue);
    expect(await ink.toPng(), isNull, reason: 'an empty pad must never upload a blank image');
  });

  testWidgets('a drawn signature exports real PNG bytes', (tester) async {
    final ink = SignatureInk();
    addTearDown(ink.dispose);

    await tester.pumpWidget(_pad(ink));
    await _draw(tester);

    expect(ink.isEmpty, isFalse, reason: 'the Agree button unlocks off this flag');

    final bytes = await tester.runAsync(() => ink.toPng());
    expect(bytes, isNotNull);

    expect(
      bytes!.sublist(0, 8),
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
      reason: 'the server sniffs the PNG magic; anything else is refused',
    );
    expect(
      bytes.length,
      lessThan(2 * 1024 * 1024),
      reason: 'SIGNATURE_IMAGE is capped at 2 MB',
    );
  });

  testWidgets('clearing the pad takes the signature away again', (tester) async {
    final ink = SignatureInk();
    addTearDown(ink.dispose);

    await tester.pumpWidget(_pad(ink));
    await _draw(tester);
    expect(ink.isEmpty, isFalse);

    ink.clear();
    await tester.pump();

    expect(ink.isEmpty, isTrue);
    expect(await ink.toPng(), isNull);
  });

  testWidgets('a stroke that runs off the pad stays inside the picture', (tester) async {
    final ink = SignatureInk();
    addTearDown(ink.dispose);

    await tester.pumpWidget(_pad(ink));

    final centre = tester.getCenter(find.byType(SignaturePad));
    final gesture = await tester.startGesture(centre);
    await gesture.moveBy(const Offset(400, 400));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(ink.isEmpty, isFalse);
    expect(await tester.runAsync(() => ink.toPng()), isNotNull);
  });
}
