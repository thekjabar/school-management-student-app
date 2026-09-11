import 'dart:async';
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

bool stopIsPlaced(PlannedStop s) {
  final lat = s.lat;
  final lon = s.lon;
  if (lat == null || lon == null) return false;
  if (lat == 0 && lon == 0) return false;
  return lat.abs() <= 90 && lon.abs() <= 180;
}

class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.stops,
    required this.tint,
    required this.leg,
    this.terminalStopId,
    this.compact = false,
    this.fullScreen = false,
  });

  final List<PlannedStop> stops;

  final Color tint;

  final String leg;

  final String? terminalStopId;

  final bool compact;

  final bool fullScreen;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  MapboxMap? _mapbox;

  String? _touched;

  List<LatLng>? _road;

  String? _roadFor;

  @override
  void dispose() {
    super.dispose();
  }

  void _wantRoad(List<LatLng> points) {
    final key = points
        .map((p) => '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}')
        .join(';');
    if (_roadFor == key) return;
    _roadFor = key;

    final ready = Directions.cached(points);
    if (ready != null) {
      _road = ready;
      return;
    }
    _road = null;
    Directions.road(points).then((line) {
      if (!mounted || _roadFor != key) return;
      setState(() => _road = line);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pins = _pins();

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

    final points = [for (final p in pins) p.at];
    _wantRoad(points);

    final spread = <String>{
      for (final p in points)
        '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}',
    }.length > 1;

    if (!MapTiles.configured) {
      return MapNotConfigured(tint: widget.tint);
    }

    final map = _MapboxCanvas(
      pins: pins,
      road: _road,
      tint: widget.tint,
      compact: widget.compact,
      fullScreen: widget.fullScreen,
      initialFit: spread ? points : null,
      onReady: (m) => _mapbox = m,
      onPinTap: widget.compact
          ? null
          : (stopId) => setState(() => _touched = stopId),
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
            child: _Callout(
              pin: _shown(pins),
              tint: widget.tint,
              leg: widget.leg,
              expanded: _touched != null,
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
                        stops: widget.stops,
                        tint: widget.tint,
                        leg: widget.leg,
                        terminalStopId: widget.terminalStopId,
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
          ValueListenableBuilder<geo.Position?>(
            valueListenable: BusLocation.instance.here,
            builder: (context, me, _) {
              if (me == null) return const SizedBox.shrink();
              return PositionedDirectional(
                end: 10,
                top: 64,
                child: Semantics(
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
                        Icons.my_location_rounded,
                        size: 21,
                        color: AppTheme.blue,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        const _Credit(),
      ],
    );
  }

  Future<void> _fitAll(List<LatLng> points) async {
    final map = _mapbox;
    if (map == null || points.isEmpty) return;
    final camera = await map.cameraForCoordinates(
      [for (final p in points) Point(coordinates: Position(p.longitude, p.latitude))],
      widget.compact
          ? MbxEdgeInsets(top: 26, left: 26, bottom: 26, right: 26)
          : widget.fullScreen
              ? MbxEdgeInsets(top: 96, left: 54, bottom: 70, right: 54)
              : MbxEdgeInsets(top: 74, left: 46, bottom: 46, right: 46),
      null,
      null,
    );
    final zoom = camera.zoom;
    if (zoom != null && zoom > 16.5) camera.zoom = 16.5;
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

  List<_Stop> _pins() {
    final next = widget.stops.indexWhere((s) => s.departedAt == null);

    final out = <_Stop>[];
    for (var i = 0; i < widget.stops.length; i++) {
      final s = widget.stops[i];
      if (!stopIsPlaced(s)) continue;
      out.add(_Stop(
        stop: s,
        order: i + 1,
        at: LatLng(s.lat!, s.lon!),
        next: i == next,
        school: widget.terminalStopId != null && s.stopId == widget.terminalStopId,
      ));
    }
    return out;
  }

  _Stop? _shown(List<_Stop> pins) {
    for (final p in pins) {
      if (p.stop.stopId == _touched) return p;
    }
    for (final p in pins) {
      if (p.next) return p;
    }
    return null;
  }
}

class RouteMapScreen extends StatelessWidget {
  const RouteMapScreen({
    super.key,
    required this.stops,
    required this.tint,
    required this.leg,
    this.terminalStopId,
  });

  final List<PlannedStop> stops;
  final Color tint;
  final String leg;
  final String? terminalStopId;

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
                    stops: stops,
                    tint: tint,
                    leg: leg,
                    terminalStopId: terminalStopId,
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
    required this.stop,
    required this.order,
    required this.at,
    required this.next,
    required this.school,
  });

  final PlannedStop stop;

  final int order;
  final LatLng at;

  final bool next;

  final bool school;
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.pin,
    required this.tint,
    required this.leg,
    this.expanded = false,
  });

  final _Stop? pin;
  final Color tint;
  final String leg;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final p = pin;

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
        if (p.school) t('driver.school'),
        if (p.stop.done)
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

class _MapboxCanvas extends StatefulWidget {
  const _MapboxCanvas({
    required this.pins,
    required this.road,
    required this.tint,
    required this.compact,
    required this.fullScreen,
    required this.initialFit,
    required this.onReady,
    required this.onPinTap,
  });

  final List<_Stop> pins;

  final List<LatLng>? road;

  final Color tint;
  final bool compact;
  final bool fullScreen;

  final List<LatLng>? initialFit;

  final void Function(MapboxMap map) onReady;
  final void Function(String stopId)? onPinTap;

  @override
  State<_MapboxCanvas> createState() => _MapboxCanvasState();
}

class _MapboxCanvasState extends State<_MapboxCanvas> {
  MapboxMap? _map;
  PointAnnotationManager? _points;
  PolylineAnnotationManager? _lines;

  final Map<String, String> _stopForAnnotation = {};

  String? _drawnFor;

  StreamSubscription<geo.Position>? _live;
  List<LatLng>? _liveLeg;
  String? _liveLegFor;

  @override
  void dispose() {
    _live?.cancel();
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

    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: false,
        showAccuracyRing: true,
        puckBearingEnabled: true,
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
    _points ??= await map.annotations.createPointAnnotationManager();
    _lines ??= await map.annotations.createPolylineAnnotationManager();

    _points?.tapEvents(
      onTap: (annotation) {
        final stopId = _stopForAnnotation[annotation.id];
        if (stopId != null) widget.onPinTap?.call(stopId);
      },
    );

    _watchLive();
    await _draw();
  }

  void _watchLive() {
    _live?.cancel();
    _live = null;
    if (widget.compact) return;
    BusLocation.instance.here.addListener(_onFix);
    _onFix();
  }

  void _onFix() {
    final me = BusLocation.instance.here.value;
    if (me == null) return;
    final next = widget.pins.where((p) => p.stop.departedAt == null).firstOrNull;
    if (next == null) return;

    final from = LatLng(
      double.parse(me.latitude.toStringAsFixed(3)),
      double.parse(me.longitude.toStringAsFixed(3)),
    );
    final key = '${from.latitude},${from.longitude}>${next.stop.stopId}';
    if (_liveLegFor == key) return;
    _liveLegFor = key;

    final ready = Directions.cached([from, next.at]);
    _liveLeg = ready ?? [from, next.at];
    unawaited(_draw());

    if (ready == null) {
      Directions.road([from, next.at]).then((line) {
        if (!mounted || _liveLegFor != key) return;
        _liveLeg = line;
        unawaited(_draw());
      });
    }
  }

  Future<void> _draw() async {
    final points = _points;
    final lines = _lines;
    if (points == null || lines == null) return;

    final signature = [
      for (final p in widget.pins)
        '${p.stop.stopId}:${p.stop.departedAt != null}:${p.stop.skipped}:${p.school}',
      'road:${widget.road?.length ?? 0}',
      'live:${_liveLeg?.length ?? 0}',
    ].join('|');
    if (_drawnFor == signature) return;
    _drawnFor = signature;

    await points.deleteAll();
    await lines.deleteAll();
    _stopForAnnotation.clear();

    final route = widget.road ?? [for (final p in widget.pins) p.at];
    if (route.length >= 2) {
      await lines.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: [
              for (final p in route) Position(p.longitude, p.latitude),
            ],
          ),
          lineColor: widget.tint.toARGB32(),
          lineWidth: widget.compact ? 3.5 : 5.0,
          lineJoin: LineJoin.ROUND,
        ),
      );
    }

    final leg = _liveLeg;
    if (leg != null && leg.length >= 2) {
      await lines.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: [
              for (final p in leg) Position(p.longitude, p.latitude),
            ],
          ),
          lineColor: AppTheme.blue.toARGB32(),
          lineWidth: widget.compact ? 2.5 : 3.5,
          lineJoin: LineJoin.ROUND,
        ),
      );
    }

    for (final pin in widget.pins) {
      final image = await _pinImage(pin);
      final made = await points.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(pin.at.longitude, pin.at.latitude)),
          image: image,
          iconSize: 1,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
      _stopForAnnotation[made.id] = pin.stop.stopId;
    }
  }
  static final Map<String, Uint8List> _images = {};

  Future<Uint8List> _pinImage(_Stop pin) async {
    final tint = widget.tint;
    final done = pin.stop.done;
    final plain = !pin.school && !done && !pin.next;
    final size = widget.compact ? (pin.next ? 32.0 : 25.0) : (pin.next ? 52.0 : 40.0);

    final fill = pin.school
        ? AppTheme.blue
        : done
            ? AppTheme.green
            : pin.next
                ? tint
                : AppTheme.surface;
    final ink = plain ? tint : Colors.white;

    final label = pin.school
        ? null
        : done
            ? null
            : '${pin.order}';
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final key = '${fill.toARGB32()}:${ink.toARGB32()}:$size:${pin.school}:$done:'
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
    final rect = Rect.fromCenter(center: centre, width: size, height: size);

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3.5);
    final body = Paint()..color = fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = border
      ..color = plain ? tint : Colors.white;

    if (pin.school) {
      final r = RRect.fromRectAndRadius(rect, Radius.circular(size * 0.3));
      canvas.drawRRect(r.shift(const Offset(0, 2)), shadow);
      canvas.drawRRect(r, body);
      canvas.drawRRect(r.deflate(border / 2), stroke);
    } else {
      canvas.drawCircle(centre.translate(0, 2), half, shadow);
      canvas.drawCircle(centre, half, body);
      canvas.drawCircle(centre, half - border / 2, stroke);
    }

    final icon = pin.school
        ? Icons.school_rounded
        : done
            ? Icons.check_rounded
            : null;

    final painter = TextPainter(textDirection: TextDirection.ltr);
    if (icon != null) {
      painter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * (pin.school ? 0.5 : 0.55),
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
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

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (canvasSize * dpr).round(),
      (canvasSize * dpr).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = bytes!.buffer.asUint8List();
    _images[key] = out;
    return out;
  }

  @override
  void didUpdateWidget(covariant _MapboxCanvas old) {
    super.didUpdateWidget(old);
    unawaited(_draw());
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.pins.first.at;
    return MapWidget(
      key: const ValueKey('run-map'),
      styleUri: MapTiles.styleUri,
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(first.longitude, first.latitude)),
        zoom: 14.5,
        padding: MbxEdgeInsets(top: 56, left: 40, bottom: 40, right: 40),
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}
