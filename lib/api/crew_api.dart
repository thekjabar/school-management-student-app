import 'dart:math';
import 'dart:typed_data';

import '../i18n/strings.dart';
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

/* ---------------------------------------------------------------------------
 * The server's vocabulary
 *
 * These are copied from transport-service — TripStatus in prisma/schema.prisma
 * and the event and capture enums at the top of custody.controller.ts. They are
 * written out rather than guessed at because a status string that is not one of
 * these matches nothing, and a filter that matches nothing does not fail: it
 * quietly passes everything through. `ENDED` was exactly that — a value no trip
 * has ever had, used to exclude finished runs, so none were excluded.
 * ------------------------------------------------------------------------- */

/// Statuses that mean the bus is still expected to do something today.
///
/// The same list as LIVE_TRIP_STATUSES in dispatch.service.ts.
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

/// Statuses that mean the run is over, one way or another. Nothing on a driver's
/// screen should ever offer to start, resume or end one of these.
const Set<String> kClosedTripStatuses = {
  'COMPLETED',
  'CANCELLED',
  'ABANDONED',
  'VOID',
};

/// Custody events that put a child ON the bus. BOARDING_TYPES in
/// custody.service.ts.
const Set<String> kBoardingEvents = {
  'BOARDED',
  'WRONG_BUS',
  'TRANSFER_INTO_VEHICLE',
};

/// Custody events that take a child OFF it. ALIGHTING_TYPES in the same file,
/// and the only ones the server judges against the expected stop.
const Set<String> kAlightingEvents = {
  'ALIGHTED',
  'WRONG_STOP',
  'HANDOVER',
};

/// The stop the bus is actually standing at when a custody event is recorded.
///
/// This mirrors `expectedStopFor()` in custody.service.ts, and it has to,
/// because the server compares the two and rewrites any mismatch.
///
/// The afternoon is not the morning backwards. On the OUT leg children board at
/// their own stop and get off at the campus gate; on the RETURN leg they board
/// at the gate and are handed over at their own stop. The app used to send the
/// child's own stop for every event on every leg — so every ordinary morning
/// drop-off at the school arrived with the child's HOME stop attached, the
/// server read that as a child put down somewhere they should not have been,
/// rewrote the row to WRONG_STOP and raised a CRITICAL safeguarding alert. One
/// per child, every morning. An office that gets forty of those before eight
/// o'clock stops reading them, and the one that matters arrives in the middle.
///
/// [riderStopId] is the stop the child belongs to — the card the row is drawn
/// under. [terminalStopId] is the campus gate. Either may be null, and a null
/// answer is deliberate: an event with no stopId is one the server records as
/// "not stated", which is honest, whereas the wrong stopId is an alarm.
///
/// NO_SHOW is neither a boarding nor an alighting, so the server never judges
/// its stop. It is sent as the stop the bus genuinely waited at — the child's
/// own stop in the morning, the gate in the afternoon — because the ledger is
/// read by people, months later, asking where a child was last seen.
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

/// The verdict on one custody event, as the server gave it.
///
/// The batch endpoint answers 200 even when the events inside it were refused,
/// so "the request worked" and "the child is recorded" are different questions.
/// This is the second one.
class CustodyVerdict {
  const CustodyVerdict({
    required this.accepted,
    this.duplicate = false,
    this.reason,
    this.rewrittenTo,
    this.alertRaised = false,
  });

  /// Whether the ledger now holds this event.
  final bool accepted;

  /// Accepted, but it was already there — a retry after a dropped connection.
  /// Nothing is wrong and the driver need not be told twice.
  final bool duplicate;

  /// Why it was refused, in the server's own words, when it was.
  final String? reason;

  /// Set when the server wrote something OTHER than what was asked for —
  /// a drop-off away from the expected stop is stored as WRONG_STOP. The
  /// driver has to know, because it means the office has been told.
  final String? rewrittenTo;

  /// Whether recording it raised an alert somebody will act on.
  final bool alertRaised;
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

  /// The bus is out with children on it, so the stop calls will be accepted.
  ///
  /// `stops/:sequence/arrive` refuses anything without `startedAt`, and BOARDING
  /// is the state AFTER the pre-trip check and BEFORE departure — the bus has
  /// not moved. Offering "I've arrived" there is offering a call the server is
  /// right to refuse.
  bool get running => status == 'IN_PROGRESS' || status == 'ARRIVED';

  /// The driver is on duty: checked in, at any point between the walk-around
  /// and the cabin sweep.
  bool get underway =>
      status == 'BOARDING' ||
      status == 'IN_PROGRESS' ||
      status == 'ARRIVED' ||
      status == 'SWEEP_PENDING' ||
      status == 'SWEEP_OVERDUE';

