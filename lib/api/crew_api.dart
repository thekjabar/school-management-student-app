import 'dart:math';

import 'client.dart';

/// A version 4 uuid, minted on the handset.
///
/// The custody ledger and the sweep record are both keyed on one, because the
/// key has to exist BEFORE the first send attempt: it is what makes a retry
/// over a dropped connection free rather than a second boarding.
String uuidV4() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int from, int to) =>
      bytes.sublist(from, to).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// A run the crew is on today.
class CrewTrip {
  CrewTrip({
    required this.id,
    required this.leg,
    required this.status,
    required this.serviceDate,
    required this.scheduledDepartureAt,
    required this.startedAt,
    required this.endedAt,
    required this.routeName,
    required this.routeColorHex,
    required this.vehicleLabel,
    required this.plate,
    required this.expected,
    required this.boarded,
    required this.alighted,
    required this.sweepRequired,
    required this.sweepConfirmedAt,
    required this.sweepDeadlineAt,
    required this.complianceGate,
    required this.complianceFailReasons,
  });

  final String id;
  final String leg;
  final String status;
  final DateTime serviceDate;
  final DateTime? scheduledDepartureAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String routeName;
  final String? routeColorHex;
  final String? vehicleLabel;
  final String? plate;
  final int expected;
  final int boarded;
  final int alighted;
  final bool sweepRequired;
  final DateTime? sweepConfirmedAt;
  final DateTime? sweepDeadlineAt;
  final String complianceGate;
  final List<String> complianceFailReasons;

  bool get running => status == 'IN_PROGRESS' || status == 'BOARDING';
  bool get finished => status == 'COMPLETED';

  /// The cabin sweep is owed and has not happened. The single most dangerous
  /// state in the system — it is how a child is left on a bus.
  bool get sweepOwed => sweepRequired && endedAt != null && sweepConfirmedAt == null;

  static DateTime? _at(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

  factory CrewTrip.fromJson(Map<String, dynamic> j) {
    final route = (j['route'] ?? {}) as Map<String, dynamic>;
    return CrewTrip(
      id: j['id'] as String,
      leg: (j['leg'] ?? 'OUT') as String,
      status: (j['status'] ?? '') as String,
      serviceDate: DateTime.parse(j['serviceDate'] as String).toLocal(),
      scheduledDepartureAt: _at(j['scheduledDepartureAt']),
      startedAt: _at(j['startedAt']),
      endedAt: _at(j['endedAt']),
      routeName: (route['name'] ?? 'Route') as String,
      routeColorHex: route['colorHex'] as String?,
      vehicleLabel: j['vehicleLabelSnapshot'] as String?,
      plate: j['plateSnapshot'] as String?,
      expected: (j['expectedStudentCount'] as num?)?.toInt() ?? 0,
      boarded: (j['boardedCount'] as num?)?.toInt() ?? 0,
      alighted: (j['alightedCount'] as num?)?.toInt() ?? 0,
      sweepRequired: (j['sweepRequired'] ?? true) as bool,
      sweepConfirmedAt: _at(j['sweepConfirmedAt']),
      sweepDeadlineAt: _at(j['sweepDeadlineAt']),
      complianceGate: (j['complianceGate'] ?? 'NOT_CHECKED') as String,
      complianceFailReasons: ((j['complianceFailReasons'] as List?) ?? []).cast<String>(),
    );
  }
}

/// One child on a stop's list.
class RiderOnStop {
  RiderOnStop({
    required this.studentId,
    required this.name,
    required this.seatNumber,
    required this.requiresAssistance,
    required this.boardedAt,
    required this.alightedAt,
  });

  final String studentId;
  final String name;
  final String? seatNumber;
  final bool requiresAssistance;
  final DateTime? boardedAt;
  final DateTime? alightedAt;

  bool get accountedFor => boardedAt != null || alightedAt != null;

  factory RiderOnStop.fromJson(Map<String, dynamic> j) => RiderOnStop(
        studentId: j['studentId'] as String,
        name: (j['name'] ?? 'Student') as String,
        seatNumber: j['seatNumber'] as String?,
        requiresAssistance: (j['requiresAssistance'] ?? false) as bool,
        boardedAt: j['boardedAt'] == null ? null : DateTime.parse(j['boardedAt'] as String).toLocal(),
        alightedAt: j['alightedAt'] == null ? null : DateTime.parse(j['alightedAt'] as String).toLocal(),
      );
}

/// A stop on the run, with the children who belong to it.
class PlannedStop {
  PlannedStop({
    required this.stopId,
    required this.name,
    required this.landmark,
    required this.lat,
    required this.lon,
    required this.plannedSequence,
    required this.metresAway,
    required this.students,
    required this.arrivedAt,
    required this.departedAt,
  });

