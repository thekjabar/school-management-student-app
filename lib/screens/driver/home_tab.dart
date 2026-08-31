import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import 'route_strip.dart';
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
CrewTrip? pickLiveTrip(List<CrewTrip> trips) {
  if (trips.isEmpty) return null;
  final live = trips.where((t) => t.status == 'IN_PROGRESS').toList();
  if (live.isNotEmpty) return live.first;
  final ahead = trips.where((t) => t.status != 'ENDED' && t.status != 'CANCELLED').toList()
    ..sort((a, b) => (a.scheduledDepartureAt ?? DateTime(2100))
        .compareTo(b.scheduledDepartureAt ?? DateTime(2100)));
  return ahead.isNotEmpty ? ahead.first : trips.first;
}

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
        return _Duty(trip: live, plan: plan);
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

            if (counts != null) ...[
              Card16(
                padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
                child: IconFigureStrip(
                  figures: [
                    IconFigure(
                      icon: Icons.groups_rounded,
                      label: t('driver.studentsOnRoute'),
                      value: '${counts.expected}',
                      caption: t('driver.onRoute'),
                      color: Role.driver.tint,
                    ),
                    IconFigure(
                      icon: Icons.check_circle_outline_rounded,
                      label: t('driver.pickedUp'),
                      value: '${counts.boarded}',
                      caption: _percent(counts.boarded, counts.expected),
                      color: AppTheme.green,
                    ),
                    IconFigure(
                      icon: Icons.person_add_alt_rounded,
                      label: t('driver.toPickUp'),
                      value: '${(counts.expected - counts.boarded).clamp(0, 9999)}',
                      caption: _percent(counts.expected - counts.boarded, counts.expected),
                      color: AppTheme.amber,
                    ),
                    IconFigure(
                      icon: Icons.account_balance_rounded,
                      label: t('driver.toDropOff'),
                      value: '${counts.stillOnBoard}',
                      caption: t('driver.school'),
                      color: AppTheme.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kCardGap),
            ],

            // ---- The stop they are driving to -----------------------------
            _NextStopCard(
              stop: next,
              leg: trip.leg,
              busy: _busy,
              onOpen: () => _open(context, trip),
              // Only while the run is actually under way. Recording an arrival
              // at a stop on a run nobody has started is a call the server is
              // right to refuse, and offering it invites the refusal.
              onStopAction: next == null || !trip.running
                  ? null
                  : () => next.arrivedAt == null
                      ? _stopAction(
                          () => CrewApi.instance
                              .arriveAtStop(trip.id, next.plannedSequence),
                          t('driver.arrived'),
                        )
                      : _stopAction(
                          () => CrewApi.instance
                              .leaveStop(trip.id, next.plannedSequence),
                          t('driver.movingOn'),
                        ),
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

  static String _percent(int part, int whole) =>
      whole <= 0 ? '—' : '(${(part / whole * 100).round()}%)';

  void _open(BuildContext context, CrewTrip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripScreen(tripId: trip.id, serviceDate: trip.serviceDate),
      ),
    );
  }
}

class _Duty {
  _Duty({required this.trip, required this.plan});

  final CrewTrip? trip;
  final TripPlan? plan;

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
    final live = trip.status == 'IN_PROGRESS';
    final school = Session.instance.me?.schoolName ?? '';

    return Card16(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              // The route as a diagram, not a map. There is no tile provider in
              // this app, and a decorative map that looks live is worse than an
              // honest diagram — a driver would trust the wrong thing.
              PositionedDirectional(
                end: 0,
                top: 0,
                bottom: 0,
                width: box.maxWidth * 0.46,
                child: RouteStrip(
                  stops: plan?.stops ?? const [],
                  tint: tint,
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
 * The next stop
 * ------------------------------------------------------------------------- */

class _NextStopCard extends StatelessWidget {
  const _NextStopCard({
    required this.stop,
    required this.leg,
    required this.busy,
    required this.onOpen,
    required this.onStopAction,
  });

  final PlannedStop? stop;
  final String leg;
  final bool busy;
  final VoidCallback onOpen;

  /// Arrive, or move on — whichever the stop is owed. Null when there is no
  /// stop left to act on.
  final VoidCallback? onStopAction;

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;
    final s = stop;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('driver.nextStop'),
            actionLabel: t('driver.viewAllStops'),
            onAction: onOpen,
          ),
          if (s == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                t('driver.noStopsLeft'),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: AppTheme.dark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.flag_rounded, size: 19, color: tint),
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
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              leg == 'RETURN'
                                  ? tn('driver.nToDropOff', s.students.length)
                                  : tn('driver.nToPickUp', s.students.length),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            // The landmark. In much of the Region this is the
                            // only usable address, and it was on the run screen
                            // three taps away instead of on the card naming the
                            // stop the driver is heading for.
                            if (s.landmark != null && s.landmark!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                s.landmark!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                              ),
                            ],
                            if (s.metresAway != null) ...[
                              const SizedBox(height: 4),
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: tint,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        // Records the arrival, or the departure once the bus is
                        // there. It used to open the run screen and record
                        // nothing, under a label that said it had.
                        child: _Button(
                          // Nothing directional: an east arrow points the wrong
                          // way on a Kurdish or Arabic screen.
                          icon: s.arrivedAt == null
                              ? Icons.check_circle_outline_rounded
                              : Icons.directions_bus_rounded,
                          label: s.arrivedAt == null
                              ? t('driver.iveArrived')
                              : t('driver.movingOn'),
                          filled: true,
                          busy: busy,
                          onTap: onStopAction,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        // Was "Navigate", and opened the same run screen. There
                        // is no navigation in this build — no maps app is
                        // launched from anywhere — so the button now says what
                        // it does.
                        child: _Button(
                          icon: Icons.list_alt_rounded,
                          label: t('driver.openRun'),
                          filled: false,
                          onTap: onOpen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One of the two buttons under the next stop.
///
/// 48 high, because a bus is not a desk. The pair used to be 40, which is under
/// every platform's floor and well under what a gloved thumb hits at the first
/// attempt.
class _Button extends StatelessWidget {
  const _Button({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;
    final off = onTap == null || busy;
    final ink = filled ? Colors.white : tint;

    return GestureDetector(
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: off ? 0.55 : 1,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: filled ? tint : AppTheme.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: filled ? tint : tint.withValues(alpha: 0.45)),
          ),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: ink),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: ink),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: ink,
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

/* ---------------------------------------------------------------------------
 * The four tiles
 * ------------------------------------------------------------------------- */

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
