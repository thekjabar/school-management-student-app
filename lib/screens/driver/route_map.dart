import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart' hide Path;

import '../../api/bus_location.dart';
import '../../api/crew_api.dart';
import '../../api/directions.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/home_kit.dart';
import '../../ui/map_tiles.dart';
import '../../ui/screen_kit.dart';
import 'roster_kit.dart';
import 'run_order.dart';
import 'run_route_cache.dart';

class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.tripId,
    required this.stops,
    required this.tint,
    required this.leg,
    this.school,
    this.compact = false,
    this.fullScreen = false,
  });

  final String tripId;

  final List<PlannedStop> stops;

  final Color tint;

  final String leg;

  final SchoolGate? school;

  final bool compact;

  final bool fullScreen;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  MapboxMap? _mapbox;

  String? _touched;

  List<List<LatLng>>? _road;

  String? _roadFor;

  void _wantRoad(List<RunWaypoint> waypoints) {
    final key = runRouteKey(leg: widget.leg, waypoints: waypoints);
    if (_roadFor == key) return;
    _roadFor = key;

    final points = [for (final w in waypoints) w.at];
    if (points.length < 2) {
      _road = null;
      return;
    }
    final ready = RunRouteCache.peek(widget.tripId)?.routes[key];
    if (ready != null) {
      _road = ready;
      return;
    }
    _road = null;
    final schoolIndex = waypoints.indexWhere((w) => w.school);
    RunRouteCache.route(
      widget.tripId,
      key,
      points,
      schoolIndex: schoolIndex < 0 ? null : schoolIndex,
    ).then((legs) {
      if (!mounted || _roadFor != key || legs == null) return;
      setState(() => _road = legs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = runTarget(stops: widget.stops, leg: widget.leg, school: widget.school);
    final pins = _pins(target);

    if (pins.isEmpty) {
      return _NoMap(
        compact: widget.compact,
        tint: widget.tint,
        reason: widget.stops.isEmpty
            ? t('driver.noStopsLeft')
            : t(widget.compact
                ? 'driver.map.noPositionsShort'
                : 'driver.map.noPositions'),
      );
    }

    final waypoints = runWaypoints(stops: widget.stops, leg: widget.leg, school: widget.school);
    _wantRoad(waypoints);

    final points = [for (final p in pins) p.at];

    final spread = <String>{
      for (final p in points)
        '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}',
    }.length > 1;

    if (!MapTiles.configured) {
      return MapNotConfigured(tint: widget.tint);
    }

    final map = _MapboxCanvas(
      tripId: widget.tripId,
      leg: widget.leg,
      pins: pins,
      waypoints: waypoints,
      road: _road,
      tint: widget.tint,
      compact: widget.compact,
      fullScreen: widget.fullScreen,
      initialFit: spread ? points : null,
      onReady: (m) => _mapbox = m,
      onPinTap: widget.compact
          ? null
          : (key) => setState(() => _touched = key),
    );

    if (widget.compact) {
      return IgnorePointer(
        child: Stack(
          children: [Positioned.fill(child: map), const _Credit(small: true)],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: map),
        PositionedDirectional(
          start: 10,
          top: 10,
          end: 62,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ValueListenableBuilder<geo.Position?>(
              valueListenable: BusLocation.instance.here,
              builder: (context, me, _) => _Callout(
                pin: _shown(pins, target),
                target: target,
                bus: me == null ? null : LatLng(me.latitude, me.longitude),
                tint: widget.tint,
                leg: widget.leg,
                expanded: _touched != null,
              ),
            ),
          ),
        ),
        PositionedDirectional(
          end: 10,
          top: 10,
          child: Semantics(
            button: true,
            label: t(widget.fullScreen ? 'driver.map.showWholeRun' : 'driver.map.fullScreen'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!widget.fullScreen) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RouteMapScreen(
                        tripId: widget.tripId,
                        stops: widget.stops,
                        tint: widget.tint,
                        leg: widget.leg,
                        school: widget.school,
                      ),
                    ),
                  );
                  return;
                }
                setState(() => _touched = null);
                if (spread) {
                  unawaited(_fitAll(points));
                } else {
                  unawaited(_moveTo(points.first, 15.5));
                }
              },
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: AppTheme.dark ? 0.4 : 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  widget.fullScreen ? Icons.zoom_out_map_rounded : Icons.open_in_full_rounded,
                  size: 21,
                  color: widget.tint,
                ),
              ),
            ),
          ),
        ),
        if (widget.fullScreen)
          PositionedDirectional(
            end: 10,
            top: 64,
            child: ValueListenableBuilder<geo.Position?>(
              valueListenable: BusLocation.instance.here,
              builder: (context, me, _) {
                if (me == null) return const SizedBox.shrink();
                return Semantics(
                  button: true,
                  label: t('driver.map.centreOnMe'),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() => _touched = null);
                      unawaited(_moveTo(LatLng(me.latitude, me.longitude), 16.5));
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: AppTheme.dark ? 0.4 : 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.directions_bus_rounded,
                        size: 21,
                        color: widget.tint,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const _Credit(),
      ],
    );
  }

  Future<void> _fitAll(List<LatLng> points) async {
    final map = _mapbox;
    if (map == null || points.isEmpty) return;
    final camera = await cameraToFit(map, points, compact: widget.compact, fullScreen: widget.fullScreen);
    await map.flyTo(camera, MapAnimationOptions(duration: 600));
  }

  Future<void> _moveTo(LatLng at, double zoom) async {
    await _mapbox?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(at.longitude, at.latitude)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  List<_Stop> _pins(RunTarget? target) {
    final schoolId = widget.school?.stopId;
    final numbers = runNumbers(widget.stops, schoolId);

    final out = <_Stop>[];
    for (var i = 0; i < widget.stops.length; i++) {
      final s = widget.stops[i];
      if (isSchoolStop(s, schoolId) || !stopIsPlaced(s)) continue;
      out.add(_Stop(
        key: 'pin-$i',
        stop: s,
        order: numbers[i] ?? i + 1,
        at: LatLng(s.lat!, s.lon!),
        next: identical(target?.stop, s),
        school: false,
      ));
    }

    final gate = widget.school;
    if (gate != null && gate.placed) {
      out.add(_Stop(
        key: 'school',
        stop: _schoolStop(gate),
        order: 0,
        at: LatLng(gate.lat!, gate.lon!),
        next: target?.school == true,
        school: true,
      ));
    }
    return out;
  }

  PlannedStop _schoolStop(SchoolGate gate) => PlannedStop(
        stopId: gate.stopId ?? 'school',
        name: (gate.name ?? '').trim().isEmpty ? t('driver.school') : gate.name!.trim(),
        landmark: null,
        lat: gate.lat,
        lon: gate.lon,
        plannedSequence: 0,
        metresAway: null,
        students: const [],
        arrivedAt: null,
        departedAt: null,
        skipped: false,
        etaAt: null,
        etaIsActual: false,
        dwellSeconds: 0,
        driveSeconds: 0,
      );

  _Stop? _shown(List<_Stop> pins, RunTarget? target) {
    for (final p in pins) {
      if (p.key == _touched) return p;
    }
    for (final p in pins) {
      if (p.next) return p;
    }
    final gate = widget.school;
    if (target != null && target.school && gate != null) {
      return _Stop(
        key: 'school',
        stop: _schoolStop(gate),
        order: 0,
        at: const LatLng(0, 0),
        next: true,
        school: true,
      );
    }
    return null;
  }
}

