import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// latlong2 exports a generic Path<T> for geodesic paths, which shadows
// dart:ui's Path and breaks anything in the file that paints.
import 'package:geolocator/geolocator.dart';
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
  final _map = MapController();

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
    _map.dispose();
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

    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: points.first,
        initialZoom: 15.5,
        // The whole run on screen from the first frame, so nobody has to drag a
        // map to find out where the morning goes.
        initialCameraFit: spread ? _fit(points) : null,
        minZoom: 3,
        maxZoom: 18,
        // Not the package's default grey. This is what shows through before a
        // tile lands, and instead of one that never does — on a bus, that is
        // most of the time.
        backgroundColor: AppTheme.neutralSoft,
        // No rotation, ever. North stays up so the streets match the ones in
        // the driver's head; a map twisted by a stray two-finger drag on a
        // phone in a cradle is a map nobody can read.
        //
        // And no ONE-FINGER drag. This map sits in the middle of a scrolling
        // screen, so a map that took single-finger drags would eat every swipe
        // meant for the stop list underneath — the driver pushes up to reach
        // the next stop and the map slides away instead. Two fingers pan it,
        // two fingers zoom it, and the button in the corner puts the whole run
        // back on screen. One finger belongs to the page.
        interactionOptions: InteractionOptions(
          flags: widget.compact
              ? InteractiveFlag.none
              : widget.fullScreen
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.pinchZoom |
                      InteractiveFlag.pinchMove |
                      InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        MapTiles.layer(),
        PolylineLayer(polylines: _order(pins)),
        // The bit of the journey the driver is actually on: from where the bus
        // is now to the stop it is heading for.
        //
        // The route line only ever joined stop to stop, so the leg being driven
        // at this moment — the only one that is not yet history or not yet
        // relevant — was the one segment missing from the map. Dashed, because
        // it is the bus's own position over open ground rather than a planned
        // road, and nothing should read it as the route the office authored.
        ValueListenableBuilder<Position?>(
          valueListenable: BusLocation.instance.here,
          builder: (context, me, _) {
            if (me == null) return const SizedBox.shrink();
            final next = pins.where((p) => p.stop.departedAt == null).firstOrNull;
            if (next == null) return const SizedBox.shrink();
            return PolylineLayer(
              polylines: [
                Polyline(
                  points: [LatLng(me.latitude, me.longitude), next.at],
                  strokeWidth: widget.compact ? 2.5 : 3.5,
                  color: AppTheme.blue.withValues(alpha: 0.75),
                  pattern: StrokePattern.dashed(segments: const [7, 6]),
                ),
              ],
            );
          },
        ),
        MarkerLayer(
          markers: [
            for (final p in pins)
              Marker(
                point: p.at,
                width: _size(p) + 10,
                height: _size(p) + 10,
                child: _Pin(
                  pin: p,
                  tint: widget.tint,
                  size: _size(p),
                  onTap: widget.compact
                      ? null
                      : () => setState(() => _touched = p.stop.stopId),
                ),
              ),
          ],
        ),
        // The bus itself, over its own route.
        //
        // Drawn from the live fix rather than the last position the server
        // happened to store, so it is honest about being this handset's own
        // idea of where it is. Nothing is drawn at all until there is a fix —
        // a dot at 0,0 in the Gulf of Guinea is worse than no dot.
        ValueListenableBuilder<Position?>(
          valueListenable: BusLocation.instance.here,
          builder: (context, me, _) {
            if (me == null) return const SizedBox.shrink();
            return MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(me.latitude, me.longitude),
                  width: 26,
                  height: 26,
                  child: const _MeDot(),
                ),
              ],
            );
          },
        ),
      ],
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
                  _map.fitCamera(_fit(points));
                } else {
                  _map.move(points.first, 15.5);
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
        const _Credit(),
      ],
    );
  }

  /// Room for the callout above, and enough that a marker never sits against
  /// the frame, where it reads as off-screen.
  CameraFit _fit(List<LatLng> points) => CameraFit.coordinates(
        coordinates: points,
        padding: widget.compact
            ? const EdgeInsets.all(26)
            : widget.fullScreen
                ? const EdgeInsets.fromLTRB(54, 96, 54, 70)
                : const EdgeInsets.fromLTRB(46, 74, 46, 46),
        // Close enough to read the street, never so close that two stops on the
        // same road land on top of each other.
        maxZoom: 16.5,
      );

  double _size(_Stop p) => widget.compact ? (p.next ? 32 : 25) : (p.next ? 52 : 40);

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

  /// The line through the stops.
  ///
  /// The line follows the roads, through Mapbox Directions, and falls back to
  /// stop-to-stop when it cannot: offline, out of quota, or a stop pinned
  /// somewhere no vehicle can reach. It used to be stop-to-stop always, which
  /// drew the run through the Citadel and across blocks with no through road —
  /// a picture of the ORDER presented as a picture of the route.
  ///
  /// The part already driven is green and the part still owed is the driver
  /// tint, which is the same reading as the stop list underneath.
  List<Polyline> _order(List<_Stop> pins) {
    final width = widget.compact ? 3.5 : 5.0;
    final casing = AppTheme.surface.withValues(alpha: 0.8);
    final done = AppTheme.green.withValues(alpha: 0.75);
    final owed = widget.tint.withValues(alpha: 0.9);

    final road = _road;
    if (road != null && road.length > 2) {
      // The driving line, cut once at the last stop already visited so the part
      // behind the bus reads the same here as it does in the list underneath.
      //
      // The cut is made at the point of the LINE nearest that stop rather than
      // at the stop's own coordinate: a stop sits a few metres off the
      // carriageway, and joining the two halves there would put a visible kink
      // in the road.
      final lastDone = pins.lastIndexWhere((p) => p.stop.done);
      if (lastDone <= 0 || lastDone == pins.length - 1) {
        return [
          Polyline(
            points: road,
            strokeWidth: width,
            color: lastDone == pins.length - 1 ? done : owed,
            borderStrokeWidth: 2,
            borderColor: casing,
          ),
        ];
      }

      final cut = Directions.nearestIndex(road, pins[lastDone].at);
      return [
        Polyline(
          points: road.sublist(0, cut + 1),
          strokeWidth: width,
          color: done,
          borderStrokeWidth: 2,
          borderColor: casing,
        ),
        Polyline(
          points: road.sublist(cut),
          strokeWidth: width,
          color: owed,
          borderStrokeWidth: 2,
          borderColor: casing,
        ),
      ];
    }

    // No road yet — the first paint, or Mapbox could not answer. Stop to stop,
    // which is what this always drew.
    final out = <Polyline>[];
    for (var i = 0; i + 1 < pins.length; i++) {
      final a = pins[i];
      final b = pins[i + 1];
      final behind = a.stop.done && b.stop.done;
      out.add(Polyline(
        points: [a.at, b.at],
        strokeWidth: width,
        color: behind ? done : owed,
        // A pale casing, so the line stays readable over a dark block of
        // buildings as well as over pale paper.
        borderStrokeWidth: 2,
        borderColor: casing,
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

/// A stop on the map, big enough to hit with a glove.
///
/// Three things told by shape as well as by colour, because a driver squinting
/// at a phone in low sun is not reading hues: the school is a rounded square, a
/// finished stop is a tick, and the next stop is half again the size of
/// everything else with a halo round it.
class _Pin extends StatelessWidget {
  const _Pin({
    required this.pin,
    required this.tint,
    required this.size,
    required this.onTap,
  });

  final _Stop pin;
  final Color tint;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final done = pin.stop.done;
    final plain = !pin.school && !done && !pin.next;
    final fill = pin.school
        ? AppTheme.blue
        : done
            ? AppTheme.green
            : pin.next
                ? tint
                : AppTheme.surface;

    final body = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: pin.school ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: pin.school ? BorderRadius.circular(size * 0.3) : null,
        border: Border.all(
          color: plain ? tint : Colors.white,
          width: size > 34 ? 3 : 2.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: pin.school
          ? Icon(Icons.school_rounded, size: size * 0.5, color: Colors.white)
          : done
              ? Icon(Icons.check_rounded, size: size * 0.55, color: Colors.white)
              : Text(
                  '${pin.order}',
                  style: TextStyle(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: plain ? tint : Colors.white,
                  ),
                ),
    );

    final marker = pin.next
        ? Stack(
            alignment: Alignment.center,
            children: [
              // The halo. The one thing on this map that has to be found
              // without being looked for.
              Container(
                width: size + 10,
                height: size + 10,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                ),
              ),
              body,
            ],
          )
        : body;

    if (onTap == null) return Center(child: marker);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(child: marker),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Over the map
 * ------------------------------------------------------------------------- */

/// Which stop is being looked at, in words.
///
/// The next one by default — a driver should not have to work out which of
/// twelve circles is theirs — and whichever marker was tapped after that, so a
/// pin can be identified without captions cluttering the map.
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

/// Not one stop on this run has a position on file.
///
/// A themed panel that names the problem, rather than an empty map of
/// somewhere: a map centred on a default city with no pins on it would be read
/// as the run.
/// The bus, where this handset says it is.
///
/// A blue dot with a white collar rather than a bus glyph: it is the shape
/// every mapping app on the phone already uses for "you are here", and a
/// driver should not have to learn a new one from us. Deliberately smaller
/// than a stop pin — it moves, and the stops are what the run is about.
class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: AppTheme.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

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
