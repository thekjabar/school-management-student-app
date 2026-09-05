import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
// latlong2 exports a generic Path<T> for geodesic paths, which shadows
// dart:ui's Path and breaks anything in the file that paints.
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

/// Whether a stop carries a position this app is allowed to draw.
///
/// Null is the ordinary case: a stop the office has not pinned yet. (0, 0) is
/// not a stop either — it is what a database holds when nobody typed anything,
/// and it is a spot in the Gulf of Guinea that would drag the camera off the
/// city and squash the whole run into one pixel.
///
/// A stop that fails this is left OFF the map and named underneath it. It is
/// never drawn at a guessed position: that is a bus sent to the wrong street.
bool stopIsPlaced(PlannedStop s) {
  final lat = s.lat;
  final lon = s.lon;
  if (lat == null || lon == null) return false;
  if (lat == 0 && lon == 0) return false;
  return lat.abs() <= 90 && lon.abs() <= 180;
}

/// The run on a real map — Mapbox tiles, one marker per stop, standing
/// where the stop actually is.
///
/// This replaced a CustomPaint that drew a lazy S-curve with dots on it and
/// captioned itself "not a live map". The apology was the honest half of a
/// dishonest widget: the coordinates were on every stop the whole time, and the
/// parent side of this app has been drawing real OSM tiles since it shipped.
///
/// What the map does NOT claim:
///
///   * The line between two markers is the ORDER the stops are driven, not the
///     road the bus takes. Road geometry needs a routing service this product
///     does not have. There is no caption saying so, because a straight line
///     between two pins is universally read as "these two connect" — the old
///     caption existed to excuse a drawing, and this is not a drawing.
///   * The bus is drawn from THIS handset's own fix, and only once there is
///     one. Before that no bus marker exists at all — an invented one is a bus
///     on the wrong street, and the whole point of the dot is that it is real.
///
/// Built for 06:40 in a yard, one-handed, in gloves: the next stop is the
/// largest thing on the map, markers are finger-sized, and every pin, line and
/// number is drawn from data the phone already holds. Tiles are the only part
/// that needs the network, so when the signal is bad the run still draws over a
/// plain themed ground instead of a grey void, and nothing blocks the screen
/// while tiles arrive.
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

  /// The stops in the order they are driven — the order the plan returned,
  /// whether that is the office's or nearest-first.
  final List<PlannedStop> stops;

  final Color tint;

  /// OUT or RETURN, which decides whether a stop's children are picked up or
  /// dropped off.
  final String leg;

  /// The campus gate, when the caller knows it.
  ///
  /// The plan cannot name it — its stops are built from the manifest and no
  /// child belongs to the gate — so only a screen that has read the trip pack
  /// can pass it. Null means "not known", never "not there", and an unknown
  /// gate is simply drawn as an ordinary stop rather than guessed at.
  final String? terminalStopId;

  /// The small map beside the run's name on the home card: no interaction, no
  /// callout, smaller markers.
  final bool compact;

  /// Filling a screen of its own, pushed from the corner button of the card
  /// map. There is no page underneath to scroll, so one finger pans it, and
  /// the corner button fits the whole run back on screen instead of opening
  /// another copy.
  final bool fullScreen;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  MapboxMap? _mapbox;

  /// The stop whose marker was last tapped, by id rather than by index so it
  /// survives the reload that follows every arrive and depart.
  String? _touched;

  /// The run drawn along the roads, once Mapbox has said where they go.
  ///
  /// Null until the first answer, and the straight line is drawn meanwhile —
  /// the order of the stops is the thing the driver needs, and it should not
  /// wait on a network round trip to appear.
  List<LatLng>? _road;

  /// The stops the shape in [_road] was fetched for, so a run whose stops
  /// change — a skipped stop, a re-ordered route — asks again rather than
  /// drawing the old shape through the new pins.
  String? _roadFor;

  @override
  void dispose() {
    super.dispose();
  }

  /// Ask for the driving line, once per distinct set of stops.
  ///
  /// Called from build because the stops arrive as a widget property and change
  /// under it; guarded by [_roadFor] so a rebuild does not re-request. Failure
  /// is silent by design — Directions hands back the straight line, which is
  /// what was being drawn before any of this existed.
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

    // Nothing to place. The list is the run, so say so and let the caller's own
    // list answer the question — an empty grey square would not.
    //
    // Two different nothings, and they must not read the same: a run with no
    // stops on it at all, and a run whose stops have never been pinned.
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

    // Every stop at the same spot — one stop, or a route whose pins were all
    // typed the same. Fitting a camera to a zero-sized box divides by nothing,
    // so centre on it instead.
    final spread = <String>{
      for (final p in points)
        '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}',
    }.length > 1;

    // No token, no tiles, and a driver looking at a blank rectangle before a
    // shift cannot tell that from a route that has not loaded.
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
      // Inside a card whose own tap opens the run. A map that swallowed that
      // tap would break the card.
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
            child: _Callout(pin: _shown(pins), tint: widget.tint, leg: widget.leg),
          ),
        ),
        // In the card this opens the run full screen; full screen, where the
        // map already fills the window, it puts the whole run back in view.
        // The card used to carry the re-fit here too, and with the run already
        // fitted — which it is, from the first frame — the button did nothing
        // visible, which reads as broken.
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
              // 44 square. Everything on a driver screen is pressed with a
              // gloved thumb.
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
        // Centre on the bus.
        //
        // Under the fit-the-run button, because they are the two halves of the
        // same question — where is the run, and where am I in it — and a driver
        // who has panned away needs the second one as often as the first. Shown
        // only in the full-screen map, and only once there is a real fix: a
        // locate button that answers with nothing is worse than no button.
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

  /// The whole run back on screen.
  ///
  /// Room for the callout above, and enough that a marker never sits against
  /// the frame, where it reads as off-screen. The engine works the camera out
  /// from the coordinates rather than being told a zoom, so a run down one
  /// street and a run across the city both fill the frame.
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
    // Close enough to read the street, never so close that two stops on the
    // same road land on top of each other.
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

  /// The pins, in driving order, skipping every stop with no position.
  List<_Stop> _pins() {
    // The first stop not yet departed. Not the nearest — a driver following the
    // route wants the next one in order, and the nearest is the one they just
    // left as often as it is the one ahead.
    final next = widget.stops.indexWhere((s) => s.departedAt == null);

    final out = <_Stop>[];
    for (var i = 0; i < widget.stops.length; i++) {
      final s = widget.stops[i];
      if (!stopIsPlaced(s)) continue;
      out.add(_Stop(
        stop: s,
        // Numbered by where it falls in the run, so the numbers count 1, 2, 3
        // along the road the bus is actually driving.
        order: i + 1,
        at: LatLng(s.lat!, s.lon!),
        next: i == next,
        school: widget.terminalStopId != null && s.stopId == widget.terminalStopId,
      ));
    }
    return out;
  }

  /// What the callout is about: the marker last tapped, else the next stop,
  /// else nothing, on a run where every stop is behind.
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

