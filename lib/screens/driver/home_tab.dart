import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/sheets.dart';
import 'route_map.dart';
import 'trip_screen.dart';

/// The run every driver screen is about.
///
/// Today's, if there is one. Otherwise the next one scheduled — because the
/// weekend here is Friday and Saturday, and a driver opening the app on Friday
/// evening was met with "no runs assigned to you today" and nothing else. The
/// next run IS the answer to what they opened the app for.
Future<CrewTrip?> loadDutyTrip() async {
  final today = pickLiveTrip(await CrewApi.instance.today());
  if (today != null) return today;

  // Forward, one day at a time. `days=N` is a HISTORY window on the server —
  // it answers "the last N days", so asking it for what is coming returned
  // last week and nothing else. Dates have to be asked for by name.
  final from = DateTime.now();
  for (var i = 1; i <= 7; i++) {
    final day = DateTime(from.year, from.month, from.day + i);
    final stamp = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final rows = await CrewApi.instance.trips(date: stamp);
    final next = pickLiveTrip(rows);
    if (next != null) return next;
  }
  return null;
}

/// The run that answers "what am I doing now": the one under way, else the next
/// one due out.
///
/// The filter here used to drop `ENDED`, which is not a TripStatus — the real
/// ones are PLANNED, ROSTERED, BLOCKED, BOARDING, IN_PROGRESS, ARRIVED,
/// SWEEP_PENDING, SWEEP_OVERDUE, COMPLETED, CANCELLED, ABANDONED and VOID. A
/// comparison against a value nothing ever holds does not fail; it excludes
/// nothing. So a COMPLETED morning run stayed in the list, and because the list
/// is sorted by departure time the run that finished at half past seven beat
/// the afternoon run that had not left yet. A driver opening the app after
/// lunch was shown this morning, with "Start / Resume" on it, and the afternoon
/// run was nowhere.
///
/// A run under way outranks a run due out. Within that, the ones that have
/// stopped carrying children but still owe something come first — a bus that
/// has arrived with an unconfirmed cabin sweep is the most dangerous state in
/// the system, and it must not be pushed off the screen by the next departure.
CrewTrip? pickLiveTrip(List<CrewTrip> trips) {
  if (trips.isEmpty) return null;

  final busy = trips.where((t) => t.underway).toList()..sort(_byUrgency);
  if (busy.isNotEmpty) return busy.first;

  // Everything still owed today, earliest first. BLOCKED stays in: the bus is
  // stopped, the driver has to be told so, and hiding the run does not unblock
  // it.
  final ahead = trips.where((t) => t.live).toList()
    ..sort((a, b) => (a.scheduledDepartureAt ?? DateTime(2100))
        .compareTo(b.scheduledDepartureAt ?? DateTime(2100)));

  // Nothing left. Null rather than a finished run, so the caller goes looking
  // for the next day instead of offering to start something that is over.
  return ahead.isNotEmpty ? ahead.first : null;
}

/// Sweep overdue first, then sweep pending, then the bus on the road.
int _byUrgency(CrewTrip a, CrewTrip b) => _urgency(a).compareTo(_urgency(b));

int _urgency(CrewTrip t) => switch (t.status) {
      'SWEEP_OVERDUE' => 0,
      'SWEEP_PENDING' => 1,
      'ARRIVED' => 2,
      'IN_PROGRESS' => 3,
      _ => 4,
    };

/// What a driver sees at 06:40 with cold hands.
///
/// One question first — which run, and can I start it — then the four numbers
/// that decide whether they are ahead or behind, then the stop they are
/// actually driving to. Everything below that is reference.
class DriverHome extends StatefulWidget {
  const DriverHome({super.key, required this.onOpenTab});

  final void Function(int tab) onOpenTab;

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  final _loaderKey = GlobalKey<LoaderState<_Duty>>();
  bool _busy = false;

  void Function(int tab) get onOpenTab => widget.onOpenTab;

