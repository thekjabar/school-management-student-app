import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;

import '../i18n/strings.dart';
import 'attachments.dart';
import 'client.dart';

String uuidV4() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int from, int to) =>
      bytes.sublist(from, to).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

const Set<String> kLiveTripStatuses = {
  'PLANNED',
  'ROSTERED',
  'BLOCKED',
  'BOARDING',
  'IN_PROGRESS',
  'ARRIVED',
  'SWEEP_PENDING',
  'SWEEP_OVERDUE',
};

const Set<String> kClosedTripStatuses = {
  'COMPLETED',
  'CANCELLED',
  'ABANDONED',
  'VOID',
};

const Set<String> kBoardingEvents = {
  'BOARDED',
  'WRONG_BUS',
  'TRANSFER_INTO_VEHICLE',
};

const Set<String> kAlightingEvents = {
  'ALIGHTED',
  'WRONG_STOP',
  'HANDOVER',
};

const String kCrewPhoneDeviceKind = 'CREW_PHONE';

String? custodyStopId({
  required String leg,
  required String eventType,
  String? riderStopId,
  String? terminalStopId,
}) {
  final alighting = kAlightingEvents.contains(eventType);
  final atOwnStop = leg == 'RETURN' ? alighting : !alighting;
  return atOwnStop ? riderStopId : terminalStopId;
}

class CustodyVerdict {
  const CustodyVerdict({
    required this.accepted,
    this.duplicate = false,
    this.reason,
    this.rewrittenTo,
    this.alertRaised = false,
  });

  final bool accepted;

  final bool duplicate;

  final String? reason;

  final String? rewrittenTo;

  final bool alertRaised;
}

const int kMaxCustodyBatchEvents = 200;

class CustodyEntry {
  const CustodyEntry({
    required this.studentId,
    required this.eventType,
    this.stopId,
  });

  final String studentId;
  final String eventType;

  final String? stopId;
}

class CustodyOutcome {
  const CustodyOutcome({required this.studentId, required this.verdict});

  final String studentId;
  final CustodyVerdict verdict;
}

class TelemetryPolicy {
  const TelemetryPolicy({
    required this.activeTripIntervalSeconds,
    required this.idleIntervalSeconds,
    required this.maxBatchPoints,
  });

  final int activeTripIntervalSeconds;
  final int idleIntervalSeconds;
  final int maxBatchPoints;

  static const TelemetryPolicy fallback = TelemetryPolicy(
    activeTripIntervalSeconds: 15,
    idleIntervalSeconds: 120,
    maxBatchPoints: 200,
  );

  factory TelemetryPolicy.fromJson(Map<String, dynamic> j) => TelemetryPolicy(
        activeTripIntervalSeconds:
            (j['activeTripIntervalSeconds'] as num?)?.toInt() ??
                fallback.activeTripIntervalSeconds,
        idleIntervalSeconds: (j['idleIntervalSeconds'] as num?)?.toInt() ??
            fallback.idleIntervalSeconds,
        maxBatchPoints:
            (j['maxBatchPoints'] as num?)?.toInt() ?? fallback.maxBatchPoints,
      );
}

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

  bool get running => status == 'IN_PROGRESS' || status == 'ARRIVED';

  bool get underway =>
      status == 'BOARDING' ||
      status == 'IN_PROGRESS' ||
      status == 'ARRIVED' ||
      status == 'SWEEP_PENDING' ||
      status == 'SWEEP_OVERDUE';

  bool get live => kLiveTripStatuses.contains(status);

  bool get closed => kClosedTripStatuses.contains(status);

  bool get finished => status == 'COMPLETED';

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

class RiderOnStop {
  RiderOnStop({
    required this.studentId,
    required this.name,
    required this.seatNumber,
    required this.requiresAssistance,
    required this.boardedAt,
    required this.alightedAt,
    this.resolution,
  });

  final String studentId;
  final String name;
  final String? seatNumber;
  final bool requiresAssistance;
  final DateTime? boardedAt;
  final DateTime? alightedAt;

  final String? resolution;

  bool get accountedFor =>
      boardedAt != null || alightedAt != null || resolution == 'NO_SHOW';

  bool get notTravelling => resolution == 'NO_SHOW';

