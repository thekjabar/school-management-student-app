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
import 'run_driving.dart';
import 'run_order.dart';
import 'stop_announcer.dart';
import 'stop_presence.dart';

const List<(String, String)> _serverSays = [
  ('not been started', 'driver.mustSetOff'),
  ('is not running', 'driver.mustSetOff'),
  ('pre-trip check', 'driver.mustCheckBus'),
  ('check everyone at school first', 'driver.gate.checkFirst'),
  ('mark everyone off at school first', 'driver.gate.dropFirst'),
  ('get closer to the stop first', 'driver.presence.farServer'),
  ('get closer to the school gate first', 'driver.presence.farSchoolServer'),
  ('bus position is not known yet', 'driver.presence.noFixServer'),
  ('arrive at the stop first', 'driver.notHere.arriveFirst'),
  ('wait at the stop a little longer', 'driver.notHere.waitServer'),
  ('pick up every child at this stop', 'driver.flow.resolveFirst'),
];

String _driverWords(String message) {
  final lower = message.toLowerCase();
  for (final (fragment, key) in _serverSays) {
    if (lower.contains(fragment)) return t(key);
  }
  return message;
}

String _driverError(Object? e) => _driverWords(errorText(e));

class _RiderAt {
  const _RiderAt({required this.rider, required this.stopId, required this.stopName});

  final RiderOnStop rider;
  final String stopId;
  final String stopName;
}

List<_RiderAt> _stillAboard(TripPlan plan) => [
      for (final stop in plan.stops)
        for (final rider in stop.students)
          if (rider.boardedAt != null && rider.alightedAt == null)
            _RiderAt(rider: rider, stopId: stop.stopId, stopName: stop.name),
    ];

List<_RiderAt> _uncheckedAtSchool(TripPlan plan) => [
      for (final stop in plan.stops)
        for (final rider in stop.students)
          if (!rider.accountedFor)
            _RiderAt(rider: rider, stopId: stop.stopId, stopName: stop.name),
    ];

Future<void> _markRider(
  BuildContext context, {
  required String tripId,
  required String leg,
  required RiderOnStop rider,
  required String riderStopId,
  required String? terminalStopId,
  required String eventType,
  required String label,
  required VoidCallback onChanged,
}) async {
  try {
    final fix = reportedFix(BusLocation.instance.here.value);
    final verdict = await CrewApi.instance.recordCustody(
      tripId: tripId,
      studentId: rider.studentId,
      eventType: eventType,
      stopId: custodyStopId(
        leg: leg,
        eventType: eventType,
        riderStopId: riderStopId,
        terminalStopId: terminalStopId,
      ),
      lat: fix?.lat,
      lon: fix?.lon,
      gpsAccuracyM: fix?.accuracyM,
      positionAgeMs: fix?.ageMs,
    );
    onChanged();
    if (!context.mounted) return;
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
    if (context.mounted) showNote(context, _driverError(e), bad: true);
  }
}

Future<void> _correctRider(
  BuildContext context, {
  required String tripId,
  required String leg,
  required RiderOnStop rider,
  required String riderStopId,
  required String? terminalStopId,
  required VoidCallback onBusy,
  required VoidCallback onChanged,
}) async {
  final answer = await showAppSheet<({String type, String reason})>(
    context,
    builder: (_) => _CorrectionSheet(rider: rider, leg: leg),
  );
  if (answer == null || !context.mounted) return;

  onBusy();
  try {
    final events = await CrewApi.instance.tripCustodyEvents(tripId);
    final theirs = events
        .where((e) => e['studentId'] == rider.studentId && e['correctsEventId'] == null)
        .toList()
      ..sort((a, b) => ((b['effectiveTime'] ?? '') as String)
          .compareTo((a['effectiveTime'] ?? '') as String));
    final original = theirs.firstOrNull;
    if (original == null) {
      if (context.mounted) showNote(context, t('driver.nothingToCorrect'), bad: true);
      return;
    }

    final verdict = await CrewApi.instance.correctCustody(
      eventId: (original['id'] ?? '') as String,
      correctedType: answer.type,
      correctionReason: answer.reason,
      stopId: custodyStopId(
        leg: leg,
        eventType: answer.type,
        riderStopId: riderStopId,
        terminalStopId: terminalStopId,
      ),
    );
    onChanged();
    if (!context.mounted) return;
    if (!verdict.accepted) {
      showNote(context, verdict.reason ?? t('driver.correctionRefused'), bad: true);
      return;
    }
    showNote(context, t('driver.corrected'));
  } catch (e) {
    if (context.mounted) showNote(context, _driverError(e), bad: true);
  }
}