  /// Arriving at a stop, and leaving it.
  ///
  /// Both were buttons on this card that only opened the run screen. They are
  /// the two calls the platform actually offers, they are what the driver is
  /// pressing the card for, and doing them here saves four taps at the one
  /// moment nobody has four taps to spare.
  Future<void> _stopAction(Future<void> Function() call, String label) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await call();
      _loaderKey.currentState?.reload();
      if (mounted) showNote(context, label);
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<_Duty>(
      key: _loaderKey,
      tint: Role.driver.tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18),
      load: () async {
        final live = await loadDutyTrip();
        final plan = live == null ? null : await CrewApi.instance.plan(live.id);
        // The campus gate, needed the moment this card can record a boarding
        // itself. A failure here must not take the run down with it: without it
        // the app states no stopId, which the server records as "not stated" —
        // a gap in the ledger rather than a false alarm.
        String? gate;
        if (live != null) {
          try {
            gate = await CrewApi.instance.terminalStopId(live.id);
          } catch (_) {
            gate = null;
          }
        }
        return _Duty(trip: live, plan: plan, terminalStopId: gate);
      },
      builder: (context, duty) {
        final trip = duty.trip;
        if (trip == null) {
          return Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                t('driver.noRunsToday'),
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ),
          );
        }

        final counts = duty.plan?.counts;
        final next = duty.nextStop;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DutyCard(trip: trip, plan: duty.plan, onOpen: () => _open(context, trip)),
            const SizedBox(height: kCardGap),

            // The whole run in one line rather than four tiles.
            //
            // The tiles restated the same roll four ways and competed with the
            // stop the driver is actually working: "28 to pick up" beside a
            // stop owing three is two numbers to reconcile at the wheel. The
            // run-level figures are context, so they read as context.
            if (counts != null) ...[
              _RunSummary(counts: counts),
              const SizedBox(height: kCardGap),
            ],

            if ((duty.plan?.stops ?? const <PlannedStop>[]).isNotEmpty) ...[
              _MapStrip(
                stops: duty.plan!.stops,
                leg: trip.leg,
                terminalStopId: duty.terminalStopId,
              ),
              const SizedBox(height: kCardGap),
            ],

            // ---- The stop they are working, and the children on it ---------
            //
            // One card, not two. The old pair named the same stop twice with
            // different counts — a "next stop" panel saying six to pick up
            // above a roster saying three left — and put the children three
            // taps away on another screen. This is the working surface: who is
            // here, one tap each, and the two stop buttons under them.
            _CurrentStopCard(
              stop: next,
              tripId: trip.id,
              leg: trip.leg,
              busy: _busy,
              running: trip.running,
              terminalStopId: duty.terminalStopId,
              schoolReached: duty.plan?.terminalArrivedAt != null,
              onOpen: () => _open(context, trip),
              onChanged: () => _loaderKey.currentState?.reload(),
              onArrive: next == null || !trip.running
                  ? null
                  : () => _stopAction(
                        () => CrewApi.instance
                            .arriveAtStop(trip.id, next.plannedSequence),
                        t('driver.arrived'),
                      ),
              onLeave: next == null || !trip.running
                  ? null
                  : () => _stopAction(
                        () => CrewApi.instance
                            .leaveStop(trip.id, next.plannedSequence),
                        t('driver.movingOn'),
                      ),
              onSkip: next == null || !trip.running
                  ? null
                  : () => _skip(context, trip, next),
            ),
            const SizedBox(height: kCardGap),

            // ---- The four things they DO ----------------------------------
            //
            // Four tiles, four different places. Attendance used to open the
            // Profile tab — tab three, counted from a list that had changed —
            // and Notifications opened the run, because this app keeps no
            // notifications at all.
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.person_add_alt_1_outlined,
                    top: t('driver.boarding'),
                    bottom: t('driver.checkIn'),
                    color: Role.driver.tint,
                    onTap: () => _open(context, trip),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.assignment_turned_in_outlined,
                    top: t('driver.attendance'),
                    bottom: t('driver.mark'),
                    color: AppTheme.green,
                    onTap: () => onOpenTab(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.route_outlined,
                    top: t('driver.route'),
                    bottom: t('driver.stops'),
                    color: AppTheme.amber,
                    onTap: () => onOpenTab(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.verified_user_outlined,
                    top: t('driver.safety'),
                    bottom: trip.sweepRequired && trip.sweepConfirmedAt == null
                        ? t('driver.sweepDue')
                        : t('driver.allGood'),
                    color: AppTheme.blue,
                    onTap: () => _open(context, trip),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kCardGap),

            // ---- Reference -------------------------------------------------
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ProgressCard(
                      trip: trip,
                      plan: duty.plan,
                      onOpen: () => onOpenTab(1),
                    ),
                  ),
                  const SizedBox(width: kCardGap),
                  Expanded(child: _VehicleCard(trip: trip)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Skipping a stop, with the reason the ledger keeps.
  ///
  /// The same confirm the run screen uses. A skip is a stop nobody was served
  /// at, so it is never a bare tap: the office reads the reason back.
  Future<void> _skip(BuildContext context, CrewTrip trip, PlannedStop stop) async {
    final reason = await showAppSheet<String>(
      context,
      builder: (_) => const SkipStopSheet(),
    );
    if (reason == null) return;
    await _stopAction(
      () => CrewApi.instance.skipStop(trip.id, stop.plannedSequence, reason),
      t('driver.skipped'),
    );
  }

  void _open(BuildContext context, CrewTrip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripScreen(tripId: trip.id, serviceDate: trip.serviceDate),
      ),
    );
  }
}

