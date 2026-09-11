import 'package:flutter/material.dart';

enum NavGlyph { home, messages, calendar, profile, route, students }

class NavGlyphIcon extends StatelessWidget {
  const NavGlyphIcon({
    super.key,
    required this.glyph,
    required this.color,
    this.filled = false,
    this.size = 22,
  });

  final NavGlyph glyph;
  final Color color;

  final bool filled;

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(glyph: glyph, color: color, filled: filled),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.glyph, required this.color, required this.filled});

  final NavGlyph glyph;
  final Color color;
  final bool filled;

  static const _weight = 2.1;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _weight
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final solid = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    switch (glyph) {
      case NavGlyph.home:
        _home(canvas, stroke, solid);
      case NavGlyph.messages:
        _messages(canvas, stroke, solid);
      case NavGlyph.calendar:
        _calendar(canvas, stroke, solid);
      case NavGlyph.profile:
        _profile(canvas, stroke, solid);
      case NavGlyph.route:
        _route(canvas, stroke, solid);
      case NavGlyph.students:
        _students(canvas, stroke, solid);
    }

    canvas.restore();
  }

  void _home(Canvas canvas, Paint stroke, Paint solid) {
    final path = Path()
      ..moveTo(12, 3.7)
      ..lineTo(20.5, 10.7)
      ..lineTo(20.5, 19.6)
      ..lineTo(14.7, 19.6)
      ..lineTo(14.7, 16.2)
      ..lineTo(9.3, 16.2)
      ..lineTo(9.3, 19.6)
      ..lineTo(3.5, 19.6)
      ..lineTo(3.5, 10.7)
      ..close();

    if (filled) {
      canvas.drawPath(path, solid);
      canvas.drawPath(path, stroke..strokeWidth = _weight);
    } else {
      canvas.drawPath(path, stroke..strokeWidth = _weight);
    }
  }

  void _messages(Canvas canvas, Paint stroke, Paint solid) {
    final bubble = Path()
      ..addRRect(RRect.fromLTRBR(4.3, 3.5, 19.7, 16.6, const Radius.circular(6.6)));
    final tail = Path()
      ..moveTo(10.2, 14.4)
      ..lineTo(4.6, 20.6)
      ..lineTo(9.0, 14.0)
      ..close();
    final shape = Path.combine(PathOperation.union, bubble, tail);

    if (filled) {
      canvas.drawPath(shape, solid);
    } else {
      canvas.drawPath(shape, stroke);
      for (final x in [8.4, 12.0, 15.6]) {
        canvas.drawCircle(Offset(x, 10.0), 1.15, solid);
      }
    }
  }

  void _calendar(Canvas canvas, Paint stroke, Paint solid) {
    final body = RRect.fromLTRBR(3.2, 5.3, 20.8, 21.0, const Radius.circular(3.4));
    if (filled) {
      canvas.drawRRect(body, solid);
    } else {
      canvas.drawRRect(body, stroke);
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _weight
      ..strokeCap = StrokeCap.round
      ..color = filled ? const Color(0xFFFFFFFF) : color;
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = filled ? const Color(0xFFFFFFFF) : color;

    canvas.drawLine(const Offset(3.2, 9.9), const Offset(20.8, 9.9), line);
    canvas.drawLine(const Offset(8.1, 3.1), const Offset(8.1, 7.3), line);
    canvas.drawLine(const Offset(15.9, 3.1), const Offset(15.9, 7.3), line);

    canvas.drawCircle(const Offset(10.2, 14.6), 1.05, dot);
    canvas.drawCircle(const Offset(13.8, 14.6), 1.05, dot);
  }

  void _profile(Canvas canvas, Paint stroke, Paint solid) {
    canvas.drawCircle(const Offset(12, 7.9), 4.0, filled ? solid : stroke);

    final shoulders = Path()
      ..moveTo(4.8, 21.0)
      ..lineTo(4.8, 19.6)
      ..cubicTo(4.8, 16.3, 8.0, 14.6, 12.0, 14.6)
      ..cubicTo(16.0, 14.6, 19.2, 16.3, 19.2, 19.6)
      ..lineTo(19.2, 21.0);
    canvas.drawPath(
      shoulders,
      filled
          ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = color)
          : stroke,
    );
  }

  void _route(Canvas canvas, Paint stroke, Paint solid) {
    final outline = Path()
      ..moveTo(2.6, 6.2)
      ..lineTo(8.7, 3.4)
      ..lineTo(15.3, 6.6)
      ..lineTo(21.4, 3.8)
      ..lineTo(21.4, 17.8)
      ..lineTo(15.3, 20.6)
      ..lineTo(8.7, 17.4)
      ..lineTo(2.6, 20.2)
      ..close();
    canvas.drawPath(outline, filled ? solid : stroke);

    final crease = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _weight
      ..strokeCap = StrokeCap.round
      ..color = filled ? const Color(0xFFFFFFFF) : color;
    canvas.drawLine(const Offset(8.7, 3.4), const Offset(8.7, 17.4), crease);
    canvas.drawLine(const Offset(15.3, 6.6), const Offset(15.3, 20.6), crease);
  }

  void _students(Canvas canvas, Paint stroke, Paint solid) {
    final back = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _weight
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    canvas.drawCircle(const Offset(16.6, 7.6), 3.1, filled ? solid : back);
    canvas.drawPath(
      Path()
        ..moveTo(15.2, 13.4)
        ..cubicTo(19.2, 13.0, 21.6, 15.2, 21.6, 18.6)
        ..lineTo(21.6, 20.2),
      filled
          ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..color = color)
          : back,
    );

    canvas.drawCircle(const Offset(9.2, 8.4), 3.7, filled ? solid : stroke);
    canvas.drawPath(
      Path()
        ..moveTo(2.8, 20.4)
        ..lineTo(2.8, 19.2)
        ..cubicTo(2.8, 16.2, 5.6, 14.6, 9.2, 14.6)
        ..cubicTo(12.8, 14.6, 15.6, 16.2, 15.6, 19.2)
        ..lineTo(15.6, 20.4),
      filled
          ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = color)
          : stroke,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.filled != filled;
}

class HeartPersonIcon extends StatelessWidget {
  const HeartPersonIcon({super.key, required this.color, this.size = 22});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HeartPersonPainter(color)),
    );
  }
}

class _HeartPersonPainter extends CustomPainter {
  _HeartPersonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final heart = Path()
      ..moveTo(12, 10.6)
      ..cubicTo(12, 10.6, 7.4, 7.9, 7.4, 5.2)
      ..cubicTo(7.4, 3.5, 8.8, 2.4, 10.1, 2.4)
      ..cubicTo(11.0, 2.4, 11.7, 2.9, 12, 3.5)
      ..cubicTo(12.3, 2.9, 13.0, 2.4, 13.9, 2.4)
      ..cubicTo(15.2, 2.4, 16.6, 3.5, 16.6, 5.2)
      ..cubicTo(16.6, 7.9, 12, 10.6, 12, 10.6)
      ..close();
    canvas.drawPath(heart, stroke);

    final body = Path()
      ..moveTo(4.6, 21.2)
      ..lineTo(4.6, 19.4)
      ..cubicTo(4.6, 15.9, 7.9, 13.8, 12, 13.8)
      ..cubicTo(16.1, 13.8, 19.4, 15.9, 19.4, 19.4)
      ..lineTo(19.4, 21.2);
    canvas.drawPath(body, stroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeartPersonPainter old) => old.color != color;
}
