import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
// latlong2 exports a generic Path<T> for geodesic paths, which shadows
// dart:ui's Path. Nothing here paints one any more, but nothing here should
// ever pick up the wrong one by accident either.
import 'package:latlong2/latlong.dart' hide Path;

import '../../api/directions.dart';
import '../../api/parent_api.dart';
import '../../api/push.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/map_tiles.dart';
import '../../ui/screen_kit.dart';
import 'track_screen.dart';

/// Where the bus is, and when it gets there.
///
/// One question, asked at 07:40 with a coat half on. The ETA is the largest
/// thing on the screen; everything under it is what a parent reads once and
/// then never again — the driver's name, the plate, the number to ring.
class BusScreen extends StatefulWidget {
  const BusScreen({super.key, required this.child});

  final Child child;

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  final _loaderKey = GlobalKey<LoaderState<_Bus>>();
  final _map = MapController();
  Timer? _tick;
  bool _dismissedAlerts = false;

  /// The arrangement's stops, fetched once. They do not move between polls,
  /// and a lookup that fails must not take the bus down with it.
  AssignedStops? _stops;

  @override
  void initState() {
    super.initState();
    // A live position that does not move is not live. Half a minute is often
    // enough to see the bus turn into the street.
    //
    // Quiet, because an ordinary reload drops the screen to a spinner for the
    // length of the request — and now that there is a real map on it, that is
    // a map that blinks out and fetches its tiles again twice a minute.
    _tick = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loaderKey.currentState?.reload(quiet: true),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _map.dispose();
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
            ScreenHeader(
              title: t('bus.title'),
              trailing: ChildPill(
                name: widget.child.name,
                line: widget.child.className,
                tint: tint,
              ),
            ),
            Expanded(
              child: Loader<_Bus>(
                key: _loaderKey,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
                load: () async {
                  final r = await Future.wait<Object?>([
                    ParentApi.instance.transport(widget.child.studentId),
                    ParentApi.instance.live(),
                    _assignedStops(),
                  ]);
                  final buses = r[1] as List<LiveBus>;
                  return _Bus(
                    transport: r[0] as TransportInfo,
                    live: buses
                        .where((b) => b.studentId == widget.child.studentId)
                        .firstOrNull,
                    stops: r[2] as AssignedStops?,
                  );
                },
                builder: (context, bus) {
                  if (!bus.transport.ridesTheBus) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: Center(
                        child: Text(
                          t('bus.notOnBus'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ),
                    );
                  }

                  final trip = bus.run;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _frame(bus));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MapCard(bus: bus, controller: _map, onOpen: _openTrack),
                      const SizedBox(height: kCardGap),
                      _RouteCard(bus: bus),
                      const SizedBox(height: kCardGap),
                      _Tiles(bus: bus, trip: trip),
                      if (!_dismissedAlerts && !Push.granted) ...[
                        const SizedBox(height: kCardGap),
                        NoticeBanner(
                          icon: Icons.notifications_active_rounded,
                          color: tint,
                          title: t('bus.getNotified'),
                          body: t('bus.getNotifiedBody'),
                          action: t('bus.enableAlerts'),
                          onAction: _enableAlerts,
                          onClose: () => setState(() => _dismissedAlerts = true),
                        ),
                      ],
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

  /// Where the arrangement puts this child's stops.
  ///
  /// For the days the live feed has nothing to say — a weekend, a holiday, an
  /// account the school has not granted location to — the map can still show
  /// where the bus collects her. /parent/home is what the home-address screen
  /// already reads: the family's own arrangement, and never a position.
  Future<AssignedStops?> _assignedStops() async {
    if (_stops != null) return _stops;
    try {
      final home = await ParentApi.instance.homeLocation();
      _stops = home.children
          .where((c) => c.studentId == widget.child.studentId)
          .firstOrNull;
    } catch (_) {
      // Then the map draws what the live feed gives it, which may be nothing.
      // That is said on the card; an error page here would hide the driver's
      // number behind a lookup the parent never asked for.
    }
    return _stops;
  }

  /// Put everything known on screen.
  ///
  /// Every time, not once: nobody can pan this map, so there is no view of
  /// theirs to preserve, and a bus that drives out of the frame between two
  /// polls is a bus that has vanished.
  void _frame(_Bus bus) {
    // The same test the card makes before it builds a map at all. The
    // controller is only attached while one exists.
    if (!MapTiles.configured) return;
    final points = bus.mapPoints;
    if (points.isEmpty) return;

    if (points.length == 1) {
      _map.move(points.first, 15.5);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        // Room for the callouts drawn over the map, and enough that a marker
        // never sits against the frame's edge where it reads as off-screen.
        padding: const EdgeInsets.fromLTRB(44, 76, 44, 66),
        maxZoom: 16,
      ),
    );
  }

  void _openTrack() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackScreen(child: widget.child)),
    );
  }

  Future<void> _enableAlerts() async {
    final ok = await Push.askPermission();
    if (!mounted) return;
    setState(() {});
    if (!ok) showNote(context, t('more.pushBlocked'));
  }
}

