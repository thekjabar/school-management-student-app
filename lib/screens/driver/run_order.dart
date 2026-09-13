import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/bus_location.dart';
import '../../api/crew_api.dart';
import '../../api/directions.dart';
import '../../i18n/strings.dart';
import 'roster_kit.dart';
import 'run_route_cache.dart';

bool stopIsPlaced(PlannedStop s) {
  final lat = s.lat;
  final lon = s.lon;
  if (lat == null || lon == null) return false;
  if (lat == 0 && lon == 0) return false;
  return lat.abs() <= 90 && lon.abs() <= 180;
}

double metresBetween(LatLng a, LatLng b) {
  const earth = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLon = rad(b.longitude - a.longitude);
  final s = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earth * math.asin(math.min(1.0, math.sqrt(s)));
}

double bearingBetween(LatLng a, LatLng b) {
  double rad(double d) => d * math.pi / 180;
  final dLon = rad(b.longitude - a.longitude);
  final y = math.sin(dLon) * math.cos(rad(b.latitude));
  final x = math.cos(rad(a.latitude)) * math.sin(rad(b.latitude)) -
      math.sin(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double angleGap(double a, double b) {
  final d = ((a - b) % 360 + 360) % 360;
  return d > 180 ? 360 - d : d;
}

const double kCourseMinSpeedMs = 2.5;

const double kAheadMinMetres = 30;

double? followBearing({
  required double heading,
  required double speed,
  required LatLng bus,
  List<LatLng>? road,
  LatLng? next,
}) {
  if (speed.isFinite && speed >= kCourseMinSpeedMs && heading.isFinite && heading >= 0) {
    return heading % 360;
  }
  LatLng? ahead;
  if (road != null && road.length >= 2) {
    var nearest = 0;
    var gap = double.infinity;
    for (var i = 0; i < road.length; i++) {
      final d = metresBetween(road[i], bus);
      if (d < gap) {
        gap = d;
        nearest = i;
      }
    }
    for (var j = nearest + 1; j < road.length; j++) {
      if (metresBetween(bus, road[j]) >= kAheadMinMetres) {
        ahead = road[j];
        break;
      }
    }
  }
  ahead ??= next;
  if (ahead == null || metresBetween(bus, ahead) < 8) return null;
  return bearingBetween(bus, ahead);
}

String distanceAway(int metres) {
  if (metres < 1000) return tn('driver.metresAway', metres);
  final km = metres / 1000;
  return tn('driver.kmAway', km < 10 ? km.toStringAsFixed(1) : '${km.round()}');
}

List<int> nearestNeighbourOrder(
  int count,
  double Function(int to) fromStart,
  double Function(int from, int to) between,
) {
  final left = [for (var i = 0; i < count; i++) i];
  final out = <int>[];
  int? cursor;
  while (left.isNotEmpty) {
    var best = 0;
    var bestCost = double.infinity;
    for (var j = 0; j < left.length; j++) {
      final cost = cursor == null ? fromStart(left[j]) : between(cursor, left[j]);
      if (cost < bestCost) {
        bestCost = cost;
        best = j;
      }
    }
    cursor = left.removeAt(best);
    out.add(cursor);
  }
  return out;
}

enum RunBasis { office, fromBus, fromLastStop, fromSchool, schoolFirst, noPosition }

typedef TravelCost = double Function(LatLng from, LatLng to);

class RunArrangement {
  const RunArrangement({required this.stops, required this.basis, this.road = false, this.bus});

  final List<PlannedStop> stops;

  final RunBasis basis;

  final bool road;

  final LatLng? bus;

  PlannedStop? get next => stops.where((s) => !s.done).firstOrNull;

  RunArrangement kept(RunBasis basis, bool road) =>
      RunArrangement(stops: stops, basis: basis, road: road, bus: bus);

  String note(String leg) => switch (basis) {
        RunBasis.office => t('driver.order.note.office'),
        RunBasis.fromBus => t(road
            ? (leg == 'RETURN' ? 'driver.order.note.road' : 'driver.order.note.roadOut')
            : (leg == 'RETURN' ? 'driver.order.note.straight' : 'driver.order.note.straightOut')),
        RunBasis.fromLastStop => t('driver.order.note.fromLastStop'),
        RunBasis.fromSchool => t('driver.order.note.fromSchool'),
        RunBasis.schoolFirst => t('driver.order.note.schoolFirst'),
        RunBasis.noPosition => t('driver.order.note.noPosition'),
      };
}

class RunTarget {
  const RunTarget.school({required this.students})
      : school = true,
        stop = null;

  const RunTarget.stop(PlannedStop this.stop)
      : school = false,
        students = 0;

  final bool school;

  final PlannedStop? stop;

  final int students;
}

RunTarget? runTarget({
  required List<PlannedStop> stops,
  required String leg,
  SchoolGate? school,
}) {
  final schoolId = school?.stopId;
  if (school != null && schoolCheckOpen(leg, stops)) {
    return RunTarget.school(students: stops.fold(0, (n, s) => n + s.remaining));
  }
  final next = stops.where((s) => !s.done && !isSchoolStop(s, schoolId)).firstOrNull;
  if (next != null) return RunTarget.stop(next);
  if (leg == 'RETURN' || school == null) return null;
  return RunTarget.school(
    students: stops.fold(
      0,
      (n, s) => n + s.students.where((r) => r.boardedAt != null && r.alightedAt == null).length,
    ),
  );
}

bool isSchoolStop(PlannedStop s, String? schoolStopId) =>
    schoolStopId != null && s.stopId == schoolStopId && s.students.isEmpty;

DateTime _finishedAt(PlannedStop s) => s.departedAt ?? s.arrivedAt ?? DateTime(9999);

RunArrangement arrangeRun({
  required List<PlannedStop> stops,
  required String leg,
  required bool nearest,
  LatLng? bus,
  SchoolGate? school,
  TravelCost? cost,
  bool road = false,
  List<String>? keepOrder,
}) {
  final schoolId = school?.stopId;
  final bySequence = stops.toList()..sort((a, b) => a.plannedSequence.compareTo(b.plannedSequence));
  final done = bySequence.where((s) => s.done && !isSchoolStop(s, schoolId)).toList()
    ..sort((a, b) => _finishedAt(a).compareTo(_finishedAt(b)));
  final schoolRows = bySequence.where((s) => isSchoolStop(s, schoolId)).toList();
  final pending = bySequence.where((s) => !s.done && !isSchoolStop(s, schoolId)).toList();

  List<PlannedStop> assemble(List<PlannedStop> ordered) => leg == 'RETURN'
      ? [...schoolRows, ...done, ...ordered]
      : [...done, ...ordered, ...schoolRows];

  List<PlannedStop> measured(List<PlannedStop> list) {
    final from = bus;
    if (from == null) return list;
    return [
      for (final s in list)
        stopIsPlaced(s)
            ? s.withMetresAway(
                (Directions.metres(from, LatLng(s.lat!, s.lon!)) ??
                        metresBetween(from, LatLng(s.lat!, s.lon!)))
                    .round(),
              )
            : s.withMetresAway(null),
    ];
  }

  if (!nearest) {
    return RunArrangement(stops: measured(assemble(pending)), basis: RunBasis.office, bus: bus);
  }

  final atStop = pending.where((s) => s.arrivedAt != null).toList()
    ..sort((a, b) => a.arrivedAt!.compareTo(b.arrivedAt!));
  final open = pending.where((s) => s.arrivedAt == null).toList();
  final placed = open.where(stopIsPlaced).toList();
  final unplaced = open.where((s) => !stopIsPlaced(s)).toList();

  final lastDone = done.where(stopIsPlaced).lastOrNull;
  final schoolAt = school != null && school.placed ? LatLng(school.lat!, school.lon!) : null;

  final RunBasis basis;
  LatLng? anchor;
  if (leg == 'RETURN' && schoolAt != null && schoolCheckOpen(leg, stops)) {
    basis = bus == null ? RunBasis.fromSchool : RunBasis.schoolFirst;
    anchor = schoolAt;
  } else if (bus != null) {
    basis = RunBasis.fromBus;
    anchor = bus;
  } else if (lastDone != null) {
    basis = RunBasis.fromLastStop;
    anchor = LatLng(lastDone.lat!, lastDone.lon!);
  } else if (leg == 'RETURN' && schoolAt != null) {
    basis = RunBasis.fromSchool;
    anchor = schoolAt;
  } else {
    return RunArrangement(stops: measured(assemble(pending)), basis: RunBasis.noPosition, bus: bus);
  }

  final List<int> order;
  if (keepOrder != null && placed.every((s) => keepOrder.contains(s.stopId))) {
    order = [for (var i = 0; i < placed.length; i++) i]
      ..sort((a, b) => keepOrder.indexOf(placed[a].stopId).compareTo(keepOrder.indexOf(placed[b].stopId)));
  } else {
    final pinned = atStop.where(stopIsPlaced).lastOrNull;
    final start = pinned == null ? anchor : LatLng(pinned.lat!, pinned.lon!);
    final travel = cost ?? metresBetween;
    final points = [for (final s in placed) LatLng(s.lat!, s.lon!)];
    order = nearestNeighbourOrder(
      placed.length,
      (to) => travel(start, points[to]),
      (from, to) => travel(points[from], points[to]),
    );
  }

  return RunArrangement(
    stops: measured(assemble([...atStop, for (final i in order) placed[i], ...unplaced])),
    basis: basis,
    road: road,
    bus: bus,
  );
}

const Set<RunBasis> _guessedBases = {RunBasis.fromLastStop, RunBasis.fromSchool, RunBasis.noPosition};

bool orderWaitsForBus(RunBasis basis) => _guessedBases.contains(basis);

String runPhase({required String leg, required List<PlannedStop> stops, required bool nearest}) => [
      leg,
      leg == 'RETURN' && schoolCheckOpen(leg, stops) ? 'toSchool' : 'stops',
      nearest ? 'nearest' : 'office',
    ].join(':');

List<String> openStopIds(List<PlannedStop> stops, String? schoolStopId) => [
      for (final s in stops)
        if (!s.done && s.arrivedAt == null && stopIsPlaced(s) && !isSchoolStop(s, schoolStopId)) s.stopId,
    ];

bool canKeepOrder({
  required PinnedOrder? pinned,
  required List<String> open,
  required bool busKnown,
}) {
  if (pinned == null) return false;
  if (busKnown && orderWaitsForBus(pinned.basis)) return false;
  final known = pinned.order.toSet();
  return open.every(known.contains);
}

List<int?> runNumbers(List<PlannedStop> stops, String? schoolStopId) {
  var n = 0;
  return [for (final s in stops) isSchoolStop(s, schoolStopId) ? null : ++n];
}

class RunWaypoint {
  const RunWaypoint({
    required this.at,
    required this.done,
    required this.school,
    required this.key,
    required this.id,
  });

  final LatLng at;
  final bool done;
  final bool school;
  final String key;

  final String id;

  String get place => '$id@${at.latitude.toStringAsFixed(5)},${at.longitude.toStringAsFixed(5)}';
}

List<RunWaypoint> runWaypoints({
  required List<PlannedStop> stops,
  required String leg,
  SchoolGate? school,
}) {
  final schoolId = school?.stopId;
  final out = <RunWaypoint>[];
  RunWaypoint? gate;
  if (school != null && school.placed) {
    gate = RunWaypoint(
      at: LatLng(school.lat!, school.lon!),
      done: leg == 'RETURN' && !schoolCheckOpen(leg, stops),
      school: true,
      key: 'school',
      id: 'school',
    );
  }
  if (leg == 'RETURN' && gate != null) out.add(gate);
  for (var i = 0; i < stops.length; i++) {
    final s = stops[i];
    if (isSchoolStop(s, schoolId) || !stopIsPlaced(s) || droppedFromRoute(s)) continue;
    out.add(RunWaypoint(at: LatLng(s.lat!, s.lon!), done: s.done, school: false, key: 'pin-$i', id: s.stopId));
  }
  if (leg != 'RETURN' && gate != null) out.add(gate);
  return out;
}

bool droppedFromRoute(PlannedStop s) {
  if (s.arrivedAt != null || s.departedAt != null) return false;
  if (s.skipped) return true;
  return s.students.isNotEmpty && s.students.every((r) => r.notTravelling);
}

String runRouteKey({required String leg, required List<RunWaypoint> waypoints}) =>
    [leg, for (final w in waypoints) w.place].join(';');

String busLegKey({required String leg, required RunWaypoint target}) => '$leg;${target.place}';

const double busLegFromStopMetres = 300;

const double busAtTargetMetres = 150;

bool busLegNeeded({required List<RunWaypoint> waypoints, required LatLng bus}) {
  final i = waypoints.indexWhere((w) => !w.done);
  if (i == -1) return false;
  if (metresBetween(waypoints[i].at, bus) <= busAtTargetMetres) return false;
  if (i == 0) return true;
  return metresBetween(waypoints[i - 1].at, bus) > busLegFromStopMetres;
}

enum LegState { done, next, later }

List<LegState> legStates(List<RunWaypoint> waypoints) {
  final firstOpen = waypoints.indexWhere((w) => !w.done);
  return [
    for (var i = 0; i < waypoints.length - 1; i++)
      if (firstOpen == -1 || i + 1 < firstOpen)
        LegState.done
      else if (i + 1 == firstOpen)
        LegState.next
      else
        LegState.later,
  ];
}

class RunOrder {
  RunOrder._();

  static const _officeKey = 'driver.runOrder.office';

  static const _roadWait = Duration(seconds: 4);

  static final ValueNotifier<bool> nearest = ValueNotifier<bool>(true);

  static bool _restored = false;

  static final Map<String, SchoolGate> _schools = {};

  static Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      nearest.value = !(prefs.getBool(_officeKey) ?? false);
    } catch (_) {
      nearest.value = true;
    }
  }

  static Future<void> choose(bool nearestFirst) async {
    nearest.value = nearestFirst;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_officeKey, !nearestFirst);
    } catch (_) {
    }
  }

  static Future<SchoolGate?> school(String tripId) async {
    final known = _schools[tripId];
    if (known != null) return known;
    try {
      final gate = await CrewApi.instance.schoolGate(tripId);
      _schools[tripId] = gate;
      return gate;
    } catch (_) {
      return null;
    }
  }

  static Future<LatLng?> busPosition() async {
    final live = BusLocation.instance.here.value;
    if (live != null) return LatLng(live.latitude, live.longitude);
    try {
      final permission = await geo.Geolocator.checkPermission();
      if (permission != geo.LocationPermission.always &&
          permission != geo.LocationPermission.whileInUse) {
        return null;
      }
      final last = await geo.Geolocator.getLastKnownPosition();
      if (last == null) return null;
      if (DateTime.now().difference(last.timestamp) > const Duration(minutes: 10)) return null;
      return LatLng(last.latitude, last.longitude);
    } catch (_) {
      return null;
    }
  }

  static LatLng _rounded(LatLng p) => LatLng(
        double.parse(p.latitude.toStringAsFixed(4)),
        double.parse(p.longitude.toStringAsFixed(4)),
      );

  static Future<RunArrangement> resolve({
    required String tripId,
    required String leg,
    required List<PlannedStop> stops,
    SchoolGate? school,
  }) async {
    await _restore();
    final gate = school ?? await RunOrder.school(tripId);
    final seen = await busPosition();
    final bus = seen == null ? null : _rounded(seen);

    if (!nearest.value) {
      return arrangeRun(stops: stops, leg: leg, nearest: false, bus: bus, school: gate);
    }

    final book = await RunRouteCache.open(tripId);
    final phase = runPhase(leg: leg, stops: stops, nearest: true);
    final pinned = book.orders[phase];
    if (canKeepOrder(pinned: pinned, open: openStopIds(stops, gate?.stopId), busKnown: bus != null)) {
      return arrangeRun(
        stops: stops,
        leg: leg,
        nearest: true,
        bus: bus,
        school: gate,
        keepOrder: pinned!.order,
      ).kept(pinned.basis, pinned.road);
    }

    final placed = <String, LatLng>{};
    for (final s in stops) {
      if (s.done || !stopIsPlaced(s)) continue;
      final p = LatLng(s.lat!, s.lon!);
      placed['${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}'] ??= p;
    }
    if (leg == 'RETURN' && gate != null && gate.placed) {
      final p = LatLng(gate.lat!, gate.lon!);
      placed['${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}'] ??= p;
    }
    final among = placed.values.toList();

    Directions.rememberMatrix(book.matrix);
    var road = true;
    if (among.length > 1) {
      road = await Directions.travelTimes(among).timeout(_roadWait, onTimeout: () => false);
      if (road) RunRouteCache.keepMatrix(tripId, Directions.matrixAmong(among));
    }

    LatLng stand(LatLng p) {
      if (!identical(p, bus)) return p;
      for (final known in among) {
        if (metresBetween(known, p) <= busLegFromStopMetres) return known;
      }
      return p;
    }

    double travel(LatLng a, LatLng b) =>
        Directions.seconds(stand(a), stand(b)) ?? metresBetween(a, b) / 8.0;

    final run = arrangeRun(
      stops: stops,
      leg: leg,
      nearest: true,
      bus: bus,
      school: gate,
      cost: road ? travel : null,
      road: road,
    );
    RunRouteCache.keepOrder(
      tripId,
      phase,
      PinnedOrder(
        order: [
          for (final s in run.stops)
            if (!s.done && stopIsPlaced(s) && !isSchoolStop(s, gate?.stopId)) s.stopId,
        ],
        basis: run.basis,
        road: run.road,
      ),
    );
    return run;
  }
}