  final String stopId;
  final String name;
  final String? landmark;
  final double? lat;
  final double? lon;
  final int plannedSequence;
  final int? metresAway;
  final List<RiderOnStop> students;
  final DateTime? arrivedAt;
  final DateTime? departedAt;

  bool get done => departedAt != null;
  int get remaining => students.where((s) => !s.accountedFor).length;

  factory PlannedStop.fromJson(Map<String, dynamic> j) => PlannedStop(
        stopId: j['stopId'] as String,
        name: (j['name'] ?? '') as String,
        landmark: j['landmarkDescription'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        plannedSequence: (j['plannedSequence'] as num?)?.toInt() ?? 0,
        metresAway: (j['metresAway'] as num?)?.toInt(),
        students: ((j['students'] as List?) ?? [])
            .map((e) => RiderOnStop.fromJson(e as Map<String, dynamic>))
            .toList(),
        arrivedAt: j['arrivedAt'] == null ? null : DateTime.parse(j['arrivedAt'] as String).toLocal(),
        departedAt: j['departedAt'] == null ? null : DateTime.parse(j['departedAt'] as String).toLocal(),
      );
}

class Headcount {
  Headcount({
    required this.onRegister,
    required this.notComingToday,
    required this.expected,
    required this.boarded,
    required this.alighted,
    required this.stillOnBoard,
    required this.stopsTotal,
    required this.stopsDone,
    required this.summary,
    required this.excluded,
  });

  final int onRegister;
  final int notComingToday;
  final int expected;
  final int boarded;
  final int alighted;
  final int stillOnBoard;
  final int stopsTotal;
  final int stopsDone;
  final String summary;
  final List<String> excluded;

  factory Headcount.fromJson(Map<String, dynamic> j) => Headcount(
        onRegister: (j['onRegister'] as num?)?.toInt() ?? 0,
        notComingToday: (j['notComingToday'] as num?)?.toInt() ?? 0,
        expected: (j['expected'] as num?)?.toInt() ?? 0,
        boarded: (j['boarded'] as num?)?.toInt() ?? 0,
        alighted: (j['alighted'] as num?)?.toInt() ?? 0,
        stillOnBoard: (j['stillOnBoard'] as num?)?.toInt() ?? 0,
        stopsTotal: (j['stopsTotal'] as num?)?.toInt() ?? 0,
        stopsDone: (j['stopsDone'] as num?)?.toInt() ?? 0,
        summary: (j['summary'] ?? '') as String,
        excluded: ((j['excluded'] as List?) ?? [])
            .map((e) => e is Map ? (e['name'] ?? e['studentId'] ?? '').toString() : e.toString())
            .toList(),
      );
}

/// The plan for a run: the stops in the order they should be driven.
class TripPlan {
  TripPlan({
    required this.ordering,
    required this.orderingNote,
    required this.counts,
    required this.stops,
  });

  /// "planned" — the office's order — or "nearest", recomputed from where the
  /// bus actually is.
  final String ordering;
  final String orderingNote;
  final Headcount counts;
  final List<PlannedStop> stops;

