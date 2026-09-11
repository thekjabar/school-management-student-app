import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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

  bool _framed = false;

  @override
  void initState() {
    super.initState();
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
        padding: const EdgeInsets.fromLTRB(48, 56, 48, 48),
        maxZoom: 16,
      ),
    );
  }
}

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

      case 'DONE_FOR_TODAY':
        return (
          Icons.home_rounded,
          AppTheme.green,
          tv('track.doneForToday', {'name': name}),
          t('track.doneForTodayBody'),
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

    if (!MapTiles.configured) {
      return Card16(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kCardRadius),
          child: SizedBox(height: 320, child: MapNotConfigured(tint: tint)),
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
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom |
                        InteractiveFlag.pinchMove |
                        InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  MapTiles.layer(),

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
                            colour: bus.onBoard ? AppTheme.green : AppTheme.textMuted,
                            stale: bus.stale,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

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

              const MapOffline(),

              PositionedDirectional(
                start: 8,
                bottom: 6,
                child: const MapAttribution(),
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
