import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The illustration on the welcome screen: a school, and a family walking to it.
///
/// Drawn rather than shipped as an image, for three reasons that matter more
/// than the drawing being harder. It weighs nothing in the APK; it is sharp on
/// every screen density from a 720p Android to a tablet; and it recolours with
/// the role, so the same scene sits under a violet parent app and an orange
/// driver app without maintaining four PNGs.
///
/// Everything is laid out in a 0..1 box and scaled to whatever size it is
/// given, so the composition holds at any width.
class SchoolScene extends StatelessWidget {
  const SchoolScene({super.key, required this.tint, this.height = 210});

  final Color tint;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _ScenePainter(tint)),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.tint);

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Everything below is expressed against a 0..1 box, so one set of numbers
    // describes the composition at any size.
    Offset p(double x, double y) => Offset(x * w, y * h);
    Rect box(double x, double y, double bw, double bh) =>
        Rect.fromLTWH(x * w, y * h, bw * w, bh * h);

    final paint = Paint()..isAntiAlias = true;

    final skin = const Color(0xFFF2C6A0);
    final ground = tint.withValues(alpha: 0.10);
    final wall = Colors.white;
    final wallShade = const Color(0xFFF3F1FB);
    final leaf = const Color(0xFF4BAE7E);
    final leafDark = const Color(0xFF3C9B6E);
    final trunk = const Color(0xFFB08160);

    // ---- Ground -----------------------------------------------------------
    paint.color = ground;
    canvas.drawRRect(
      RRect.fromRectAndRadius(box(0.02, 0.74, 0.96, 0.22), Radius.circular(0.09 * h)),
      paint,
    );

    // ---- Sun ---------------------------------------------------------------
    paint.color = const Color(0xFFFFD166).withValues(alpha: 0.75);
    canvas.drawCircle(p(0.86, 0.14), 0.055 * h * 1.6, paint);

    // ---- Clouds ------------------------------------------------------------
    paint.color = Colors.white.withValues(alpha: 0.85);
    void cloud(double cx, double cy, double s) {
      canvas.drawCircle(p(cx, cy), 0.05 * h * s, paint);
      canvas.drawCircle(p(cx + 0.035, cy - 0.02), 0.065 * h * s, paint);
      canvas.drawCircle(p(cx + 0.075, cy), 0.048 * h * s, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((cx - 0.005) * w, cy * h, 0.088 * w, 0.055 * h * s),
          Radius.circular(0.03 * h),
        ),
        paint,
      );
    }

    cloud(0.08, 0.13, 1.0);
    cloud(0.62, 0.08, 0.75);

    // ---- The school --------------------------------------------------------
    // Body
    paint.color = wall;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        box(0.30, 0.34, 0.40, 0.42),
        topLeft: Radius.circular(0.02 * h),
        topRight: Radius.circular(0.02 * h),
      ),
      paint,
    );

    // Roof — a broad trapezoid, which reads as a school rather than a house.
    paint.color = tint;
    final roof = Path()
      ..moveTo(0.26 * w, 0.34 * h)
      ..lineTo(0.50 * w, 0.17 * h)
      ..lineTo(0.74 * w, 0.34 * h)
      ..close();
    canvas.drawPath(roof, paint);

    // The little bell tower and its flag.
    paint.color = wallShade;
    canvas.drawRRect(
      RRect.fromRectAndRadius(box(0.468, 0.115, 0.064, 0.075), Radius.circular(0.012 * h)),
      paint,
    );
    paint.color = tint;
    canvas.drawRect(box(0.4975, 0.055, 0.005, 0.07), paint);
    final flag = Path()
      ..moveTo(0.5025 * w, 0.058 * h)
      ..lineTo(0.575 * w, 0.082 * h)
      ..lineTo(0.5025 * w, 0.106 * h)
      ..close();
    canvas.drawPath(flag, paint);

    // Clock on the tower.
    paint.color = Colors.white;
    canvas.drawCircle(p(0.5, 0.152), 0.021 * h, paint);
    paint
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.006 * h;
    canvas.drawCircle(p(0.5, 0.152), 0.021 * h, paint);
    paint.style = PaintingStyle.fill;

    // Door
    paint.color = tint.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        box(0.457, 0.575, 0.086, 0.185),
        topLeft: Radius.circular(0.04 * h),
        topRight: Radius.circular(0.04 * h),
      ),
      paint,
    );
    paint.color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(p(0.528, 0.672), 0.008 * h, paint);

    // Windows, in two rows.
    for (final wy in [0.405, 0.56]) {
      for (final wx in [0.345, 0.598]) {
        paint.color = wallShade;
        canvas.drawRRect(
          RRect.fromRectAndRadius(box(wx, wy, 0.058, 0.085), Radius.circular(0.014 * h)),
          paint,
        );
        paint.color = tint.withValues(alpha: 0.35);
        canvas.drawRRect(
          RRect.fromRectAndRadius(box(wx + 0.008, wy + 0.012, 0.042, 0.061), Radius.circular(0.01 * h)),
          paint,
        );
      }
    }

    // Steps
    paint.color = wallShade;
    canvas.drawRRect(
      RRect.fromRectAndRadius(box(0.428, 0.755, 0.144, 0.022), Radius.circular(0.008 * h)),
      paint,
    );

    // ---- Trees -------------------------------------------------------------
    void tree(double cx, double baseY, double scale) {
      paint.color = trunk;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((cx - 0.009) * w, (baseY - 0.10 * scale) * h, 0.018 * w, 0.11 * scale * h),
          Radius.circular(0.01 * h),
        ),
        paint,
      );
      paint.color = leaf;
      canvas.drawCircle(p(cx, baseY - 0.155 * scale), 0.062 * h * scale, paint);
      paint.color = leafDark;
      canvas.drawCircle(p(cx - 0.028, baseY - 0.115 * scale), 0.046 * h * scale, paint);
      paint.color = leaf;
      canvas.drawCircle(p(cx + 0.030, baseY - 0.118 * scale), 0.050 * h * scale, paint);
    }

    tree(0.155, 0.80, 1.0);
    tree(0.855, 0.795, 0.92);

    // ---- The family --------------------------------------------------------
    // An adult and two children, walking in. Deliberately simple geometry: a
    // realistic figure at this size becomes a smudge, and a school app's
    // artwork should not be the most detailed thing on the screen.
    void person({
      required double cx,
      required double feetY,
      required double scale,
      required Color clothes,
      required Color hair,
      bool bag = false,
    }) {
      final headR = 0.040 * h * scale;
      final bodyH = 0.115 * h * scale;
      final bodyW = 0.055 * w * scale;
      final bodyTop = feetY * h - bodyH;

      // Legs
      paint.color = const Color(0xFF3B4256);
      for (final dx in [-0.010, 0.010]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH((cx + dx) * w - 0.007 * w, bodyTop + bodyH * 0.82, 0.014 * w, 0.052 * h * scale),
            Radius.circular(0.01 * h),
          ),
          paint,
        );
      }

      // Satchel, behind the body.
      if (bag) {
        paint.color = clothes.withValues(alpha: 0.55);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx * w + bodyW * 0.42, bodyTop + bodyH * 0.12, 0.030 * w, 0.075 * h * scale),
            Radius.circular(0.014 * h),
          ),
          paint,
        );
      }

      // Body
      paint.color = clothes;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx * w - bodyW / 2, bodyTop, bodyW, bodyH),
          Radius.circular(0.028 * h),
        ),
        paint,
      );

      // Head and hair
      final headC = Offset(cx * w, bodyTop - headR * 0.72);
      paint.color = skin;
      canvas.drawCircle(headC, headR, paint);
      paint.color = hair;
      canvas.drawArc(
        Rect.fromCircle(center: headC, radius: headR),
        math.pi,
        math.pi,
        true,
        paint,
      );
    }

    person(cx: 0.245, feetY: 0.905, scale: 1.18, clothes: tint, hair: const Color(0xFF2F2A3D), bag: false);
    person(cx: 0.345, feetY: 0.915, scale: 0.80, clothes: const Color(0xFF4BAE7E), hair: const Color(0xFF3A2E28), bag: true);
    person(cx: 0.745, feetY: 0.912, scale: 0.86, clothes: const Color(0xFF3B82F6), hair: const Color(0xFF241F2E), bag: true);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.tint != tint;
}