class _Bus {
  _Bus({required this.transport, required this.live, required this.stops});

  final TransportInfo transport;
  final LiveBus? live;

  /// The arrangement's stops, when the home lookup answered.
  final AssignedStops? stops;

  /// The run this screen is about: the afternoon one once it is under way, the
  /// morning one until then.
  TripToday? get run {
    if (transport.today.isEmpty) return null;
    final back = transport.today.where((t) => t.leg == 'RETURN').toList();
    if (back.isNotEmpty && (back.first.boardedAt != null || back.first.status == 'IN_PROGRESS')) {
      return back.first;
    }
    final out = transport.today.where((t) => t.leg == 'OUT').toList();
    return out.isNotEmpty ? out.first : transport.today.first;
  }

  bool get moving => run?.status == 'IN_PROGRESS';

  /// Which way this run goes. The morning leg is home → school, the afternoon
  /// school → home; no run at all reads as the morning one.
  bool get toSchool => run == null || run!.leg != 'RETURN';

  /// The bus, where the live feed has a position it is allowed to show.
  LatLng? get busAt {
    final l = live;
    return l != null && l.hasFix ? LatLng(l.lat!, l.lon!) : null;
  }

  /// The child's stop for this run: the pickup going out, the drop-off coming
  /// home. The live feed's placement first, since that is the stop on the trip
  /// the feed is actually about; the arrangement's when the feed has none.
  LatLng? get stopAt {
    final l = live;
    if (l != null && l.stopLat != null && l.stopLon != null) {
      return LatLng(l.stopLat!, l.stopLon!);
    }
    final s = toSchool ? stops?.pickup : stops?.dropoff;
    if (s != null && s.lat != null && s.lon != null) return LatLng(s.lat!, s.lon!);
    return null;
  }

  /// Everything the map has to show.
  ///
  /// The school is not among them. No parent endpoint returns a campus
  /// position, and a pin placed by guess is a wrong answer drawn confidently.
  List<LatLng> get mapPoints => [?busAt, ?stopAt];
}

/* ---------------------------------------------------------------------------
 * The map
 * ------------------------------------------------------------------------- */