class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.tripId, this.serviceDate});

  final String tripId;

  final DateTime? serviceDate;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final _loaderKey = GlobalKey<LoaderState<_TripData>>();
  String? _busy;

  String? _busyStudent;

  DateTime? _schoolArrivedAt;

  bool _orderedWithoutBus = false;

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

  final ValueNotifier<CrewTrip?> _headerTrip = ValueNotifier<CrewTrip?>(null);

  late final RunDriving _driving = RunDriving(
    stopPanel: (context, run, stop) {
      final data = _data;
      if (data == null) return const SizedBox.shrink();
      return _stopCard(data, stop, onMap: true);
    },
    schoolPanel: (context, run) {
      final data = _data;
      if (data == null) return null;
      return data.trip?.leg == 'RETURN' ? _boardingCard(data) : _arrivalCard(data);
    },
    runBar: (context, run) {
      final data = _data;
      final trip = data?.trip;
      if (data == null || trip == null) return null;
      return _runBar(data, trip);
    },
    sos: (context, run) {
      final trip = _data?.trip;
      if (trip == null || trip.startedAt == null || trip.endedAt != null) return null;
      return _PanicChip(busy: _busy != null, onPressed: () => _panic(trip));
    },
  );

  _TripData? _data;

  @override
  void initState() {
    super.initState();
    BusLocation.instance.here.addListener(_onFirstFix);
  }

  @override
  void dispose() {
    BusLocation.instance.here.removeListener(_onFirstFix);
    StopAnnouncer.instance.release(widget.tripId);
    _driving.dispose();
    _headerTrip.dispose();
    _search.dispose();
    super.dispose();
  }

  void _publish(_TripData data) {
    _data = data;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_data, data)) return;
      final trip = data.trip;
      final leg = trip?.leg ?? 'OUT';
      _driving.publish(RunSnapshot(
        trip: trip,
        leg: leg,
        stops: data.run.stops,
        planStops: data.plan.stops,
        school: data.school,
      ));
      if (trip != null) {
        StopAnnouncer.instance.track(
          tripId: trip.id,
          leg: leg,
          stops: data.run.stops,
          school: data.school,
          running: trip.startedAt != null && trip.endedAt == null,
        );
      }
    });
  }

  Widget _stopCard(_TripData data, PlannedStop s, {bool onMap = false}) {
    final trip = data.trip;
    final stops = data.run.stops;
    final numbers = runNumbers(stops, data.school?.stopId);
    final i = stops.indexWhere((x) => identical(x, s));
    final running = trip != null && trip.startedAt != null && trip.endedAt == null;
    final started = trip != null && trip.startedAt != null;
    final leg = trip?.leg ?? 'OUT';
    final homeLocked = schoolCheckOpen(leg, data.plan.stops) && running;
    return StopCard(
      key: ValueKey('${onMap ? 'map-' : ''}stop-${s.stopId}-${s.students.firstOrNull?.studentId ?? ''}'),
      current: onMap || identical(s, data.run.next),
      number: i < 0 ? null : numbers[i],
      query: onMap ? '' : _query,
      stop: s,
      tripId: widget.tripId,
      leg: leg,
      terminalStopId: data.terminalStopId,
      schoolReached: data.plan.terminalArrivedAt != null,
      running: running,
      started: started,
      locked: homeLocked && !isSchoolStop(s, data.school?.stopId),
      onChanged: () => _loaderKey.currentState?.reload(),
    );
  }

  String _schoolName(_TripData data) =>
      data.school?.name ?? Session.instance.me?.schoolName ?? t('driver.school');

  Widget _boardingCard(_TripData data, {String query = ''}) {
    final trip = data.trip;
    final schoolCheckLive = canCheckAtSchool(trip);
    return BoardingCheckCard(
      stops: data.plan.stops,
      schoolName: _schoolName(data),
      canCheck: schoolCheckLive,
      lockedNoteKey: schoolCheckLive
          ? null
          : (const {'PLANNED', 'ROSTERED', 'BLOCKED'}.contains(trip?.status)
              ? 'driver.mustCheckBus'
              : 'driver.tickAfterSetOff'),
      query: query,
      busyStudent: _busyStudent,
      busyAll: _busy != null,
      onBoard: (r, s) => _markAtSchool(data, r, s, 'BOARDED', t('driver.onBoard')),
      onNotHere: (r, s) => _markAtSchool(data, r, s, 'NO_SHOW', t('driver.notRiding')),
      onCorrect: (r, s) => _correctAtSchool(data, r, s),
      onAllOnBus: () => _allOnBus(data),
    );
  }

  Widget _arrivalCard(_TripData data, {String query = ''}) {
    final trip = data.trip;
    final running = trip != null && trip.startedAt != null && trip.endedAt == null;
    final started = trip != null && trip.startedAt != null;
    final schoolArrivedAt = data.plan.terminalArrivedAt ?? _schoolArrivedAt ?? data.school?.arrivedAt;
    return SchoolArrivalCard(
      stops: data.plan.stops,
      schoolName: _schoolName(data),
      running: running,
      started: started,
      canArrive: data.school?.sequence != null,
      arrivedAt: schoolArrivedAt,
      gate: data.school,
      query: query,
      busyStudent: _busyStudent,
      busyAll: _busy != null,
      onArrive: () => _arriveAtSchool(data.school!.sequence!),
      onDrop: (r, s) => _markAtSchool(
        data,
        r,
        s,
        'ALIGHTED',
        schoolArrivedAt != null ? t('driver.atSchool') : t('driver.setDownEarly'),
      ),
      onAllOff: () => _recordAllOff(data),
    );
  }

  ({String? end, String? depart}) _runLocks(_TripData data) {
    final trip = data.trip;
    final leg = trip?.leg ?? 'OUT';
    final running = trip != null && trip.startedAt != null && trip.endedAt == null;
    final started = trip != null && trip.startedAt != null;
    return (
      end: running && mustDropAtSchool(leg, data.plan.stops) ? t('driver.gate.dropFirst') : null,
      depart: mustCheckBeforeSetOff(leg, started, data.plan.stops) ? t('driver.gate.checkFirst') : null,
    );
  }

  Widget _runBar(_TripData data, CrewTrip trip) {
    final locks = _runLocks(data);
    return RunActionBar(
      trip: trip,
      busy: _busy,
      onStart: () => _startShift(trip),
      onDepart: () => _act(t('driver.departed'), () => CrewApi.instance.depart(trip.id)),
      onEnd: () => _endRun(trip, data.plan.counts.stillOnBoard),
      endBlocked: locks.end,
      departBlocked: locks.depart,
    );
  }

  void _onFirstFix() {
    if (!_orderedWithoutBus || BusLocation.instance.here.value == null) return;
    _orderedWithoutBus = false;
    _loaderKey.currentState?.reload();
  }

  Future<_TripData> _load() async {
    final api = CrewApi.instance;
    final results = await Future.wait([
      _dutyList(),
      api.plan(widget.tripId),
      api.sweepState(widget.tripId),
      RunOrder.school(widget.tripId),
    ]);
    final trips = results[0] as List<CrewTrip>;
    _headerTrip.value = trips.where((t) => t.id == widget.tripId).firstOrNull;
    final plan = results[1] as TripPlan;
    final school = results[3] as SchoolGate?;
    final run = await RunOrder.resolve(
      tripId: widget.tripId,
      leg: _headerTrip.value?.leg ?? 'OUT',
      stops: plan.stops,
      school: school,
    );
    _orderedWithoutBus = orderWaitsForBus(run.basis);

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
      plan: plan,
      run: run,
      sweep: results[2] as SweepState,
      school: school,
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

    final picked = await showAppSheet<List<_RiderAt>>(
      context,
      builder: (_) => _RecordAllOffSheet(
        aboard: aboard,
        title: leg == 'OUT'
            ? t('driver.recordAllOffTitleOut')
            : t('driver.recordAllOffTitleReturn'),
        how: t('driver.recordAllOffHow'),
        confirmKey: 'driver.recordTickedOff',
      ),
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

  Future<void> _allOnBus(_TripData data) async {
    final unchecked = _uncheckedAtSchool(data.plan);
    if (unchecked.isEmpty) return;

    final picked = await showAppSheet<List<_RiderAt>>(
      context,
      builder: (_) => _RecordAllOffSheet(
        aboard: unchecked,
        title: t('driver.gate.whoOnBus'),
        how: t('driver.gate.whoOnBusHow'),
        confirmKey: 'driver.gate.recordOnBus',
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() => _busy = t('driver.gate.recordingOnBus'));
    try {
      final outcomes = await CrewApi.instance.recordCustodyBatch(
        tripId: widget.tripId,
        manualReason: kCrewAllOnBusReason,
        entries: [
          for (final a in picked)
            CustodyEntry(
              studentId: a.rider.studentId,
              eventType: 'BOARDED',
              stopId: custodyStopId(
                leg: 'RETURN',
                eventType: 'BOARDED',
                riderStopId: a.stopId,
                terminalStopId: data.terminalStopId,
              ),
            ),
        ],
      );
      _loaderKey.currentState?.reload();
      if (!mounted) return;
      final said = _boardingNote(outcomes);
      showNote(context, said.text, bad: said.bad);
    } catch (e) {
      if (mounted) showNote(context, _driverError(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  ({String text, bool bad}) _boardingNote(List<CustodyOutcome> outcomes) {
    final refused = outcomes.where((o) => !o.verdict.accepted).toList();
    final ok = outcomes.length - refused.length;
    if (refused.isEmpty) return (text: tn('driver.gate.onBusRecorded', ok), bad: false);
    final why = refused.map((o) => o.verdict.reason).whereType<String>().firstOrNull;
    return (
      text: why == null
          ? tv('driver.gate.someOnRefused', {'ok': ok, 'bad': refused.length})
          : tv('driver.gate.someOnRefusedWhy', {
              'ok': ok,
              'bad': refused.length,
              'why': _driverWords(why),
            }),
      bad: true,
    );
  }

  Future<void> _markAtSchool(
    _TripData data,
    RiderOnStop rider,
    PlannedStop stop,
    String eventType,
    String label,
  ) async {
    if (_busyStudent != null) return;
    setState(() => _busyStudent = rider.studentId);
    try {
      await _markRider(
        context,
        tripId: widget.tripId,
        leg: data.trip?.leg ?? 'OUT',
        rider: rider,
        riderStopId: stop.stopId,
        terminalStopId: data.terminalStopId,
        eventType: eventType,
        label: label,
        onChanged: () => _loaderKey.currentState?.reload(),
      );
    } finally {
      if (mounted) setState(() => _busyStudent = null);
    }
  }

  Future<void> _correctAtSchool(_TripData data, RiderOnStop rider, PlannedStop stop) async {
    if (_busyStudent != null) return;
    try {
      await _correctRider(
        context,
        tripId: widget.tripId,
        leg: data.trip?.leg ?? 'OUT',
        rider: rider,
        riderStopId: stop.stopId,
        terminalStopId: data.terminalStopId,
        onBusy: () => setState(() => _busyStudent = rider.studentId),
        onChanged: () => _loaderKey.currentState?.reload(),
      );
    } finally {
      if (mounted) setState(() => _busyStudent = null);
    }
  }

  Future<void> _arriveAtSchool(int sequence) => _act(t('driver.arrived'), () async {
        await CrewApi.instance.arriveAtStop(
          widget.tripId,
          sequence,
          fix: reportedFix(BusLocation.instance.here.value),
        );
        _schoolArrivedAt ??= DateTime.now();
      });

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
                action: (trip != null &&
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
                  _publish(data);
                  final counts = data.plan.counts;
                  final trip = data.trip;

                  final running =
                      trip != null && trip.startedAt != null && trip.endedAt == null;
                  final started = trip != null && trip.startedAt != null;

                  final aboard = _stillAboard(data.plan);

                  final leg = trip?.leg ?? 'OUT';
                  final checkOpen = schoolCheckOpen(leg, data.plan.stops);
                  final homeLocked = checkOpen && running;
                  final locks = _runLocks(data);
                  final hasRiders = data.plan.stops.any((s) => s.students.isNotEmpty);

                  final stops = data.run.stops;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      if (running) ...[
                        const VoiceBanner(),
                        const SizedBox(height: 12),
                      ],
                      if (trip != null) ...[
                        _RunControls(
                          trip: trip,
                          timing: data.plan.timing,
                          busy: _busy,
                          onStart: () => _startShift(trip),
                          onDepart: () => _act(t('driver.departed'), () => CrewApi.instance.depart(trip.id)),
                          onEnd: () => _endRun(trip, counts.stillOnBoard),
                          endBlocked: locks.end,
                          departBlocked: locks.depart,
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
                      if (leg == 'RETURN' && started && aboard.isNotEmpty && !homeLocked) ...[
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
                        nearestFirst: RunOrder.nearest.value,
                        note: data.run.note(trip?.leg ?? 'OUT'),
                        onChanged: (v) async {
                          await RunOrder.choose(v);
                          if (!mounted) return;
                          setState(() {});
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
                            child: RouteMap(
                              tripId: widget.tripId,
                              stops: stops,
                              tint: Role.driver.tint,
                              leg: trip?.leg ?? 'OUT',
                              school: data.school,
                              live: running,
                              driving: _driving,
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
                      if (leg == 'RETURN' && hasRiders) _boardingCard(data, query: _query),
                      for (final s in stops)
                        if (_query.isEmpty || s.students.any((r) => _matches(r, _query)))
                          _stopCard(data, s),
                      if (leg == 'OUT' && hasRiders) _arrivalCard(data, query: _query),
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
    required this.run,
    required this.sweep,
    required this.school,
  });

  final CrewTrip? trip;
  final TripPlan plan;

  final RunArrangement run;
  final SweepState sweep;

  final SchoolGate? school;

  String? get terminalStopId => school?.stopId;
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

({String label, VoidCallback? action, String? how, int? step}) runStepFor(
  String status, {
  required VoidCallback onStart,
  required VoidCallback onDepart,
  required VoidCallback onEnd,
}) =>
    switch (status) {
      'PLANNED' || 'ROSTERED' => (label: t('driver.startShift'), action: onStart, how: t('driver.step.check'), step: 1),
      'BLOCKED' => (label: t('driver.startShift'), action: onStart, how: t('driver.step.check'), step: 1),
      'BOARDING' => (label: t('driver.setOff'), action: onDepart, how: t('driver.step.setOff'), step: 2),
      'IN_PROGRESS' => (label: t('driver.endRun'), action: onEnd, how: t('driver.step.atStops'), step: 3),
      'ARRIVED' => (label: t('driver.endRun'), action: onEnd, how: t('driver.step.endRun'), step: 4),
      'SWEEP_PENDING' || 'SWEEP_OVERDUE' =>
        (label: t('driver.sweepOutstanding'), action: null, how: t('driver.step.sweep'), step: 5),
      'CANCELLED' || 'VOID' || 'ABANDONED' => (label: t('driver.runCalledOff'), action: null, how: null, step: null),
      _ => (label: t('driver.runFinished'), action: null, how: t('driver.step.done'), step: 5),
    };

String? runLockFor(
  VoidCallback? action, {
  required VoidCallback onDepart,
  required VoidCallback onEnd,
  String? endBlocked,
  String? departBlocked,
}) =>
    identical(action, onEnd)
        ? endBlocked
        : identical(action, onDepart)
            ? departBlocked
            : null;

class RunActionBar extends StatelessWidget {
  const RunActionBar({
    super.key,
    required this.trip,
    required this.busy,
    required this.onStart,
    required this.onDepart,
    required this.onEnd,
    this.endBlocked,
    this.departBlocked,
  });

  final CrewTrip trip;
  final String? busy;
  final VoidCallback onStart;
  final VoidCallback onDepart;
  final VoidCallback onEnd;
  final String? endBlocked;
  final String? departBlocked;

  @override
  Widget build(BuildContext context) {
    final step = runStepFor(trip.status, onStart: onStart, onDepart: onDepart, onEnd: onEnd);
    final lock = runLockFor(
      step.action,
      onDepart: onDepart,
      onEnd: onEnd,
      endBlocked: endBlocked,
      departBlocked: departBlocked,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lock != null) ...[
          FlowNote(icon: Icons.lock_outline_rounded, text: lock, colour: AppTheme.rose),
          const SizedBox(height: 8),
        ],
        if (step.action == null)
          FlowNote(
            icon: trip.status == 'COMPLETED' ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            text: step.label,
            colour: trip.status == 'COMPLETED' ? AppTheme.textMuted : AppTheme.rose,
          )
        else
          BigButton(
            label: step.label,
            color: Role.driver.tint,
            busy: busy != null,
            height: 50,
            onPressed: lock == null ? step.action : null,
          ),
      ],
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
    this.endBlocked,
    this.departBlocked,
  });

  final CrewTrip trip;

  final String? endBlocked;

  final String? departBlocked;

  final TripTiming timing;
  final String? busy;
  final VoidCallback onStart;
  final VoidCallback onDepart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final (:label, :action, :how, :step) =
        runStepFor(trip.status, onStart: onStart, onDepart: onDepart, onEnd: onEnd);

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

    final lock = runLockFor(
      action,
      onDepart: onDepart,
      onEnd: onEnd,
      endBlocked: endBlocked,
      departBlocked: departBlocked,
    );

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
          if (lock != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.rose),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lock,
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
            const SizedBox(height: 10),
            BigButton(
              label: label,
              color: Role.driver.tint,
              height: 52,
              onPressed: null,
            ),
          ] else if (action == null)
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
    final tint = Role.driver.tint;
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                nearestFirst ? Icons.near_me_rounded : Icons.format_list_numbered_rounded,
                size: 18,
                color: nearestFirst ? tint : AppTheme.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t(nearestFirst ? 'driver.nearestFirst' : 'driver.order.office'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppTheme.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: t('driver.nearestFirst'),
                toggled: nearestFirst,
                child: Switch(
                  value: nearestFirst,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  thumbColor: const WidgetStatePropertyAll(Colors.white),
                  trackColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? tint : AppTheme.textFaint,
                  ),
                  trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class StopCard extends StatefulWidget {
  const StopCard({
    super.key,
    required this.stop,
    required this.tripId,
    required this.leg,
    required this.terminalStopId,
    required this.schoolReached,
    required this.running,
    required this.started,
    required this.onChanged,
    this.query = '',
    this.current = false,
    this.number,
    this.locked = false,
  });

  final PlannedStop stop;

  final bool locked;

  final int? number;
  final String tripId;
  final String leg;

  final String query;

  final String? terminalStopId;

  final bool schoolReached;

  final bool running;

  final bool started;

  final bool current;

  final VoidCallback onChanged;

  @override
  State<StopCard> createState() => _StopCardState();
}

class _StopCardState extends State<StopCard> {
  bool? _openChoice;
  String? _busyStudent;
  bool _busyStop = false;

  RosterFilter _show = RosterFilter.all;

  Timer? _hold;

  int get _holdSeconds => requiredWaitSeconds(widget.stop);

  int get _holdLeft {
    if (widget.leg == 'OUT') return 0;
    final at = widget.stop.arrivedAt;
    if (at == null || widget.stop.departedAt != null) return 0;
    if (widget.stop.remaining == 0) return 0;
    final left = _holdSeconds - DateTime.now().difference(at).inSeconds;
    if (left <= 0) return 0;
    return left > _holdSeconds ? _holdSeconds : left;
  }

  bool get _school => isSchoolStop(widget.stop, widget.terminalStopId);

  Presence get _presence => stopPresence(
        widget.stop,
        school: _school,
        fix: BusLocation.instance.here.value,
      );

  bool get _ticking => widget.running && !widget.stop.done;

  @override
  void initState() {
    super.initState();
    BusLocation.instance.here.addListener(_onFix);
    _syncHold();
  }

  @override
  void didUpdateWidget(covariant StopCard old) {
    super.didUpdateWidget(old);
    _syncHold();
  }

  @override
  void dispose() {
    BusLocation.instance.here.removeListener(_onFix);
    _hold?.cancel();
    super.dispose();
  }

  void _onFix() {
    if (mounted && _ticking) setState(() {});
  }

  void _syncHold() {
    final wanted = _ticking;
    if (wanted && _hold == null) {
      _hold = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (!_ticking) {
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
    try {
      await _correctRider(
        context,
        tripId: widget.tripId,
        leg: widget.leg,
        rider: rider,
        riderStopId: widget.stop.stopId,
        terminalStopId: widget.terminalStopId,
        onBusy: () => setState(() => _busyStudent = rider.studentId),
        onChanged: widget.onChanged,
      );
    } finally {
      if (mounted) setState(() => _busyStudent = null);
    }
  }

  Future<void> _mark(RiderOnStop rider, String eventType, String label) async {
    setState(() => _busyStudent = rider.studentId);
    try {
      await _markRider(
        context,
        tripId: widget.tripId,
        leg: widget.leg,
        rider: rider,
        riderStopId: widget.stop.stopId,
        terminalStopId: widget.terminalStopId,
        eventType: eventType,
        label: label,
        onChanged: widget.onChanged,
      );
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
    final open = widget.query.isNotEmpty || (_openChoice ?? widget.current);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _StopHeader(
              stop: widget.stop,
              number: widget.number,
              open: open,
              onTap: () => setState(() => _openChoice = !(_openChoice ?? widget.current)),
            ),
            if (open) ...[
              Divider(height: 1, color: AppTheme.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _flow(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _banner() {
    final s = widget.stop;
    if (!widget.running &&
        widget.started &&
        s.students.any((r) => r.boardedAt != null && r.alightedAt == null)) {
      return _FlowBanner(
        text: t('driver.dropAfterEnd'),
        colour: AppTheme.amber,
        wash: AppTheme.amberSoft,
      );
    }
    if (!widget.running) {
      return _FlowBanner(
        text: t('driver.tickAfterSetOff'),
        colour: AppTheme.textMuted,
        wash: AppTheme.neutralSoft,
      );
    }
    if (widget.locked) {
      return _FlowBanner(
        text: t('driver.gate.checkFirst'),
        colour: AppTheme.amber,
        wash: AppTheme.amberSoft,
      );
    }
    if (s.done) return null;
    return _FlowBanner(
      text: s.students.length > 1 ? t('driver.flow.guideMany') : t('driver.flow.guide'),
      colour: AppTheme.blue,
      wash: AppTheme.blueSoft,
    );
  }

  List<Widget> _flow() {
    final s = widget.stop;
    final running = widget.running && !widget.locked;
    final canSkip = !s.done && s.arrivedAt == null;
    final holdLeft = _holdLeft;
    final holding = holdLeft > 0;
    final banner = _banner();
    final hasChildren = s.students.isNotEmpty;
    final presence = _presence;
    final out = widget.leg == 'OUT';
    final moveBlocked = out && !mayMoveOnOut(s);
    final presenceNote = running && !s.done && !presence.allowed ? presence.note : null;

    return [
      ?banner,
      Padding(
        padding: EdgeInsets.only(top: banner == null ? 0 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 5,
                  child: _StepLabel(
                    number: 1,
                    label: t('driver.flow.arrive'),
                    done: s.arrivedAt != null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _StepLabel(
                    number: 2,
                    label: t('driver.flow.skip'),
                    done: s.skipped,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: s.arrivedAt != null
                        ? _FlowDone(
                            icon: Icons.location_on_rounded,
                            text: tn('driver.arrivedAt', hhmm(s.arrivedAt)),
                            colour: AppTheme.green,
                          )
                        : _FlowButton(
                            label: t('driver.arrived'),
                            icon: Icons.location_on_rounded,
                            colour: Colors.white,
                            fill: Role.driver.tint,
                            busy: _busyStop,
                            onPressed: running && presence.allowed
                                ? () => _stopAction(
                                      () => CrewApi.instance.arriveAtStop(
                                        widget.tripId,
                                        s.plannedSequence,
                                        fix: reportedFix(BusLocation.instance.here.value),
                                      ),
                                      t('driver.arrived'),
                                    )
                                : null,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: s.skipped
                        ? _FlowDone(
                            icon: Icons.skip_next_rounded,
                            text: t('driver.skipped'),
                            colour: AppTheme.amber,
                            mirror: true,
                          )
                        : _FlowButton(
                            label: t('driver.skipStop'),
                            icon: Icons.skip_next_rounded,
                            mirror: true,
                            colour: AppTheme.text,
                            fill: AppTheme.surface,
                            outline: true,
                            onPressed: canSkip && running && !_busyStop ? _skipStop : null,
                          ),
                  ),
                ],
              ),
            ),
            if (presenceNote != null) ...[
              const SizedBox(height: 6),
              FlowNote(
                key: const ValueKey('presence-note'),
                icon: presence.state == PresenceState.noFix
                    ? Icons.gps_not_fixed_rounded
                    : Icons.near_me_rounded,
                text: presenceNote,
                colour: AppTheme.amber,
              ),
            ],
          ],
        ),
      ),
      if (hasChildren)
        _FlowStep(
          number: 3,
          label: s.students.length > 1 ? t('driver.flow.children') : t('driver.flow.child'),
          done: s.remaining == 0,
          child: _childActions(),
        ),
      _FlowStep(
        number: hasChildren ? 4 : 3,
        label: t('driver.flow.leave'),
        done: s.done,
        child: s.done
            ? _FlowDone(
                icon: s.skipped ? Icons.skip_next_rounded : Icons.check_circle_rounded,
                text: s.skipped
                    ? t('driver.skipped')
                    : tn('driver.flow.movedOnAt', hhmm(s.departedAt)),
                colour: s.skipped ? AppTheme.amber : AppTheme.green,
                mirror: s.skipped,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FlowButton(
                    label: holding
                        ? '${t('driver.movingOn')} · ${holdLeft ~/ 60}:${(holdLeft % 60).toString().padLeft(2, '0')}'
                        : t('driver.movingOn'),
                    icon: Icons.skip_next_rounded,
                    mirror: true,
                    colour: Colors.white,
                    fill: AppTheme.blue,
                    busy: _busyStop,
                    onPressed: running && !holding && !moveBlocked
                        ? () => _stopAction(
                              () => CrewApi.instance.leaveStop(widget.tripId, s.plannedSequence),
                              t('driver.movingOn'),
                            )
                        : null,
                  ),
                  if (running && moveBlocked) ...[
                    const SizedBox(height: 6),
                    FlowNote(
                      icon: Icons.lock_outline_rounded,
                      text: t('driver.flow.resolveFirst'),
                      colour: AppTheme.textMuted,
                    ),
                  ],
                  if (holding) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t('driver.holdAtStop'),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
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
    ];
  }

  Widget _childActions() {
    final s = widget.stop;
    final out = widget.leg == 'OUT';
    final presence = _presence;
    final live = widget.running && !widget.locked;
    final waitLeft = notHereWaitLeft(s);
    final notHereNote = !out || !live || s.done || s.remaining == 0
        ? null
        : waitLeft == null
            ? t('driver.notHere.arriveFirst')
            : waitLeft > 0
                ? tn('driver.notHere.waitNote', waitClock(waitLeft))
                : null;
    final riders = RosterFilters.apply(
      s.students,
      widget.query.isEmpty ? _show : RosterFilter.all,
    ).where((r) => _TripScreenState._matches(r, widget.query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.query.isEmpty && s.students.length > 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RosterFilters(
              riders: s.students,
              value: _show,
              onChanged: (f) => setState(() => _show = f),
            ),
          ),
        if (notHereNote != null) ...[
          FlowNote(
            key: const ValueKey('not-here-note'),
            icon: Icons.timer_outlined,
            text: notHereNote,
            colour: AppTheme.textMuted,
          ),
          const SizedBox(height: 8),
        ],
        for (final (i, r) in riders.indexed) ...[
          if (i > 0) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 8),
          ],
          _ChildActions(
            rider: r,
            leg: widget.leg,
            schoolReached: widget.schoolReached,
            named: s.students.length > 1 || r.name.trim() != s.name.trim(),
            busy: _busyStudent == r.studentId,
            canPickUp: live && (!out || presence.allowed),
            canSetDown: widget.started && !widget.locked && (out || presence.allowed),
            canNotHere: live && (!out || mayMarkNotHere(s)),
            notHereLeft: out && live ? (waitLeft ?? 0) : 0,
            onBoard: () => _mark(r, 'BOARDED', t('driver.onBoard')),
            onOff: () => _mark(
              r,
              widget.leg == 'OUT' ? 'ALIGHTED' : 'HANDOVER',
              widget.leg == 'OUT'
                  ? (widget.schoolReached ? t('driver.atSchool') : t('driver.setDownEarly'))
                  : t('driver.handedOver'),
            ),
            onNoShow: () => _mark(r, 'NO_SHOW', t('driver.notRiding')),
            onCorrect: () => _correct(r),
          ),
        ],
      ],
    );
  }
}

class _StopHeader extends StatelessWidget {
  const _StopHeader({required this.stop, required this.open, required this.onTap, this.number});

  final PlannedStop stop;

  final int? number;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = stop;
    final remaining = s.remaining;
    final settled = s.done || remaining == 0;
    final place = [
      if (s.landmark != null && s.landmark!.isNotEmpty) s.landmark!,
      if (s.metresAway != null && !s.done) distanceAway(s.metresAway!),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.skipped
                    ? AppTheme.amberSoft
                    : settled
                        ? AppTheme.greenSoft
                        : Role.driver.wash,
                borderRadius: BorderRadius.circular(11),
              ),
              child: s.skipped
                  ? _Mirrored(
                      child: Icon(Icons.skip_next_rounded, size: 20, color: AppTheme.amber),
                    )
                  : settled
                      ? Icon(Icons.check_rounded, size: 20, color: AppTheme.green)
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Text(
                              '${number ?? s.plannedSequence}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Role.driver.tint,
                              ),
                            ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.25,
                      color: AppTheme.text,
                    ),
                  ),
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      place,
                      style: TextStyle(fontSize: 12.5, height: 1.3, color: AppTheme.textMuted),
                    ),
                  ],
                  if (s.skippedReason != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      s.skippedReason!,
                      style: TextStyle(fontSize: 12, height: 1.3, color: AppTheme.amber),
                    ),
                  ],
                  if (s.etaAt != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          s.etaIsActual ? Icons.check_circle_rounded : Icons.schedule_rounded,
                          size: 13,
                          color: s.etaIsActual ? AppTheme.green : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            stopEtaText(s),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: s.etaIsActual ? AppTheme.green : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: s.skipped
                    ? AppTheme.amberSoft
                    : remaining == 0
                        ? AppTheme.greenSoft
                        : Role.driver.wash,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                s.skipped
                    ? t('driver.skipped')
                    : remaining == 0
                        ? t('driver.done')
                        : tn('driver.nLeft', remaining),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: s.skipped
                      ? AppTheme.amber
                      : remaining == 0
                          ? AppTheme.green
                          : Role.driver.tint,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 24,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class FlowNote extends StatelessWidget {
  const FlowNote({super.key, required this.icon, required this.text, required this.colour});

  final IconData icon;
  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: colour),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: colour,
            ),
          ),
        ),
      ],
    );
  }
}

class _FlowBanner extends StatelessWidget {
  const _FlowBanner({required this.text, required this.colour, required this.wash});

  final String text;
  final Color colour;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded, size: 16, color: colour),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.label, required this.done});

  final int number;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final tone = done ? AppTheme.green : AppTheme.textMuted;
    final style = TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600, color: tone);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (done)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.check_circle_rounded, size: 14, color: tone),
          )
        else
          Text('$number.', style: style),
        const SizedBox(width: 4),
        Expanded(child: Text(label, style: style)),
      ],
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.number,
    required this.label,
    required this.done,
    required this.child,
  });

  final int number;
  final String label;
  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepLabel(number: number, label: label, done: done),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _Mirrored extends StatelessWidget {
  const _Mirrored({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Transform.flip(
        flipX: Directionality.of(context) == TextDirection.rtl,
        child: child,
      );
}

class _FlowDone extends StatelessWidget {
  const _FlowDone({
    required this.icon,
    required this.text,
    required this.colour,
    this.mirror = false,
  });

  final IconData icon;
  final String text;
  final Color colour;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(icon, size: 16, color: colour);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.neutralSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          mirror ? _Mirrored(child: glyph) : glyph,
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: colour),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowButton extends StatelessWidget {
  const _FlowButton({
    required this.label,
    required this.icon,
    required this.colour,
    required this.fill,
    required this.onPressed,
    this.busy = false,
    this.outline = false,
    this.mirror = false,
    this.height = 44,
  });

  final String label;
  final IconData icon;
  final Color colour;
  final Color fill;
  final VoidCallback? onPressed;
  final bool busy;
  final bool outline;
  final bool mirror;
  final double height;

  @override
  Widget build(BuildContext context) {
    final live = onPressed != null && !busy;
    final dim = !live && !busy;
    final tone = dim ? colour.withValues(alpha: outline ? 0.4 : 0.55) : colour;
    final ground = dim && !outline ? fill.withValues(alpha: 0.5) : fill;
    final glyph = Icon(icon, size: 18, color: tone);

    return Semantics(
      button: true,
      enabled: live,
      child: Material(
        color: ground,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: outline
              ? BorderSide(color: AppTheme.textFaint.withValues(alpha: dim ? 0.35 : 0.6), width: 1.2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: live ? onPressed : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: colour),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          mirror ? _Mirrored(child: glyph) : glyph,
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: tone,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
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

class _ChildActions extends StatelessWidget {
  const _ChildActions({
    required this.rider,
    required this.leg,
    required this.schoolReached,
    required this.named,
    required this.busy,
    required this.canPickUp,
    required this.canSetDown,
    this.canNotHere = true,
    this.notHereLeft = 0,
    required this.onBoard,
    required this.onOff,
    required this.onNoShow,
    required this.onCorrect,
  });

  final RiderOnStop rider;
  final String leg;

  final bool schoolReached;

  final bool named;
  final bool busy;

  final bool canPickUp;
  final bool canSetDown;
  final bool canNotHere;
  final int notHereLeft;
  final VoidCallback onBoard;
  final VoidCallback onOff;
  final VoidCallback onNoShow;

  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    final onBus = rider.boardedAt != null && rider.alightedAt == null;
    final off = rider.alightedAt != null;

    final notRiding = !off && !onBus && rider.notTravelling;
    final waiting = !off && !onBus && !notRiding;
    final status = riderStatus(rider, leg: leg, schoolReached: schoolReached);

    final showWho = named || !waiting || rider.requiresAssistance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showWho) ...[
          Row(
            children: [
              SeatChip(rider: rider, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (named || rider.requiresAssistance)
                      Row(
                        children: [
                          if (named)
                            Flexible(
                              child: Text(
                                rider.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: AppTheme.text,
                                ),
                              ),
                            ),
                          if (named && rider.requiresAssistance) const SizedBox(width: 6),
                          if (rider.requiresAssistance)
                            Icon(Icons.accessible_rounded, size: 16, color: AppTheme.amber),
                        ],
                      ),
                    if (!waiting)
                      Text(
                        status.text,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: notRiding ? FontWeight.w600 : FontWeight.w500,
                          color: status.tone,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (busy)
          const SizedBox(
            height: 40,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          )
        else if (off || (notRiding && leg == 'RETURN'))
          _FlowButton(
            label: t('driver.wrong'),
            icon: Icons.edit_note_rounded,
            colour: AppTheme.textMuted,
            fill: AppTheme.neutralSoft,
            height: 40,
            onPressed: onCorrect,
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: onBus
                      ? _FlowButton(
                          label: leg == 'OUT' ? t('driver.setDown') : t('driver.handOver'),
                          icon: Icons.logout_rounded,
                          mirror: true,
                          colour: AppTheme.green,
                          fill: AppTheme.greenSoft,
                          height: 40,
                          onPressed: canSetDown ? onOff : null,
                        )
                      : _FlowButton(
                          label: t('driver.pickUp'),
                          icon: Icons.login_rounded,
                          mirror: true,
                          colour: Role.driver.tint,
                          fill: Role.driver.wash,
                          height: 40,
                          onPressed: canPickUp ? onBoard : null,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: onBus || notRiding
                      ? _FlowButton(
                          label: t('driver.wrong'),
                          icon: Icons.edit_note_rounded,
                          colour: AppTheme.textMuted,
                          fill: AppTheme.neutralSoft,
                          height: 40,
                          onPressed: onCorrect,
                        )
                      : _FlowButton(
                          label: notHereLeft > 0
                              ? '${t('driver.notHere')} · ${waitClock(notHereLeft)}'
                              : t('driver.notHere'),
                          icon: Icons.close_rounded,
                          colour: AppTheme.text,
                          fill: AppTheme.neutralSoft,
                          height: 40,
                          onPressed: canNotHere ? onNoShow : null,
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

typedef RiderAction = void Function(RiderOnStop rider, PlannedStop stop);

List<({RiderOnStop rider, PlannedStop stop})> _ridersIn(List<PlannedStop> stops) => [
      for (final s in stops)
        for (final r in s.students) (rider: r, stop: s),
    ];

DateTime? _latest(Iterable<DateTime?> times) {
  DateTime? out;
  for (final at in times) {
    if (at != null && (out == null || at.isAfter(out))) out = at;
  }
  return out;
}

class BoardingCheckCard extends StatefulWidget {
  const BoardingCheckCard({
    super.key,
    required this.stops,
    required this.schoolName,
    required this.canCheck,
    this.lockedNoteKey,
    required this.busyStudent,
    required this.busyAll,
    required this.onBoard,
    required this.onNotHere,
    required this.onCorrect,
    required this.onAllOnBus,
    this.query = '',
  });

  final List<PlannedStop> stops;
  final String schoolName;
  final bool canCheck;
  final String? lockedNoteKey;
  final String? busyStudent;
  final bool busyAll;
  final RiderAction onBoard;
  final RiderAction onNotHere;
  final RiderAction onCorrect;
  final VoidCallback onAllOnBus;
  final String query;

  @override
  State<BoardingCheckCard> createState() => _BoardingCheckCardState();
}

class _BoardingCheckCardState extends State<BoardingCheckCard> {
  bool? _openChoice;

  @override
  Widget build(BuildContext context) {
    final riders = _ridersIn(widget.stops);
    final all = riders.length;
    final checked = riders.where((e) => e.rider.accountedFor).length;
    final remaining = all - checked;
    final complete = remaining == 0;
    final onBus = riders.where((e) => e.rider.boardedAt != null).length;
    final away = riders.where((e) => e.rider.boardedAt == null && e.rider.notTravelling).length;
    final lastAt = _latest(riders.map((e) => e.rider.boardedAt));
    final open = widget.query.isNotEmpty || (_openChoice ?? !complete);
    final shown = riders.where((e) => _TripScreenState._matches(e.rider, widget.query)).toList();

    final summary = [
      tv('driver.gate.boardingDone', {'on': onBus, 'away': away}),
      if (lastAt != null) hhmm(lastAt),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _GateHeader(
              title: t('driver.gate.boardingTitle'),
              lines: [widget.schoolName, if (complete) summary],
              pill: complete ? t('driver.done') : tv('driver.gate.checked', {'done': checked, 'all': all}),
              done: complete,
              open: open,
              onTap: () => setState(() => _openChoice = !open),
            ),
            if (open) ...[
              Divider(height: 1, color: AppTheme.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.canCheck && !complete)
                      _FlowBanner(
                        text: t(widget.lockedNoteKey ?? 'driver.tickAfterSetOff'),
                        colour: AppTheme.textMuted,
                        wash: AppTheme.neutralSoft,
                      )
                    else if (!complete)
                      _FlowBanner(
                        text: t('driver.gate.boardingHow'),
                        colour: AppTheme.blue,
                        wash: AppTheme.blueSoft,
                      ),
                    _FlowStep(
                      number: 1,
                      label: t('driver.flow.children'),
                      done: complete,
                      child: _GateProgress(done: checked, all: all),
                    ),
                    for (final (i, e) in shown.indexed) ...[
                      SizedBox(height: i == 0 ? 10 : 8),
                      if (i > 0) ...[
                        Divider(height: 1, color: AppTheme.border),
                        const SizedBox(height: 8),
                      ],
                      _boardingRow(e.rider, e.stop),
                    ],
                    if (!complete) ...[
                      const SizedBox(height: 12),
                      _FlowButton(
                        label: tn('driver.gate.allOnBus', remaining),
                        icon: Icons.how_to_reg_rounded,
                        colour: Colors.white,
                        fill: AppTheme.green,
                        height: 48,
                        busy: widget.busyAll,
                        onPressed: widget.canCheck && widget.busyStudent == null
                            ? widget.onAllOnBus
                            : null,
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

  Widget _boardingRow(RiderOnStop r, PlannedStop s) {
    final resolved = r.accountedFor;
    final status = riderStatus(r, leg: 'RETURN', schoolReached: false);
    final live = widget.canCheck && !widget.busyAll;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GateWho(
          rider: r,
          line: resolved ? status.text : (s.landmark ?? ''),
          tone: resolved ? status.tone : AppTheme.textMuted,
        ),
        const SizedBox(height: 6),
        if (widget.busyStudent == r.studentId)
          const _RowSpinner()
        else if (resolved)
          _FlowButton(
            label: t('driver.wrong'),
            icon: Icons.edit_note_rounded,
            colour: AppTheme.textMuted,
            fill: AppTheme.neutralSoft,
            onPressed: widget.busyAll ? null : () => widget.onCorrect(r, s),
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _FlowButton(
                    label: t('driver.gate.onTheBus'),
                    icon: Icons.login_rounded,
                    mirror: true,
                    colour: Role.driver.tint,
                    fill: Role.driver.wash,
                    onPressed: live ? () => widget.onBoard(r, s) : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FlowButton(
                    label: t('driver.notHere'),
                    icon: Icons.close_rounded,
                    colour: AppTheme.text,
                    fill: AppTheme.neutralSoft,
                    onPressed: live ? () => widget.onNotHere(r, s) : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class SchoolArrivalCard extends StatefulWidget {
  const SchoolArrivalCard({
    super.key,
    required this.stops,
    required this.schoolName,
    required this.running,
    required this.started,
    required this.canArrive,
    required this.arrivedAt,
    required this.busyStudent,
    required this.busyAll,
    required this.onArrive,
    required this.onDrop,
    required this.onAllOff,
    this.query = '',
    this.gate,
  });

  final List<PlannedStop> stops;
  final String schoolName;
  final bool running;
  final bool started;

  final SchoolGate? gate;

  final bool canArrive;
  final DateTime? arrivedAt;
  final String? busyStudent;
  final bool busyAll;
  final VoidCallback onArrive;
  final RiderAction onDrop;
  final VoidCallback onAllOff;
  final String query;

  @override
  State<SchoolArrivalCard> createState() => _SchoolArrivalCardState();
}

class _SchoolArrivalCardState extends State<SchoolArrivalCard> {
  bool? _openChoice;

  Timer? _tick;

  bool get _watching => widget.running && widget.arrivedAt == null && widget.canArrive;

  @override
  void initState() {
    super.initState();
    BusLocation.instance.here.addListener(_onFix);
    _syncTick();
  }

  @override
  void didUpdateWidget(covariant SchoolArrivalCard old) {
    super.didUpdateWidget(old);
    _syncTick();
  }

  @override
  void dispose() {
    BusLocation.instance.here.removeListener(_onFix);
    _tick?.cancel();
    super.dispose();
  }

  void _onFix() {
    if (mounted && _watching) setState(() {});
  }

  void _syncTick() {
    if (_watching && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 2), (_) => _onFix());
    } else if (!_watching && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final riders = _ridersIn(widget.stops);
    final aboard = riders.where((e) => e.rider.boardedAt != null && e.rider.alightedAt == null).toList();
    final rode = riders.where((e) => e.rider.boardedAt != null).length;
    final off = riders.where((e) => e.rider.alightedAt != null).length;
    final complete = aboard.isEmpty && off > 0;
    final lastOff = _latest(riders.map((e) => e.rider.alightedAt));
    final open = widget.query.isNotEmpty || (_openChoice ?? aboard.isNotEmpty);
    final shown = aboard.where((e) => _TripScreenState._matches(e.rider, widget.query)).toList();

    final arrived = widget.arrivedAt != null;
    final presence = gatePresence(widget.gate, fix: BusLocation.instance.here.value);
    final presenceNote = widget.running && !arrived && !presence.allowed ? presence.note : null;
    final canDrop = widget.started && (arrived || !widget.canArrive || !widget.running) && !widget.busyAll;

    final summary = [
      tn('driver.gate.offAtSchool', off),
      if (lastOff != null) hhmm(lastOff),
    ].join(' · ');

    var step = 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _GateHeader(
              title: t('driver.gate.arrivalTitle'),
              lines: [widget.schoolName, if (complete) summary],
              pill: complete
                  ? t('driver.done')
                  : tv('driver.gate.offChecked', {'done': off, 'all': rode}),
              done: complete,
              open: open,
              onTap: () => setState(() => _openChoice = !open),
            ),
            if (open) ...[
              Divider(height: 1, color: AppTheme.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.started)
                      _FlowBanner(
                        text: t('driver.tickAfterSetOff'),
                        colour: AppTheme.textMuted,
                        wash: AppTheme.neutralSoft,
                      )
                    else if (aboard.isNotEmpty)
                      _FlowBanner(
                        text: t('driver.gate.arrivalHow'),
                        colour: AppTheme.blue,
                        wash: AppTheme.blueSoft,
                      ),
                    if (widget.canArrive)
                      _FlowStep(
                        number: ++step,
                        label: t('driver.flow.arrive'),
                        done: arrived,
                        child: arrived
                            ? _FlowDone(
                                icon: Icons.location_on_rounded,
                                text: tn('driver.arrivedAt', hhmm(widget.arrivedAt)),
                                colour: AppTheme.green,
                              )
                            : _FlowButton(
                                label: t('driver.arrived'),
                                icon: Icons.location_on_rounded,
                                colour: Colors.white,
                                fill: Role.driver.tint,
                                busy: widget.busyAll,
                                onPressed: widget.running && presence.allowed ? widget.onArrive : null,
                              ),
                      ),
                    if (widget.canArrive && presenceNote != null) ...[
                      const SizedBox(height: 6),
                      FlowNote(
                        key: const ValueKey('gate-presence-note'),
                        icon: presence.state == PresenceState.noFix
                            ? Icons.gps_not_fixed_rounded
                            : Icons.near_me_rounded,
                        text: presenceNote,
                        colour: AppTheme.amber,
                      ),
                    ],
                    _FlowStep(
                      number: ++step,
                      label: t('driver.flow.children'),
                      done: complete,
                      child: complete
                          ? _FlowDone(
                              icon: Icons.check_circle_rounded,
                              text: summary,
                              colour: AppTheme.green,
                            )
                          : aboard.isEmpty
                              ? Text(
                                  t('driver.gate.nobodyAboard'),
                                  style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.textMuted),
                                )
                              : _GateProgress(done: off, all: rode),
                    ),
                    for (final (i, e) in shown.indexed) ...[
                      SizedBox(height: i == 0 ? 10 : 8),
                      if (i > 0) ...[
                        Divider(height: 1, color: AppTheme.border),
                        const SizedBox(height: 8),
                      ],
                      _GateWho(
                        rider: e.rider,
                        line: tn('driver.onBoardSince', hhmm(e.rider.boardedAt)),
                        tone: AppTheme.blue,
                      ),
                      const SizedBox(height: 6),
                      if (widget.busyStudent == e.rider.studentId)
                        const _RowSpinner()
                      else
                        _FlowButton(
                          label: t('driver.setDown'),
                          icon: Icons.logout_rounded,
                          mirror: true,
                          colour: AppTheme.green,
                          fill: AppTheme.greenSoft,
                          onPressed: canDrop ? () => widget.onDrop(e.rider, e.stop) : null,
                        ),
                    ],
                    if (aboard.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _FlowButton(
                        label: tn('driver.recordAllOffOut', aboard.length),
                        icon: Icons.logout_rounded,
                        mirror: true,
                        colour: Colors.white,
                        fill: AppTheme.green,
                        height: 48,
                        busy: widget.busyAll,
                        onPressed: canDrop && widget.busyStudent == null ? widget.onAllOff : null,
                      ),
                      if (widget.running) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.rose),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                t('driver.gate.dropFirst'),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.rose,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _GateHeader extends StatelessWidget {
  const _GateHeader({
    required this.title,
    required this.lines,
    required this.pill,
    required this.done,
    required this.open,
    required this.onTap,
  });

  final String title;
  final List<String> lines;
  final String pill;
  final bool done;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = done ? AppTheme.green : Role.driver.tint;
    final wash = done ? AppTheme.greenSoft : Role.driver.wash;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(11)),
              child: Icon(done ? Icons.check_rounded : Icons.school_rounded, size: 20, color: tone),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.25,
                      color: AppTheme.text,
                    ),
                  ),
                  for (final (i, line) in lines.indexed)
                    if (line.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        line,
                        style: TextStyle(
                          fontSize: i == 0 ? 12.5 : 12,
                          height: 1.3,
                          fontWeight: i == 0 ? FontWeight.w400 : FontWeight.w700,
                          color: i == 0 ? AppTheme.textMuted : AppTheme.green,
                        ),
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  pill,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tone),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 24,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _GateProgress extends StatelessWidget {
  const _GateProgress({required this.done, required this.all});

  final int done;
  final int all;

  @override
  Widget build(BuildContext context) {
    final complete = all > 0 && done >= all;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: all == 0 ? 0 : done / all,
        minHeight: 6,
        backgroundColor: AppTheme.neutralSoft,
        valueColor: AlwaysStoppedAnimation<Color>(complete ? AppTheme.green : Role.driver.tint),
      ),
    );
  }
}

class _GateWho extends StatelessWidget {
  const _GateWho({required this.rider, required this.line, required this.tone});

  final RiderOnStop rider;
  final String line;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SeatChip(rider: rider, size: 30),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      rider.name,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.text),
                    ),
                  ),
                  if (rider.requiresAssistance) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.accessible_rounded, size: 16, color: AppTheme.amber),
                  ],
                ],
              ),
              if (line.isNotEmpty)
                Text(
                  line,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tone),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RowSpinner extends StatelessWidget {
  const _RowSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
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
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
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
      child: Semantics(
        button: true,
        label: t('driver.sos'),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.rose,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppTheme.rose.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.sos_rounded, size: 20, color: Colors.white),
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
  const _RecordAllOffSheet({
    required this.aboard,
    required this.title,
    required this.how,
    required this.confirmKey,
  });

  final List<_RiderAt> aboard;
  final String title;
  final String how;

  final String confirmKey;

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
            widget.title,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.text),
          ),
          const SizedBox(height: 4),
          Text(
            widget.how,
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
                : tn(widget.confirmKey, picked.length),
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