/// The run on a map that fills the screen.
///
/// Pushed from the corner button of the card map on the run and route
/// screens. Same stops, same pins, same tint; the difference is room — the
/// card is 230 pixels high and a run across half of Erbil is a cluster of
/// numbers in it — and one-finger panning, which the card cannot allow
/// because it sits in a scrolling page.
///
/// The stops are the list the caller had when the button was pressed. The
/// screen underneath reloads after every arrive and depart, and the driver is
/// back on it for those, so a snapshot is the right thing here.
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

/// One stop, placed.
class _Stop {
  const _Stop({
    required this.stop,
    required this.order,
    required this.at,
    required this.next,
    required this.school,
  });

  final PlannedStop stop;

  /// Its position in the run, counting from 1.
  final int order;
  final LatLng at;

  /// The one the bus is driving to now.
  final bool next;

  /// The campus gate rather than somebody's street corner.
  final bool school;
}

/* ---------------------------------------------------------------------------
 * Markers
 * ------------------------------------------------------------------------- */
class _Callout extends StatelessWidget {
  const _Callout({required this.pin, required this.tint, required this.leg});

  final _Stop? pin;
  final Color tint;
  final String leg;

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
          // Every stop departed. The run is done, and there is no next one.
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
          : Row(
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
    );
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

/// Mapbox's licence requires the credit. It is not decoration and it
/// does not come off.
class _Credit extends StatelessWidget {
  const _Credit({this.small = false});

  final bool small;

  @override
  // The small one sits on the trailing side: on the home card the leading edge
  // of the map is under a fade, and a credit nobody can reach is not a credit.
  Widget build(BuildContext context) => PositionedDirectional(
        start: small ? null : 8,
        end: small ? 5 : null,
        bottom: small ? 4 : 6,
        child: MapAttribution(small: small),
      );
}

/* ---------------------------------------------------------------------------
 * When there is nothing to map
 * ------------------------------------------------------------------------- */

/// Drawn in place of the map when the run has no stop this app may plot.
class _NoMap extends StatelessWidget {
  const _NoMap({required this.compact, required this.tint, required this.reason});

  final bool compact;
  final Color tint;