  factory RiderOnStop.fromJson(Map<String, dynamic> j) => RiderOnStop(
        studentId: j['studentId'] as String,
        name: (j['name'] ?? 'Student') as String,
        seatNumber: j['seatNumber'] as String?,
        requiresAssistance: (j['requiresAssistance'] ?? false) as bool,
        boardedAt: j['boardedAt'] == null ? null : DateTime.parse(j['boardedAt'] as String).toLocal(),
        alightedAt: j['alightedAt'] == null ? null : DateTime.parse(j['alightedAt'] as String).toLocal(),
        resolution: j['resolution'] as String?,
      );
}

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
    required this.skipped,
    this.skippedReason,
    required this.etaAt,
    required this.etaIsActual,
    required this.dwellSeconds,
    required this.driveSeconds,
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

  final bool skipped;
  final String? skippedReason;

  final DateTime? etaAt;

  final bool etaIsActual;

  final int dwellSeconds;

  final int driveSeconds;

  bool get done => departedAt != null || skipped;
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
        skipped: (j['skipped'] ?? false) as bool,
        skippedReason: j['skippedReason'] as String?,
        etaAt: j['etaAt'] == null ? null : DateTime.parse(j['etaAt'] as String).toLocal(),
        etaIsActual: (j['etaIsActual'] ?? false) as bool,
        dwellSeconds: (j['dwellSeconds'] as num?)?.toInt() ?? 0,
        driveSeconds: (j['driveSeconds'] as num?)?.toInt() ?? 0,
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

class TripTiming {
  TripTiming({
    required this.departByAt,
    required this.mustArriveBy,
    required this.scheduledDepartureAt,
    required this.startedAt,
    required this.driveSeconds,
    required this.dwellSeconds,
    required this.estimatedDurationSeconds,
    required this.slackSeconds,
    required this.secondsPerStudent,
  });

  final DateTime? departByAt;

  final DateTime? mustArriveBy;

  final DateTime? scheduledDepartureAt;

  final DateTime? startedAt;

  final int driveSeconds;

  final int dwellSeconds;

  final int estimatedDurationSeconds;

  final int? slackSeconds;

  final int secondsPerStudent;

  bool get hasDepartBy => departByAt != null;

  bool get tooTight => (slackSeconds ?? 0) < 0;

  int get shortByMinutes => (-(slackSeconds ?? 0) / 60).ceil();

  static DateTime? _at(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

  factory TripTiming.fromJson(Map<String, dynamic> j) => TripTiming(
        departByAt: _at(j['departByAt']),
        mustArriveBy: _at(j['mustArriveBy']),
        scheduledDepartureAt: _at(j['scheduledDepartureAt']),
        startedAt: _at(j['startedAt']),
        driveSeconds: (j['driveSeconds'] as num?)?.toInt() ?? 0,
        dwellSeconds: (j['dwellSeconds'] as num?)?.toInt() ?? 0,
        estimatedDurationSeconds: (j['estimatedDurationSeconds'] as num?)?.toInt() ?? 0,
        slackSeconds: (j['slackSeconds'] as num?)?.toInt(),
        secondsPerStudent: (j['secondsPerStudent'] as num?)?.toInt() ?? 0,
      );
}

class TripPlan {
  TripPlan({
    required this.ordering,
    required this.orderingNote,
    required this.counts,
    required this.stops,
    required this.timing,
    this.terminalArrivedAt,
  });

  final String ordering;
  final String orderingNote;
  final Headcount counts;
  final List<PlannedStop> stops;

  final TripTiming timing;

  final DateTime? terminalArrivedAt;