/// A real map, framed for the parent.
///
/// It used to be a drawing: a dashed curve between a house and a school, with
/// the bus dot placed by the trip's status. A parent read it as where their
/// child was. This is Mapbox, the same tiles as the full tracking screen, with
/// only what the platform actually knows about drawn on it — the bus when it is
/// reporting and may be shown, the child's stop when the office has placed it,
/// and a dotted line between the two that is a distance, not a route.
///
/// It cannot be panned. It sits in the page's scrolling list, where a drag
/// would fight the scroll, and the framing is done for the parent on every
/// poll. Anyone who wants to look around taps it and gets the full screen.
class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.bus,
    required this.controller,
    required this.onOpen,
  });

  final _Bus bus;
  final MapController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final live = bus.live;
    final eta = live?.etaMinutes;
    final trip = bus.run;
    final busAt = bus.busAt;
    final stopAt = bus.stopAt;
    final points = bus.mapPoints;
    final drawn = points.isNotEmpty && MapTiles.configured;

    // Where this run is headed. Origin and destination trade places between
    // the morning and the afternoon leg.
    final toSchool = bus.toSchool;
    final school = Session.instance.me?.schoolName ?? t('driver.school');
    final originName =
        toSchool ? (bus.transport.pickupStopName ?? t('bus.home')) : school;
    final destName =
        toSchool ? school : (bus.transport.dropoffStopName ?? t('bus.home'));

    final Widget ground;
    if (points.isEmpty) {
      ground = const _NothingToMap();
    } else if (!MapTiles.configured) {
      ground = MapNotConfigured(tint: tint);
    } else {
      ground = FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: points.first,
          initialZoom: 15,
          minZoom: 4,
          maxZoom: 18,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          // A tap anywhere on the map is a request for the big one. Only when
          // there is a live row to open it on; without one the full screen
          // says "no bus", which is a door that opens onto a wall.
          onTap: live == null ? null : (_, _) => onOpen(),
        ),
        children: [
          MapTiles.layer(),

          // How far the bus still has to come — along the roads it will take
          // when Mapbox can say, and dotted-straight while it cannot.
          //
          // Dotted was the honest form when there was no routing at all: a
          // solid straight line reads as a road, and this one crossed blocks
          // no bus can drive through. Now the road is drawn solid, because it
          // IS the road, and only the fallback stays dotted.
          //
          // The bus coordinate is rounded to about a hundred metres before it
          // is asked about, so a bus creeping up a street reuses one answer
          // instead of spending a request and a parent's data on every tick.
          if (busAt != null && stopAt != null)
            Builder(
              builder: (_) {
                final coarse = LatLng(
                  (busAt.latitude * 1000).roundToDouble() / 1000,
                  (busAt.longitude * 1000).roundToDouble() / 1000,
                );
                final road = Directions.cached([coarse, stopAt]);
                if (road == null) unawaited(Directions.road([coarse, stopAt]));
                return PolylineLayer(
                  polylines: [
                    Polyline(
                      points: road ?? [busAt, stopAt],
                      strokeWidth: 3,
                      pattern: road == null ? const StrokePattern.dotted() : const StrokePattern.solid(),
                      color: tint.withValues(alpha: road == null ? 0.55 : 0.8),
                    ),
                  ],
                );
              },
            ),

          MarkerLayer(
            markers: [
              if (stopAt != null)
                Marker(
                  point: stopAt,
                  width: 30,
                  height: 30,
                  child: _StopPin(colour: tint),
                ),
              if (busAt != null)
                Marker(
                  point: busAt,
                  width: 34,
                  height: 34,
                  child: _BusPin(
                    // Green only when she is actually on it, as on the full
                    // tracking screen. A bus that is not carrying her is a
                    // bus, and it is drawn as one.
                    colour: live!.onBoard ? AppTheme.green : AppTheme.textMuted,
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return Card16(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              Positioned.fill(child: ground),

              PositionedDirectional(
                start: 10,
                top: 10,
                child: _Callout(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: bus.moving ? AppTheme.green : AppTheme.textFaint,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                bus.moving ? t('bus.onTheWay') : t('bus.noRunTitle'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: bus.moving ? AppTheme.green : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.sensors_rounded, size: 13, color: AppTheme.textMuted),
                              const SizedBox(width: 5),
                              Text(
                                live?.visible == true ? t('bus.live') : t('bus.notLive'),
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (eta != null) ...[
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$eta',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                    height: 1,
                                    color: tint,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    t('bus.min'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              t('bus.estimatedArrival'),
                              style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Origin to destination, by leg: home → school in the morning,
              // school → home in the afternoon.
              PositionedDirectional(
                start: 10,
                bottom: 10,
                child: _Callout(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: _Place(
                            icon: toSchool ? Icons.home_rounded : Icons.account_balance_rounded,
                            name: originName,
                            time: hhmm(trip?.startedAt ?? trip?.scheduledDepartureAt),
                            tint: tint,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.textFaint),
                        ),
                        Flexible(
                          child: _Place(
                            icon: toSchool ? Icons.account_balance_rounded : Icons.home_rounded,
                            name: destName,
                            time: null,
                            tint: tint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (drawn && live != null)
                PositionedDirectional(
                  end: 10,
                  top: 10,
                  child: Tooltip(
                    message: t('track.title'),
                    child: GestureDetector(
                      onTap: onOpen,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Color(0x1A101828), blurRadius: 10, offset: Offset(0, 3)),
                          ],
                        ),
                        child: Icon(Icons.open_in_full_rounded, size: 17, color: tint),
                      ),
                    ),
                  ),
                ),

              // Says so when the tiles will not come, rather than leaving a
              // grey rectangle that looks like every other reason a map is
              // blank.
              const MapOffline(),

              // Mapbox's licence requires the credit, and it still carries it —
              // behind the ⓘ, which is where Mapbox allows a mobile app to keep
              // it. Off the picture, and complete: the pill that used to sit
              // here named two of the three parties and left out the third.
              if (drawn)
                PositionedDirectional(
                  end: 8,
                  bottom: 6,
                  child: const MapAttribution(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One end of the run: an icon, the place, and when the bus left it.
class _Place extends StatelessWidget {
  const _Place({
    required this.icon,
    required this.name,
    required this.time,
    required this.tint,
  });

  final IconData icon;
  final String name;
  final String? time;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: tint),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text,
                ),
              ),
              if (time != null)
                Text(
                  time!,
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Drawn where the map would be when there is nothing to put on one.
///
/// Said in words rather than shown as an empty map of somewhere, which a parent
/// would read as "the bus is there".
class _NothingToMap extends StatelessWidget {
  const _NothingToMap();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.neutralSoft,
      child: Center(
        child: Padding(
          // Clear of the callouts in the top and bottom corners.
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 58),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined, size: 20, color: AppTheme.textFaint),
              const SizedBox(height: 6),
              Text(
                t('track.noMap'),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.35, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(color: Color(0x14101828), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _BusPin extends StatelessWidget {
  const _BusPin({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
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
        child: Icon(Icons.person_pin_circle_outlined, size: 15, color: colour),
      );
}

/* ---------------------------------------------------------------------------
 * The run
 * ------------------------------------------------------------------------- */

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.bus});

  final _Bus bus;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final trip = bus.run;
    if (trip == null) {
      return Card16(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Text(
            t('bus.noRunToday'),
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    // Four milestones, each either behind, happening, or ahead — derived from
    // the trip's own timestamps rather than stored as a stage. The words
    // follow the leg: the morning runs home → school, the afternoon runs
    // school → home, and "Arrive at school" on the ride home would be a lie.
    final toSchool = trip.leg != 'RETURN';
    final school = Session.instance.me?.schoolName ?? t('driver.school');
    final arrived = trip.alightedAt ?? trip.endedAt;
    final steps = <(String, String, DateTime?, int)>[
      (
        t('bus.started'),
        toSchool ? t('driver.depot') : school,
        trip.startedAt,
        trip.startedAt != null ? 2 : 0,
      ),
      (
        toSchool
            ? tn('bus.arrivedAt', bus.transport.pickupStopName ?? t('bus.home'))
            : t('bus.boarded'),
        toSchool ? (bus.transport.pickupLandmark ?? '') : '',
        trip.boardedAt,
        trip.boardedAt != null ? 2 : (trip.startedAt != null ? 1 : 0),
      ),
      (
        t('bus.onTheWay'),
        toSchool ? t('bus.headingToSchool') : t('bus.headingHome'),
        null,
        arrived != null ? 2 : (trip.boardedAt != null ? 1 : 0),
      ),
      (
        toSchool
            ? t('bus.arriveAtSchool')
            : tn('bus.arrivedAt', bus.transport.dropoffStopName ?? t('bus.home')),
        toSchool ? school : (bus.transport.dropoffLandmark ?? ''),
        arrived,
        arrived != null ? 2 : 0,
      ),
    ];

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.directions_bus_rounded, size: 17, color: tint),
              ),
              const SizedBox(width: 9),
              Text(
                t('bus.todaysRoute'),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppTheme.text,
                ),
              ),
              if ((bus.transport.routeName ?? '').isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(child: StatusChip(bus.transport.routeName!, color: tint)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            _Step(
              title: steps[i].$1,
              sub: steps[i].$2,
              at: steps[i].$3,
              state: steps[i].$4,
              first: i == 0,
              last: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.sub,
    required this.at,
    required this.state,
    required this.first,
    required this.last,
  });

  final String title;
  final String sub;
  final DateTime? at;

  /// 0 ahead, 1 happening, 2 behind.
  final int state;

  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final (colour, chip) = switch (state) {
      2 => (AppTheme.green, t('bus.completed')),
      1 => (tint, t('bus.liveNow')),
      _ => (AppTheme.textFaint, t('bus.upcoming')),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: first ? Colors.transparent : AppTheme.border,
                    ),
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: state == 0 ? Colors.transparent : colour,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: state == 0 ? AppTheme.border : colour,
                      width: 2,
                    ),
                  ),
                  child: switch (state) {
                    2 => const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                    1 => const Icon(Icons.directions_bus_rounded, size: 13, color: Colors.white),
                    _ => null,
                  },
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: last ? Colors.transparent : AppTheme.border,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: state == 1
                    ? tint.withValues(alpha: AppTheme.dark ? 0.14 : 0.07)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      at == null ? '—' : hhmm(at),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // Stop names go inside titles here, and "Arrived at
                          // Zanko — st…" is not a place. Two lines before an
                          // ellipsis is ever allowed.
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: 1.15,
                            color: AppTheme.text,
                          ),
                        ),
                        if (sub.isNotEmpty)
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (state == 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chip,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.sensors_rounded, size: 11, color: Colors.white),
                        ],
                      ),
                    )
                  else
                    StatusChip(chip, color: colour),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Who is driving
 * ------------------------------------------------------------------------- */

class _Tiles extends StatelessWidget {
  const _Tiles({required this.bus, required this.trip});

  final _Bus bus;
  final TripToday? trip;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final phone = trip?.driverPhone;

    return Row(
      children: [
        Expanded(
          child: _Tile(
            icon: Icons.directions_bus_rounded,
            colour: tint,
            label: t('driver.busNumber'),
            value: trip?.vehicleLabel ?? trip?.plate ?? '—',
            valueColour: tint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Tile(
            icon: Icons.person_rounded,
            colour: AppTheme.amber,
            label: t('bus.driver'),
            value: trip?.driverName ?? '—',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Tile(
            icon: Icons.phone_rounded,
            colour: AppTheme.blue,
            label: t('bus.driverPhone'),
            value: phone ?? '—',
            caption: phone == null ? null : t('bus.callAnytime'),
            captionColour: AppTheme.blue,
            onTap: phone == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: phone));
                    if (context.mounted) showNote(context, t('bus.numberCopied'));
                  },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          // The design puts "Safety — Verified — Background checked" here.
          // Nothing in the platform records a driver's vetting, so that tile
          // would be a reassurance the app invented about the person a child
          // gets into a vehicle with. The seat is a real fact about this child
          // on this bus, and it is what a parent asks the office about.
          child: _Tile(
            icon: Icons.event_seat_rounded,
            colour: AppTheme.rose,
            label: t('bus.seat'),
            value: bus.transport.seatNumber ?? '—',
            caption: bus.transport.routeName,
            captionColour: AppTheme.rose,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.colour,
    required this.label,
    required this.value,
    this.caption,
    this.captionColour,
    this.valueColour,
    this.onTap,
  });

  final IconData icon;
  final Color colour;
  final String label;
  final String value;
  final String? caption;
  final Color? captionColour;
  final Color? valueColour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: colour),
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: valueColour ?? AppTheme.text,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                caption!,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: captionColour ?? AppTheme.textFaint,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