  /// Still owes the day something.
  bool get live => kLiveTripStatuses.contains(status);

  /// Over — completed, called off, or abandoned.
  bool get closed => kClosedTripStatuses.contains(status);

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

/// The four answers ShiftStartDto will accept for a walk-around.
///
/// INSPECTION_OUTCOMES in crew-trip.controller.ts. FAIL and NOT_COMPLETED both
/// block the trip: the server sets the run to BLOCKED and `depart` then refuses
/// it. That is the whole point of the check, so neither is offered lightly.
const String kInspectionPass = 'PASS';
const String kInspectionPassWithDefects = 'PASS_WITH_DEFECTS';
const String kInspectionFail = 'FAIL';
const String kInspectionNotCompleted = 'NOT_COMPLETED';

/// The kind of file a pre-trip photograph is filed as.
///
/// One of CREW_KINDS in identity-service's uploads.controller.ts, which is the
/// short list a crew handset is allowed to produce at all. INSPECTION_PHOTO is
/// the one that carries a walk-around's evidence: the server keeps it for three
/// years, which is how long a school would need it if the morning were ever
/// questioned.
const String kCrewInspectionPhoto = 'INSPECTION_PHOTO';

/// Which checklist the answers were given against.
///
/// Stored beside them, so an answer given in March can still be read against
/// the questions that were actually asked in March. Bump it when the item list
/// below changes, never reuse it for a different list.
const String kPreTripChecklistVersion = 'ksp-crew-pretrip-1';

/// One pre-trip walk-around, exactly as the server asks for it.
///
/// Every field here is evidence rather than form-filling, and the server keeps
/// all of it: an inspection completed in nine seconds from the driver's kitchen
/// is indistinguishable from a real one unless the duration and the handset's
/// clock offset are on the row.
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

  /// Minted before the FIRST send, reused on every retry. A crew phone loses
  /// signal in every basement car park; without this one walk-around becomes
  /// four inspections and the compliance figure becomes fiction.
  final String clientUuid;

  /// The answers, keyed by the item's own token — never by its translated
  /// label. The office reads these months later, in a language nobody chose.
  final Map<String, String> items;

  final String outcome;

  /// Really measured, from opening the checklist to submitting it. Clamped to
  /// the range the server accepts rather than invented.
  final int durationSeconds;

  /// The crew member's own photograph, taken at the bus. Required — it is what
  /// ties the record to a person rather than to a session token, and a session
  /// token can be handed to a cousin along with the phone.
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