Future<CameraOptions> cameraToFit(
  MapboxMap map,
  List<LatLng> points, {
  required bool compact,
  required bool fullScreen,
}) =>
    map.cameraForCoordinatesPadding(
      [for (final p in points) Point(coordinates: Position(p.longitude, p.latitude))],
      CameraOptions(),
      compact
          ? MbxEdgeInsets(top: 26, left: 26, bottom: 26, right: 26)
          : fullScreen
              ? MbxEdgeInsets(top: 96, left: 54, bottom: 70, right: 54)
              : MbxEdgeInsets(top: 74, left: 46, bottom: 46, right: 46),
      16.5,
      null,
    );

class RouteMapScreen extends StatelessWidget {
  const RouteMapScreen({
    super.key,
    required this.tripId,
    required this.stops,
    required this.tint,
    required this.leg,
    this.school,
  });

  final String tripId;
  final List<PlannedStop> stops;
  final Color tint;
  final String leg;
  final SchoolGate? school;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('driver.map.title')),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 0),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radius),
                  ),
                  child: RouteMap(
                    tripId: tripId,
                    stops: stops,
                    tint: tint,
                    leg: leg,
                    school: school,
                    fullScreen: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stop {
  const _Stop({
    required this.key,
    required this.stop,
    required this.order,
    required this.at,
    required this.next,
    required this.school,
  });

  final String key;

  final PlannedStop stop;

  final int order;
  final LatLng at;

  final bool next;

  final bool school;
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.pin,
    required this.target,
    required this.bus,
    required this.tint,
    required this.leg,
    this.expanded = false,
  });

  final _Stop? pin;
  final RunTarget? target;
  final LatLng? bus;
  final Color tint;
  final String leg;
  final bool expanded;

  int? _metres(_Stop p) {
    if (p.school && !p.next) return null;
    final from = bus;
    if (from != null && stopIsPlaced(p.stop)) {
      return metresBetween(from, LatLng(p.stop.lat!, p.stop.lon!)).round();
    }
    return p.school ? null : p.stop.metresAway;
  }

  @override
  Widget build(BuildContext context) {
    final p = pin;
    final metres = p == null ? null : _metres(p);

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 13, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.dark ? 0.4 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: p == null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                t('driver.noStopsLeft'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text,
                ),
              ),
            )
          : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.school
                        ? AppTheme.blue.withValues(alpha: AppTheme.dark ? 0.28 : 0.12)
                        : tint.withValues(alpha: AppTheme.dark ? 0.24 : 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: p.school
                      ? Icon(Icons.school_rounded, size: 16, color: AppTheme.blue)
                      : Text(
                          '${p.order}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: tint,
                          ),
                        ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: AppTheme.text,
                        ),
                      ),
                      Text(
                        _line(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: p.next ? tint : AppTheme.textMuted,
                        ),
                      ),
                      if (metres != null && !p.stop.done)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.navigation_rounded, size: 11, color: AppTheme.textMuted),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                distanceAway(metres),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (expanded && !p.school) ..._riders(p),
            ],
          ),
    );
  }

  List<Widget> _riders(_Stop p) {
    final riders = p.stop.students;
    if (riders.isEmpty) {
      return [
        const SizedBox(height: 7),
        Text(
          t('driver.nobodyAtStop'),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
        ),
      ];
    }

    return [
      const SizedBox(height: 8),
      Divider(height: 1, color: AppTheme.border),
      const SizedBox(height: 7),
      Text(
        '${t('driver.atThisStop')} · ${riders.length}',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: AppTheme.textFaint,
        ),
      ),
      const SizedBox(height: 6),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 236, maxWidth: 300),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in riders) _RiderLine(rider: r, tint: tint),
            ],
          ),
        ),
      ),
    ];
  }

  String _line(_Stop p) => [
        if (p.next) t('driver.nextStop'),
        if (p.school && p.next && target?.school == true)
          leg == 'RETURN'
              ? tn('driver.pickUpAtSchool', target!.students)
              : tn('driver.dropOffAtSchool', target!.students)
        else if (p.school)
          t('driver.school')
        else if (p.stop.done)
          t('driver.done')
        else
          leg == 'RETURN'
              ? tn('driver.nToDropOff', p.stop.students.length)
              : tn('driver.nToPickUp', p.stop.students.length),
      ].join(' · ');
}