class _Duty {
  _Duty({required this.trip, required this.plan, this.terminalStopId});

  final CrewTrip? trip;
  final TripPlan? plan;

  /// The campus gate's stop id, or null if it could not be read.
  final String? terminalStopId;

  /// The first stop not yet departed. Not "the nearest" — a driver following
  /// the route wants the next one in order, and the nearest is the one they
  /// just left as often as it is the one ahead.
  PlannedStop? get nextStop {
    final stops = plan?.stops ?? const <PlannedStop>[];
    for (final s in stops) {
      if (s.departedAt == null) return s;
    }
    return null;
  }
}

/* ---------------------------------------------------------------------------
 * The run
 * ------------------------------------------------------------------------- */

class _DutyCard extends StatelessWidget {
  const _DutyCard({required this.trip, required this.plan, required this.onOpen});

  final CrewTrip trip;
  final TripPlan? plan;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;
    // On duty from the walk-around to the cabin sweep, not only while the wheels
    // are turning. A driver who has checked in and is loading children was
    // being told "No run under way".
    final live = trip.underway;
    final school = Session.instance.me?.schoolName ?? '';

    return Card16(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              // The run, on the real map. Small, still, and not interactive —
              // the whole point of this panel is that it is glanced at, and the
              // card's own button is what a thumb lands on.
              PositionedDirectional(
                end: 0,
                top: 0,
                bottom: 0,
                width: box.maxWidth * 0.46,
                child: RouteMap(
                  stops: plan?.stops ?? const [],
                  tint: tint,
                  leg: trip.leg,
                  compact: true,
                ),
              ),
              // The map runs under the last of the text. A fade off its leading
              // edge keeps a street name from competing with the route's own
              // name, and softens what would otherwise be a hard rectangle down
              // the middle of the card.
              PositionedDirectional(
                end: 0,
                top: 0,
                bottom: 0,
                width: box.maxWidth * 0.46,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [
                          AppTheme.surface,
                          AppTheme.surface.withValues(alpha: 0),
                        ],
                        // Short. Just enough to cover the tail of the text
                        // column — any further and it starts rubbing out the
                        // stops the map is there to show.
                        stops: const [0.0, 0.26],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
                child: SizedBox(
                  width: box.maxWidth * 0.56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: live ? tint : AppTheme.textFaint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              live
                                  ? t('driver.onDuty')
                                  : _isToday(trip.serviceDate)
                                      ? t('driver.offDuty')
                                      : '${t('driver.nextRun')} · ${shortDate(trip.serviceDate)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        trip.routeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          height: 1.1,
                          color: tint,
                        ),
                      ),
                      if (school.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          school,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Fact(
                              icon: Icons.schedule_rounded,
                              label: t('driver.startTime'),
                              value: hhmm(trip.scheduledDepartureAt),
                            ),
                          ),
                          Expanded(
                            child: _Fact(
                              icon: Icons.directions_bus_rounded,
                              label: t('driver.busNumber'),
                              value: trip.vehicleLabel ?? trip.plate ?? '—',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      // 46 high. The primary action on the driver's first
                      // screen was a 39 dp pill.
                      GestureDetector(
                        onTap: onOpen,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: tint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  t('driver.startOrResume'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.play_arrow_rounded, size: 15, color: tint),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isToday(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Role.driver.tint),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ---------------------------------------------------------------------------
 * The run, in one line
 * ------------------------------------------------------------------------- */

/// The whole roll, small, as context for the stop being worked.
///
/// This replaced four figure tiles. The tiles were the same roll counted four
/// ways, each as loud as the stop card under them, so "28 to pick up" sat
/// beside a stop owing three and the driver had two numbers to reconcile before
/// touching anything. Run totals are background: they belong on one line, in
/// muted type, under the card that names the bus.
class _RunSummary extends StatelessWidget {
  const _RunSummary({required this.counts});

  final Headcount counts;

  @override
  Widget build(BuildContext context) {
    final toGo = (counts.expected - counts.boarded).clamp(0, 9999);
    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.groups_rounded, size: 17, color: AppTheme.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Stat(value: '${counts.expected}', label: t('driver.onRoute')),
                _Dot(),
                _Stat(
                  value: '${counts.stillOnBoard}',
                  label: t('driver.aboardNow'),
                  color: AppTheme.blue,
                ),
                _Dot(),
                _Stat(
                  value: '$toGo',
                  label: t('driver.stillToPickUp'),
                  color: toGo == 0 ? AppTheme.green : AppTheme.amber,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color ?? AppTheme.text,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text('·', style: TextStyle(fontSize: 13, color: AppTheme.textFaint));
}

/* ---------------------------------------------------------------------------
 * The map, as a strip
 * ------------------------------------------------------------------------- */

/// The route, small, with the whole map one tap away.
///
/// A map is worth having on the screen the driver lives on, but not worth the
/// half of it the mocked-up panel took: the overlay covered the route it was
/// describing and repeated the stop named directly underneath it. So the strip
/// shows the shape of the run and nothing else, and opens the real map — which
/// already exists, full screen, with its own controls — when touched.
class _MapStrip extends StatelessWidget {
  const _MapStrip({
    required this.stops,
    required this.leg,
    required this.terminalStopId,
  });

  final List<PlannedStop> stops;
  final String leg;
  final String? terminalStopId;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: IgnorePointer(
                child: RouteMap(
                  stops: stops,
                  tint: Role.driver.tint,
                  leg: leg,
                  terminalStopId: terminalStopId,
                ),
              ),
            ),
            // The whole strip is the target, not a small corner button: this is
            // pressed one-handed from a driver's seat.
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RouteMapScreen(
                        stops: stops,
                        tint: Role.driver.tint,
                        leg: leg,
                        terminalStopId: terminalStopId,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_full_rounded, size: 13, color: Role.driver.tint),
                    const SizedBox(width: 6),
                    Text(
                      t('driver.viewFullRoute'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Role.driver.tint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * The stop being worked
 * ------------------------------------------------------------------------- */

/// Where the driver actually does the job.
///
/// One card for one stop: which stop, whether the bus has arrived, who is on
/// it, one tap per child, and the two stop buttons underneath. It replaced a
/// pair of cards that named the same stop twice with different counts and put
/// the children on another screen entirely.
class _CurrentStopCard extends StatefulWidget {
  const _CurrentStopCard({
    required this.stop,
    required this.tripId,
    required this.leg,
    required this.busy,
    required this.running,
    required this.terminalStopId,
    required this.schoolReached,
    required this.onOpen,
    required this.onChanged,
    required this.onArrive,
    required this.onLeave,
    required this.onSkip,
  });

  final PlannedStop? stop;
  final String tripId;
  final String leg;
  final bool busy;
  final bool running;
  final String? terminalStopId;
  final bool schoolReached;
  final VoidCallback onOpen;
  final VoidCallback onChanged;
  final VoidCallback? onArrive;
  final VoidCallback? onLeave;
  final VoidCallback? onSkip;

  @override
  State<_CurrentStopCard> createState() => _CurrentStopCardState();
}

enum _Show { all, toPickUp, aboard, done }

class _CurrentStopCardState extends State<_CurrentStopCard> {
  _Show _show = _Show.all;
  String? _busyStudent;
  Timer? _hold;

  /// How long the bus stands here before it may move on. The stop's own planned
  /// dwell, which the server derives from the children booked onto it, clamped
  /// so a one-child stop is not held as long as an eight-child one and no stop
  /// holds a bus that is ready for longer than is fair. Identical to the rule
  /// on the run screen: a driver must not be able to dodge the wait by doing
  /// the same job from the other screen.
  int get _holdSeconds => (widget.stop?.dwellSeconds ?? 0).clamp(20, 90);

  int get _holdLeft {
    final s = widget.stop;
    final at = s?.arrivedAt;
    if (s == null || at == null || s.departedAt != null) return 0;
    final left = _holdSeconds - DateTime.now().difference(at).inSeconds;
    if (left <= 0) return 0;
    return left > _holdSeconds ? _holdSeconds : left;
  }

  @override
  void initState() {
    super.initState();
    _syncHold();
  }

  @override
  void didUpdateWidget(covariant _CurrentStopCard old) {
    super.didUpdateWidget(old);
    _syncHold();
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  void _syncHold() {
    final wanted = _holdLeft > 0;
    if (wanted && _hold == null) {
      _hold = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_holdLeft <= 0) {
          _hold?.cancel();
          _hold = null;
        }
      });
    } else if (!wanted && _hold != null) {
      _hold!.cancel();
      _hold = null;
    }
  }

  /// Board a child, or mark them as not here. The same call the run screen
  /// makes, including the stop the BUS is at rather than the child's own.
  Future<void> _mark(RiderOnStop r, String eventType, String label) async {
    final s = widget.stop;
    if (s == null) return;
    setState(() => _busyStudent = r.studentId);
    try {
      final verdict = await CrewApi.instance.recordCustody(
        tripId: widget.tripId,
        studentId: r.studentId,
        eventType: eventType,
        stopId: custodyStopId(
          leg: widget.leg,
          eventType: eventType,
          riderStopId: s.stopId,
          terminalStopId: widget.terminalStopId,
        ),
      );
      widget.onChanged();
      if (!mounted) return;
      // What the SERVER did, not what was asked of it: the batch endpoint
      // answers 200 even when it rewrote or refused the event inside.
      showNote(
        context,
        verdict.accepted ? label : (verdict.reason ?? label),
        bad: !verdict.accepted,
      );
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busyStudent = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stop;
    final tint = Role.driver.tint;

    if (s == null) {
      return Card16(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        child: Text(
          t('driver.noStopsLeft'),
          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
        ),
      );
    }

    final arrived = s.arrivedAt != null;
    final holdLeft = _holdLeft;
    final holding = holdLeft > 0;

    final all = s.students;
    final toPickUp = all.where((r) => !r.accountedFor).toList();
    final aboard =
        all.where((r) => r.boardedAt != null && r.alightedAt == null).toList();
    final done = all.where((r) => r.alightedAt != null).toList();
    final shown = switch (_show) {
      _Show.all => all,
      _Show.toPickUp => toPickUp,
      _Show.aboard => aboard,
      _Show.done => done,
    };

    return Card16(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- which stop, and whether the bus is on it -------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        arrived ? AppTheme.greenSoft : tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    '${s.plannedSequence}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: arrived ? AppTheme.green : tint,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (s.landmark != null && s.landmark!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.landmark!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                      const SizedBox(height: 5),
                      if (arrived)
                        Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 14, color: AppTheme.green),
                            const SizedBox(width: 5),
                            Text(
                              '${t('driver.arrived')} ${hhmm(s.arrivedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.green,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        if (s.etaAt != null) StopEta(stop: s),
                        if (s.metresAway != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.place_rounded, size: 12, color: tint),
                              const SizedBox(width: 4),
                              Text(
                                s.metresAway! >= 1000
                                    ? tn('driver.kmAway',
                                        (s.metresAway! / 100).round() / 10)
                                    : tn('driver.metresAway', s.metresAway!),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: tint,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (s.remaining > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.amberSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tn('driver.nLeft', s.remaining),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.amber,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ---- who is on this stop ----------------------------------------
          if (all.isNotEmpty) ...[
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _Chip(
                    label: t('driver.filterAll'),
                    count: all.length,
                    on: _show == _Show.all,
                    colour: AppTheme.text,
                    onTap: () => setState(() => _show = _Show.all),
                  ),
                  _Chip(
                    label: t('driver.toPickUp'),
                    count: toPickUp.length,
                    on: _show == _Show.toPickUp,
                    colour: AppTheme.amber,
                    onTap: () => setState(() => _show = _Show.toPickUp),
                  ),
                  _Chip(
                    label: t('driver.onBoard'),
                    count: aboard.length,
                    on: _show == _Show.aboard,
                    colour: AppTheme.blue,
                    onTap: () => setState(() => _show = _Show.aboard),
                  ),
                  _Chip(
                    label: t('driver.dropped'),
                    count: done.length,
                    on: _show == _Show.done,
                    colour: AppTheme.green,
                    onTap: () => setState(() => _show = _Show.done),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Text(
                  t('driver.nobodyInFilter'),
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                ),
              )
            else
              ...shown.map((r) => _StopRider(
                    rider: r,
                    leg: widget.leg,
                    schoolReached: widget.schoolReached,
                    busy: _busyStudent == r.studentId,
                    canPickUp: widget.running,
                    onBoard: () => _mark(r, 'BOARDED', t('driver.onBoard')),
                    onNoShow: () => _mark(r, 'NO_SHOW', t('driver.notRiding')),
                  )),
          ],

          // ---- and the two things to do with the stop itself ---------------
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(
              children: [
                if (!arrived) ...[
                  BigButton(
                    label: t('driver.arrived'),
                    color: tint,
                    busy: widget.busy,
                    onPressed: widget.onArrive,
                  ),
                  // Only before the bus is on the stop: the server refuses a
                  // skip the instant an arrival is recorded, so offering it
                  // afterwards is offering a refusal.
                  if (widget.onSkip != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: TextButton.icon(
                        onPressed: widget.busy ? null : widget.onSkip,
                        icon: Icon(Icons.skip_next_rounded,
                            size: 18, color: AppTheme.textMuted),
                        label: Text(
                          t('driver.skipStop'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  BigButton(
                    label: holding
                        ? '${t('driver.movingOn')} · ${holdLeft ~/ 60}:${(holdLeft % 60).toString().padLeft(2, '0')}'
                        : t('driver.movingOn'),
                    color: AppTheme.blue,
                    busy: widget.busy,
                    onPressed: holding ? null : widget.onLeave,
                  ),
                  if (holding) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 15, color: AppTheme.textMuted),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            t('driver.holdAtStop'),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: TextButton(
                    onPressed: widget.onOpen,
                    child: Text(
                      t('driver.openRun'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: tint,
                      ),
                    ),
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

/// One filter on the stop's roster.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.on,
    required this.colour,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool on;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: on ? colour : AppTheme.neutralSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// A child on the stop being worked, with the one tap they are owed.
///
/// The actions are words, not bare icons: this list is read by somebody who has
/// glanced up from the road, and a green arrow beside a red cross is two
/// guesses rather than two answers.
class _StopRider extends StatelessWidget {
  const _StopRider({
    required this.rider,
    required this.leg,
    required this.schoolReached,
    required this.busy,
    required this.canPickUp,
    required this.onBoard,
    required this.onNoShow,
  });

  final RiderOnStop rider;
  final String leg;
  final bool schoolReached;
  final bool busy;
  final bool canPickUp;
  final VoidCallback onBoard;
  final VoidCallback onNoShow;

  @override
  Widget build(BuildContext context) {
    final onBus = rider.boardedAt != null && rider.alightedAt == null;
    final off = rider.alightedAt != null;
    final notRiding = !off && !onBus && rider.notTravelling;

    final String status;
    final Color tone;
    if (off) {
      status =
          '${leg == 'OUT' ? (schoolReached ? t('driver.atSchool') : t('driver.setDownEarly')) : t('driver.handedOver')} ${hhmm(rider.alightedAt)}';
      tone = leg == 'OUT' && !schoolReached ? AppTheme.amber : AppTheme.green;
    } else if (onBus) {
      status = tn('driver.onBoardSince', hhmm(rider.boardedAt));
      tone = AppTheme.blue;
    } else if (notRiding) {
      status = t('driver.notRiding');
      tone = AppTheme.rose;
    } else {
      status = t('driver.waitingAtStop');
      tone = AppTheme.textMuted;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: off
                  ? AppTheme.greenSoft
                  : onBus
                      ? AppTheme.blueSoft
                      : notRiding
                          ? AppTheme.roseSoft
                          : AppTheme.neutralSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              rider.seatNumber ?? '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: off
                    ? AppTheme.green
                    : onBus
                        ? AppTheme.blue
                        : notRiding
                            ? AppTheme.rose
                            : AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rider.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(status, style: TextStyle(fontSize: 11.5, color: tone)),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          // Nothing left to offer once the child is settled: off the bus is the
          // end of it, and a second "not here" on a child already marked not
          // here is the tap that taught drivers this screen ignores them.
          else if (!off && !onBus) ...[
            _Word(
              label: t('driver.pickUp'),
              colour: AppTheme.green,
              onTap: canPickUp ? onBoard : null,
            ),
            if (!notRiding) ...[
              const SizedBox(width: 6),
              _Word(
                label: t('driver.notHere'),
                colour: AppTheme.rose,
                onTap: canPickUp ? onNoShow : null,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// A labelled action on a rider's row. 44 high, because it is pressed standing
/// in an aisle, one-handed, often with the child already in front of you.
class _Word extends StatelessWidget {
  const _Word({required this.label, required this.colour, required this.onTap});

  final String label;
  final Color colour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dead = onTap == null;
    final tone = dead ? AppTheme.textFaint : colour;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: dead ? 0.07 : 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style:
              TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: tone),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.top,
    required this.bottom,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String top;
  final String bottom;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppTheme.dark ? 0.16 : 0.09),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                top,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text,
                ),
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                bottom,
                maxLines: 1,
                style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Reference
 * ------------------------------------------------------------------------- */

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.trip, required this.plan, required this.onOpen});

  final CrewTrip trip;
  final TripPlan? plan;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final counts = plan?.counts;
    final done = counts?.stopsDone ?? 0;
    final total = counts?.stopsTotal ?? 0;

    // Which of the four milestones the run has reached. Derived from the trip
    // and the stop tally rather than stored, because nothing writes a "stage".
    final stage = trip.endedAt != null
        ? 3
        : total > 0 && done >= total
            ? 2
            : trip.startedAt != null
                ? 1
                : 0;

    return Card16(
      padding: const EdgeInsets.all(12),
      // The whole card, not only the ten-point "Full route" link in its
      // corner. That link is the smallest thing on the driver's home screen.
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('driver.routeProgress'),
            actionLabel: t('driver.viewFullRoute'),
            dense: true,
            onAction: onOpen,
          ),
          _Step(
            index: 0,
            stage: stage,
            label: t('driver.depot'),
            note: hhmm(trip.scheduledDepartureAt),
          ),
          _Step(
            index: 1,
            stage: stage,
            label: t('driver.pickups'),
            note: total > 0 ? '$done / $total' : '—',
          ),
          _Step(
            index: 2,
            stage: stage,
            label: t('driver.school'),
            note: counts == null ? '—' : '${counts.stillOnBoard}',
          ),
          _Step(
            index: 3,
            stage: stage,
            label: t('driver.dropoffs'),
            note: trip.endedAt != null ? t('driver.done') : t('driver.ongoing'),
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.stage,
    required this.label,
    required this.note,
    this.last = false,
  });

  final int index;
  final int stage;
  final String label;
  final String note;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;
    final passed = index < stage;
    final here = index == stage;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: passed || here ? tint : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: passed || here ? tint : AppTheme.border,
                      width: 2,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: passed ? tint : AppTheme.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: here ? FontWeight.w800 : FontWeight.w600,
                      color: here ? tint : AppTheme.text,
                    ),
                  ),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: AppTheme.textFaint),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.trip});

  final CrewTrip trip;

  @override
  Widget build(BuildContext context) {
    // What the platform actually knows about the bus. The design shows fuel,
    // tyres and engine; nothing reports those, and a green "Engine: Good" that
    // is a constant is worse than no gauge at all on a vehicle a driver is
    // about to take out with children in it.
    final sweepDue = trip.sweepRequired && trip.sweepConfirmedAt == null;

    return Card16(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('driver.vehicle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppTheme.text,
                  ),
                ),
              ),
              Icon(
                sweepDue ? Icons.error_outline_rounded : Icons.verified_user_rounded,
                size: 17,
                color: sweepDue ? AppTheme.amber : AppTheme.green,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            trip.vehicleLabel ?? t('driver.noBus'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 10),
          _Line(label: t('driver.plate'), value: trip.plate ?? '—'),
          Divider(height: 13, color: AppTheme.border),
          _Line(
            label: t('driver.safety'),
            value: sweepDue ? t('driver.sweepDue') : t('driver.sweepDone'),
            colour: sweepDue ? AppTheme.amber : AppTheme.green,
          ),
          Divider(height: 13, color: AppTheme.border),
          _Line(
            label: t('driver.onBoard'),
            value: '${trip.boarded - trip.alighted}',
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.colour});

  final String label;
  final String value;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colour ?? AppTheme.text,
          ),
        ),
      ],
    );
  }
}
