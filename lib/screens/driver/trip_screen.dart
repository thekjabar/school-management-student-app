import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';
import 'route_map.dart';

/// One run, from the driver's seat.
///
/// The whole screen is one question repeated: WHO IS STILL NOT ACCOUNTED FOR.
/// The headcount line at the top answers it in words, every stop shows how many
/// of its children are outstanding, and the sweep at the bottom is the last
/// check before the bus is left.
class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.tripId, this.serviceDate});

  final String tripId;

  /// The day this run belongs to.
  ///
  /// The run's own row — and with it the start/depart/end button — was looked
  /// up in TODAY's duty list only. On a Friday evening the home screen offers
  /// Sunday's run quite correctly, and opening it produced a stop list with no
  /// way to start anything, because Sunday's run is not in today's list.
  final DateTime? serviceDate;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final _loaderKey = GlobalKey<LoaderState<_TripData>>();
  bool _nearestFirst = false;
  String? _busy;

  Future<List<CrewTrip>> _dutyList() {
    final day = widget.serviceDate;
    if (day == null) return CrewApi.instance.today();
    final stamp = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    return CrewApi.instance.trips(date: stamp);
  }

  String? _terminalStopId;
  bool _gateKnown = false;

  /// The campus gate, for the half of the run that does not happen at a child's
  /// own stop.
  ///
  /// Fetched once and kept. The route's gate does not move during a run, and
  /// this screen reloads after every child is marked — asking for the whole
  /// trip pack, forty children's guardians and medical cards included, once per
  /// tap would be both slow on a bus and a stream of access-log rows saying the
  /// crew read the pack again.
  ///
  /// A failure must not take the stop list down with it, and is not cached: the
  /// next reload tries again. Until it succeeds the app sends no stopId for a
  /// gate event, which the server records as "not stated" — a gap in the
  /// ledger, but not a false alarm, and far better than guessing.
  Future<String?> _gate() async {
    if (_gateKnown) return _terminalStopId;
    try {
      _terminalStopId = await CrewApi.instance.terminalStopId(widget.tripId);
      _gateKnown = true;
    } catch (_) {
      return null;
    }
    return _terminalStopId;
  }

  Future<_TripData> _load() async {
    final api = CrewApi.instance;
    final results = await Future.wait([
      _dutyList(),
      api.plan(widget.tripId, nearest: _nearestFirst),
      api.sweepState(widget.tripId),
      _gate(),
    ]);
    final trips = results[0] as List<CrewTrip>;
    return _TripData(
      trip: trips.where((t) => t.id == widget.tripId).firstOrNull,
      plan: results[1] as TripPlan,
      sweep: results[2] as SweepState,
      terminalStopId: results[3] as String?,
    );
  }

  /// The pre-trip walk-around, then the shift start.
  ///
  /// The check is the payload — the server will not open a shift without one —
  /// so the sheet comes first and the call only happens if the driver actually
  /// filed it.
  Future<void> _startShift(CrewTrip trip) async {
    final check = await showAppSheet<PreTripCheck>(
      context,
      builder: (_) => const _PreTripSheet(),
    );
    if (check == null || !mounted) return;
    await _act(
      t('driver.shiftStarted'),
      () => CrewApi.instance.startShift(trip.id, check),
    );
  }

  /// A child was still on the bus when the aisle was walked.
  ///
  /// The sweep could only ever be filed as CLEAR, so a driver who found a child
  /// asleep on the back row had one button and it said the bus was empty. The
  /// server has taken CHILD_FOUND all along and insists on a name with it —
  /// which is the point: the office has to know WHICH child before the parent
  /// rings. The list offered is this run's own roster.
  Future<void> _reportChildFound(TripPlan plan) async {
    final riders = [
      for (final stop in plan.stops)
        for (final r in stop.students) r,
    ];
    if (riders.isEmpty) return;

    final chosen = await showAppSheet<RiderOnStop>(
      context,
      builder: (_) => _ChildFoundSheet(riders: riders),
    );
    if (chosen == null || !mounted) return;

    await _act(
      t('driver.childFoundFiled'),
      () => CrewApi.instance.sweepChildFound(widget.tripId, studentId: chosen.studentId),
    );
  }

  /// Close the run, and do not let an unaccounted child pass as "Run ended".
  ///
  /// The server answers with the number of children it could not account for,
  /// and its own comment on that field is "Anything but zero is an alarm, not a
  /// note". The app used to discard it and report plain success — so the one
  /// moment a driver could still walk back down the aisle passed with a green
  /// tick.
  Future<void> _endRun(CrewTrip trip) async {
    setState(() => _busy = t('driver.runEnded'));
    try {
      final unaccounted = await CrewApi.instance.endTrip(trip.id);
      _loaderKey.currentState?.reload();
      if (!mounted) return;
      if (unaccounted > 0) {
        showNote(context, tn('driver.endedUnaccounted', unaccounted), bad: true);
      } else {
        showNote(context, t('driver.runEnded'));
      }
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// The panic button.
  ///
  /// Confirmed once, because it is the loudest thing this platform does — an
  /// INTERRUPTING, CRITICAL alert that puts a named human on the phone — and a
  /// pocket press must not raise it. One tap to confirm, no typing, no reason
  /// field: whatever is happening at the door, the driver has one hand and no
  /// time, and the office can ask afterwards.
  Future<void> _panic(CrewTrip trip) async {
    final go = await showAppSheet<bool>(
      context,
      builder: (_) => const _PanicSheet(),
    );
    if (go != true || !mounted) return;
    await _act(t('driver.sosSent'), () => CrewApi.instance.sos(trip.id));
  }

  /// Run something, and say what the server said about it.
  ///
  /// [_act] shows its own busy label back as the note, which is right where the
  /// only outcomes are "it worked" and "it threw". The sweep has a third: the
  /// server takes the request, records the walk, and refuses to count it. A
  /// fixed green label over that is the app contradicting the server on the one
  /// control that exists to stop a child being left in a locked bus — so the
  /// call that has an opinion gets to read it, via [note].
  Future<void> _actWith<T>(
    String label,
    Future<T> Function() action,
    ({String text, bool bad}) Function(T) note,
  ) async {
    setState(() => _busy = label);
    try {
      final result = await action();
      _loaderKey.currentState?.reload();
      if (!mounted) return;
      final said = note(result);
      showNote(context, said.text, bad: said.bad);
    } catch (e) {
      // Every failure, not just the ones the API answered. A dropped
      // connection threw straight past this and left the driver looking at a
      // button that had apparently done nothing.
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// The plain form: the label is both what the button is doing and what the
  /// driver is told when it is done.
  Future<void> _act(String label, Future<void> Function() action) => _actWith<bool>(
        label,
        () async {
          await action();
          return true;
        },
        (_) => (text: label, bad: false),
      );

  /// What to tell the driver about a sweep the server has already judged.
  ///
  /// Only `genuine` clears the run, and only `genuine` gets the green note.
  /// The other answers are not failures of the app and must not be dressed up
  /// as successes: the walk IS on file, an alert HAS been raised, and the bus
  /// is still recorded as unswept. Rubber-stamped is reported ahead of late,
  /// because "that did not look like a walk" is the graver thing to be told.
  ({String text, bool bad}) _sweepNote(SweepVerdict verdict) {
    if (verdict.genuine) return (text: t('driver.sweepConfirmed'), bad: false);

    if (verdict.rubberStamped) {
      final why = verdict.rubberStampReasons.map(humanise).join(', ');
      return (
        text: why.isEmpty
            ? t('driver.sweepRubberStamped')
            : '${t('driver.sweepRubberStamped')} ${tn('driver.sweepRubberStampWhy', why)}',
        bad: true,
      );
    }

    if (!verdict.withinDeadline) return (text: t('driver.sweepLate'), bad: true);

    // Neither reason given, and still not counted. Saying so plainly beats
    // guessing, and beats a green tick over a bus the server calls unswept.
    return (text: t('driver.sweepNotCounted'), bad: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('driver.theRun')),
            Expanded(
              child: Loader<_TripData>(
                key: _loaderKey,
                tint: Role.driver.tint,
                load: _load,
                builder: (context, data) {
                  final counts = data.plan.counts;
                  final trip = data.trip;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // Before the wheels turn, the only question left on this
                      // screen is when to go — so it is the first thing on it.
                      // Once the run has started it is history, and history at
                      // the top of a working screen is in the way.
                      if (data.plan.timing.hasDepartBy &&
                          data.plan.timing.startedAt == null) ...[
                        _LeaveByCard(
                          timing: data.plan.timing,
                          childrenOnRun: counts.expected,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _HeadcountCard(counts: counts),
                      if (trip != null && trip.startedAt != null && trip.endedAt == null) ...[
                        const SizedBox(height: 12),
                        _PanicButton(busy: _busy != null, onPressed: () => _panic(trip)),
                      ],
                      if (trip != null) ...[
                        const SizedBox(height: 12),
                        _RunControls(
                          trip: trip,
                          busy: _busy,
                          onStart: () => _startShift(trip),
                          onDepart: () => _act(t('driver.departed'), () => CrewApi.instance.depart(trip.id)),
                          onEnd: () => _endRun(trip),
                        ),
                      ],
                      SectionHead(t('driver.stops')),
                      _OrderToggle(
                        nearestFirst: _nearestFirst,
                        note: data.plan.orderingNote,
                        onChanged: (v) {
                          setState(() => _nearestFirst = v);
                          _loaderKey.currentState?.reload();
                        },
                      ),
                      const SizedBox(height: 12),
                      // The same stops as the cards below, in the same order,
                      // on the ground. This is the one screen that knows which
                      // stop is the campus gate, so it is the one that can tell
                      // the school apart from a street corner.
                      Card16(
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          child: SizedBox(
                            height: 230,
                            child: RouteMap(
                              stops: data.plan.stops,
                              tint: Role.driver.tint,
                              leg: trip?.leg ?? 'OUT',
                              terminalStopId: data.terminalStopId,
                            ),
                          ),
                        ),
                      ),
                      RouteMapNote(stops: data.plan.stops),
                      const SizedBox(height: 14),
                      ...data.plan.stops.map(
                        (s) => _StopCard(
                          stop: s,
                          tripId: widget.tripId,
                          leg: trip?.leg ?? 'OUT',
                          terminalStopId: data.terminalStopId,
                          onChanged: () => _loaderKey.currentState?.reload(),
                        ),
                      ),
                      SectionHead(t('driver.beforeYouLeave')),
                      _SweepCard(
                        sweep: data.sweep,
                        tripEnded: trip?.endedAt != null,
                        stillOwed: trip?.status == 'SWEEP_PENDING' ||
                            trip?.status == 'SWEEP_OVERDUE',
                        busy: _busy != null,
                        onConfirm: () => _actWith(
                          t('driver.sweepConfirmed'),
                          () => CrewApi.instance.confirmSweep(widget.tripId),
                          _sweepNote,
                        ),
                        onChildFound: () => _reportChildFound(data.plan),
                      ),
                      const SizedBox(height: 20),
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
}

class _TripData {
  _TripData({
    required this.trip,
    required this.plan,
    required this.sweep,
    required this.terminalStopId,
  });

  final CrewTrip? trip;
  final TripPlan plan;
  final SweepState sweep;

  /// The campus gate. Null when the route has none marked, or when the pack
  /// could not be read.
  final String? terminalStopId;
}

/// When to leave, and why it is not the time printed on the timetable.
///
/// "Depart 07:00, arrive 07:45" was costed at half a minute a child. Five
/// children at one stop spend five times that, so a driver who leaves exactly
/// on time still arrives late and is never told which of the two numbers was
/// wrong — and the answer he reaches for is to cut a stop short, which is the
/// one thing nobody wants him to do. This card is the same sum done against
/// today's roster: the time to go, how long until then, and where the minutes
/// went.
///
/// Shown only before the run starts. Afterwards it is a question already
/// answered, and the screen has forty children on it instead.
class _LeaveByCard extends StatefulWidget {
  const _LeaveByCard({required this.timing, required this.childrenOnRun});

  final TripTiming timing;

  /// The children the run is carrying today. The standing-at-stops half of the
  /// estimate is theirs, and naming them is what makes the number checkable
  /// rather than something the phone simply asserts.
  final int childrenOnRun;

  @override
  State<_LeaveByCard> createState() => _LeaveByCardState();
}

class _LeaveByCardState extends State<_LeaveByCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Half a minute, not a whole one. The countdown reads in whole minutes, and
    // a minute-long tick started at some arbitrary point inside a minute leaves
    // the number up to 59 seconds stale — which on this card is the difference
    // between "Leave now" and having already left late.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // A periodic timer holding a setState outlives the screen otherwise, and
    // this screen is pushed and popped all morning.
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timing = widget.timing;
    final departBy = timing.departByAt!;
    final secondsLeft = departBy.difference(DateTime.now()).inSeconds;

    // Three states and only three: still time, go now, gone. The middle one is
    // a window rather than an instant, because "Leave in 0 min" is not an
    // instruction anybody can act on.
    final late = secondsLeft <= -60;
    final countdown = secondsLeft > 30
        ? tn('driver.leaveIn', (secondsLeft / 60).round())
        : late
            ? tn('driver.shouldHaveLeft', (-secondsLeft / 60).floor())
            : t('driver.leaveNow');

    final accent = late ? AppTheme.rose : Role.driver.tint;

    return Panel(
      color: late ? AppTheme.roseSoft : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.schedule_rounded,
                color: accent,
                background: late ? AppTheme.surface : Role.driver.wash,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('driver.leaveBy'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    // The one number this card exists for, at the size a driver
                    // reads from the far side of a cab.
                    Text(
                      hhmm(departBy),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1.2,
                        color: late ? AppTheme.rose : AppTheme.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            countdown,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: accent),
          ),
          const SizedBox(height: 4),
          // The arithmetic, in words. A driver given only the answer has no way
          // to tell a good one from a bad one, and the whole complaint about the
          // old timetable was that its answer could not be checked.
          Text(
            tv('driver.leaveByMath', {
              'drive': (timing.driveSeconds / 60).round(),
              'dwell': (timing.dwellSeconds / 60).round(),
              'n': widget.childrenOnRun,
            }),
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
          ),
          // Negative slack. Said as a fact about the timetable, because that is
          // what it is: no amount of driving buys the minutes back, and a line
          // that reads as an accusation is answered by skipping a stop.
          if (timing.tooTight) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.rose),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tn('driver.timetableTight', timing.shortByMinutes),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.rose,
                    ),
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

/// The count, in words.
///
/// "40 on the register, 3 away, 37 to carry" is the sentence a driver says out
/// loud at the gate. Giving them the sentence rather than three numbers to
/// subtract is the difference between a check that happens and one that does
/// not.
class _HeadcountCard extends StatelessWidget {
  const _HeadcountCard({required this.counts});

  final Headcount counts;

  @override
  Widget build(BuildContext context) {
    final outstanding = counts.expected - counts.alighted;
    final allDone = outstanding <= 0 && counts.expected > 0;

    return Panel(
      color: allDone ? AppTheme.greenSoft : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            counts.summary.isEmpty
                // The server writes this sentence in the reader's language and
                // usually sends it. When it does not, the fallback has to be a
                // translated sentence too — it was English on every screen.
                ? tv('driver.headcountLine', {
                    'a': counts.onRegister,
                    'b': counts.notComingToday,
                    'c': counts.expected,
                  })
                : counts.summary,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Fig(label: t('driver.onBoard'), value: '${counts.stillOnBoard}', colour: AppTheme.blue),
              _Fig(label: t('driver.dropped'), value: '${counts.alighted}', colour: AppTheme.green),
              _Fig(
                label: t('driver.stillToDrop'),
                value: '$outstanding',
                colour: outstanding > 0 ? AppTheme.amber : AppTheme.textMuted,
              ),
              _Fig(label: t('driver.stops'), value: '${counts.stopsDone}/${counts.stopsTotal}', colour: AppTheme.text),
            ],
          ),
          if (counts.excluded.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 10),
            Text(
              t('driver.notRiding'),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 5),
            Text(
              counts.excluded.join(', '),
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _RunControls extends StatelessWidget {
  const _RunControls({
    required this.trip,
    required this.busy,
    required this.onStart,
    required this.onDepart,
    required this.onEnd,
  });

  final CrewTrip trip;
  final String? busy;
  final VoidCallback onStart;
  final VoidCallback onDepart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    // One button at a time, and it is always the next thing to do. Presenting
    // start, depart and end together invites the wrong one to be pressed on a
    // moving bus.
    //
    // Every arm names a real TripStatus. ARRIVED, SWEEP_PENDING and
    // SWEEP_OVERDUE all used to fall through to "This run has finished" — so a
    // bus standing at the gate with children still on it offered nothing at
    // all, and a run whose cabin sweep was overdue said it was done.
    final (String label, VoidCallback? action) = switch (trip.status) {
      'PLANNED' || 'ROSTERED' => (t('driver.startShift'), onStart),
      // The walk-around failed, or the office stopped the bus. A second check
      // is the way back: a PASS clears the gate and returns the run to
      // BOARDING. The reason is shown above the button rather than on it.
      'BLOCKED' => (t('driver.startShift'), onStart),
      'BOARDING' => (t('driver.setOff'), onDepart),
      // Still carrying children — at the gate or between stops. Ending is what
      // starts the sweep clock, and the server allows it right up until the
      // trip is closed.
      'IN_PROGRESS' || 'ARRIVED' => (t('driver.endRun'), onEnd),
      // Ended. The sweep card below is the only thing left to do, and it is the
      // one thing nobody may be told is optional.
      'SWEEP_PENDING' || 'SWEEP_OVERDUE' => (t('driver.sweepOutstanding'), null),
      'CANCELLED' || 'VOID' || 'ABANDONED' => (t('driver.runCalledOff'), null),
      _ => (t('driver.runFinished'), null),
    };

    // Nothing left to do AND nothing left owed.
    final settled = trip.status == 'COMPLETED';
    final blocked = trip.status == 'BLOCKED';

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.directions_bus_filled_rounded,
                color: AppTheme.textMuted,
                background: AppTheme.neutralSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip.vehicleLabel ?? t('driver.bus')}${trip.plate != null ? ' · ${trip.plate}' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    Text(
                      '${tn('driver.dueOut', hhmm(trip.scheduledDepartureAt))}'
                      '${trip.startedAt != null ? ' · ${tn('driver.departedAt', hhmm(trip.startedAt))}' : ''}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Why the bus is stopped, in the office's own words, above the button
          // that clears it. A driver who is not told the reason cannot fix it
          // and cannot report it either.
          if (blocked) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block_rounded, size: 18, color: AppTheme.rose),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tn(
                      'driver.blocked',
                      trip.complianceFailReasons.isEmpty
                          ? t('driver.callTheOffice')
                          : trip.complianceFailReasons.join(', '),
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.rose,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // A finished run gets a sentence, not a button that cannot be
          // pressed. A dead control on a moving bus is pressed anyway, and
          // then pressed harder.
          if (action == null)
            Row(
              children: [
                // A green tick on a run whose cabin sweep is overdue reads as
                // "all fine", which is the opposite of what is true.
                Icon(
                  settled ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  size: 18,
                  color: settled ? AppTheme.green : AppTheme.rose,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: settled ? AppTheme.textMuted : AppTheme.rose,
                    ),
                  ),
                ),
              ],
            )
          else
            BigButton(
              label: label,
              color: Role.driver.tint,
              busy: busy != null,
              height: 52,
              onPressed: action,
            ),
        ],
      ),
    );
  }
}

class _OrderToggle extends StatelessWidget {
  const _OrderToggle({required this.nearestFirst, required this.note, required this.onChanged});

  final bool nearestFirst;
  final String note;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('driver.nearestFirst'),
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
              Switch(
                value: nearestFirst,
                activeTrackColor: Role.driver.tint,
                onChanged: onChanged,
              ),
            ],
          ),
          if (note.isNotEmpty)
            Text(
              note,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.45),
            ),
        ],
      ),
    );
  }
}

