import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/bus_location.dart';
import '../../api/crew_api.dart';
import '../../api/device_heartbeat.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';
import 'roster_kit.dart';
import 'route_map.dart';

const List<(String, String)> _serverSays = [
  ('not been started', 'driver.mustSetOff'),
  ('is not running', 'driver.mustSetOff'),
  ('pre-trip check', 'driver.mustCheckBus'),
];

String _driverWords(String message) {
  final lower = message.toLowerCase();
  for (final (fragment, key) in _serverSays) {
    if (lower.contains(fragment)) return t(key);
  }
  return message;
}

String _driverError(Object? e) => _driverWords(errorText(e));

class _Aboard {
  const _Aboard({required this.rider, required this.stopId, required this.stopName});

  final RiderOnStop rider;
  final String stopId;
  final String stopName;
}

List<_Aboard> _stillAboard(TripPlan plan) => [
      for (final stop in plan.stops)
        for (final rider in stop.students)
          if (rider.boardedAt != null && rider.alightedAt == null)
            _Aboard(rider: rider, stopId: stop.stopId, stopName: stop.name),
    ];

class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.tripId, this.serviceDate});

  final String tripId;

  final DateTime? serviceDate;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final _loaderKey = GlobalKey<LoaderState<_TripData>>();
  bool _nearestFirst = false;
  String? _busy;

  final TextEditingController _search = TextEditingController();
  String _query = '';

  static bool _matches(RiderOnStop r, String q) =>
      q.isEmpty ||
      r.name.toLowerCase().contains(q) ||
      (r.seatNumber ?? '').toLowerCase().contains(q);

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

  final ValueNotifier<CrewTrip?> _headerTrip = ValueNotifier<CrewTrip?>(null);

  @override
  void dispose() {
    _headerTrip.dispose();
    _search.dispose();
    super.dispose();
  }

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
    final me = BusLocation.instance.here.value;
    final results = await Future.wait([
      _dutyList(),
      api.plan(
        widget.tripId,
        nearest: _nearestFirst,
        lat: me?.latitude,
        lon: me?.longitude,
      ),
      api.sweepState(widget.tripId),
      _gate(),
    ]);
    final trips = results[0] as List<CrewTrip>;
    _headerTrip.value = trips.where((t) => t.id == widget.tripId).firstOrNull;

    final live = _headerTrip.value;
    if (live != null && live.startedAt != null && live.endedAt == null) {
      unawaited(BusLocation.instance.start(live.id));
      DeviceHeartbeat.instance.noteTrip(live.id);
    } else {
      if (BusLocation.instance.isRunning) unawaited(BusLocation.instance.stop());
      DeviceHeartbeat.instance.noteTrip(null);
    }
    return _TripData(
      trip: trips.where((t) => t.id == widget.tripId).firstOrNull,
      plan: results[1] as TripPlan,
      sweep: results[2] as SweepState,
      terminalStopId: results[3] as String?,
    );
  }

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

  Future<void> _endRun(CrewTrip trip, int stillOnBoard) async {
    if (stillOnBoard > 0) {
      final go = await showAppSheet<bool>(
        context,
        builder: (_) => _EndWithChildrenSheet(count: stillOnBoard),
      );
      if (go != true || !mounted) return;
    }
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
      if (mounted) showNote(context, _driverError(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _recordAllOff(_TripData data) async {
    final leg = data.trip?.leg ?? 'OUT';
    final aboard = _stillAboard(data.plan);
    if (aboard.isEmpty) return;

    final picked = await showAppSheet<List<_Aboard>>(
      context,
      builder: (_) => _RecordAllOffSheet(aboard: aboard, leg: leg),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    final eventType = leg == 'OUT' ? 'ALIGHTED' : 'HANDOVER';

    setState(() => _busy = t('driver.recordingAllOff'));
    try {
      final outcomes = await CrewApi.instance.recordCustodyBatch(
        tripId: widget.tripId,
        entries: [
          for (final a in picked)
            CustodyEntry(
              studentId: a.rider.studentId,
              eventType: eventType,
              stopId: custodyStopId(
                leg: leg,
                eventType: eventType,
                riderStopId: a.stopId,
                terminalStopId: data.terminalStopId,
              ),
            ),
        ],
      );
      _loaderKey.currentState?.reload();
      if (!mounted) return;
      final said = _batchNote(outcomes);
      showNote(context, said.text, bad: said.bad);
    } catch (e) {
      if (mounted) showNote(context, _driverError(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  ({String text, bool bad}) _batchNote(List<CustodyOutcome> outcomes) {
    final refused = outcomes.where((o) => !o.verdict.accepted).toList();
    final ok = outcomes.length - refused.length;

    if (refused.isNotEmpty) {
      final why = refused.map((o) => o.verdict.reason).whereType<String>().firstOrNull;
      return (
        text: why == null
            ? tv('driver.someOffRefused', {'ok': ok, 'bad': refused.length})
            : tv('driver.someOffRefusedWhy', {
                'ok': ok,
                'bad': refused.length,
                'why': _driverWords(why),
              }),
        bad: true,
      );
    }

    final away = outcomes.where((o) => o.verdict.rewrittenTo != null).length;
    if (away > 0) {
      return (text: tv('driver.allOffButAway', {'ok': ok, 'away': away}), bad: true);
    }

    return (text: tn('driver.allOffRecorded', ok), bad: false);
  }

  Future<void> _panic(CrewTrip trip) async {
    final go = await showAppSheet<bool>(
      context,
      builder: (_) => const _PanicSheet(),
    );
    if (go != true || !mounted) return;
    await _act(t('driver.sosSent'), () => CrewApi.instance.sos(trip.id));
  }

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
      if (mounted) showNote(context, _driverError(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _act(String label, Future<void> Function() action) => _actWith<bool>(
        label,
        () async {
          await action();
          return true;
        },
        (_) => (text: label, bad: false),
      );

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
            ValueListenableBuilder<CrewTrip?>(
              valueListenable: _headerTrip,
              builder: (context, trip, _) => ScreenHeader(
                title: trip == null
                    ? t('driver.theRun')
                    : (trip.leg == 'RETURN' ? t('driver.legReturn') : t('driver.legOut')),
                subtitle: trip?.routeName,
                trailing: (trip != null &&
                        trip.startedAt != null &&
                        trip.endedAt == null)
                    ? _PanicChip(
                        busy: _busy != null,
                        onPressed: () => _panic(trip),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: Loader<_TripData>(
                key: _loaderKey,
                tint: Role.driver.tint,
                load: _load,
                builder: (context, data) {
                  final counts = data.plan.counts;
                  final trip = data.trip;

                  final running =
                      trip != null && trip.startedAt != null && trip.endedAt == null;
                  final started = trip != null && trip.startedAt != null;

                  final aboard = _stillAboard(data.plan);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      if (trip != null) ...[
                        _RunControls(
                          trip: trip,
                          timing: data.plan.timing,
                          busy: _busy,
                          onStart: () => _startShift(trip),
                          onDepart: () => _act(t('driver.departed'), () => CrewApi.instance.depart(trip.id)),
                          onEnd: () => _endRun(trip, counts.stillOnBoard),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (data.plan.timing.hasDepartBy &&
                          data.plan.timing.startedAt == null) ...[
                        _LeaveByCard(
                          timing: data.plan.timing,
                          childrenOnRun: counts.expected,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _HeadcountCard(counts: counts),
                      if (started && aboard.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _RecordAllOffButton(
                          count: aboard.length,
                          leg: trip.leg,
                          busy: _busy != null,
                          onPressed: () => _recordAllOff(data),
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
                      const _LocationNotice(),
                      Card16(
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          child: SizedBox(
                            height: 230,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: RouteMap(
                                    stops: data.plan.stops,
                                    tint: Role.driver.tint,
                                    leg: trip?.leg ?? 'OUT',
                                    terminalStopId: data.terminalStopId,
                                  ),
                                ),
                                if (data.plan.stops
                                    .where((s) => s.departedAt == null)
                                    .isNotEmpty)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: _NextStopPanel(
                                      stop: data.plan.stops
                                          .firstWhere((s) => s.departedAt == null),
                                      leg: trip?.leg ?? 'OUT',
                                      onOpenMap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => RouteMapScreen(
                                            stops: data.plan.stops,
                                            tint: Role.driver.tint,
                                            leg: trip?.leg ?? 'OUT',
                                            terminalStopId: data.terminalStopId,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      RouteMapNote(stops: data.plan.stops),
                      const SizedBox(height: 14),
                      _ChildSearch(
                        controller: _search,
                        onChanged: (v) =>
                            setState(() => _query = v.trim().toLowerCase()),
                      ),
                      if (_query.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Builder(builder: (_) {
                          final hits = data.plan.stops
                              .expand((s) => s.students)
                              .where((r) => _matches(r, _query))
                              .length;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(
                              hits == 0
                                  ? t('driver.searchNone')
                                  : tn('driver.searchHits', '$hits'),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: hits == 0 ? AppTheme.textMuted : Role.driver.tint,
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 6),
                      ...data.plan.stops
                          .where((s) =>
                              _query.isEmpty ||
                              s.students.any((r) => _matches(r, _query)))
                          .map(
                        (s) => _StopCard(
                          query: _query,
                          stop: s,
                          tripId: widget.tripId,
                          leg: trip?.leg ?? 'OUT',
                          terminalStopId: data.terminalStopId,
                          schoolReached: data.plan.terminalArrivedAt != null,
                          running: running,
                          started: started,
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

  final String? terminalStopId;
}

class _LeaveByCard extends StatefulWidget {
  const _LeaveByCard({required this.timing, required this.childrenOnRun});

  final TripTiming timing;

  final int childrenOnRun;

  @override
  State<_LeaveByCard> createState() => _LeaveByCardState();
}

class _LeaveByCardState extends State<_LeaveByCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timing = widget.timing;
    final departBy = timing.departByAt!;
    final secondsLeft = departBy.difference(DateTime.now()).inSeconds;

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
          Text(
            tv('driver.leaveByMath', {
              'drive': (timing.driveSeconds / 60).round(),
              'dwell': (timing.dwellSeconds / 60).round(),
              'n': widget.childrenOnRun,
            }),
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
          ),
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
          Row(
            children: [
              _StatTile(
                icon: Icons.groups_rounded,
                value: '${counts.expected}',
                label: t('driver.students'),
                caption: t('driver.onThisRun'),
                colour: Role.driver.tint,
                wash: Role.driver.wash,
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: Icons.check_circle_outline_rounded,
                value: '${counts.stillOnBoard}',
                label: t('driver.onBoard'),
                caption: t('driver.currently'),
                colour: AppTheme.green,
                wash: AppTheme.greenSoft,
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: Icons.person_add_alt_rounded,
                value: '$outstanding',
                label: t('driver.stillToDrop'),
                caption: t('driver.remaining'),
                colour: outstanding > 0 ? AppTheme.amber : AppTheme.textMuted,
                wash: outstanding > 0 ? AppTheme.amberSoft : AppTheme.neutralSoft,
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: Icons.account_balance_rounded,
                value: '${counts.alighted}',
                label: t('driver.dropped'),
                caption: t('driver.atSchoolShort'),
                colour: AppTheme.blue,
                wash: AppTheme.blueSoft,
              ),
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
    required this.timing,
    required this.busy,
    required this.onStart,
    required this.onDepart,
    required this.onEnd,
  });

  final CrewTrip trip;

  final TripTiming timing;
  final String? busy;
  final VoidCallback onStart;
  final VoidCallback onDepart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final (String label, VoidCallback? action, String? how, int? step) =
        switch (trip.status) {
      'PLANNED' || 'ROSTERED' => (t('driver.startShift'), onStart, t('driver.step.check'), 1),
      'BLOCKED' => (t('driver.startShift'), onStart, t('driver.step.check'), 1),
      'BOARDING' => (t('driver.setOff'), onDepart, t('driver.step.setOff'), 2),
      'IN_PROGRESS' => (t('driver.endRun'), onEnd, t('driver.step.atStops'), 3),
      'ARRIVED' => (t('driver.endRun'), onEnd, t('driver.step.endRun'), 4),
      'SWEEP_PENDING' || 'SWEEP_OVERDUE' =>
        (t('driver.sweepOutstanding'), null, t('driver.step.sweep'), 5),
      'CANCELLED' || 'VOID' || 'ABANDONED' => (t('driver.runCalledOff'), null, null, null),
      _ => (t('driver.runFinished'), null, t('driver.step.done'), 5),
    };

    final statusWord = switch (trip.status) {
      'PLANNED' || 'ROSTERED' => t('driver.statusNotStarted'),
      'BLOCKED' => t('driver.statusStopped'),
      'BOARDING' => t('driver.boarding'),
      'IN_PROGRESS' => t('driver.onRoute'),
      'ARRIVED' => t('driver.atSchool'),
      'SWEEP_PENDING' || 'SWEEP_OVERDUE' => t('driver.sweepDue'),
      'CANCELLED' || 'VOID' || 'ABANDONED' => t('driver.statusCalledOff'),
      _ => t('driver.statusFinished'),
    };

    final school = Session.instance.me?.schoolName ?? '';

    final settled = trip.status == 'COMPLETED';
    final blocked = trip.status == 'BLOCKED';

    final owing = action == null && !settled;
    final accent = settled
        ? AppTheme.textMuted
        : owing
            ? AppTheme.rose
            : Role.driver.tint;
    final wash = settled
        ? AppTheme.neutralSoft
        : owing
            ? AppTheme.roseSoft
            : Role.driver.wash;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.directions_bus_filled_rounded,
                color: Role.driver.tint,
                background: Role.driver.wash,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip.vehicleLabel ?? t('driver.bus')}${trip.plate != null ? ' · ${trip.plate}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    if (school.isNotEmpty)
                      Text(
                        school,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.34,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: wash,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          statusWord,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _TimeFact(
                icon: Icons.schedule_rounded,
                label: trip.startedAt != null
                    ? t('driver.startedAtLabel')
                    : t('driver.dueOutLabel'),
                value: hhmm(trip.startedAt ?? trip.scheduledDepartureAt),
                colour: Role.driver.tint,
              ),
              const SizedBox(width: 18),
              _TimeFact(
                icon: Icons.rocket_launch_outlined,
                label: t('driver.estFinish'),
                value: hhmm(timing.mustArriveBy),
                colour: Role.driver.tint,
              ),
              const Spacer(),
              if (step != null)
                SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        tn('driver.stepOf', step),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: step / 5,
                          minHeight: 6,
                          backgroundColor: AppTheme.neutralSoft,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
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
          if (how != null) ...[
            Text(
              how,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (action == null)
            Row(
              children: [
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
    required this.schoolReached,
    required this.running,
    required this.started,
    required this.onChanged,
    this.query = '',
  });

  final PlannedStop stop;
  final String tripId;
  final String leg;

  final String query;

  final String? terminalStopId;

  final bool schoolReached;

  final bool running;

  final bool started;

  final VoidCallback onChanged;

  @override
  State<_StopCard> createState() => _StopCardState();
}

class _StopCardState extends State<_StopCard> {
  bool _open = false;
  String? _busyStudent;
  bool _busyStop = false;

  RosterFilter _show = RosterFilter.all;

  Timer? _hold;

  int get _holdSeconds => widget.stop.dwellSeconds.clamp(20, 90);

  int get _holdLeft {
    final at = widget.stop.arrivedAt;
    if (at == null || widget.stop.departedAt != null) return 0;
    if (widget.stop.remaining == 0) return 0;
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
  void didUpdateWidget(covariant _StopCard old) {
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

  Future<void> _correct(RiderOnStop rider) async {
    final answer = await showAppSheet<({String type, String reason})>(
      context,
      builder: (_) => _CorrectionSheet(rider: rider, leg: widget.leg),
    );
    if (answer == null) return;

    setState(() => _busyStudent = rider.studentId);
    try {
      final events = await CrewApi.instance.tripCustodyEvents(widget.tripId);
      final theirs = events
          .where((e) => e['studentId'] == rider.studentId && e['correctsEventId'] == null)
          .toList()
        ..sort((a, b) => ((b['effectiveTime'] ?? '') as String)
            .compareTo((a['effectiveTime'] ?? '') as String));
      final original = theirs.firstOrNull;
      if (original == null) {
        if (mounted) showNote(context, t('driver.nothingToCorrect'), bad: true);
        return;
      }

      final verdict = await CrewApi.instance.correctCustody(
        eventId: (original['id'] ?? '') as String,
        correctedType: answer.type,
        correctionReason: answer.reason,
        stopId: custodyStopId(
          leg: widget.leg,
          eventType: answer.type,
          riderStopId: widget.stop.stopId,
          terminalStopId: widget.terminalStopId,
        ),
      );
      widget.onChanged();
      if (!mounted) return;
      if (!verdict.accepted) {
        showNote(context, verdict.reason ?? t('driver.correctionRefused'), bad: true);
        return;
      }
      showNote(context, t('driver.corrected'));
    } catch (e) {
      if (mounted) showNote(context, _driverError(e), bad: true);
    } finally {
      if (mounted) setState(() => _busyStudent = null);
    }
  }

  Future<void> _mark(RiderOnStop rider, String eventType, String label) async {
    setState(() => _busyStudent = rider.studentId);
    try {
      final verdict = await CrewApi.instance.recordCustody(
        tripId: widget.tripId,
        studentId: rider.studentId,
        eventType: eventType,
        stopId: custodyStopId(
          leg: widget.leg,
          eventType: eventType,
          riderStopId: widget.stop.stopId,
          terminalStopId: widget.terminalStopId,
        ),
      );
      widget.onChanged();
      if (!mounted) return;
      final first = rider.name.split(' ').first;
      if (!verdict.accepted) {
        final reason = verdict.reason;
        showNote(
          context,
          reason == null ? tv('driver.notRecorded', {'name': first}) : _driverWords(reason),
          bad: true,
        );
      } else if (verdict.rewrittenTo != null) {
        showNote(context, tv('driver.recordedAs', {'name': first}), bad: true);
      } else {
        showNote(context, '$first — $label');
      }
    } catch (e) {
      if (mounted) showNote(context, _driverError(e), bad: true);
    } finally {
      if (mounted) setState(() => _busyStudent = null);
    }
  }

  Future<void> _stopAction(Future<void> Function() call, String label) async {
    if (_busyStop) return;
    setState(() => _busyStop = true);
    try {
      await call();
      widget.onChanged();
      if (mounted) showNote(context, label);
    } catch (e) {
      if (mounted) showNote(context, _driverError(e), bad: true);
    } finally {
      if (mounted) setState(() => _busyStop = false);
    }
  }

  Future<void> _skipStop() async {
    final reason = await showAppSheet<String>(
      context,
      builder: (_) => const SkipStopSheet(),
    );
    if (reason == null || _busyStop) return;
    setState(() => _busyStop = true);
    try {
      await CrewApi.instance.skipStop(widget.tripId, widget.stop.plannedSequence, reason);
      widget.onChanged();
      if (mounted) showNote(context, t('driver.skipped'));
    } catch (e) {
      if (mounted) showNote(context, _driverError(e), bad: true);
    } finally {
      if (mounted) setState(() => _busyStop = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stop;
    final remaining = s.remaining;
    final canSkip = !s.done && s.arrivedAt == null;
    final holdLeft = _holdLeft;
    final holding = holdLeft > 0;
    final open = _open || widget.query.isNotEmpty;

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
                        color: s.skipped
                            ? AppTheme.amberSoft
                            : s.done
                                ? AppTheme.greenSoft
                                : remaining == 0
                                    ? AppTheme.greenSoft
                                    : Role.driver.wash,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: s.skipped
                          ? Icon(Icons.skip_next_rounded, size: 18, color: AppTheme.amber)
                          : s.done || remaining == 0
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
                            [
                              if (s.landmark != null) s.landmark!,
                              if (s.metresAway != null)
                                tn('driver.metresAway', s.metresAway!),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          if (s.skippedReason != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              s.skippedReason!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppTheme.amber),
                            ),
                          ],
                          if (s.etaAt != null) ...[
                            const SizedBox(height: 3),
                            StopEta(stop: s),
                          ],
                        ],
                      ),
                    ),
                    Tag(
                      s.skipped
                          ? t('driver.skipped')
                          : remaining == 0
                              ? t('driver.done')
                              : tn('driver.nLeft', remaining),
                      color: s.skipped
                          ? AppTheme.amber
                          : remaining == 0
                              ? AppTheme.green
                              : AppTheme.amber,
                      background: s.skipped
                          ? AppTheme.amberSoft
                          : remaining == 0
                              ? AppTheme.greenSoft
                              : AppTheme.amberSoft,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppTheme.textFaint,
                    ),
                  ],
                ),
              ),
            ),
            if (open) ...[
              Divider(height: 1, color: AppTheme.border),
              if (!widget.running &&
                  widget.started &&
                  s.students.any((r) => r.boardedAt != null && r.alightedAt == null))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t('driver.dropAfterEnd'),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (!widget.running)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t('driver.tickAfterSetOff'),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (s.arrivedAt == null)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, canSkip ? 2 : 4),
                  child: BigButton(
                    label: t('driver.arrived'),
                    color: Role.driver.tint,
                    busy: _busyStop,
                    onPressed: widget.running
                        ? () => _stopAction(
                              () => CrewApi.instance
                                  .arriveAtStop(widget.tripId, s.plannedSequence),
                              t('driver.arrived'),
                            )
                        : null,
                  ),
                ),
              if (canSkip)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                  child: SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: TextButton.icon(
                      onPressed: widget.running && !_busyStop ? _skipStop : null,
                      icon: Icon(Icons.skip_next_rounded, size: 18, color: AppTheme.textMuted),
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
                ),
              if (widget.query.isEmpty && s.students.length > 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
                  child: RosterFilters(
                    riders: s.students,
                    value: _show,
                    onChanged: (f) => setState(() => _show = f),
                  ),
                ),
              ...RosterFilters.apply(s.students, widget.query.isEmpty ? _show : RosterFilter.all)
                  .where((r) => _TripScreenState._matches(r, widget.query))
                  .map((r) => _RiderRow(
                    rider: r,
                    leg: widget.leg,
                    schoolReached: widget.schoolReached,
                    busy: _busyStudent == r.studentId,
                    canPickUp: widget.running,
                    canSetDown: widget.started,
                    onBoard: () => _mark(r, 'BOARDED', t('driver.onBoard')),
                    onOff: () => _mark(
                      r,
                      widget.leg == 'OUT' ? 'ALIGHTED' : 'HANDOVER',
                      widget.leg == 'OUT'
                          ? (widget.schoolReached
                              ? t('driver.atSchool')
                              : t('driver.setDownEarly'))
                          : t('driver.handedOver'),
                    ),
                    onNoShow: () => _mark(r, 'NO_SHOW', t('driver.notRiding')),
                    onCorrect: () => _correct(r),
                  )),
              if (!s.done)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BigButton(
                        label: holding
                            ? '${t('driver.movingOn')} · ${holdLeft ~/ 60}:${(holdLeft % 60).toString().padLeft(2, '0')}'
                            : t('driver.movingOn'),
                        color: AppTheme.blue,
                        busy: _busyStop,
                        onPressed: widget.running && !holding
                            ? () => _stopAction(
                                  () => CrewApi.instance
                                      .leaveStop(widget.tripId, s.plannedSequence),
                                  t('driver.movingOn'),
                                )
                            : null,
                      ),
                      if (holding) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.timer_outlined, size: 16, color: AppTheme.textMuted),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                t('driver.holdAtStop'),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

class SkipStopSheet extends StatefulWidget {
  const SkipStopSheet({super.key});

  @override
  State<SkipStopSheet> createState() => _SkipStopSheetState();
}

class _SkipStopSheetState extends State<SkipStopSheet> {
  final TextEditingController _reason = TextEditingController();
  String _text = '';

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _text.trim();
    final valid = trimmed.length >= 3;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
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
              t('driver.skipStopTitle'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.text),
            ),
            const SizedBox(height: 4),
            Text(
              t('driver.skipStopWhy'),
              style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              autofocus: true,
              maxLines: 2,
              maxLength: 300,
              style: const TextStyle(fontSize: 13.5),
              onChanged: (v) => setState(() => _text = v),
              decoration: InputDecoration(
                labelText: t('driver.skipReasonLabel'),
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
            ),
            if (_text.isNotEmpty && !valid) ...[
              const SizedBox(height: 6),
              Text(
                t('driver.skipReasonTooShort'),
                style: TextStyle(fontSize: 11.5, color: AppTheme.rose),
              ),
            ],
            const SizedBox(height: 14),
            BigButton(
              label: t('driver.skipConfirm'),
              color: AppTheme.rose,
              height: 54,
              onPressed: valid ? () => Navigator.of(context).pop(trimmed) : null,
            ),
          ],
        ),
      ),
    );
  }
}

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

String stopEtaText(PlannedStop stop) => stop.etaAt == null
    ? '—'
    : stop.etaIsActual
        ? tn('driver.arrivedAt', hhmm(stop.etaAt))
        : tn('driver.etaShort', hhmm(stop.etaAt));

String stopEtaLine(PlannedStop stop) => stop.etaAt == null
    ? '—'
    : stop.etaIsActual
        ? tn('driver.arrivedAt', hhmm(stop.etaAt))
        : tn('driver.etaDue', hhmm(stop.etaAt));

class _RiderRow extends StatelessWidget {
  const _RiderRow({
    required this.rider,
    required this.leg,
    required this.schoolReached,
    required this.busy,
    required this.canPickUp,
    required this.canSetDown,
    required this.onBoard,
    required this.onOff,
    required this.onNoShow,
    required this.onCorrect,
  });

  final RiderOnStop rider;
  final String leg;

  final bool schoolReached;
  final bool busy;

  final bool canPickUp;
  final bool canSetDown;
  final VoidCallback onBoard;
  final VoidCallback onOff;
  final VoidCallback onNoShow;

  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    final onBus = rider.boardedAt != null && rider.alightedAt == null;
    final off = rider.alightedAt != null;

    final notRiding = !off && !onBus && rider.notTravelling;

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
                      : notRiding
                          ? AppTheme.roseSoft
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
                    '${leg == 'OUT' ? (schoolReached ? t('driver.atSchool') : t('driver.setDownEarly')) : t('driver.handedOver')} ${hhmm(rider.alightedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: leg == 'OUT' && !schoolReached ? AppTheme.amber : AppTheme.green,
                    ),
                  )
                else if (onBus)
                  Text(
                    tn('driver.onBoardSince', hhmm(rider.boardedAt)),
                    style: TextStyle(fontSize: 11, color: AppTheme.blue),
                  )
                else if (notRiding)
                  Text(
                    t('driver.notRiding'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.rose,
                    ),
                  ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else if (off)
            WordButton(
              icon: Icons.edit_note_rounded,
              label: t('driver.wrong'),
              colour: AppTheme.textMuted,
              onTap: onCorrect,
            )
          else
            Row(
              children: [
                WordButton(
                  icon: onBus ? Icons.logout_rounded : Icons.login_rounded,
                  label: onBus
                      ? (leg == 'OUT' ? t('driver.setDown') : t('driver.handOver'))
                      : t('driver.pickUp'),
                  colour: onBus ? AppTheme.green : Role.driver.tint,
                  onTap: onBus
                      ? (canSetDown ? onOff : null)
                      : (canPickUp ? onBoard : null),
                ),
                if (!notRiding && !onBus) ...[
                  const SizedBox(width: 6),
                  WordButton(
                    icon: Icons.close_rounded,
                    label: t('driver.notHere'),
                    colour: AppTheme.rose,
                    onTap: canPickUp ? onNoShow : null,
                  ),
                ],
                if (onBus || notRiding) ...[
                  const SizedBox(width: 6),
                  WordButton(
                    icon: Icons.edit_note_rounded,
                    label: t('driver.wrong'),
                    colour: AppTheme.textMuted,
                    onTap: onCorrect,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SweepCard extends StatefulWidget {
  const _SweepCard({
    required this.sweep,
    required this.busy,
    required this.onConfirm,
    required this.tripEnded,
    required this.onChildFound,
    required this.stillOwed,
  });

  final bool stillOwed;

  final VoidCallback onChildFound;

  final SweepState sweep;
  final bool busy;
  final VoidCallback onConfirm;

  final bool tripEnded;

  @override
  State<_SweepCard> createState() => _SweepCardState();
}

class _SweepCardState extends State<_SweepCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _startTicking();
  }

  @override
  void didUpdateWidget(covariant _SweepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sweep.confirmableFrom != widget.sweep.confirmableFrom) {
      _startTicking();
    }
  }

  void _startTicking() {
    _tick?.cancel();
    _tick = null;
    if (widget.sweep.confirmable) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (widget.sweep.confirmable) {
        timer.cancel();
        _tick = null;
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sweep = widget.sweep;
    final stillOwed = widget.stillOwed;
    final busy = widget.busy;

    if (!sweep.required_) {
      return Panel(
        child: Text(
          t('driver.sweepNotRequired'),
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
      );
    }

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

    if (!widget.tripEnded) {
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

    final seconds = sweep.secondsRemaining;
    final late = seconds != null && seconds <= 0;

    final waitSeconds = sweep.secondsUntilConfirmable;
    final waiting = waitSeconds > 0;

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
            '${t('driver.sweepHow')}${t('driver.sweepWhy')}',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
          ),
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
          if (waiting) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hourglass_bottom_rounded, size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tn('driver.sweepWaitCountdown', waitSeconds),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('driver.sweepWaitWhy'),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (late && sweep.attemptsSoFar > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment_turned_in_rounded, size: 19, color: AppTheme.rose),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sweep.confirmedAt != null
                          ? tn('driver.sweepFiledAt', hhmm(sweep.confirmedAt))
                          : t('driver.sweepFiled'),
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
            )
          else
            BigButton(
              label: t('driver.walkedTheBus'),
              color: late ? AppTheme.rose : AppTheme.amber,
              busy: busy,
              height: 54,
              onPressed: waiting ? null : widget.onConfirm,
            ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: busy ? null : widget.onChildFound,
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

class _LocationNotice extends StatelessWidget {
  const _LocationNotice();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BusLocationState>(
      valueListenable: BusLocation.instance.state,
      builder: (context, state, _) {
        if (state != BusLocationState.denied &&
            state != BusLocationState.blocked &&
            state != BusLocationState.coarse) {
          return const SizedBox.shrink();
        }
        final coarse = state == BusLocationState.coarse;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            color: AppTheme.amberSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  coarse ? Icons.gps_not_fixed_rounded : Icons.location_off_rounded,
                  size: 18,
                  color: AppTheme.amber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coarse
                            ? t('driver.locationCoarseTitle')
                            : t('driver.locationOffTitle'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        coarse
                            ? t('driver.locationCoarseWhy')
                            : t('driver.locationOffWhy'),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => state == BusLocationState.blocked
                            ? Geolocator.openLocationSettings()
                            : Geolocator.openAppSettings(),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            coarse
                                ? t('driver.locationCoarseFix')
                                : t('driver.locationOffFix'),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Role.driver.tint,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NextStopPanel extends StatelessWidget {
  const _NextStopPanel({
    required this.stop,
    required this.leg,
    required this.onOpenMap,
  });

  final PlannedStop stop;
  final String leg;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.44,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('driver.nextStop'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: tint,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${stop.plannedSequence}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: tint,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (stop.landmark != null && stop.landmark!.isNotEmpty)
                        Text(
                          stop.landmark!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (stop.remaining > 0) ...[
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.amberSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  leg == 'RETURN'
                      ? tn('driver.nToDropOff', stop.remaining)
                      : tn('driver.nToPickUp', stop.remaining),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.amber,
                  ),
                ),
              ),
            ],
            if (stop.metresAway != null) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(Icons.navigation_rounded, size: 13, color: tint),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      stop.metresAway! >= 1000
                          ? tn('driver.kmAway', (stop.metresAway! / 100).round() / 10)
                          : tn('driver.metresAway', stop.metresAway!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onOpenMap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.list_alt_rounded, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        t('driver.viewFullRoute'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
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
    );
  }
}

class _TimeFact extends StatelessWidget {
  const _TimeFact({
    required this.icon,
    required this.label,
    required this.value,
    required this.colour,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colour),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
            ),
            Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.caption,
    required this.value,
    required this.colour,
    required this.wash,
  });

  final IconData icon;
  final String label;

  final String caption;
  final String value;
  final Color colour;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 10, 9, 10),
        decoration: BoxDecoration(
          color: wash,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: colour),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: colour,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: AppTheme.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

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

class _PreTripSheet extends StatefulWidget {
  const _PreTripSheet();

  @override
  State<_PreTripSheet> createState() => _PreTripSheetState();
}

class _PreTripSheetState extends State<_PreTripSheet> {
  final String _clientUuid = uuidV4();

  final DateTime _openedAt = DateTime.now();

  final Map<String, String> _answers = {};
  final TextEditingController _odometer = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  bool _unsafe = false;

  bool _tried = false;

  final Map<String, GlobalKey> _itemKeys = {
    for (final item in _preTripItems) item.$1: GlobalKey(),
  };

  List<(String, String)> get _missing =>
      _preTripItems.where((i) => !_answers.containsKey(i.$1)).toList();

  String? _selfieAssetId;

  Uint8List? _shot;

  String _mime = 'image/jpeg';

  DateTime? _takenAt;

  bool _sending = false;

  String? _sendFailed;

  @override
  void dispose() {
    _odometer.dispose();
    _notes.dispose();
    super.dispose();
  }

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
      _selfieAssetId = null;
      _sendFailed = null;
    });
    await _sendSelfie();
  }

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

  String get _outcome {
    if (_unsafe) return kInspectionFail;
    if (_answers.values.contains(_answerNotChecked)) return kInspectionNotCompleted;
    if (_answers.values.contains(_answerDefect)) return kInspectionPassWithDefects;
    return kInspectionPass;
  }

  void _file() {
    if (_sending) {
      showNote(context, t('driver.pretrip.selfieSending'), bad: true);
      return;
    }
    final selfie = _selfieAssetId;
    if (selfie == null) {
      showNote(context, t('driver.pretrip.selfieRequired'), bad: true);
      return;
    }
    final missing = _missing;
    if (missing.isNotEmpty) {
      setState(() => _tried = true);
      final ctx = _itemKeys[missing.first.$1]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          alignment: 0.15,
        );
      }
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
                        key: _itemKeys[item.$1],
                        label: t(item.$2),
                        answer: _answers[item.$1],
                        flagged: _tried && !_answers.containsKey(item.$1),
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
                    if (_tried && _missing.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.rose),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              '${tn('driver.pretrip.stillToAnswer', '${_missing.length}')} '
                              '${_missing.map((i) => t(i.$2)).join(' · ')}',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
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

class _ChildSearch extends StatelessWidget {
  const _ChildSearch({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: t('driver.searchChild'),
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textFaint,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) => value.text.isEmpty
                ? const SizedBox(width: 4)
                : GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                      FocusScope.of(context).unfocus();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                      child: Icon(Icons.close_rounded, size: 19, color: AppTheme.textMuted),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PreTripRow extends StatelessWidget {
  const _PreTripRow({
    super.key,
    required this.label,
    required this.answer,
    required this.flagged,
    required this.onAnswer,
  });

  final String label;
  final String? answer;

  final bool flagged;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        color: flagged ? AppTheme.roseSoft : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (flagged) ...[
                  Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.rose),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: flagged ? AppTheme.rose : AppTheme.text,
                    ),
                  ),
                ),
              ],
            ),
            if (flagged) ...[
              const SizedBox(height: 3),
              Text(
                t('driver.pretrip.notAnswered'),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.rose),
              ),
            ],
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

String _imageMime(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

String _imageExtension(String mime) => switch (mime) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      'image/heif' => 'heif',
      _ => 'jpg',
    };

class _SelfieStep extends StatelessWidget {
  const _SelfieStep({
    required this.shot,
    required this.held,
    required this.sending,
    required this.failed,
    required this.onTake,
    required this.onSendAgain,
  });

  final Uint8List? shot;

  final bool held;

  final bool sending;

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
            filled: shot == null,
            onTap: sending ? null : onTake,
          ),
        ],
      ),
    );
  }
}

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

class _PanicChip extends StatelessWidget {
  const _PanicChip({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.roseSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.rose.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emergency_share_rounded, size: 17, color: AppTheme.rose),
            const SizedBox(width: 7),
            Text(
              t('driver.sos'),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.rose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordAllOffButton extends StatelessWidget {
  const _RecordAllOffButton({
    required this.count,
    required this.leg,
    required this.busy,
    required this.onPressed,
  });

  final int count;
  final String leg;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: busy ? null : onPressed,
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: Text(
            tn(
              leg == 'OUT' ? 'driver.recordAllOffOut' : 'driver.recordAllOffReturn',
              count,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: AppTheme.green,
            disabledBackgroundColor: AppTheme.green.withValues(alpha: 0.5),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

class _RecordAllOffSheet extends StatefulWidget {
  const _RecordAllOffSheet({required this.aboard, required this.leg});

  final List<_Aboard> aboard;
  final String leg;

  @override
  State<_RecordAllOffSheet> createState() => _RecordAllOffSheetState();
}

class _RecordAllOffSheetState extends State<_RecordAllOffSheet> {
  late final Set<String> _ticked = {
    for (final a in widget.aboard) a.rider.studentId,
  };

  @override
  Widget build(BuildContext context) {
    final picked = [
      for (final a in widget.aboard)
        if (_ticked.contains(a.rider.studentId)) a,
    ];

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
            widget.leg == 'OUT'
                ? t('driver.recordAllOffTitleOut')
                : t('driver.recordAllOffTitleReturn'),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.text),
          ),
          const SizedBox(height: 4),
          Text(
            t('driver.recordAllOffHow'),
            style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.aboard.length,
              itemBuilder: (context, i) {
                final a = widget.aboard[i];
                final on = _ticked.contains(a.rider.studentId);
                return CheckboxListTile(
                  value: on,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  activeColor: AppTheme.green,
                  title: Text(
                    a.rider.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                  ),
                  subtitle: Text(
                    [
                      a.stopName,
                      if (a.rider.boardedAt != null)
                        tn('driver.onBoardSince', hhmm(a.rider.boardedAt)),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _ticked.add(a.rider.studentId);
                    } else {
                      _ticked.remove(a.rider.studentId);
                    }
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          BigButton(
            label: picked.isEmpty
                ? t('driver.recordNobody')
                : tn('driver.recordTickedOff', picked.length),
            color: AppTheme.green,
            height: 54,
            onPressed: picked.isEmpty ? null : () => Navigator.of(context).pop(picked),
          ),
        ],
      ),
    );
  }
}

class _EndWithChildrenSheet extends StatelessWidget {
  const _EndWithChildrenSheet({required this.count});

  final int count;

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
            tn('driver.stillAboardWarning', count),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.rose),
          ),
          const SizedBox(height: 6),
          Text(
            t('driver.stillAboardHow'),
            style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          BigButton(
            label: t('driver.goBackAndDrop'),
            color: Role.driver.tint,
            height: 54,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: 10),
          BigButton(
            label: t('driver.endAnyway'),
            color: AppTheme.rose,
            height: 54,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

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

class _CorrectionSheet extends StatefulWidget {
  const _CorrectionSheet({required this.rider, required this.leg});

  final RiderOnStop rider;
  final String leg;

  @override
  State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  String? _type;
  final _reason = TextEditingController();

  static const _minReason = 5;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final ready = _type != null && _reason.text.trim().length >= _minReason;

    final options = <(String, String, IconData)>[
      ('NO_SHOW', t('driver.correctNotThere'), Icons.close_rounded),
      ('BOARDED', t('driver.correctDidBoard'), Icons.login_rounded),
      (
        widget.leg == 'OUT' ? 'ALIGHTED' : 'HANDOVER',
        widget.leg == 'OUT' ? t('driver.correctDidGetOff') : t('driver.correctWasHandedOver'),
        Icons.logout_rounded,
      ),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t('driver.correctTitle'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tv('driver.correctFor', {'name': widget.rider.name}),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),

              Text(
                t('driver.correctWhatHappened'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 9),
              for (final o in options)
                InkWell(
                  onTap: () => setState(() => _type = o.$1),
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                    decoration: BoxDecoration(
                      color: _type == o.$1 ? tint.withValues(alpha: 0.10) : AppTheme.canvas,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: _type == o.$1 ? tint : AppTheme.border,
                        width: _type == o.$1 ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(o.$3, size: 19, color: _type == o.$1 ? tint : AppTheme.textMuted),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            o.$2,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _type == o.$1 ? FontWeight.w700 : FontWeight.w500,
                              color: _type == o.$1 ? tint : AppTheme.text,
                            ),
                          ),
                        ),
                        if (_type == o.$1)
                          Icon(Icons.check_circle_rounded, size: 19, color: tint),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),
              Text(
                t('driver.correctWhy'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                maxLines: 2,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: t('driver.correctWhyHint'),
                  counterText: '',
                  filled: true,
                  fillColor: AppTheme.canvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.history_edu_rounded, size: 16, color: AppTheme.textFaint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t('driver.correctBothKept'),
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textFaint),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: ready
                      ? () => Navigator.of(context)
                          .pop((type: _type!, reason: _reason.text.trim()))
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: tint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                    t('driver.correctSend'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