class _RiderLine extends StatelessWidget {
  const _RiderLine({required this.rider, required this.tint});

  final RiderOnStop rider;
  final Color tint;

  String get _word {
    if (rider.alightedAt != null) return t('driver.done');
    if (rider.boardedAt != null) return t('driver.pickedUp');
    if (rider.notTravelling) return t('driver.notRiding');
    return t('driver.waitingAtStop');
  }

  @override
  Widget build(BuildContext context) {
    final tone = riderTone(rider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SeatChip(rider: rider, size: 26),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        rider.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                    if (rider.requiresAssistance) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.accessible_rounded, size: 13, color: AppTheme.amber),
                    ],
                  ],
                ),
                Text(
                  _word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tone),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit({this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) => PositionedDirectional(
        start: small ? null : 8,
        end: small ? 5 : null,
        bottom: small ? 4 : 6,
        child: MapAttribution(small: small),
      );
}

class _NoMap extends StatelessWidget {
  const _NoMap({required this.compact, required this.tint, required this.reason});

  final bool compact;
  final Color tint;

  final String reason;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: AppTheme.dark ? 0.10 : 0.06),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: compact ? 20 : 28,
                color: AppTheme.textFaint,
              ),
              SizedBox(height: compact ? 6 : 10),
              Text(
                reason,
                textAlign: TextAlign.center,
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RouteMapNote extends StatelessWidget {
  const RouteMapNote({super.key, required this.stops});

  final List<PlannedStop> stops;

  @override
  Widget build(BuildContext context) {
    final missing = stops.where((s) => !stopIsPlaced(s)).toList();
    if (missing.isEmpty || missing.length == stops.length) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 9, 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_off_outlined, size: 15, color: AppTheme.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tn('driver.map.unplaced', missing.length),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  missing.map((s) => s.name).join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
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
}

const _routeSource = 'ksp-run-route';
const _arrowImage = 'ksp-run-arrow';
const _casingLayer = 'ksp-run-casing';
const _lineLayer = 'ksp-run-line';
const _linkLayer = 'ksp-run-link';
const _arrowLayer = 'ksp-run-arrows';

const double _linkMinMetres = 12;

const double _liveTrimMetres = 50;

class _MapboxCanvas extends StatefulWidget {
  const _MapboxCanvas({
    required this.tripId,
    required this.leg,
    required this.pins,
    required this.waypoints,
    required this.road,
    required this.tint,
    required this.compact,
    required this.fullScreen,
    required this.initialFit,
    required this.onReady,
    required this.onPinTap,
  });

  final String tripId;

  final String leg;

  final List<_Stop> pins;

  final List<RunWaypoint> waypoints;

  final List<List<LatLng>>? road;

  final Color tint;
  final bool compact;
  final bool fullScreen;

  final List<LatLng>? initialFit;

  final void Function(MapboxMap map) onReady;
  final void Function(String key)? onPinTap;

  @override
  State<_MapboxCanvas> createState() => _MapboxCanvasState();
}

class _MapboxCanvasState extends State<_MapboxCanvas> {
  MapboxMap? _map;
  PointAnnotationManager? _points;
  bool _tapsWired = false;
  bool _layersReady = false;
  bool _listening = false;

  final Map<String, String> _pinForAnnotation = {};

  String? _pinsDrawnFor;
  String? _linesDrawnFor;

  List<LatLng>? _liveLeg;
  String? _liveFor;
  LatLng? _bus;

  double _dpr = 2;

  @override
  void dispose() {
    if (_listening) BusLocation.instance.here.removeListener(_onFix);
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    widget.onReady(map);

    await map.gestures.updateSettings(
      GesturesSettings(
        rotateEnabled: false,
        pitchEnabled: false,
        scrollEnabled: !widget.compact,
        pinchToZoomEnabled: !widget.compact,
        doubleTapToZoomInEnabled: !widget.compact,
        quickZoomEnabled: !widget.compact,
      ),
    );

    final bus = await _busImage(_dpr, widget.compact ? 0.8 : 1.0);
    final blank = await _blankImage();

    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: false,
        showAccuracyRing: !widget.compact,
        accuracyRingColor: widget.tint.withValues(alpha: 0.12).toARGB32(),
        accuracyRingBorderColor: widget.tint.withValues(alpha: 0.35).toARGB32(),
        puckBearingEnabled: true,
        puckBearing: PuckBearing.COURSE,
        locationPuck: LocationPuck(
          locationPuck2D: LocationPuck2D(
            topImage: blank,
            bearingImage: bus,
            shadowImage: blank,
          ),
        ),
      ),
    );

    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.compass.updateSettings(CompassSettings(enabled: false));
    await map.attribution.updateSettings(AttributionSettings(enabled: false));
    await map.logo.updateSettings(LogoSettings(enabled: false));
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;
    _layersReady = false;
    _linesDrawnFor = null;
    _pinsDrawnFor = null;
    await _ensureLayers(map);
    _points ??= await map.annotations.createPointAnnotationManager();

    if (!_tapsWired) {
      _tapsWired = true;
      _points?.tapEvents(
        onTap: (annotation) {
          final key = _pinForAnnotation[annotation.id];
          if (key != null) widget.onPinTap?.call(key);
        },
      );
    }

    _watchLive();
    await _fitOnce(map);
    await _drawLines();
    await _drawPins();
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  Future<void> _ensureLayers(MapboxMap map) async {
    final style = map.style;
    final tint = widget.tint;
    final later = Color.lerp(tint, Colors.white, 0.38)!;
    final done = AppTheme.dark ? const Color(0xFF5B6475) : const Color(0xFFA6ACB8);
    final nextWidth = widget.compact ? 4.0 : 6.5;
    final laterWidth = widget.compact ? 3.0 : 5.0;
    final doneWidth = widget.compact ? 2.5 : 4.0;

    try {
      if (!await style.styleSourceExists(_routeSource)) {
        await style.addStyleSource(
          _routeSource,
          jsonEncode({
            'type': 'geojson',
            'data': {'type': 'FeatureCollection', 'features': <Object>[]},
          }),
        );
      }

      if (!await style.hasStyleImage(_arrowImage)) {
        final dpr = _dpr;
        final size = widget.compact ? 9.0 : 12.0;
        final png = await _arrowPng(dpr, size);
        final px = (size * dpr).round();
        await style.addStyleImage(
          _arrowImage,
          dpr,
          MbxImage(width: px, height: px, data: png),
          false,
          [],
          [],
          null,
        );
      }

      final layers = <Map<String, Object>>[
        {
          'id': _casingLayer,
          'type': 'line',
          'source': _routeSource,
          'filter': ['in', ['get', 'state'], ['literal', ['next', 'later']]],
          'layout': {
            'line-join': 'round',
            'line-cap': 'round',
            'line-sort-key': ['match', ['get', 'state'], 'next', 2, 1],
          },
          'paint': {
            'line-color': AppTheme.dark ? '#0A1324' : '#FFFFFF',
            'line-width': ['match', ['get', 'state'], 'next', nextWidth + 3, laterWidth + 2.5],
          },
        },
        {
          'id': _lineLayer,
          'type': 'line',
          'source': _routeSource,
          'filter': ['!=', ['get', 'state'], 'link'],
          'layout': {
            'line-join': 'round',
            'line-cap': 'round',
            'line-sort-key': ['match', ['get', 'state'], 'next', 3, 'later', 2, 1],
          },
          'paint': {
            'line-color': ['match', ['get', 'state'], 'done', _hex(done), 'next', _hex(tint), _hex(later)],
            'line-width': ['match', ['get', 'state'], 'done', doneWidth, 'next', nextWidth, laterWidth],
          },
        },
        {
          'id': _linkLayer,
          'type': 'line',
          'source': _routeSource,
          'filter': ['==', ['get', 'state'], 'link'],
          'layout': {'line-cap': 'round'},
          'paint': {
            'line-color': _hex(done),
            'line-width': widget.compact ? 1.5 : 2.5,
            'line-dasharray': [0.1, 2.0],
          },
        },
        {
          'id': _arrowLayer,
          'type': 'symbol',
          'source': _routeSource,
          'filter': ['in', ['get', 'state'], ['literal', ['next', 'later']]],
          'layout': {
            'symbol-placement': 'line',
            'symbol-spacing': widget.compact ? 48 : 64,
            'icon-image': _arrowImage,
            'icon-allow-overlap': true,
            'icon-ignore-placement': true,
            'icon-rotation-alignment': 'map',
            'icon-keep-upright': false,
          },
        },
      ];

      for (final layer in layers) {
        if (!await style.styleLayerExists(layer['id']! as String)) {
          await style.addStyleLayer(jsonEncode(layer), null);
        }
      }
      _layersReady = true;
    } catch (_) {
      _layersReady = false;
    }
  }

  void _watchLive() {
    if (widget.compact) {
      unawaited(RunRouteCache.open(widget.tripId).then((_) => _onFix()));
      return;
    }
    if (_listening) return;
    _listening = true;
    BusLocation.instance.here.addListener(_onFix);
    unawaited(RunRouteCache.open(widget.tripId).then((_) => _onFix()));
  }

  RunWaypoint? get _nextWaypoint => widget.waypoints.where((w) => !w.done).firstOrNull;

  bool _straight = false;

  void _onFix() {
    if (!mounted) return;
    final book = RunRouteCache.peek(widget.tripId);
    if (book == null) return;
    final me = widget.compact ? null : BusLocation.instance.here.value;
    if (me != null) _bus = LatLng(me.latitude, me.longitude);

    final next = _nextWaypoint;
    if (next == null) {
      _liveFor = null;
      _liveLeg = null;
      _straight = false;
      unawaited(_drawLines());
      return;
    }

    final key = busLegKey(leg: widget.leg, target: next);
    final decided = book.busLegs[key];
    if (decided != null) {
      _liveFor = key;
      _liveLeg = decided.line;
      _straight = false;
    } else if (_liveFor != key) {
      _liveLeg = null;
      _straight = false;
      final bus = _bus;
      if (bus != null && me != null) {
        _liveFor = key;
        final needed = busLegNeeded(waypoints: widget.waypoints, bus: bus);
        _straight = needed;
        final heading = me.heading.isFinite && me.heading >= 0 && me.speed.isFinite && me.speed > 1.5
            ? me.heading
            : null;
        RunRouteCache.busLeg(
          widget.tripId,
          key,
          bus: bus,
          target: next.at,
          needed: needed,
          school: next.school,
          heading: heading,
        ).then((leg) {
          if (!mounted || _liveFor != key) return;
          if (leg != null) {
            _liveLeg = leg.line;
            _straight = false;
          }
          unawaited(_drawLines());
        });
      }
    }
    unawaited(_drawLines());
  }

  List<LatLng>? _liveFromBus() {
    final leg = _liveLeg;
    final bus = _bus;
    if (leg == null) {
      final next = _nextWaypoint;
      return _straight && bus != null && next != null ? [bus, next.at] : null;
    }
    if (leg.length < 2 || bus == null) return leg;
    final i = Directions.nearestIndex(leg, bus);
    if (metresBetween(leg[i], bus) > _liveTrimMetres) return leg;
    final rest = leg.sublist(math.min(i + 1, leg.length - 1));
    return [bus, ...rest];
  }

  Future<void> _drawLines() async {
    final map = _map;
    if (map == null || !_layersReady) return;

    final waypoints = widget.waypoints;
    final states = legStates(waypoints);
    final road = widget.road;
    final roadFits = road != null && road.length == states.length;
    final live = _liveFromBus();

    final features = <Map<String, Object>>[];

    void add(String state, List<LatLng> line) {
      if (line.length < 2) return;
      features.add({
        'type': 'Feature',
        'properties': {'state': state},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in line) [p.longitude, p.latitude],
          ],
        },
      });
    }

    for (var i = 0; i < states.length; i++) {
      final state = states[i];
      if (state == LegState.next && live != null) continue;
      final line = roadFits ? road[i] : [waypoints[i].at, waypoints[i + 1].at];
      add(state.name, line);
    }
    if (live != null) add(LegState.next.name, live);

    if (roadFits) {
      for (var j = 0; j < waypoints.length; j++) {
        final end = j > 0 ? road[j - 1].last : road[0].first;
        if (metresBetween(end, waypoints[j].at) >= _linkMinMetres) {
          add('link', [end, waypoints[j].at]);
        }
      }
    }

    final signature = [
      for (final f in features)
        '${(f['properties'] as Map)['state']}:${((f['geometry'] as Map)['coordinates'] as List).length}',
      if (live != null) '${live.first.latitude},${live.first.longitude}',
    ].join('|');
    if (_linesDrawnFor == signature) return;
    _linesDrawnFor = signature;

    try {
      await map.style.setStyleSourceProperty(
        _routeSource,
        'data',
        jsonEncode({'type': 'FeatureCollection', 'features': features}),
      );
    } catch (_) {
      _linesDrawnFor = null;
    }
  }

  Future<void> _drawPins() async {
    final points = _points;
    if (points == null) return;

    final signature = [
      for (final p in widget.pins)
        '${p.key}:${p.stop.stopId}:${p.order}:${p.next}:${p.stop.done}:${p.stop.name}:'
            '${p.at.latitude},${p.at.longitude}',
    ].join('|');
    if (_pinsDrawnFor == signature) return;
    _pinsDrawnFor = signature;

    await points.deleteAll();
    _pinForAnnotation.clear();

    for (final pin in widget.pins) {
      final image = await _pinImage(pin);
      final made = await points.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(pin.at.longitude, pin.at.latitude)),
          image: image,
          iconSize: 1,
          iconAnchor: IconAnchor.CENTER,
          symbolSortKey: pin.school ? 3 : pin.next ? 2 : 1,
        ),
      );
      _pinForAnnotation[made.id] = pin.key;
    }
  }

  static final Map<String, Uint8List> _images = {};

  static Future<Uint8List> _png(ui.Picture picture, double width, double height, double dpr) async {
    final image = await picture.toImage((width * dpr).round(), (height * dpr).round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static Future<Uint8List> _blankImage() async {
    final key = 'blank';
    final cached = _images[key];
    if (cached != null) return cached;
    final recorder = ui.PictureRecorder();
    Canvas(recorder);
    final out = await _png(recorder.endRecording(), 2, 2, 1);
    _images[key] = out;
    return out;
  }

  Future<Uint8List> _busImage(double dpr, double scale) async {
    final tint = widget.tint;
    final key = 'bus:${tint.toARGB32()}:$dpr:$scale';
    final cached = _images[key];
    if (cached != null) return cached;

    final bodyW = 24.0 * scale;
    final bodyH = 42.0 * scale;
    final pad = 6.0 * scale;
    final side = bodyH + pad * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    final centre = Offset(side / 2, side / 2);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centre, width: bodyW, height: bodyH),
      Radius.circular(6 * scale),
    );

    canvas.drawRRect(
      body.shift(Offset(0, 1.5 * scale)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 3 * scale),
    );
    canvas.drawRRect(body, Paint()..color = tint);
    canvas.drawRRect(
      body.deflate(1.1 * scale),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * scale
        ..color = Colors.white,
    );

    final glass = Paint()..color = const Color(0xFF1F2937).withValues(alpha: 0.88);
    final left = centre.dx - bodyW / 2;
    final top = centre.dy - bodyH / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 4 * scale, top + 4 * scale, bodyW - 8 * scale, 8 * scale),
        Radius.circular(2.5 * scale),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 5 * scale, top + bodyH - 7 * scale, bodyW - 10 * scale, 3 * scale),
        Radius.circular(1.5 * scale),
      ),
      glass,
    );
    final roof = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 6 * scale, top + (16 + i * 6) * scale, bodyW - 12 * scale, 2.4 * scale),
          Radius.circular(1.2 * scale),
        ),
        roof,
      );
    }

    final out = await _png(recorder.endRecording(), side, side, dpr);
    _images[key] = out;
    return out;
  }

  static Future<Uint8List> _arrowPng(double dpr, double size) async {
    final key = 'arrow:$dpr:$size';
    final cached = _images[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    final path = Path()
      ..moveTo(size * 0.32, size * 0.2)
      ..lineTo(size * 0.68, size * 0.5)
      ..lineTo(size * 0.32, size * 0.8);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.17
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );

    final out = await _png(recorder.endRecording(), size, size, dpr);
    _images[key] = out;
    return out;
  }

  Future<Uint8List> _pinImage(_Stop pin) async {
    if (pin.school) return _schoolImage(pin);

    final tint = widget.tint;
    final done = pin.stop.done;
    final plain = !done && !pin.next;
    final size = widget.compact ? (pin.next ? 32.0 : 25.0) : (pin.next ? 52.0 : 40.0);

    final fill = done
        ? AppTheme.green
        : pin.next
            ? tint
            : AppTheme.surface;
    final ink = plain ? tint : Colors.white;

    final label = done ? null : '${pin.order}';
    final dpr = _dpr;

    final key = '${fill.toARGB32()}:${ink.toARGB32()}:$size:$done:'
        '${pin.next}:${label ?? ''}:$dpr';
    final cached = _images[key];
    if (cached != null) return cached;

    final pad = pin.next ? 10.0 : 6.0;
    final canvasSize = size + pad * 2;
    final centre = Offset(canvasSize / 2, canvasSize / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);

    if (pin.next) {
      canvas.drawCircle(
        centre,
        (size + 10) / 2,
        Paint()..color = tint.withValues(alpha: 0.28),
      );
    }

    final border = size > 34 ? 3.0 : 2.4;
    final half = size / 2;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3.5);
    final body = Paint()..color = fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = border
      ..color = plain ? tint : Colors.white;

    canvas.drawCircle(centre.translate(0, 2), half, shadow);
    canvas.drawCircle(centre, half, body);
    canvas.drawCircle(centre, half - border / 2, stroke);

    final painter = TextPainter(textDirection: TextDirection.ltr);
    if (done) {
      painter.text = TextSpan(
        text: String.fromCharCode(Icons.check_rounded.codePoint),
        style: TextStyle(
          fontSize: size * 0.55,
          fontFamily: Icons.check_rounded.fontFamily,
          package: Icons.check_rounded.fontPackage,
          color: Colors.white,
          height: 1,
        ),
      );
    } else {
      painter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          height: 1,
          color: ink,
        ),
      );
    }
    painter.layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );

    final out = await _png(recorder.endRecording(), canvasSize, canvasSize, dpr);
    _images[key] = out;
    return out;
  }

  Future<Uint8List> _schoolImage(_Stop pin) async {
    final dpr = _dpr;
    final blue = AppTheme.blue;
    final compact = widget.compact;
    final icon = compact ? 30.0 : 46.0;
    final name = pin.stop.name;
    final key = 'school:${blue.toARGB32()}:$compact:$dpr:$name:${AppTheme.dark}';
    final cached = _images[key];
    if (cached != null) return cached;

    TextPainter? label;
    if (!compact) {
      label = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.2, color: blue),
        ),
        textDirection: _isRtl(name) ? TextDirection.rtl : TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 150);
    }

    const pad = 6.0;
    const gap = 4.0;
    final pillH = label == null ? 0.0 : label.height + 8;
    final pillW = label == null ? 0.0 : label.width + 16;
    final width = math.max(icon + pad * 2, pillW + 4);
    final extra = label == null ? 0.0 : pillH + gap;
    final height = icon + pad * 2 + extra * 2;
    final centre = Offset(width / 2, height / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);

    final square = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centre, width: icon, height: icon),
      Radius.circular(icon * 0.28),
    );
    canvas.drawRRect(
      square.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3.5),
    );
    canvas.drawRRect(square, Paint()..color = blue);
    canvas.drawRRect(
      square.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );

    final glyph = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.school_rounded.codePoint),
        style: TextStyle(
          fontSize: icon * 0.56,
          fontFamily: Icons.school_rounded.fontFamily,
          package: Icons.school_rounded.fontPackage,
          color: Colors.white,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(canvas, centre - Offset(glyph.width / 2, glyph.height / 2));

    if (label != null) {
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centre.dx, centre.dy + icon / 2 + gap + pillH / 2),
          width: pillW,
          height: pillH,
        ),
        Radius.circular(pillH / 2),
      );
      canvas.drawRRect(
        pill.shift(const Offset(0, 1)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5),
      );
      canvas.drawRRect(pill, Paint()..color = AppTheme.surface);
      label.paint(canvas, Offset(pill.left + 8, pill.top + 4));
    }

    final out = await _png(recorder.endRecording(), width, height, dpr);
    _images[key] = out;
    return out;
  }

  static bool _isRtl(String text) => RegExp(r'[֐-ࣿ]').hasMatch(text);

  @override
  void didUpdateWidget(covariant _MapboxCanvas old) {
    super.didUpdateWidget(old);
    unawaited(_drawLines());
    unawaited(_drawPins());
    _onFix();
  }

  late final ViewportState _start = CameraViewportState(
    center: Point(coordinates: Position(widget.pins.first.at.longitude, widget.pins.first.at.latitude)),
    zoom: 14.5,
    padding: const EdgeInsets.fromLTRB(40, 56, 40, 40),
  );

  bool _fitted = false;

  Future<void> _fitOnce(MapboxMap map) async {
    final fit = widget.initialFit;
    if (_fitted || fit == null) return;
    _fitted = true;
    try {
      await map.setCamera(
        await cameraToFit(map, fit, compact: widget.compact, fullScreen: widget.fullScreen),
      );
    } catch (_) {
      _fitted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _dpr = MediaQuery.devicePixelRatioOf(context);
    return MapWidget(
      key: const ValueKey('run-map'),
      styleUri: MapTiles.styleUri,
      viewport: _start,
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}