class _StopCard extends StatefulWidget {
  const _StopCard({
    required this.stop,
    required this.tripId,
    required this.leg,
    required this.terminalStopId,
    required this.onChanged,
  });

  final PlannedStop stop;
  final String tripId;
  final String leg;

  /// The campus gate, where the morning's drop-offs and the afternoon's
  /// boardings actually happen.
  final String? terminalStopId;

  final VoidCallback onChanged;

  @override
  State<_StopCard> createState() => _StopCardState();
}

class _StopCardState extends State<_StopCard> {
  bool _open = false;
  String? _busyStudent;
  bool _busyStop = false;

  Future<void> _mark(RiderOnStop rider, String eventType, String label) async {
    setState(() => _busyStudent = rider.studentId);
    try {
      final verdict = await CrewApi.instance.recordCustody(
        tripId: widget.tripId,
        studentId: rider.studentId,
        eventType: eventType,
        // The stop the BUS is at, not the card this row is drawn under. Sending
        // the child's home stop for a morning drop-off at the school is what
        // made the server rewrite the event to WRONG_STOP and wake the
        // safeguarding lead, once per child, every morning.
        stopId: custodyStopId(
          leg: widget.leg,
          eventType: eventType,
          riderStopId: widget.stop.stopId,
          terminalStopId: widget.terminalStopId,
        ),
      );
      widget.onChanged();
      if (!mounted) return;
      // What the SERVER did, not what was asked of it.
      //
      // The batch endpoint answers 200 even when the event inside it was
      // refused, and this used to read that as done: a refused boarding
      // reached the driver as a green "Ahmad — On board" while the ledger held
      // nothing, and he drove off believing the child was recorded.
      final first = rider.name.split(' ').first;
      if (!verdict.accepted) {
        showNote(context, verdict.reason ?? tv('driver.notRecorded', {'name': first}), bad: true);
      } else if (verdict.rewrittenTo != null) {
        // Accepted, but stored as something else — a drop-off away from the
        // expected stop becomes WRONG_STOP, and the office has been told.
        showNote(context, tv('driver.recordedAs', {'name': first}), bad: true);
      } else {
        // The label, not humanise(EVENT_TYPE): that spelled the server's enum
        // out in English on a Kurdish screen.
        showNote(context, '$first — $label');
      }
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busyStudent = null);
    }
  }

  /// Arriving at the stop and leaving it — the two things that move the run on.
  Future<void> _stopAction(Future<void> Function() call, String label) async {
    if (_busyStop) return;
    setState(() => _busyStop = true);
    try {
      await call();
      widget.onChanged();
      if (mounted) showNote(context, label);
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busyStop = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stop;
    final remaining = s.remaining;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.done
                            ? AppTheme.greenSoft
                            : remaining == 0
                                ? AppTheme.greenSoft
                                : Role.driver.wash,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: s.done || remaining == 0
                          ? Icon(Icons.check_rounded, size: 18, color: AppTheme.green)
                          : Text(
                              '${s.plannedSequence}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Role.driver.tint,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // The landmark, not the coordinates. In much of the
                            // Region a street address is not something a driver
                            // can navigate by; "opposite the mosque" is.
                            [
                              if (s.landmark != null) s.landmark!,
                              if (s.metresAway != null)
                                tn('driver.metresAway', s.metresAway!),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          // When the bus is due here — or, once it has been,
                          // when it got here. Same field, and the difference is
                          // drawn rather than left to the reader.
                          if (s.etaAt != null) ...[
                            const SizedBox(height: 3),
                            StopEta(stop: s),
                          ],
                        ],
                      ),
                    ),
                    Tag(
                      remaining == 0 ? t('driver.done') : tn('driver.nLeft', remaining),
                      color: remaining == 0 ? AppTheme.green : AppTheme.amber,
                      background: remaining == 0 ? AppTheme.greenSoft : AppTheme.amberSoft,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppTheme.textFaint,
                    ),
                  ],
                ),
              ),
            ),
            if (_open) ...[
              Divider(height: 1, color: AppTheme.border),
              ...s.students.map((r) => _RiderRow(
                    rider: r,
                    leg: widget.leg,
                    busy: _busyStudent == r.studentId,
                    // The note names the state the child is now in, in the
                    // reader's language.
                    onBoard: () => _mark(r, 'BOARDED', t('driver.onBoard')),
                    onOff: () => _mark(
                      r,
                      widget.leg == 'OUT' ? 'ALIGHTED' : 'HANDOVER',
                      widget.leg == 'OUT' ? t('driver.atSchool') : t('driver.handedOver'),
                    ),
                    onNoShow: () => _mark(r, 'NO_SHOW', t('driver.notRiding')),
                  )),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: BigButton(
                        label: t('driver.arrived'),
                        color: Role.driver.tint,
                        busy: _busyStop,
                        onPressed: () => _stopAction(
                          () => CrewApi.instance
                              .arriveAtStop(widget.tripId, s.plannedSequence),
                          t('driver.arrived'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BigButton(
                        label: t('driver.movingOn'),
                        color: AppTheme.blue,
                        busy: _busyStop,
                        onPressed: () => _stopAction(
                          () => CrewApi.instance
                              .leaveStop(widget.tripId, s.plannedSequence),
                          t('driver.movingOn'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A stop's arrival time, told apart from a guess about one.
///
/// The server sends both down the same field: etaAt is a forecast until the bus
/// actually gets there, and the record of the arrival afterwards. Drawing them
/// identically is how a driver comes to distrust both — so a forecast carries a
/// clock and a tilde, and an arrival carries a tick and the word for what
/// happened.
class StopEta extends StatelessWidget {
  const StopEta({super.key, required this.stop});

  final PlannedStop stop;

  @override
  Widget build(BuildContext context) {
    if (stop.etaAt == null) return const SizedBox.shrink();
    final actual = stop.etaIsActual;
    final colour = actual ? AppTheme.green : AppTheme.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          actual ? Icons.check_circle_rounded : Icons.schedule_rounded,
          size: 12,
          color: colour,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            stopEtaText(stop),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: colour),
          ),
        ),
      ],
    );
  }
}

/// The short form, for a column narrow enough that the mark beside it already
/// says which of the two it is: "Arrived 07:14", or "~07:14".
String stopEtaText(PlannedStop stop) => stop.etaAt == null
    ? '—'
    : stop.etaIsActual
        ? tn('driver.arrivedAt', hhmm(stop.etaAt))
        : tn('driver.etaShort', hhmm(stop.etaAt));

/// The long form, for a line of running text with no mark on it: a bare tilde
/// in the middle of a sentence is not a word anybody reads as "about".
String stopEtaLine(PlannedStop stop) => stop.etaAt == null
    ? '—'
    : stop.etaIsActual
        ? tn('driver.arrivedAt', hhmm(stop.etaAt))
        : tn('driver.etaDue', hhmm(stop.etaAt));

class _RiderRow extends StatelessWidget {
  const _RiderRow({
    required this.rider,
    required this.leg,
    required this.busy,
    required this.onBoard,
    required this.onOff,
    required this.onNoShow,
  });

  final RiderOnStop rider;
  final String leg;
  final bool busy;
  final VoidCallback onBoard;
  final VoidCallback onOff;
  final VoidCallback onNoShow;

  @override
  Widget build(BuildContext context) {
    final onBus = rider.boardedAt != null && rider.alightedAt == null;
    final off = rider.alightedAt != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: off
                  ? AppTheme.greenSoft
                  : onBus
                      ? AppTheme.blueSoft
                      : AppTheme.neutralSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              rider.seatNumber ?? '·',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: off
                    ? AppTheme.green
                    : onBus
                        ? AppTheme.blue
                        : AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rider.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                    ),
                    if (rider.requiresAssistance) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.accessible_rounded, size: 14, color: AppTheme.amber),
                    ],
                  ],
                ),
                if (off)
                  Text(
                    '${leg == 'OUT' ? t('driver.atSchool') : t('driver.handedOver')} ${hhmm(rider.alightedAt)}',
                    style: TextStyle(fontSize: 11, color: AppTheme.green),
                  )
                else if (onBus)
                  Text(
                    tn('driver.onBoardSince', hhmm(rider.boardedAt)),
                    style: TextStyle(fontSize: 11, color: AppTheme.blue),
                  ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else if (!off)
            Row(
              children: [
                _Mini(
                  icon: onBus ? Icons.logout_rounded : Icons.login_rounded,
                  colour: onBus ? AppTheme.green : Role.driver.tint,
                  onTap: onBus ? onOff : onBoard,
                ),
                const SizedBox(width: 6),
                _Mini(icon: Icons.close_rounded, colour: AppTheme.rose, onTap: onNoShow),
              ],
            ),
        ],
      ),
    );
  }
}

