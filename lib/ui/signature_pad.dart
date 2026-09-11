import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const Color kSignatureInkOnPaper = Color(0xFF111827);
const Color kSignaturePaper = Color(0xFFFFFFFF);

class SignatureInk extends ChangeNotifier {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  Size _size = Size.zero;

  bool get isEmpty => !_strokes.any((stroke) => stroke.length > 1);

  void begin(Offset at, Size size) {
    _size = size;
    _strokes.add(<Offset>[_inside(at, size)]);
    notifyListeners();
  }

  void extend(Offset at) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(_inside(at, _size));
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    notifyListeners();
  }

  void paint(Canvas canvas, Color colour) {
    final brush = Paint()
      ..color = colour
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (final stroke in _strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, Paint()..color = colour..isAntiAlias = true);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, brush);
    }
  }

  Future<Uint8List?> toPng({double scale = 2}) async {
    if (isEmpty || _size.width <= 0 || _size.height <= 0) return null;

    final width = (_size.width * scale).round();
    final height = (_size.height * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    canvas.scale(scale);
    canvas.clipRect(Rect.fromLTWH(0, 0, _size.width, _size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _size.width, _size.height),
      Paint()..color = kSignaturePaper,
    );
    paint(canvas, kSignatureInkOnPaper);

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        return bytes?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  Offset _inside(Offset at, Size size) =>
      Offset(at.dx.clamp(0.0, size.width), at.dy.clamp(0.0, size.height));
}

class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.ink, required this.colour});

  final SignatureInk ink;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            _PadRecognizer: GestureRecognizerFactoryWithHandlers<_PadRecognizer>(
              _PadRecognizer.new,
              (recognizer) => recognizer
                ..onStart = ((details) => ink.begin(details.localPosition, size))
                ..onUpdate = ((details) => ink.extend(details.localPosition)),
            ),
          },
          child: CustomPaint(
            painter: _InkPainter(ink: ink, colour: colour),
            size: size,
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _PadRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter({required this.ink, required this.colour}) : super(repaint: ink);

  final SignatureInk ink;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) => ink.paint(canvas, colour);

  @override
  bool shouldRepaint(_InkPainter old) => old.ink != ink || old.colour != colour;
}
