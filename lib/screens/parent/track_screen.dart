import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// latlong2 exports a generic Path<T> for geodesic paths, which shadows
// dart:ui's Path and breaks every CustomPainter in the file.
import 'package:latlong2/latlong.dart' hide Path;

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/map_tiles.dart';
import '../../ui/screen_kit.dart';

/// Where the child is, on a real map, refreshed while the screen is open.
///
/// The distinction this screen is built around: A BUS POSITION IS NOT A CHILD
/// POSITION. She may have been kept at home, or handed over ten minutes ago. A
/// moving marker labelled with her name when she is not aboard is not a small
/// inaccuracy — it is a confident wrong answer to the one question a parent
/// actually asked, and they will act on it.
///
/// So the server sends her custody state alongside the position and the screen
/// says which of the two it is showing. When she is aboard, the bus marker is
/// her. When she is not, it is a bus, plainly labelled as one, and the state
/// line says where she actually is.
///
/// The map is Mapbox. Not a decorative diagram: a parent works out
/// "twenty minutes away" from streets they recognise, and a drawing of an
/// invented road tells them nothing. Tiles fail closed — the state line above
/// them is the answer, and it is readable with no map at all.
class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key, required this.child});

  final Child child;

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final _loader = GlobalKey<LoaderState<LiveBus?>>();
  final _map = MapController();

  Timer? _tick;

  /// Set once the map has been moved to the first fix. After that the map is
  /// the parent's to pan: recentring on every poll would fight a person trying
  /// to look one street ahead.
  bool _framed = false;

  @override
  void initState() {
    super.initState();
    // Fifteen seconds. The vehicles report about every ten, so anything faster
    // is a request that returns the same row, on a connection that is usually
    // somebody's mobile data.
    _tick = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loader.currentState?.reload(quiet: true),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('track.title')),
            Expanded(
              child: Loader<LiveBus?>(
                key: _loader,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
                load: () async {
                  final all = await ParentApi.instance.live();
                  for (final b in all) {
                    if (b.studentId == widget.child.studentId) return b;
                  }
                  return null;
                },
                builder: (context, bus) {
                  if (bus == null) {
                    return NoticeBanner(
                      icon: Icons.directions_bus_outlined,
                      title: t('track.noBusTitle'),
                      body: t('track.noBusBody'),
                      color: AppTheme.blue,
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) => _frame(bus));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Above everything, and deliberately loud. A rehearsal
                      // that looks like a real bus is worse than no bus at all.
                      if (bus.simulated) ...[
                        const _DemoBand(),
                        const SizedBox(height: kCardGap),
                      ],
                      _StateCard(bus: bus, child: widget.child),
                      const SizedBox(height: kCardGap),
                      _MapCard(bus: bus, controller: _map, onRecentre: () => _frame(bus, force: true)),
                      const SizedBox(height: kCardGap),
                      _Details(bus: bus),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Put the bus and the stop both on screen, once.
  void _frame(LiveBus bus, {bool force = false}) {
    if (_framed && !force) return;

    final points = <LatLng>[
      if (bus.hasFix) LatLng(bus.lat!, bus.lon!),
      if (bus.stopLat != null && bus.stopLon != null) LatLng(bus.stopLat!, bus.stopLon!),
    ];
    if (points.isEmpty) return;

    _framed = true;
    if (points.length == 1) {
      _map.move(points.first, 15.5);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        // Room for the callouts drawn over the map, and enough that a marker
        // never sits against the frame's edge where it reads as off-screen.
        padding: const EdgeInsets.fromLTRB(48, 56, 48, 48),
        maxZoom: 16,
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Where she is
 * ------------------------------------------------------------------------- */

/// The answer, in one line, above the map.
///
/// This card is the feature. The map is how a parent checks it.
class _StateCard extends StatelessWidget {
  const _StateCard({required this.bus, required this.child});

  final LiveBus bus;
  final Child child;

  @override
  Widget build(BuildContext context) {
    final (icon, colour, title, body) = _describe(bus, child);

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: AppTheme.dark ? 0.22 : 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: colour),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.25,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Every branch a parent can actually land on, said in words.
  ///
  /// The withheld case (`childState == null`) is deliberately not folded in
  /// with "not riding": the school has not said she is off the bus, it has
  /// declined to answer, and those must not read the same.
  static (IconData, Color, String, String) _describe(LiveBus bus, Child child) {
    final name = child.name.split(' ').first;

    if (!bus.visible && bus.childState == null) {
      return (
        Icons.lock_outline_rounded,
        AppTheme.textMuted,
        t('track.withheldTitle'),
        bus.reasonText,
      );
    }

    switch (bus.childState) {
      case 'ON_BOARD':
        final eta = bus.etaMinutes;
        return (
          Icons.directions_bus_rounded,
          AppTheme.green,
          tv('track.onBoard', {'name': name}),
          eta != null && bus.stopName != null
              ? tv('track.etaAt', {'n': '$eta', 'stop': bus.stopName!})
              : eta != null
                  ? tv('track.etaOnly', {'n': '$eta'})
                  : t('track.movingNoEta'),
        );

      case 'ARRIVED':
        return (
          Icons.check_circle_outline_rounded,
          AppTheme.green,
          tv('track.arrived', {'name': name}),
          bus.alightedAt != null
              ? tv('track.arrivedAt', {'time': hhmm(bus.alightedAt)})
              : t('track.arrivedBody'),
        );

      case 'NOT_RIDING':
        return (
          Icons.home_outlined,
          AppTheme.blue,
          tv('track.notRiding', {'name': name}),
          t('track.notRidingBody'),
        );

      case 'WAITING':
      default:
        final eta = bus.etaMinutes;
        return (
          Icons.schedule_rounded,
          AppTheme.amber,
          tv('track.waiting', {'name': name}),
          eta != null
              ? tv('track.busInMinutes', {'n': '$eta'})
              : bus.visible
                  ? t('track.busOnItsWay')
                  : bus.reasonText,
        );
    }
  }
}

/* ---------------------------------------------------------------------------
 * The map
 * ------------------------------------------------------------------------- */

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.bus,
    required this.controller,
    required this.onRecentre,
  });

  final LiveBus bus;
  final MapController controller;
  final VoidCallback onRecentre;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final hasStop = bus.stopLat != null && bus.stopLon != null;

    // Nothing to draw. Say so rather than showing an empty map of somewhere,
    // which a parent will read as "the bus is there".
    if (!bus.hasFix && !hasStop) {
      return Card16(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
        child: Column(
          children: [
            Icon(Icons.location_off_outlined, size: 30, color: AppTheme.textFaint),
            const SizedBox(height: 10),
            Text(
              t('track.noMap'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    final centre = bus.hasFix
        ? LatLng(bus.lat!, bus.lon!)
        : LatLng(bus.stopLat!, bus.stopLon!);

    return Card16(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: SizedBox(
          height: 320,
          child: Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: centre,
                  initialZoom: 15,
                  minZoom: 4,
                  maxZoom: 18,
                  // No rotation. A parent glancing at this needs north to be up
                  // so the streets match the ones in their head; a map twisted
                  // by a stray two-finger drag is a map nobody can read.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom |
                        InteractiveFlag.drag |
                        InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  MapTiles.layer(),

                  // The line from the bus to the stop. Straight, and drawn
                  // dashed for that reason: it is a distance, not a route, and
                  // a solid line would be read as the road the bus will take.
                  if (bus.hasFix && hasStop)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            LatLng(bus.lat!, bus.lon!),
                            LatLng(bus.stopLat!, bus.stopLon!),
                          ],
                          strokeWidth: 3,
                          pattern: const StrokePattern.dotted(),
                          color: tint.withValues(alpha: 0.55),
                        ),
                      ],
                    ),

                  MarkerLayer(
                    markers: [
                      if (hasStop)
                        Marker(
                          point: LatLng(bus.stopLat!, bus.stopLon!),
                          width: 34,
                          height: 34,
                          child: _StopPin(colour: tint),
                        ),
                      if (bus.hasFix)
                        Marker(
                          point: LatLng(bus.lat!, bus.lon!),
                          width: 46,
                          height: 46,
                          child: _BusPin(
                            heading: bus.headingDeg,
                            // Green only when she is actually on it. A grey
                            // marker for a bus that is not carrying her is the
                            // point of the whole screen.
                            colour: bus.onBoard ? AppTheme.green : AppTheme.textMuted,
                            stale: bus.stale,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Freshness, over the map. A stale marker looks exactly like a
              // live one, and a parent watching a bus that stopped reporting
              // four minutes ago must be told so.
              PositionedDirectional(
                start: 10,
                top: 10,
                child: _Callout(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: bus.stale ? AppTheme.amber : AppTheme.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        bus.stale
                            ? tv('track.lastSeen', {'ago': _ago(bus.ageSeconds)})
                            : t('track.liveNow'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              PositionedDirectional(
                end: 10,
                bottom: 10,
                child: GestureDetector(
                  onTap: onRecentre,
                  child: _Callout(
                    child: Icon(Icons.my_location_rounded, size: 18, color: tint),
                  ),
                ),
              ),

              // Mapbox's licence requires the credit. It is not
              // decoration and it does not come off.
              PositionedDirectional(
                start: 8,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    MapTiles.credit,
                    style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ago(int? seconds) {
    if (seconds == null) return '—';
    if (seconds < 60) return tv('track.secondsAgo', {'n': '$seconds'});
    return tv('track.minutesAgo', {'n': '${seconds ~/ 60}'});
  }
}

/// Says, unmissably, that this is not a bus on a road.
///
/// A stripe rather than a footnote. The platform will only ever send simulated
/// positions to a tenant marked as a demonstration, but the moment one is on
/// screen it has to be impossible to read as real — somebody showing this to a
/// school must not be able to imply otherwise, even by saying nothing.
class _DemoBand extends StatelessWidget {
  const _DemoBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.amber,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, size: 19, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t('track.demoData'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppTheme.dark ? 0.4 : 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      );
}

class _BusPin extends StatelessWidget {
  const _BusPin({required this.heading, required this.colour, required this.stale});

  final double? heading;
  final Color colour;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final pin = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: colour,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.directions_bus_rounded, size: 17, color: Colors.white),
    );

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The heading arrow, and only when the bus is actually reporting one
          // freshly. A stale arrow points where the bus was going four minutes
          // ago, which is worse than no arrow.
          if (heading != null && !stale)
            Transform.rotate(
              angle: heading! * math.pi / 180,
              child: CustomPaint(size: const Size(46, 46), painter: _HeadingPainter(colour)),
            ),
          pin,
        ],
      ),
    );
  }
}

class _HeadingPainter extends CustomPainter {
  const _HeadingPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(c.dx, c.dy - 22)
      ..lineTo(c.dx - 5.5, c.dy - 14)
      ..lineTo(c.dx + 5.5, c.dy - 14)
      ..close();
    canvas.drawPath(path, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_HeadingPainter old) => old.colour != colour;
}

class _StopPin extends StatelessWidget {
  const _StopPin({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colour, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.person_pin_circle_outlined, size: 17, color: colour),
      );
}

/* ---------------------------------------------------------------------------
 * The rest of what is known
 * ------------------------------------------------------------------------- */

class _Details extends StatelessWidget {
  const _Details({required this.bus});

  final LiveBus bus;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String?)>[
      (Icons.person_pin_circle_outlined, t('track.stop'), bus.stopName),
      (Icons.directions_bus_outlined, t('track.bus'), bus.busLabel ?? bus.plate),
      (Icons.badge_outlined, t('track.driver'), bus.driverName),
      (
        Icons.login_rounded,
        t('track.boarded'),
        bus.boardedAt != null ? hhmm(bus.boardedAt) : null,
      ),
      (
        Icons.logout_rounded,
        t('track.alighted'),
        bus.alightedAt != null ? hhmm(bus.alightedAt) : null,
      ),
    ].where((r) => r.$3 != null && r.$3!.isNotEmpty).toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 17, color: AppTheme.border),
            Row(
              children: [
                Icon(rows[i].$1, size: 17, color: AppTheme.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rows[i].$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                Text(
                  rows[i].$3!,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