/// The board / drop / no-show buttons on a rider's row.
///
/// 46 square. These are pressed by somebody standing in an aisle, one handed,
/// often wearing gloves, while the child is still in front of them — the 36 dp
/// square they used to be is under every guideline there is and was missed
/// often enough to be marked on the wrong row.
class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.colour, required this.onTap});

  final IconData icon;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 21, color: colour),
      ),
    );
  }
}

/// The last thing before the bus is locked.
class _SweepCard extends StatelessWidget {
  const _SweepCard({
    required this.sweep,
    required this.busy,
    required this.onConfirm,
    required this.tripEnded,
    required this.onChildFound,
    required this.stillOwed,
  });

  /// The server still wants a sweep for this run.
  ///
  /// Taken from the trip's own status — SWEEP_PENDING or SWEEP_OVERDUE — and it
  /// is the authority, because `confirmedAt` on its own lies. A sweep filed
  /// BEFORE the run ended does not satisfy the run: the server stamps a fresh
  /// deadline at close and leaves the status pending. This screen showed both
  /// answers at once — a red "this run has ended and the cabin sweep is not
  /// confirmed" at the top, from the status, and a green "Cabin swept,
  /// confirmed at 16:55" at the bottom, from confirmedAt, about a run that
  /// ended eight hours after that. On the one control that exists to stop a
  /// child being left in a locked bus, the reassuring half was the wrong one.
  final bool stillOwed;