  /// The crew's runs.
  ///
  /// [date] asks for one day. [days] asks for that many days ending today,
  /// newest first, which is what a history list wants — calling this with
  /// neither returns TODAY, and that is what made "past runs" show the current
  /// day and, on a day with no runs, nothing at all.
  Future<List<CrewTrip>> trips({String? date, int? days}) async {
    final query = date != null
        ? '?date=$date'
        : days != null
            ? '?days=$days&pageSize=50'
            : '';
    final json = await _api.get('/crew/trips$query');
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

  /// The campus gate on this run, which is the stop the bus is at whenever it
  /// is not at a child's own stop.
  ///
  /// Read off the trip pack, because the plan does not carry it: the plan's
  /// stops are built from the manifest, every manifest entry points at a
  /// child's own pick-up or drop-off stop, and no child belongs to the gate. So
  /// the gate — the one stop where a whole morning's alightings happen — is the
  /// one stop the plan cannot name.
  ///
  /// Matched on `isCampusGate`, taking the LAST one in sequence order. That is
  /// what the server does: `StopAssignment.isTerminal` defaults to the stop's
  /// own `isCampusGate`, and custody.service.ts takes the highest sequence of
  /// them. Null when the route has no gate marked, which the caller must pass
  /// on as a null stopId rather than substituting something.
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

  /// Send a photograph the handset has just taken, and get back the id the
  /// rest of the platform knows it by.
  ///
  /// POST /crew/uploads/direct — the offline-friendly path, described in
  /// identity-service's CrewUploadsController as "the bytes it has been
  /// holding in its queue since the bus was underground, in one request, with
  /// no separate confirm step to lose". The file part is called `file` and
  /// nothing else; a request with any other field name is read as having no
  /// file attached at all and answered 400.
  ///
  /// [kind] must be one of CREW_KINDS in that controller — HANDOVER_PHOTO,
  /// INCIDENT_PHOTO, INCIDENT_VIDEO, INCIDENT_AUDIO, INSPECTION_PHOTO,
  /// DEFECT_PHOTO, SIGNATURE_IMAGE, VEHICLE_PHOTO. A driver's handset has no
  /// business minting an invoice or a tenant stamp, and the server refuses
  /// rather than guesses.
  ///
  /// The row it writes carries `uploadedByPersonId` = the caller, which is
  /// exactly what `shift-start` looks for: it will only accept a walk-around
  /// photograph that is a real, AVAILABLE asset at this school belonging to
  /// the person filing the check.
  ///
  /// Returns the asset id, or throws. It never returns a placeholder — an
  /// inspection filed against an id the server did not issue is a safeguarding
  /// record pointing at nothing.
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
        // The moment the shutter went, not the moment the upload finished. On
        // a bus with no signal those are minutes apart, and the office reads
        // the first one.
        'capturedAt': ?capturedAt?.toUtc().toIso8601String(),
      },
    );
    final id = json is Map<String, dynamic> ? json['id'] : null;
    if (id is! String || id.isEmpty) {
      throw ApiException(t('driver.pretrip.selfieNoId'), 0);
    }
    return id;
  }

  /// File the pre-trip walk-around and go on duty.
  ///
  /// This was posted with an EMPTY BODY, and the endpoint validates a full
  /// ShiftStartDto — clientUuid, checklistVersion, items, outcome,
  /// durationSeconds, selfieAssetId and deviceTime are all required — so it
  /// answered 400 every single time. `depart` then refuses to let the bus go
  /// without a PRE_TRIP inspection on the trip, so the failure was never one
  /// button: it was the whole morning.
  ///
  /// `deviceTime` is stamped here, at the moment of sending, because the server
  /// measures the handset's clock against its own from it and stores the
  /// difference on the inspection row.
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
      // lat, lon and accuracyM are accepted by ShiftStartDto and are NOT sent,
      // because this build still has no position source: there is no location
      // plugin in pubspec.yaml, the Android manifest asks for no location
      // permission, and the stop coordinates the plan carries are the office's
      // pins rather than a fix. The photograph does not help either — the
      // camera writes GPS into a picture only when the camera app itself holds
      // location, and image_picker re-encodes the file and drops the EXIF.
      //
      // This is not free. fleet-service's suspicious-inspections report
      // (inspections.controller.ts) matches, among other things,
      // `{ kind: 'PRE_TRIP', lat: null }` — so every walk-around this app files
      // lands on that report, and a report where every row is flagged is a
      // report nobody reads. Sending a made-up position would be worse; the
      // fix is a real fix, and it needs a plugin.
    });
  }

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
  /// [stopId] must be the stop the BUS is at, not the stop the child belongs
  /// to. Work it out with [custodyStopId]; the two differ on exactly the half
  /// of every run that happens at the school gate.
  ///
  /// The position is accepted by the server and this build never has one. There
  /// is no location plugin in pubspec.yaml and the Android manifest asks for no
  /// location permission, so nothing on a crew screen knows where the bus is —
  /// the stop coordinates the plan carries are the office's pins, not a fix,
  /// and sending one as though it were a fix would tell the server the bus was
  /// standing exactly on the stop no matter where it really was.
  ///
  /// So the geofence half of the wrong-stop check cannot fire, and these
  /// arguments exist for the day a fix does. Send all four together when that
  /// day comes: the server grades a lat/lon with no [gpsAccuracyM] as a clean
  /// GPS fix and lets it raise a CRITICAL alert, so a coarse network fix sent
  /// without its accuracy is worse than no fix at all.
  /// What the server did with one custody event.
  ///
  /// See [CustodyVerdict].
  ///
  /// The batch endpoint answers 200 whatever happens to the events inside it —
  /// it has to, because a batch can hold twenty and half of them can be
  /// duplicates from a retry. The verdict per event is in `results`, and this
  /// method used to throw it away and return void. A rejected event therefore
  /// reached the driver as a green "Ahmad — On board" while the ledger held
  /// nothing at all, and he drove off believing a child was recorded.
  ///
  /// [rewrittenTo] is set when the server accepted the event but recorded it as
  /// something else — a drop-off at the wrong stop becomes WRONG_STOP — which
  /// the driver has to be told about, because it means an alert has gone to the
  /// office with his name on it.
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
          // The crew app has no scanner in this build, so every event is a
          // deliberate tap by a named person with a reason attached. The
          // server records the weaker method rather than being told a tag was
          // read when none was.
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
    // No row for this id at all: nothing was written, and saying so is better
    // than a green tick over an empty ledger.
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