  /// Which nothing this is, already said in the reader's language.
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

/// The stops the map could not show, named.
///
/// Sits under the map card. A stop with no coordinates is not drawn at all, so
/// without this line it would simply be missing — and a driver counting pins
/// against the list would come up one short with nothing to say why.
///
/// Silent when every stop is placed, and silent when NONE is: in that case the
/// panel where the map would have been has already said so, and repeating the
/// whole list under it is noise.
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

/// The run drawn by Mapbox's own engine.
///
/// This replaced a raster-tile map. The school's style is a Mapbox Standard
/// style, and Standard carries no layers of its own — it is an import resolved
/// at draw time by the GL engine, which is why the raster endpoint answered
/// every tile with a 235-byte transparent PNG and every map came out blank. The
/// engine had to change for the style to exist at all.
///
/// What that buys beyond the style: real vector rendering, so labels stay crisp
/// at every zoom instead of being rasterised at one and stretched; no tile
/// seams; and the platform's own location puck, which draws the accuracy ring
/// and the heading properly rather than the circle-and-dot this file used to
/// paint by hand.
///
/// What it costs: markers are images, not widgets. This SDK has no
/// ViewAnnotationManager, so the numbered pins are drawn to PNG once and placed
/// as point annotations with the number as native label text. The callout, the
/// buttons and the credit are unaffected — they were always screen-anchored
/// rather than pinned to a coordinate.
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

  /// The run along the roads, once Directions has said where they go. Null
  /// until the first answer, and the straight line is drawn meanwhile.
  final List<LatLng>? road;

  final Color tint;
  final bool compact;
  final bool fullScreen;

  /// Every stop, so the first frame holds the whole run. Null when they all sit
  /// at one spot and there is nothing to fit.
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

  /// The annotation id of each pin, so a tap can be turned back into the stop
  /// it belongs to. The SDK hands back its own id and nothing else.
  final Map<String, String> _stopForAnnotation = {};

  /// What the annotations were last drawn from. Redrawing on every rebuild
  /// would clear and re-add forty images a second while the camera moves.
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

    // North stays up and the map stays flat. A map twisted by a stray finger on
    // a phone in a cradle is a map nobody can read, and the streets in a
    // driver's head are all north-up.
    await map.gestures.updateSettings(
      GesturesSettings(
        rotateEnabled: false,
        pitchEnabled: false,
        // The card map sits inside a scrolling screen. A map that took
        // one-finger drags would eat every swipe meant for the stop list under
        // it — the driver pushes up to reach the next stop and the map slides
        // away instead.
        scrollEnabled: !widget.compact,
        pinchToZoomEnabled: !widget.compact,
        doubleTapToZoomInEnabled: !widget.compact,
        quickZoomEnabled: !widget.compact,
      ),
    );

    // Mapbox's own puck, rather than the dot and circle this file used to paint.
    // It interpolates between fixes so the bus glides instead of jumping, draws
    // the accuracy ring to the map's scale, and turns to face the heading.
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

  /// Follow the bus, so the leg it is driving can be drawn and redrawn.
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

    // Snapped to roughly a hundred metres before the road is asked for. The
    // position updates every few seconds and the directions cache is keyed to
    // about a metre, so asking on every fix would be several hundred requests
    // across a morning for lines nobody could tell apart.
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

  /// Put the run on the map: the route, the leg being driven, and a pin per
  /// stop. Cleared and redrawn as a set, because a partial update leaves a
  /// stale pin on a stop that has since been served.
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

    // The route first, so the pins sit on top of it.
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

    // Then the leg the bus is on, in the location colour rather than the
    // route's, because it is where the bus is and not where the office said to
    // drive.
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
          // The number rides as native label text rather than being drawn into
          // the image, so one image serves every stop of the same state.
          textField: pin.school ? '' : '${pin.order}',
          textColor: _pinInk(pin).toARGB32(),
          textSize: widget.compact ? 10 : 13,
          textOffset: const [0, 0.05],
        ),
      );
      _stopForAnnotation[made.id] = pin.stop.stopId;
    }
  }

  Color _pinInk(_Stop pin) {
    if (pin.school) return Colors.white;
    if (pin.stop.skipped) return AppTheme.amber;
    if (pin.stop.departedAt != null) return Colors.white;
    return pin.next ? Colors.white : widget.tint;
  }

  /// A pin drawn to PNG. Three states and the school, cached by their look, so
  /// a run of forty stops rasterises four images rather than forty.
  static final Map<String, Uint8List> _images = {};

  Future<Uint8List> _pinImage(_Stop pin) async {
    final done = pin.stop.departedAt != null;
    final fill = pin.school
        ? AppTheme.blue
        : pin.stop.skipped
            ? AppTheme.amberSoft
            : done
                ? AppTheme.green
                : pin.next
                    ? widget.tint
                    : Colors.white;
    final ring = pin.school
        ? Colors.white
        : done
            ? Colors.white
            : pin.next
                ? Colors.white
                : widget.tint;
    final size = widget.compact ? 26.0 : (pin.next || pin.school ? 46.0 : 38.0);
    final key = '${fill.toARGB32()}:${ring.toARGB32()}:$size:${pin.school}';
    final cached = _images[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;
    // A soft shadow, so a white pin is still a pin against pale ground.
    canvas.drawCircle(
      Offset(r, r + 1),
      r - 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
    );
    canvas.drawCircle(Offset(r, r), r - 3, Paint()..color = fill);
    canvas.drawCircle(
      Offset(r, r),
      r - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ring,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.round(), size.round());
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