  /// Opened when the aisle was NOT empty. Deliberately a plain link under the
  /// big button rather than a second big button: the ordinary end to a sweep is
  /// that the bus is empty, and a driver at the end of a run should not have to
  /// choose between two equal-looking things to say so.
  final VoidCallback onChildFound;

  final SweepState sweep;
  final bool busy;
  final VoidCallback onConfirm;

  /// Whether the run has actually finished.
  ///
  /// The sweep is the walk down the aisle AFTER the last child is off, and both
  /// halves of this card were wrong without it. The server only computes a
  /// deadline once the trip has ended, so secondsRemaining is null all morning
  /// — and `?? 0` read that as "the deadline has passed", painting the panel
  /// red and announcing that the office had been told, from 07:00, every day,
  /// on the one panel of this screen that has to be believed.
  ///
  /// Worse, the button under it was live too, and the server takes it: nothing
  /// on either side checks that the run is over. A driver clearing that false
  /// red at 07:00, with forty children about to board, filed the empty-bus
  /// declaration for the day — after which the card turns green for good and
  /// the aisle is never walked. The control that exists to stop a child being
  /// left in a locked bus could be satisfied before the bus had moved.
  final bool tripEnded;

  @override
  Widget build(BuildContext context) {
    if (!sweep.required_) {
      return Panel(
        child: Text(
          t('driver.sweepNotRequired'),
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
      );
    }

    // Confirmed, and the server agrees it counts.
    if (sweep.confirmedAt != null && !stillOwed) {
      return Panel(
        color: AppTheme.greenSoft,
        child: Row(
          children: [
            IconChip(
              icon: Icons.verified_rounded,
              color: AppTheme.green,
              background: AppTheme.surface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('driver.cabinSwept'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  Text(
                    tn('driver.confirmedAt', hhmm(sweep.confirmedAt)),
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Not yet: the run is still going, so say what the sweep is for and leave
    // it at that. No countdown, no red, and no button to press by mistake.
    if (!tripEnded) {
      return Panel(
        child: Row(
          children: [
            IconChip(
              icon: Icons.event_seat_rounded,
              color: AppTheme.textMuted,
              background: AppTheme.neutralSoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t('driver.sweepAfterRun'),
                style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    // Only once the run is over is there a deadline at all, so only then can it
    // have passed. A null here now means the server has not sent one yet, which
    // is not the same as late.
    final seconds = sweep.secondsRemaining;
    final late = seconds != null && seconds <= 0;

    return Panel(
      color: late ? AppTheme.roseSoft : AppTheme.amberSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.event_seat_rounded,
                color: late ? AppTheme.rose : AppTheme.amber,
                background: AppTheme.surface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('driver.walkToBack'),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      late
                          ? t('driver.sweepDeadlinePassed')
                          : '${tn('driver.sweepDueBy', hhmm(sweep.deadlineAt))} — ${tn('driver.aboutMinutes', ((seconds ?? 0) / 60).ceil())}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: late ? AppTheme.rose : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            // Said every time. In an Iraqi June a sealed cabin becomes lethal in
            // minutes, not hours, and this sentence is the reason the deadline
            // is short rather than convenient.
            '${t('driver.sweepHow')}${t('driver.sweepWhy')}',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
          ),
          // Late, and he has already pressed it. The server keeps this card up
          // because a late walk does not clear the run — which from the driver's
          // seat looks exactly like a button that does nothing, and that is how
          // one run collected ten attempts. His walk did land; say so.
          if (late && sweep.attemptsSoFar > 0) ...[
            const SizedBox(height: 10),
            Text(
              t('driver.sweepRecordedNotCleared'),
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.rose,
              ),
            ),
          ],
          const SizedBox(height: 14),
          BigButton(
            label: t('driver.walkedTheBus'),
            color: late ? AppTheme.rose : AppTheme.amber,
            busy: busy,
            height: 54,
            onPressed: onConfirm,
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: busy ? null : onChildFound,
              child: Text(
                t('driver.childFound'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.rose,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fig extends StatelessWidget {
  const _Fig({required this.label, required this.value, required this.colour});

  final String label;
  final String value;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: colour),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/* ---------------------------------------------------------------------------
 * The pre-trip walk-around
 * ------------------------------------------------------------------------- */

/// The walk-around, in the order somebody walking round a bus does it.
///
/// The token on the left is what goes to the server and is never translated:
/// these answers are read by an office months later, on a screen whose language
/// nobody chose, and a key that says `تایەرەکان` cannot be queried. The key on
/// the right is what the driver reads.
const List<(String, String)> _preTripItems = [
  ('tyres', 'driver.pretrip.item.tyres'),
  ('lights', 'driver.pretrip.item.lights'),
  ('brakes', 'driver.pretrip.item.brakes'),
  ('mirrors', 'driver.pretrip.item.mirrors'),
  ('doors', 'driver.pretrip.item.doors'),
  ('seats', 'driver.pretrip.item.seats'),
  ('safetyKit', 'driver.pretrip.item.safetyKit'),
  ('cabin', 'driver.pretrip.item.cabin'),
];

const String _answerOk = 'OK';
const String _answerDefect = 'DEFECT';
const String _answerNotChecked = 'NOT_CHECKED';

/// The check the platform will not open a shift without.
///
/// It is evidence, not paperwork. The server keeps how long it took, how far
/// the handset's clock is from its own, and — the field this build cannot fill
/// — a photograph of the person who did it, standing at the bus. Everything
/// here is the driver's own answer; nothing is defaulted to OK, because a form
/// that arrives pre-passed is not a check.
class _PreTripSheet extends StatefulWidget {
  const _PreTripSheet();

  @override
  State<_PreTripSheet> createState() => _PreTripSheetState();
}

class _PreTripSheetState extends State<_PreTripSheet> {
  /// Minted once, here, and carried into the send. A retry over a dropped
  /// connection then lands as the same inspection rather than a second one.
  final String _clientUuid = uuidV4();

  /// Really measured. The server keeps it precisely so a walk-around "done" in
  /// nine seconds can be told apart from one that happened.
  final DateTime _openedAt = DateTime.now();

  final Map<String, String> _answers = {};
  final TextEditingController _odometer = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  bool _unsafe = false;

  /// The crew member's own photograph, which ShiftStartDto requires.
  ///
  /// The id of a real file on the platform: taken on this handset a moment ago,
  /// at the bus, and uploaded before the check can be filed. Nothing else will
  /// do. The server looks the id up and refuses anything that is not an
  /// AVAILABLE asset at this school belonging to the person filing the check —
  /// which is the entire point of the field, because a session token can be
  /// handed to a cousin along with the phone and a photograph of somebody
  /// standing at the bus cannot.
  ///
  /// Null until an upload has come back with an id, and never filled in from
  /// anywhere else. Not the driver's profile picture, not this morning's other
  /// run: an inspection carrying a borrowed photograph proves the wrong thing
  /// on a safeguarding record, which is worse than proving nothing.
  String? _selfieAssetId;

  /// The photograph as it was taken, kept so the thumbnail can be drawn and so
  /// an upload that failed on a dead spot can be sent again without walking
  /// back round the bus.
  Uint8List? _shot;

  /// What the camera actually handed back, read off the file's own name.
  String _mime = 'image/jpeg';

  /// When the shutter went — which, on a yard with one bar, is minutes before
  /// the upload finishes. That is the time the office reads.
  DateTime? _takenAt;

  bool _sending = false;

  /// Why the last attempt did not work, in the driver's own language, or null.
  /// Left on screen rather than flashed past, because it is the thing standing
  /// between them and starting the shift.
  String? _sendFailed;

  @override
  void dispose() {
    _odometer.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Open the camera, then send what comes back.
  ///
  /// The phone's own camera app takes it — front lens to begin with, because
  /// what is being evidenced is the person and not the bus, though the driver
  /// can turn it round if the sun is behind them. 1280 pixels at quality
  /// seventy comes to a few hundred kilobytes: this is proof that somebody was
  /// standing here, not a portrait, and the yard has one bar of signal at
  /// twenty to seven.
  Future<void> _takeSelfie() async {
    if (_sending) return;

    XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1280,
        imageQuality: 70,
      );
    } on PlatformException catch (e) {
      // The one failure a driver can actually do something about. Android
      // refuses the capture outright once the camera permission has been
      // denied, and a general "that did not work" leaves them tapping the same
      // button until the bus is late.
      if (!mounted) return;
      setState(() => _sendFailed = e.code == 'camera_access_denied'
          ? t('driver.pretrip.selfieDenied')
          : errorText(e));
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendFailed = errorText(e));
      return;
    }

    // The camera was closed without taking one. Nothing has changed, so nothing
    // is said — an error here would read as a refusal.
    final picked = shot;
    if (picked == null || !mounted) return;

    final Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendFailed = errorText(e));
      return;
    }
    if (!mounted) return;

    setState(() {
      _shot = bytes;
      _mime = _imageMime(picked.name);
      _takenAt = DateTime.now();
      // A new photograph replaces whatever was accepted before it. Leaving the
      // old id in place would file the check against the very picture the
      // driver has just decided to take again.
      _selfieAssetId = null;
      _sendFailed = null;
    });
    await _sendSelfie();
  }

  /// Put the photograph on the platform and keep the id it comes back with.
  ///
  /// Kept apart from taking it so that an upload lost to a dead spot can be
  /// sent again from where the driver is standing, rather than sending them
  /// round the bus a second time for a picture they have already taken.
  ///
  /// A failure is said plainly and left on screen. Nothing is filed, and no id
  /// is invented to get past it.
  Future<void> _sendSelfie() async {
    final bytes = _shot;
    if (bytes == null || _sending) return;

    setState(() {
      _sending = true;
      _sendFailed = null;
    });
    try {
      final id = await CrewApi.instance.uploadPhoto(
        bytes: bytes,
        mime: _mime,
        filename: 'pretrip-$_clientUuid.${_imageExtension(_mime)}',
        capturedAt: _takenAt,
      );
      if (!mounted) return;
      setState(() {
        _selfieAssetId = id;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendFailed = errorText(e);
      });
    }
  }

  bool get _answered => _answers.length == _preTripItems.length;

  /// FAIL and NOT_COMPLETED both stop the bus, and the server enforces that
  /// rather than warning about it. So the driver saying outright that this bus
  /// must not carry children outranks everything else on the form.
  String get _outcome {
    if (_unsafe) return kInspectionFail;
    if (_answers.values.contains(_answerNotChecked)) return kInspectionNotCompleted;
    if (_answers.values.contains(_answerDefect)) return kInspectionPassWithDefects;
    return kInspectionPass;
  }

  /// Hand the finished check back to the screen that opened this sheet, which
  /// then — and only then — calls shift-start.
  ///
  /// Three things are checked here rather than trusted to the button being
  /// pressed at the right moment, because every one of them is a 400 from the
  /// server and a driver standing in a yard wondering what went wrong.
  void _file() {
    // The photograph first: it is at the top of the sheet, and by the time the
    // driver has reached this button it may be several screens above them.
    if (_sending) {
      showNote(context, t('driver.pretrip.selfieSending'), bad: true);
      return;
    }
    final selfie = _selfieAssetId;
    if (selfie == null) {
      showNote(context, t('driver.pretrip.selfieRequired'), bad: true);
      return;
    }
    if (!_answered) {
      showNote(context, t('driver.pretrip.answerAll'), bad: true);
      return;
    }

    final km = int.tryParse(_odometer.text.trim());
    final notes = _notes.text.trim();

    Navigator.of(context).pop(
      PreTripCheck(
        clientUuid: _clientUuid,
        items: Map<String, String>.from(_answers),
        outcome: _outcome,
        durationSeconds:
            DateTime.now().difference(_openedAt).inSeconds.clamp(1, 7200),
        selfieAssetId: selfie,
        itemsFailedCount:
            _answers.values.where((v) => v != _answerOk).length,
        odometerKm: km != null && km >= 0 && km <= 9999999 ? km : null,
        notes: notes.isEmpty
            ? null
            : notes.substring(0, notes.length > 500 ? 500 : notes.length),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('driver.pretrip.title'),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('driver.pretrip.intro'),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  shrinkWrap: true,
                  children: [
                    // First, before the driver fills anything in. The
                    // photograph is not optional on the platform, and letting
                    // somebody answer eight questions before telling them the
                    // check cannot be filed is a worse morning than telling
                    // them now. It stays on the sheet after it is accepted, so
                    // the driver can see that it was.
                    _SelfieStep(
                      shot: _shot,
                      held: _selfieAssetId != null,
                      sending: _sending,
                      failed: _sendFailed,
                      onTake: _takeSelfie,
                      onSendAgain: _sendSelfie,
                    ),
                    const SizedBox(height: 14),
                    ..._preTripItems.map(
                      (item) => _PreTripRow(
                        label: t(item.$2),
                        answer: _answers[item.$1],
                        onAnswer: (a) => setState(() => _answers[item.$1] = a),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _PreTripField(
                      controller: _odometer,
                      label: t('driver.pretrip.odometer'),
                      numeric: true,
                    ),
                    const SizedBox(height: 10),
                    _PreTripField(
                      controller: _notes,
                      label: t('driver.pretrip.notes'),
                      numeric: false,
                    ),
                    const SizedBox(height: 12),
                    Panel(
                      color: _unsafe ? AppTheme.roseSoft : null,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t('driver.pretrip.unsafe'),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: _unsafe ? AppTheme.rose : AppTheme.text,
                              ),
                            ),
                          ),
                          Switch(
                            value: _unsafe,
                            activeTrackColor: AppTheme.rose,
                            onChanged: (v) => setState(() => _unsafe = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Said again, down here, because the photograph card is at
                    // the top of a list that is eight items long: by the time
                    // the driver reaches this button the reason the check will
                    // not go is off the screen.
                    if (_selfieAssetId == null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_camera_outlined, size: 16, color: AppTheme.rose),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              _sending
                                  ? t('driver.pretrip.selfieSending')
                                  : t('driver.pretrip.selfieRequired'),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.rose,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    BigButton(
                      label: t('driver.pretrip.file'),
                      color: _outcome == kInspectionPass ? tint : AppTheme.amber,
                      height: 54,
                      busy: _sending,
                      onPressed: _file,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the walk-around: what to look at, and the three honest answers.
///
/// "Not checked" is offered on purpose. A driver who cannot get to the back of
/// a bus parked against a wall needs somewhere to say so — the alternative is
/// that they tap OK, and an OK that means "I could not look" is the answer that
/// makes the whole record worthless.
class _PreTripRow extends StatelessWidget {
  const _PreTripRow({
    required this.label,
    required this.answer,
    required this.onAnswer,
  });

  final String label;
  final String? answer;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _PreTripChoice(
                  label: t('driver.pretrip.ok'),
                  colour: AppTheme.green,
                  on: answer == _answerOk,
                  onTap: () => onAnswer(_answerOk),
                ),
                const SizedBox(width: 8),
                _PreTripChoice(
                  label: t('driver.pretrip.defect'),
                  colour: AppTheme.amber,
                  on: answer == _answerDefect,
                  onTap: () => onAnswer(_answerDefect),
                ),
                const SizedBox(width: 8),
                _PreTripChoice(
                  label: t('driver.pretrip.notChecked'),
                  colour: AppTheme.rose,
                  on: answer == _answerNotChecked,
                  onTap: () => onAnswer(_answerNotChecked),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 48 high, because this is tapped standing beside a bus in the dark.
class _PreTripChoice extends StatelessWidget {
  const _PreTripChoice({
    required this.label,
    required this.colour,
    required this.on,
    required this.onTap,
  });

  final String label;
  final Color colour;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: on ? colour : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? colour : AppTheme.border,
              width: on ? 2 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreTripField extends StatelessWidget {
  const _PreTripField({
    required this.controller,
    required this.label,
    required this.numeric,
  });

  final TextEditingController controller;
  final String label;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      maxLines: numeric ? 1 : 2,
      maxLength: numeric ? 7 : 500,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Role.driver.tint),
        ),
      ),
    );
  }
}

/// The type of image the camera handed back.
///
/// image_picker re-encodes to JPEG whenever `imageQuality` is set, but it says
/// so only through the file's own name, and the upload endpoint checks the
/// part's Content-Type against the image types it accepts — so this is read
/// rather than assumed. Every type named here is on that server-side list;
/// anything unrecognised is called JPEG, which is what the plugin produces when
/// it re-encodes.
String _imageMime(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

/// The extension to file it under, so the name in the office's list matches
/// what is actually inside the file.
String _imageExtension(String mime) => switch (mime) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      'image/heif' => 'heif',
      _ => 'jpg',
    };

/// The one step on this sheet that cannot be typed: the crew member's own
/// photograph, taken at the bus.
///
/// It has four states and each one looks different from arm's length, because
/// the person reading it is wearing gloves in a yard before dawn and the
/// difference between "sent" and "not sent" decides whether the bus goes:
///
///   nothing yet   the driver's own colour, one large button
///   sending       the picture, greyed, with a spinner over it
///   failed        red, the server's own words, and two ways forward
///   accepted      green, a tick on the picture, and nothing left to do
///
/// The photograph shown is only the thumbnail. The evidence is the asset id the
/// server gave back for it, which is what the tick means.
class _SelfieStep extends StatelessWidget {
  const _SelfieStep({
    required this.shot,
    required this.held,
    required this.sending,
    required this.failed,
    required this.onTake,
    required this.onSendAgain,
  });

  /// The bytes as taken, for the thumbnail. Null before the first capture.
  final Uint8List? shot;

  /// An asset id is held: the platform has the photograph and this step is
  /// done.
  final bool held;

  final bool sending;

  /// Why the last attempt did not work, already in the driver's language.
  final String? failed;

  final VoidCallback onTake;
  final VoidCallback onSendAgain;

  @override
  Widget build(BuildContext context) {
    final broken = failed != null && !sending;
    final colour = held
        ? AppTheme.green
        : broken
            ? AppTheme.rose
            : Role.driver.tint;
    final wash = held
        ? AppTheme.greenSoft
        : broken
            ? AppTheme.roseSoft
            : Role.driver.wash;

    final String body;
    if (sending) {
      body = t('driver.pretrip.selfieSending');
    } else if (broken) {
      body = failed!;
    } else if (held) {
      body = t('driver.pretrip.selfieAccepted');
    } else {
      body = t('driver.pretrip.selfieWhy');
    }

    return Panel(
      color: wash,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelfieThumb(
                shot: shot,
                held: held,
                sending: sending,
                colour: colour,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('driver.pretrip.selfieTitle'),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: colour,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppTheme.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // The same picture, sent again. Offered first after a failure,
          // because a dead spot in the yard is the likeliest reason and walking
          // back round the bus for a second photograph fixes nothing.
          //
          // Not offered once an id is already held. A camera that refuses a
          // RETAKE leaves the accepted photograph standing, and re-sending it
          // would file a second copy to no purpose.
          if (broken && shot != null && !held) ...[
            _SelfieButton(
              label: t('driver.pretrip.selfieSendAgain'),
              icon: Icons.refresh_rounded,
              colour: colour,
              filled: true,
              onTap: sending ? null : onSendAgain,
            ),
            const SizedBox(height: 9),
          ],
          _SelfieButton(
            label: shot == null
                ? t('driver.pretrip.selfieTake')
                : t('driver.pretrip.selfieRetake'),
            icon: Icons.photo_camera_rounded,
            colour: colour,
            // Loud while it is the thing standing in the way; quiet once the
            // photograph is accepted, so it cannot be mistaken for the button
            // that files the check.
            filled: shot == null,
            onTap: sending ? null : onTake,
          ),
        ],
      ),
    );
  }
}

/// The photograph as taken, at a size a driver can actually judge — a picture
/// of the inside of a pocket has to be obvious at a glance.
class _SelfieThumb extends StatelessWidget {
  const _SelfieThumb({
    required this.shot,
    required this.held,
    required this.sending,
    required this.colour,
  });

  final Uint8List? shot;
  final bool held;
  final bool sending;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final bytes = shot;
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: bytes == null
                  ? Container(
                      color: AppTheme.surface,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 30,
                        color: colour,
                      ),
                    )
                  : Opacity(
                      opacity: sending ? 0.45 : 1,
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        width: 84,
                        height: 84,
                        gaplessPlayback: true,
                      ),
                    ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colour, width: 2),
                ),
              ),
            ),
          ),
          if (sending)
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6, color: colour),
                ),
              ),
            ),
          // The tick stands for the asset id, not for the picture. It appears
          // only once the server has answered with one.
          if (held && !sending)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.canvas, width: 2),
                ),
                child: const Icon(Icons.check_rounded, size: 17, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// 56 high, full width, with the icon beside the words. Gloves, and a yard in
/// the dark.
class _SelfieButton extends StatelessWidget {
  const _SelfieButton({
    required this.label,
    required this.icon,
    required this.colour,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color colour;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final off = onTap == null;
    final foreground = filled ? Colors.white : colour;
    return Opacity(
      opacity: off ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? colour : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colour,
              width: filled ? 0 : 1.6,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: foreground),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: foreground,
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

/// Which child was found on the bus.
///
/// A plain list of this run's own roster. The server insists on a name with a
/// CHILD_FOUND sweep — "Say which child was found on board" — and it is right
/// to: the record has to say who, so the office knows which family to ring
/// before the parent rings them.
class _ChildFoundSheet extends StatelessWidget {
  const _ChildFoundSheet({required this.riders});

  final List<RiderOnStop> riders;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            t('driver.childFound'),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.text),
          ),
          const SizedBox(height: 4),
          Text(
            t('driver.childFoundWho'),
            style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: riders.length,
              itemBuilder: (context, i) {
                final r = riders[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    r.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                  ),
                  onTap: () => Navigator.of(context).pop(r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The panic button, on screen for as long as the bus is running.
///
/// There was none. A driver being threatened at the door had the same options
/// as a driver with a flat tyre, which is to say a phone call to an office
/// that may not answer. The server has taken an SOS all along and turns it
/// into the loudest thing this platform can do.
class _PanicButton extends StatelessWidget {
  const _PanicButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: busy ? null : onPressed,
          icon: Icon(Icons.emergency_share_rounded, size: 19, color: AppTheme.rose),
          label: Text(
            t('driver.sos'),
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.rose),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: AppTheme.rose.withValues(alpha: 0.5)),
            backgroundColor: AppTheme.roseSoft,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

/// One tap between a pocket and a critical alert.
class _PanicSheet extends StatelessWidget {
  const _PanicSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            t('driver.sos'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.rose),
          ),
          const SizedBox(height: 6),
          Text(
            t('driver.sosWhat'),
            style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          BigButton(
            label: t('driver.sosSend'),
            color: AppTheme.rose,
            height: 54,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