  factory TripPlan.fromJson(Map<String, dynamic> j) => TripPlan(
        ordering: (j['ordering'] ?? 'planned') as String,
        orderingNote: (j['orderingNote'] ?? '') as String,
        counts: Headcount.fromJson((j['counts'] ?? {}) as Map<String, dynamic>),
        stops: ((j['stops'] as List?) ?? [])
            .map((e) => PlannedStop.fromJson(e as Map<String, dynamic>))
            .toList(),
        timing: TripTiming.fromJson(
            (j['timing'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
        terminalArrivedAt: (j['trip'] as Map<String, dynamic>?)?['terminalArrivedAt'] == null
            ? null
            : DateTime.parse((j['trip'] as Map<String, dynamic>)['terminalArrivedAt'] as String)
                .toLocal(),
      );
}

const String kInspectionPass = 'PASS';
const String kInspectionPassWithDefects = 'PASS_WITH_DEFECTS';
const String kInspectionFail = 'FAIL';
const String kInspectionNotCompleted = 'NOT_COMPLETED';

const String kCrewInspectionPhoto = 'INSPECTION_PHOTO';

const String kPreTripChecklistVersion = 'ksp-crew-pretrip-1';

class PreTripCheck {
  PreTripCheck({
    required this.clientUuid,
    required this.items,
    required this.outcome,
    required this.durationSeconds,
    required this.selfieAssetId,
    this.itemsFailedCount,
    this.odometerKm,
    this.notes,
  });

  final String clientUuid;

  final Map<String, String> items;

  final String outcome;

  final int durationSeconds;

  final String selfieAssetId;

  final int? itemsFailedCount;
  final int? odometerKm;
  final String? notes;
}

class SweepState {
  SweepState({
    required this.required_,
    required this.confirmedAt,
    required this.deadlineAt,
    required this.secondsRemaining,
    required this.attemptsSoFar,
    required this.tagFitted,
    required this.lastAlightingAt,
    required this.minSecondsAfterLastAlighting,
    required this.confirmableFrom,
  });

  final bool required_;
  final DateTime? confirmedAt;
  final DateTime? deadlineAt;
  final int? secondsRemaining;
  final int attemptsSoFar;
  final bool tagFitted;

  final DateTime? lastAlightingAt;

  final int? minSecondsAfterLastAlighting;

  final DateTime? confirmableFrom;

  int get secondsUntilConfirmable {
    final from = confirmableFrom;
    if (from == null) return 0;
    final left = from.difference(DateTime.now());
    if (left <= Duration.zero) return 0;
    return (left.inMilliseconds / 1000).ceil();
  }

  bool get confirmable => secondsUntilConfirmable <= 0;

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
        lastAlightingAt: j['lastAlightingAt'] == null
            ? null
            : DateTime.parse(j['lastAlightingAt'] as String).toLocal(),
        minSecondsAfterLastAlighting:
            (j['minSecondsAfterLastAlighting'] as num?)?.toInt(),
        confirmableFrom: j['confirmableFrom'] == null
            ? null
            : DateTime.parse(j['confirmableFrom'] as String).toLocal(),
      );
}

class SweepVerdict {
  const SweepVerdict({
    required this.genuine,
    required this.withinDeadline,
    required this.rubberStamped,
    required this.rubberStampReasons,
    required this.duplicate,
    required this.alertsRaised,
    this.deadlineSeconds,
    this.secondsFromTripEnd,
    this.confidenceScore,
    this.unaccountedCount,
  });

  final bool genuine;

  final bool withinDeadline;

  final bool rubberStamped;

  final List<String> rubberStampReasons;

  final bool duplicate;

  final List<String> alertsRaised;

  final int? deadlineSeconds;

  final int? secondsFromTripEnd;

  final int? confidenceScore;

  final int? unaccountedCount;

  static SweepVerdict from(Object? json) => json is Map
      ? SweepVerdict.fromJson(json.cast<String, dynamic>())
      : const SweepVerdict(
          genuine: false,
          withinDeadline: true,
          rubberStamped: false,
          rubberStampReasons: [],
          duplicate: false,
          alertsRaised: [],
        );

  factory SweepVerdict.fromJson(Map<String, dynamic> j) => SweepVerdict(
        genuine: j['genuine'] == true,
        withinDeadline: (j['withinDeadline'] as bool?) ?? true,
        rubberStamped: j['rubberStamped'] == true,
        rubberStampReasons: [
          for (final r in (j['rubberStampReasons'] as List?) ?? const []) '$r',
        ],
        duplicate: j['duplicate'] == true,
        alertsRaised: [
          for (final a in (j['alertsRaised'] as List?) ?? const []) '$a',
        ],
        deadlineSeconds: (j['deadlineSeconds'] as num?)?.toInt(),
        secondsFromTripEnd: (j['secondsFromTripEnd'] as num?)?.toInt(),
        confidenceScore: (j['confidenceScore'] as num?)?.toInt(),
        unaccountedCount: ((j['reconciliation'] as Map?)?['unaccountedCount'] as num?)?.toInt(),
      );
}

class CrewAnnouncement {
  CrewAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.priority,
    required this.sentAt,
    required this.pinned,
    required this.requiresAcknowledgement,
    this.acknowledgedAt,
    required this.authorName,
    required this.readAt,
    required this.attachmentCount,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final String priority;
  final DateTime? sentAt;
  final bool pinned;

  final bool requiresAcknowledgement;

  final DateTime? acknowledgedAt;
  final String authorName;
  final DateTime? readAt;

  final int attachmentCount;

  bool get isRead => readAt != null;

  bool get settled => isRead && (!requiresAcknowledgement || acknowledgedAt != null);

  factory CrewAnnouncement.fromJson(Map<String, dynamic> j) => CrewAnnouncement(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        category: (j['category'] ?? 'ANNOUNCEMENT') as String,
        priority: (j['priority'] ?? 'NORMAL') as String,
        sentAt: j['sentAt'] == null ? null : DateTime.parse(j['sentAt'] as String).toLocal(),
        pinned: (j['pinned'] ?? false) as bool,
        requiresAcknowledgement: (j['requiresAcknowledgement'] ?? false) as bool,
        acknowledgedAt: j['acknowledgedAt'] == null
            ? null
            : DateTime.parse(j['acknowledgedAt'] as String).toLocal(),
        authorName: (j['authorName'] ?? '') as String,
        readAt: j['readAt'] == null ? null : DateTime.parse(j['readAt'] as String).toLocal(),
        attachmentCount: (j['attachmentCount'] as num?)?.toInt() ?? 0,
      );
}

class Credential {
  Credential({
    required this.id,
    required this.kind,
    required this.label,
    required this.status,
    required this.derivedStatus,
    required this.number,
    required this.expiresOn,
    required this.rosterBlockFrom,
    required this.daysUntilRosterBlock,
    required this.rejectedReason,
  });

  final String id;
  final String kind;

  final String label;

  final String status;

  final String derivedStatus;
  final String? number;
  final DateTime? expiresOn;
  final DateTime? rosterBlockFrom;

  final int? daysUntilRosterBlock;
  final String? rejectedReason;

  bool get blocking =>
      daysUntilRosterBlock != null && daysUntilRosterBlock! <= 0 ||
      derivedStatus == 'EXPIRED' ||
      derivedStatus == 'REVOKED' ||
      derivedStatus == 'SUSPENDED';

  bool get expiringSoon =>
      !blocking && daysUntilRosterBlock != null && daysUntilRosterBlock! <= 14;

  factory Credential.fromJson(Map<String, dynamic> j) => Credential(
        id: (j['id'] ?? '') as String,
        kind: (j['kind'] ?? 'OTHER') as String,
        label: (j['label'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        derivedStatus: (j['derivedStatus'] ?? j['status'] ?? '') as String,
        number: j['number'] as String?,
        expiresOn: DateTime.tryParse((j['expiresOn'] ?? '') as String)?.toLocal(),
        rosterBlockFrom: DateTime.tryParse((j['rosterBlockFrom'] ?? '') as String)?.toLocal(),
        daysUntilRosterBlock: (j['daysUntilRosterBlock'] as num?)?.toInt(),
        rejectedReason: j['rejectedReason'] as String?,
      );
}

class CrewApi {
  CrewApi._();

  static final CrewApi instance = CrewApi._();
  final ApiClient _api = ApiClient.instance;

  Future<List<CrewTrip>> today() async {
    final json = await _api.get('/crew/duty/today');
    return Paged.from<CrewTrip>(json, CrewTrip.fromJson).rows;
  }

  Future<List<CrewTrip>> trips({String? date, int? days}) async {
    final query = date != null
        ? '?date=$date'
        : days != null
            ? '?days=$days&pageSize=50'
            : '';
    final json = await _api.get('/crew/trips$query');
    return Paged.from<CrewTrip>(json, CrewTrip.fromJson).rows;
  }

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

  Future<String?> terminalStopId(String tripId) async {
    final json = await _api.get('/crew/trips/$tripId/pack') as Map<String, dynamic>;
    final progress = (json['stopProgress'] as List?) ?? const [];
    String? gate;
    for (final row in progress) {
      final stop = (row as Map<String, dynamic>)['stop'] as Map<String, dynamic>?;
      if (stop != null && stop['isCampusGate'] == true) {
        gate = stop['id'] as String?;
      }
    }
    return gate;
  }

  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String mime,
    required String filename,
    String kind = kCrewInspectionPhoto,
    DateTime? capturedAt,
  }) async {
    final json = await _api.upload(
      '/crew/uploads/direct',
      field: 'file',
      bytes: bytes,
      filename: filename,
      mime: mime,
      fields: {
        'kind': kind,
        'capturedAt': ?capturedAt?.toUtc().toIso8601String(),
      },
    );
    final id = json is Map<String, dynamic> ? json['id'] : null;
    if (id is! String || id.isEmpty) {
      throw ApiException(t('driver.pretrip.selfieNoId'), 0);
    }
    return id;
  }

  Future<void> startShift(String tripId, PreTripCheck check) async {
    await _api.post('/crew/trips/$tripId/shift-start', {
      'clientUuid': check.clientUuid,
      'checklistVersion': kPreTripChecklistVersion,
      'items': check.items,
      'outcome': check.outcome,
      'durationSeconds': check.durationSeconds,
      'selfieAssetId': check.selfieAssetId,
      'deviceTime': DateTime.now().toUtc().toIso8601String(),
      'itemsFailedCount': ?check.itemsFailedCount,
      'odometerKm': ?check.odometerKm,
      'notes': ?check.notes,
    });
  }

  Future<void> depart(String tripId) => _api.post('/crew/trips/$tripId/depart');

  Future<int> endTrip(String tripId) async {
    final json = await _api.post('/crew/trips/$tripId/end') as Map<String, dynamic>;
    return (json['unaccounted'] as num?)?.toInt() ?? 0;
  }

  Future<void> arriveAtStop(String tripId, int sequence) =>
      _api.post('/crew/trips/$tripId/stops/$sequence/arrive');

  Future<void> leaveStop(String tripId, int sequence) =>
      _api.post('/crew/trips/$tripId/stops/$sequence/depart');

  Future<TelemetryPolicy> telemetryPolicy() async {
    final j = await _api.get('/crew/telemetry/policy') as Map<String, dynamic>;
    return TelemetryPolicy.fromJson(j);
  }

  Future<void> sendPositions({
    required String tripInstanceId,
    required List<Map<String, dynamic>> points,
  }) =>
      _api.post('/crew/telemetry/positions', {
        'tripInstanceId': tripInstanceId,
        'points': points,
      });

  Future<void> skipStop(String tripId, int sequence, String reason) =>
      _api.post('/crew/trips/$tripId/stops/$sequence/skip', {'reason': reason});

  Future<CustodyVerdict> recordCustody({
    required String tripId,
    required String studentId,
    required String eventType,
    String? stopId,
    double? lat,
    double? lon,
    int? gpsAccuracyM,
    int? positionAgeMs,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = uuidV4();
    final json = await _api.post('/crew/custody/events', {
      'tripInstanceId': tripId,
      'clientSentAt': now,
      'events': [
        {
          'id': id,
          'type': eventType,
          'studentId': studentId,
          'deviceTime': now,
          'stopId': ?stopId,
          'captureMethod': 'MANUAL_WITH_REASON',
          'manualReason': 'Marked by the crew on the bus.',
          'lat': ?lat,
          'lon': ?lon,
          'gpsAccuracyM': ?gpsAccuracyM,
          'positionAgeMs': ?positionAgeMs,
        },
      ],
    }) as Map<String, dynamic>;

    final results = (json['results'] as List?) ?? const [];
    final mine = results.cast<Map<String, dynamic>>().where((r) => r['id'] == id).firstOrNull;
    if (mine == null) return const CustodyVerdict(accepted: false);

    final outcome = (mine['outcome'] ?? '') as String;
    if (outcome == 'REJECTED') {
      return CustodyVerdict(accepted: false, reason: mine['reason'] as String?);
    }

    final recorded = mine['recordedType'] as String?;
    return CustodyVerdict(
      accepted: true,
      duplicate: outcome == 'DUPLICATE',
      rewrittenTo: recorded != null && recorded != eventType ? recorded : null,
      alertRaised: mine['alertRaised'] == true,
    );
  }

  Future<CustodyVerdict> correctCustody({
    required String eventId,
    required String correctedType,
    required String correctionReason,
    String? stopId,
  }) async {
    final id = uuidV4();
    final json = await _api.post('/crew/custody/events/$eventId/correction', {
      'id': id,
      'type': correctedType,
      'correctionReason': correctionReason,
      'deviceTime': DateTime.now().toUtc().toIso8601String(),
      'stopId': ?stopId,
    }) as Map<String, dynamic>;

    final results = (json['results'] as List?) ?? const [];
    final mine = results.cast<Map<String, dynamic>>().where((r) => r['id'] == id).firstOrNull;
    if (mine == null) return const CustodyVerdict(accepted: false);

    final outcome = (mine['outcome'] ?? '') as String;
    if (outcome == 'REJECTED') {
      return CustodyVerdict(accepted: false, reason: mine['reason'] as String?);
    }
    final recorded = mine['recordedType'] as String?;
    return CustodyVerdict(
      accepted: true,
      duplicate: outcome == 'DUPLICATE',
      rewrittenTo: recorded != null && recorded != correctedType ? recorded : null,
      alertRaised: mine['alertRaised'] == true,
    );
  }

  Future<List<Map<String, dynamic>>> tripCustodyEvents(String tripId) async {
    final json = await _api.get('/crew/custody/trips/$tripId/events?pageSize=200');
    return Paged.from<Map<String, dynamic>>(json, (m) => m).rows;
  }

  Future<List<CustodyOutcome>> recordCustodyBatch({
    required String tripId,
    required List<CustodyEntry> entries,
  }) async {
    final out = <CustodyOutcome>[];
    for (var from = 0; from < entries.length; from += kMaxCustodyBatchEvents) {
      final chunk = entries.sublist(
        from,
        min(from + kMaxCustodyBatchEvents, entries.length),
      );
      try {
        out.addAll(await _sendCustodyBatch(tripId, chunk));
      } catch (e) {
        if (out.isEmpty) rethrow;
        out.addAll([
          for (final entry in chunk)
            CustodyOutcome(
              studentId: entry.studentId,
              verdict: CustodyVerdict(accepted: false, reason: _failureText(e)),
            ),
        ]);
      }
    }
    return out;
  }

  Future<List<CustodyOutcome>> _sendCustodyBatch(
    String tripId,
    List<CustodyEntry> chunk,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final ids = [for (final _ in chunk) uuidV4()];

    final json = await _api.post('/crew/custody/events', {
      'tripInstanceId': tripId,
      'clientSentAt': now,
      'events': [
        for (var i = 0; i < chunk.length; i++)
          {
            'id': ids[i],
            'type': chunk[i].eventType,
            'studentId': chunk[i].studentId,
            'deviceTime': now,
            'stopId': ?chunk[i].stopId,
            'captureMethod': 'MANUAL_WITH_REASON',
            'manualReason': 'Marked off together by the crew as the bus emptied.',
          },
      ],
    }) as Map<String, dynamic>;

    final results =
        ((json['results'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final byId = <String, Map<String, dynamic>>{
      for (final r in results)
        if (r['id'] is String) r['id'] as String: r,
    };

    return [
      for (var i = 0; i < chunk.length; i++)
        CustodyOutcome(
          studentId: chunk[i].studentId,
          verdict: _verdictFrom(byId[ids[i]], chunk[i].eventType),
        ),
    ];
  }

  static CustodyVerdict _verdictFrom(Map<String, dynamic>? row, String asked) {
    if (row == null) return const CustodyVerdict(accepted: false);

    final outcome = (row['outcome'] ?? '') as String;
    if (outcome == 'REJECTED') {
      return CustodyVerdict(accepted: false, reason: row['reason'] as String?);
    }

    final recorded = row['recordedType'] as String?;
    return CustodyVerdict(
      accepted: true,
      duplicate: outcome == 'DUPLICATE',
      rewrittenTo: recorded != null && recorded != asked ? recorded : null,
      alertRaised: row['alertRaised'] == true,
    );
  }

  static String _failureText(Object e) => e is OfflineException
      ? t('common.offline')
      : e is ApiException
          ? e.message
          : t('common.loadFailed');

  Future<void> sos(String tripId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _api.post('/crew/custody/events', {
      'tripInstanceId': tripId,
      'clientSentAt': now,
      'events': [
        {
          'id': uuidV4(),
          'type': 'SOS',
          'deviceTime': now,
          'captureMethod': 'MANUAL_WITH_REASON',
          'manualReason': 'The crew pressed the panic button.',
        },
      ],
    });
  }

  Future<SweepVerdict> confirmSweep(String tripId, {String outcome = 'CLEAR'}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final json = await _api.post('/crew/sweep/scan', {
      'eventId': uuidV4(),
      'tripInstanceId': tripId,
      'method': 'MANUAL_ATTESTATION',
      'outcome': outcome,
      'scannedAt': now,
      'clientSentAt': now,
    });
    return SweepVerdict.from(json);
  }

  Future<SweepVerdict> sweepChildFound(
    String tripId, {
    required String studentId,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final json = await _api.post('/crew/sweep/scan', {
      'eventId': uuidV4(),
      'tripInstanceId': tripId,
      'method': 'MANUAL_ATTESTATION',
      'outcome': 'CHILD_FOUND',
      'childFoundStudentId': studentId,
      'notes': ?notes,
      'scannedAt': now,
      'clientSentAt': now,
    });
    return SweepVerdict.from(json);
  }

  Future<Map<String, dynamic>> me() async =>
      await _api.get('/crew/me') as Map<String, dynamic>;

  Future<List<Credential>> myCredentials() async {
    final json = await _api.get('/crew/me/credentials?pageSize=50');
    return Paged.from<Credential>(json, Credential.fromJson).rows;
  }

  Future<void> submitCredential({
    required String kind,
    String? number,
    DateTime? expiresOn,
    String? documentAssetId,
  }) async {
    await _api.post('/crew/me/credentials', {
      'kind': kind,
      'number': ?(number == null || number.trim().isEmpty ? null : number.trim()),
      'expiresOn': ?expiresOn?.toIso8601String(),
      'documentAssetId': ?documentAssetId,
    });
  }

  Future<String> uploadCredentialPhoto({
    required Uint8List bytes,
    required String filename,
    required String mime,
  }) async {
    final json = await _api.upload(
      '/crew/uploads/direct',
      field: 'file',
      bytes: bytes,
      filename: filename,
      mime: mime,
      fields: {'kind': 'STAFF_DOCUMENT'},
    );
    final id = json is Map ? json['id'] : null;
    if (id is! String || id.isEmpty) {
      throw ApiException('The photograph could not be stored.', 500);
    }
    return id;
  }

  final ValueNotifier<int> unreadAnnouncements = ValueNotifier<int>(0);

  Future<List<CrewAnnouncement>> announcements() async {
    final json = await _api.get('/crew/announcements?pageSize=50');
    final rows = Paged.from<CrewAnnouncement>(json, CrewAnnouncement.fromJson).rows;
    unreadAnnouncements.value = rows.where((a) => a.readAt == null).length;
    return rows;
  }

  Future<void> markAnnouncementRead(String id) =>
      _api.post('/crew/announcements/$id/read');

  Future<int> markAllAnnouncementsRead() async {
    final json = await _api.post('/crew/announcements/read-all');
    return ((json as Map<String, dynamic>?)?['marked'] as num?)?.toInt() ?? 0;
  }

  Future<void> acknowledgeAnnouncement(String id) =>
      _api.post('/crew/announcements/$id/acknowledge', const <String, dynamic>{});
  Future<List<AttachedFile>> announcementAttachments(String id) async {
    final json = await _api.get('/crew/announcements/$id/attachments?pageSize=50');
    return Paged.from<AttachedFile>(json, AttachedFile.fromJson).rows;
  }

  Future<String?> myCrewPhoneId() async {
    final json = await _api.get('/crew/me/devices?pageSize=50');
    final rows = Paged.from<Map<String, dynamic>>(json, (row) => row).rows;
    for (final row in rows) {
      final device = row['device'];
      if (device is! Map<String, dynamic>) continue;
      if (device['kind'] != kCrewPhoneDeviceKind) continue;
      final id = device['id'];
      if (id is String && id.isNotEmpty) return id;
    }
    return null;
  }

  Future<int?> sendHeartbeat(Map<String, dynamic> beat) async {
    final json = await _api.post('/crew/heartbeat', beat);
    return _heartbeatInterval(json);
  }

  Future<int?> flushHeartbeats(List<Map<String, dynamic>> beats) async {
    final json = await _api.post('/crew/heartbeat/flush', {'heartbeats': beats});
    return _heartbeatInterval(json);
  }

  static int? _heartbeatInterval(Object? json) => json is Map<String, dynamic>
      ? (json['nextHeartbeatSeconds'] as num?)?.toInt()
      : null;
}
