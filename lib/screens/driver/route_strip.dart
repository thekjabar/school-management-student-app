import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';

/// The run as a shape, beside the run as a list.
///
/// The design puts a live map here. This app has no tile provider and no map
/// key, so it cannot draw one — and a decorative map that looks live is the
/// worst option on the board: a driver glancing at it would believe a road
/// layout nobody drew. So this is plainly a diagram: the stops in order, the
/// ones behind filled in, the bus at the boundary, and a caption saying so.
///
/// Swap it for a real map the moment there is a provider; the widget's contract
/// is the stop list, which is what a map would take too.
class RouteStrip extends StatelessWidget {
  const RouteStrip({super.key, required this.stops, required this.tint});

  final List<PlannedStop> stops;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final done = stops.where((s) => s.departedAt != null).length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: AppTheme.dark ? 0.10 : 0.06),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _StripPainter(
                total: stops.isEmpty ? 5 : stops.length,
                done: done,
                tint: tint,
                track: AppTheme.dark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.10),
                // The ground a marker sits on, not white. On the dark theme a
                // white pin is the brightest thing on the screen, and this
                // strip is behind the run's own name.
                ground: AppTheme.surface,
              ),
            ),
          ),
          PositionedDirectional(
            start: 8,
            end: 8,
            bottom: 7,
            child: Text(
              t('driver.mapIsADiagram'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8.5, color: AppTheme.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.total,
    required this.done,
    required this.tint,
    required this.track,
    required this.ground,
  });

  final int total;
  final int done;
  final Color tint;
  final Color track;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 20 || size.height < 20) return;

    // A lazy S down the panel. The exact curve carries no information — it is
    // there so the eye reads "a route" rather than "a progress bar", and so the
    // stop markers have somewhere to sit that is not a straight line.
    final left = size.width * 0.22;
    final right = size.width * 0.78;
    final top = size.height * 0.14;
    final bottom = size.height * 0.80;

    final path = Path()
      ..moveTo(right, top)
      ..cubicTo(
        right - size.width * 0.05, top + (bottom - top) * 0.30,
        left - size.width * 0.02, top + (bottom - top) * 0.34,
        left + size.width * 0.04, top + (bottom - top) * 0.60,
      )
      ..cubicTo(
        left + size.width * 0.10, bottom - (bottom - top) * 0.10,
        right - size.width * 0.16, bottom - (bottom - top) * 0.02,
        right - size.width * 0.06, bottom,
      );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = track,
    );

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final length = metric.length;

    // The part already driven, drawn over the track.
    final ratio = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    if (ratio > 0) {
      canvas.drawPath(
        metric.extractPath(0, length * ratio),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..color = tint,
      );
    }

    // A marker per stop, evenly along the curve. Evenly rather than by distance
    // because the curve is not a map: spacing them by real metres would imply a
    // geography this drawing does not have.
    final shown = math.min(total, 6);
    for (var i = 0; i < shown; i++) {
      final at = shown == 1 ? 0.5 : i / (shown - 1);
      final pos = metric.getTangentForOffset(length * at)?.position;
      if (pos == null) continue;
      final passed = at <= ratio;
      canvas.drawCircle(
        pos,
        passed ? 5.0 : 4.2,
        Paint()..color = passed ? tint : ground,
      );
      canvas.drawCircle(
        pos,
        passed ? 5.0 : 4.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = passed ? tint : track,
      );
    }

    // The bus, where the driven part ends.
    final head = metric.getTangentForOffset(length * ratio)?.position;
    if (head != null) {
      canvas.drawCircle(head, 9, Paint()..color = tint);
      canvas.drawCircle(
        head,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = ground,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.total != total ||
      old.done != done ||
      old.tint != tint ||
      old.track != track ||
      old.ground != ground;
}