  factory TripPlan.fromJson(Map<String, dynamic> j) => TripPlan(
        ordering: (j['ordering'] ?? 'planned') as String,
        orderingNote: (j['orderingNote'] ?? '') as String,
        counts: Headcount.fromJson((j['counts'] ?? {}) as Map<String, dynamic>),
        stops: ((j['stops'] as List?) ?? [])
            .map((e) => PlannedStop.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SweepState {
  SweepState({
    required this.required_,
    required this.confirmedAt,
    required this.deadlineAt,
    required this.secondsRemaining,
    required this.attemptsSoFar,
    required this.tagFitted,
  });

  final bool required_;
  final DateTime? confirmedAt;
  final DateTime? deadlineAt;
  final int? secondsRemaining;
  final int attemptsSoFar;
  final bool tagFitted;

  factory SweepState.fromJson(Map<String, dynamic> j) => SweepState(
        required_: (j['sweepRequired'] ?? true) as bool,
        confirmedAt: j['sweepConfirmedAt'] == null
            ? null
            : DateTime.parse(j['sweepConfirmedAt'] as String).toLocal(),
        deadlineAt:
            j['deadlineAt'] == null ? null : DateTime.parse(j['deadlineAt'] as String).toLocal(),
        secondsRemaining: (j['secondsRemaining'] as num?)?.toInt(),
        attemptsSoFar: (j['attemptsSoFar'] as num?)?.toInt() ?? 0,
        tagFitted: (j['tagFitted'] ?? false) as bool,
      );
}

/// Everything the driver and attendant app asks the platform for.
class CrewApi {
  CrewApi._();

  static final CrewApi instance = CrewApi._();
  final ApiClient _api = ApiClient.instance;

  Future<List<CrewTrip>> today() async {
    final json = await _api.get('/crew/duty/today');
    return Paged.from<CrewTrip>(json, CrewTrip.fromJson).rows;
  }

  Future<List<CrewTrip>> trips({String? date}) async {
    final json = await _api.get('/crew/trips${date != null ? '?serviceDate=$date' : ''}');
    return Paged.from<CrewTrip>(json, CrewTrip.fromJson).rows;
  }

  /// The plan. Pass a position to have the office's order replaced by the
  /// nearest stop first — which is what a driver actually wants when a road is
  /// shut and they have come at the route from the wrong end.
  Future<TripPlan> plan(String tripId, {double? lat, double? lon, bool nearest = false}) async {
    final query = <String>[
      if (nearest) 'order=nearest',
      if (lat != null) 'lat=$lat',
      if (lon != null) 'lon=$lon',
    ];
    final json = await _api.get('/crew/trips/$tripId/plan${query.isEmpty ? '' : '?${query.join('&')}'}');
    return TripPlan.fromJson(json as Map<String, dynamic>);
  }

  Future<Headcount> headcount(String tripId) async {
    final json = await _api.get('/crew/trips/$tripId/headcount');
    return Headcount.fromJson(json as Map<String, dynamic>);
  }

  Future<SweepState> sweepState(String tripId) async {
    final json = await _api.get('/crew/sweep/trips/$tripId');
    return SweepState.fromJson(json as Map<String, dynamic>);
  }

  Future<void> startShift(String tripId) => _api.post('/crew/trips/$tripId/shift-start');

  Future<void> depart(String tripId) => _api.post('/crew/trips/$tripId/depart');

  Future<void> endTrip(String tripId) => _api.post('/crew/trips/$tripId/end');

  Future<void> arriveAtStop(String tripId, int sequence) =>
      _api.post('/crew/trips/$tripId/stops/$sequence/arrive');

  Future<void> leaveStop(String tripId, int sequence) =>
      _api.post('/crew/trips/$tripId/stops/$sequence/depart');

  /// Record that a child got on or off.
  ///
  /// The EVENT, not the resulting state. The ledger is what a school can defend
  /// six months later, and "who says she got off, and at what time" is the only
  /// question that matters when a family says she did not come home.
  ///
  /// The uuid is minted HERE, before the first attempt, and reused on every
  /// retry. That is what stops a dropped connection over a patchy cell from
  /// boarding the same child twice — the server treats a repeat as a duplicate
  /// and says so, rather than writing a second row.
  Future<void> recordCustody({
    required String tripId,
    required String studentId,
    required String eventType,
    String? stopId,
    double? lat,
    double? lon,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _api.post('/crew/custody/events', {
      'tripInstanceId': tripId,
      'clientSentAt': now,
      'events': [
        {
          'id': uuidV4(),
          'type': eventType,
          'studentId': studentId,
          'deviceTime': now,
          'stopId': ?stopId,
          // The crew app has no scanner in this build, so every event is a
          // deliberate tap by a named person with a reason attached. The
          // server records the weaker method rather than being told a tag was
          // read when none was.
          'captureMethod': 'MANUAL_WITH_REASON',
          'manualReason': 'Marked by the crew on the bus.',
          'lat': ?lat,
          'lon': ?lon,
        },
      ],
    });
  }

  /// Confirm the cabin was walked to the back seat.
  ///
  /// MANUAL_ATTESTATION is the honest method for a phone with no tag reader: it
  /// records that somebody SAID they walked the aisle, and the platform grades
  /// it as weaker evidence than a tag scan precisely because it is. Claiming a
  /// scan the handset never performed would corrupt the one number a school
  /// would be judged on.
  Future<void> confirmSweep(String tripId, {String outcome = 'CLEAR'}) async {
    await _api.post('/crew/sweep/scan', {
      'eventId': uuidV4(),
      'tripInstanceId': tripId,
      'method': 'MANUAL_ATTESTATION',
      'outcome': outcome,
      'scannedAt': DateTime.now().toUtc().toIso8601String(),
      'clientSentAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> me() async =>
      await _api.get('/crew/me') as Map<String, dynamic>;
}
