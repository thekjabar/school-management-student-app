import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;

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

/// The most custody events the server will take in one request.
///
/// MAX_BATCH_EVENTS in custody.service.ts, enforced by @ArrayMaxSize on the DTO
/// — a longer array is refused before a single row is written, so the app
/// splits rather than finding out. It is not a reason to fall back to one
/// request per child: a bus of twenty-nine is one request, and a bus of three
/// hundred is two.
const int kMaxCustodyBatchEvents = 200;

/// One child, and the event to record against them, inside a batch.
class CustodyEntry {
  const CustodyEntry({
    required this.studentId,
    required this.eventType,
    this.stopId,
  });

  final String studentId;
  final String eventType;

  /// The stop the BUS is standing at, worked out per child with
  /// [custodyStopId] — NOT the stop the child belongs to. On the OUT leg every
  /// alighting in a batch resolves to the campus gate; sending the child's own
  /// stop is what makes the server rewrite the row to WRONG_STOP and raise a
  /// CRITICAL safeguarding alert, and in a batch it does it once per child.
  final String? stopId;
}

/// What the server did with one child's event in a batch.
///
/// The batch answers 200 whatever happened to the events inside it, so the
/// caller needs to know which children are actually on the ledger and which
/// were refused. [studentId] is carried alongside the verdict because the
/// answer comes back keyed on the event uuid, which no screen knows about.
class CustodyOutcome {
  const CustodyOutcome({required this.studentId, required this.verdict});

  final String studentId;
  final CustodyVerdict verdict;
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
    this.resolution,
  });

  final String studentId;
  final String name;
  final String? seatNumber;
  final bool requiresAssistance;
  final DateTime? boardedAt;
  final DateTime? alightedAt;

  /// What the manifest says became of this child — NO_SHOW when the crew marked
  /// them as not travelling.
  final String? resolution;

  /// Whether this child still needs something doing about them.
  ///
  /// NO_SHOW belongs here and was missing. It sets neither boardedAt nor
  /// alightedAt, so a child the driver had just marked as not travelling looked
  /// exactly like a child not yet picked up: the stop badge still said one was
  /// owed, the stop never ticked, and the headcount went on counting them. The
  /// tap appeared to do nothing at all, so drivers pressed it again.
  bool get accountedFor =>
      boardedAt != null || alightedAt != null || resolution == 'NO_SHOW';

  /// Settled by NOT travelling, which reads differently from being on board.
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

  /// Passed without stopping — either the driver skipped it with a reason, or
  /// nobody was assigned here today at all. The server does not tell the two
  /// apart in this field (see `skipped` in crew-routing.controller.ts's
  /// `buildStops`), so neither does this screen.
  final bool skipped;
  /// Why, when the driver skipped it on purpose. Null for a stop skipped only
  /// because nobody on it was riding today.
  final String? skippedReason;

  /// When the bus is expected here — or when it actually got here, once
  /// [etaIsActual] is true. The server works it out from the drive between
  /// stops and how long this stop's own children take to load, which is the
  /// half the timetable does not cost.
  final DateTime? etaAt;

  /// [etaAt] is a record rather than a forecast: the bus has been here. The
  /// difference matters on a screen — a time that already happened must not be
  /// shown with a tilde in front of it, and a guess must not be shown with a
  /// tick.
  final bool etaIsActual;

  /// How long this stop is expected to take, from the children on it.
  final int dwellSeconds;

  /// The drive from the stop before this one to this one.
  final int driveSeconds;

  /// Passed, one way or another — actually departed, or skipped over.
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

/// When the bus actually has to leave, and what today's children cost.
///
/// The timetable says depart 07:00, arrive 07:45, and it costed those 45
/// minutes at half a minute per child. Five children waiting at one stop spend
/// five times that, so a driver who leaves exactly on time still arrives late
/// and is never told which of the two numbers was wrong. The server prices the
/// run against today's roster instead; this is that answer.
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

  /// The latest the bus can pull away and still reach the gate on time. Null
  /// when there is no arrival time to work back from.
  final DateTime? departByAt;

  /// When the run is due at the other end.
  final DateTime? mustArriveBy;

  /// What the timetable says, which is not the same question.
  final DateTime? scheduledDepartureAt;

  /// Null until the wheels turn, and it is what says whether the leave-by
  /// answer is still a decision or already history.
  final DateTime? startedAt;

  /// Driving, with nobody getting on or off.
  final int driveSeconds;

  /// Standing at stops, loading children — the part the timetable underrates.
  final int dwellSeconds;

  /// The two above, together.
  final int estimatedDurationSeconds;

  /// What the timetable has left over once the run is costed honestly.
  ///
  /// NEGATIVE means it does not allow enough time for today's children. That
  /// is a fact about the timetable, not about the driver, and nothing the
  /// driver can do about it — which is why the screen says so in those words.
  final int? slackSeconds;

  /// The loading time allowed per child.
  final int secondsPerStudent;

  /// There is a departure time to show at all. An older server sends none of
  /// this block, and every field here comes back null or zero.
  bool get hasDepartBy => departByAt != null;

  /// The timetable is short for today's roster.
  bool get tooTight => (slackSeconds ?? 0) < 0;

  /// How many whole minutes short, rounded UP: a shortfall of 61 seconds is a
  /// two-minute problem, not a one-minute one.
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
        // No default. Null means the server could not say, and zero means the
        // run fits exactly — reading the first as the second would turn "we do
        // not know" into "you have no slack", on the one field that decides
        // whether a warning is shown.
        slackSeconds: (j['slackSeconds'] as num?)?.toInt(),
        secondsPerStudent: (j['secondsPerStudent'] as num?)?.toInt() ?? 0,
      );
}

/// The plan for a run: the stops in the order they should be driven.
class TripPlan {
  TripPlan({
    required this.ordering,
    required this.orderingNote,
    required this.counts,
    required this.stops,
    required this.timing,
    this.terminalArrivedAt,
  });

  /// "planned" — the office's order — or "nearest", recomputed from where the
  /// bus actually is.
  final String ordering;
  final String orderingNote;
  final Headcount counts;
  final List<PlannedStop> stops;

  /// When to leave, and why. Never null: a server that does not send the block
  /// yields an empty one, whose [TripTiming.hasDepartBy] is false and which
  /// every screen already has to handle.
  final TripTiming timing;

  /// When the bus reached the campus gate, straight from the server.
  ///
  /// The one piece of evidence that a morning set-down really was a school
  /// arrival. Null while the bus is still on its way — and null from an older
  /// server, which is why every reader must treat null as "cannot say" rather
  /// than as proof of anything.
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

  /// When the last child stepped off. Null until somebody has.
  final DateTime? lastAlightingAt;

  /// The floor, in seconds, the server puts under a believable walk. Null when
  /// the server has not said — an older build of the platform, not a run
  /// without a floor.
  final int? minSecondsAfterLastAlighting;

  /// The instant a sweep filed for this run starts being counted.
  ///
  /// Sent as an absolute server time on purpose. Anything filed before it is
  /// graded a rubber stamp: recorded, alerted on, and deliberately NOT clearing
  /// the bus, because nobody walks to the back row in twenty seconds. Null when
  /// nobody has got off yet, which is not a wait — it is no last child to
  /// measure from.
  final DateTime? confirmableFrom;

  /// How long the driver still has to wait, in seconds. Zero once the wait is
  /// over.
  ///
  /// Measured against [confirmableFrom] rather than re-derived from
  /// [minSecondsAfterLastAlighting] and a local stopwatch: the server grades
  /// the walk against its own clock, so counting down to its own instant is the
  /// only way the number on the phone means what the button will do. A run
  /// where nobody alighted has no [confirmableFrom] and is therefore not
  /// blocked at all.
  int get secondsUntilConfirmable {
    final from = confirmableFrom;
    if (from == null) return 0;
    final left = from.difference(DateTime.now());
    if (left <= Duration.zero) return 0;
    // Rounded up, not truncated. `inSeconds` throws the fraction away, which
    // would open the button up to a second before the server's own instant —
    // and a walk filed a fraction early is refused exactly as silently as one
    // filed twenty seconds early. Better a second late than a second refused.
    return (left.inMilliseconds / 1000).ceil();
  }

  /// The walk would be counted if it were filed now.
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

/// What the server made of a sweep — which is not the same as whether the
/// request succeeded.
///
/// `POST /crew/sweep/scan` answers 200 to a sweep it has REFUSED to count. A
/// walk filed after the deadline, or one the platform grades as a rubber stamp,
/// is recorded, raises an alert, and deliberately leaves the run unswept: that
/// is the safeguard doing its job, and nothing on this side may work around it.
///
/// The app used to throw this whole answer away and show "Sweep confirmed" in
/// green over a refusal, leaving the red card exactly where it was. Drivers
/// read that as a broken button and pressed it again — ten recorded attempts on
/// one run, every one of them answered with a green tick that was a lie.
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

  /// The only value that closes the run.
  ///
  /// The server's own definition: the outcome was CLEAR, it was not rubber
  /// stamped, and it was inside the deadline. Only then does it clear
  /// `TripInstance.status` and stamp `sweepConfirmedAt` — which is why a card
  /// still sitting there after a green tick is the server disagreeing, not the
  /// screen failing to reload.
  final bool genuine;

  /// Filed inside the window the run was given. Late is not refused — it is
  /// recorded, it raises SWEEP_LATE, and it does not clear the bus.
  final bool withinDeadline;

  /// Recorded, but it did not look like somebody walking the aisle: too fast
  /// for the minimum walk, no movement, the phone nowhere near the bus. Treated
  /// as unswept, which is the whole point of grading it.
  final bool rubberStamped;

  /// Why, in the server's enum codes. Empty when it said only that it was one.
  final List<String> rubberStampReasons;

  /// Already on file — the same walk arriving twice after a dropped
  /// connection, not a second walk.
  final bool duplicate;

  /// What the office was told, e.g. SWEEP_LATE. Non-empty means a human has
  /// been handed this run.
  final List<String> alertsRaised;

  /// The window in seconds the run was given to be swept.
  final int? deadlineSeconds;

  /// How long after the run ended the walk was filed.
  final int? secondsFromTripEnd;

  /// The server's own confidence in the walk, 0–100.
  final int? confidenceScore;

  /// Children the reconciliation could not account for. Anything but zero is
  /// an alarm, not a note.
  final int? unaccountedCount;

  /// Parse the answer without ever reading silence as a yes.
  ///
  /// A 200 with no body arrives here as null. That is not the server saying the
  /// sweep counted, so it is not reported as one.
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
        // Absent reads as "not counted", never as counted. Only the server
        // saying `genuine` outright earns the green note.
        genuine: j['genuine'] == true,
        // Absent here is the other way round: the server has said nothing about
        // a deadline, and a missing answer must not be announced to the driver
        // as a late one.
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

/// A notice the school aimed at drivers or attendants — the whole school, a
/// route, a campus, or crew by name.
///
/// A fresh model rather than a reuse of the parent or teacher one:
/// CrewAnnouncementsController resolves a DIFFERENT audience — the routes and
/// campuses this person has actually been rostered on, not the classes a
/// teacher teaches — and the fields it sends back are its own, even though
/// most of them read the same. The controller's own doc comment is blunt
/// about why it exists at all: `Announcement.audienceRoles` has accepted
/// DRIVER and ATTENDANT since the first migration, and nothing in the app
/// ever had a screen that could read one.
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

  /// "I have read this and I understand it" is asked for, not just read —
  /// e.g. a changed release procedure or a road closed to buses.
  final bool requiresAcknowledgement;

  /// When this crew member said they had, if they have.
  final DateTime? acknowledgedAt;
  final String authorName;
  final DateTime? readAt;

  /// Files on the notice — a scanned circular, a revised stop map. Counted
  /// rather than fetched: neither the parent nor the teacher screen this was
  /// modelled on opens attachments either, so a count is shown and nothing is
  /// promised that this build cannot open.
  final int attachmentCount;

  /// Answered, but not necessarily settled — [requiresAcknowledgement] can
  /// still be owed.
  bool get isRead => readAt != null;

  /// Nothing left to do with this notice.
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

  /// Close the run, and say how many children the server could not account for.
  ///
  /// The count was thrown away: this returned void, and the driver was told
  /// "Run ended" whatever came back. The server's own comment on the field is
  /// "Anything but zero is an alarm, not a note" — it is the number that says a
  /// child boarded this bus and was never recorded getting off, at the exact
  /// moment the driver is about to walk away from it.
  Future<int> endTrip(String tripId) async {
    final json = await _api.post('/crew/trips/$tripId/end') as Map<String, dynamic>;
    return (json['unaccounted'] as num?)?.toInt() ?? 0;
  }

  Future<void> arriveAtStop(String tripId, int sequence) =>
      _api.post('/crew/trips/$tripId/stops/$sequence/arrive');

  Future<void> leaveStop(String tripId, int sequence) =>
      _api.post('/crew/trips/$tripId/stops/$sequence/depart');

  /// Pass a stop without stopping, with a reason.
  ///
  /// `SkipStopDto` on the server takes [reason] as 3–300 characters and
  /// nothing else. Recorded rather than left silent: a stop skipped because
  /// nobody was waiting looks identical on a map to a stop the driver forgot,
  /// and the family standing there deserves the difference to be written
  /// down. The server refuses this once the stop already has an arrival
  /// recorded — a skip is an alternative to Arrived, not something that
  /// follows it.
  Future<void> skipStop(String tripId, int sequence, String reason) =>
      _api.post('/crew/trips/$tripId/stops/$sequence/skip', {'reason': reason});

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

  /// Record a whole busload off in ONE request.
  ///
  /// At the school gate the driver has twenty-nine children going down the
  /// steps at once and a queue of buses behind him. Twenty-nine taps on
  /// twenty-nine green buttons is not something he will do, and the thing he
  /// does instead is end the run — which is how a run was closed with
  /// twenty-nine children still on the register as on board, the worst state
  /// this system has.
  ///
  /// This is ONE POST, not a loop. The endpoint has always taken an array; a
  /// request per child on a school car park's signal is twenty-nine chances to
  /// fail, twenty-nine trip recomputations on the server, and no way to tell
  /// the driver what happened overall. Anything longer than
  /// [kMaxCustodyBatchEvents] is split into as few requests as will hold it.
  ///
  /// Each entry carries its OWN [CustodyEntry.stopId], because the answer is
  /// per child: work it out with [custodyStopId] against that child's stop and
  /// the trip's terminal stop before calling.
  ///
  /// The answer is per child too. A 200 does not mean twenty-nine children were
  /// recorded — it means the request was read — so this returns one
  /// [CustodyVerdict] per entry and the screen reports what actually happened.
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
        // Nothing has reached the ledger yet, so the caller can show the
        // server's own refusal as an instruction, exactly as one tap does.
        if (out.isEmpty) rethrow;
        // Some children ARE recorded. Throwing here would drop that on the
        // floor and tell the driver the whole thing failed — the precise lie
        // this method exists to stop — so the rest come back as refused, with
        // the failure as their reason.
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

  /// One request, holding at most [kMaxCustodyBatchEvents] events.
  ///
  /// The per-event shape is [recordCustody]'s, field for field. The uuids are
  /// minted here, before the send, and kept: they are both what makes a retry
  /// over a dropped connection free and the only thing the answer is keyed on —
  /// `results` comes back per event id, in no promised order, so the ids are
  /// what put each verdict back beside the right child.
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
            // Same as a single tap: no scanner in this build, so every event
            // is a deliberate act by a named person with a reason on it. The
            // reason says it was a whole busload, because months later that is
            // the difference between a driver who watched each child off and a
            // driver who emptied the bus at the gate.
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

  /// One row of `results`, read the way [recordCustody] reads its own.
  ///
  /// A null row means the server answered without mentioning this event at
  /// all: nothing was written, and saying so beats a green tick over an empty
  /// ledger.
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

  /// A thrown failure, in words a driver can act on.
  ///
  /// OfflineException is checked first because it IS an ApiException.
  static String _failureText(Object e) => e is OfflineException
      ? t('common.offline')
      : e is ApiException
          ? e.message
          : t('common.loadFailed');

  /// The panic button.
  ///
  /// There was none, anywhere in the app, though the server has taken it all
  /// along: an SOS custody event raises an INTERRUPTING, CRITICAL alert titled
  /// "The panic button was pressed on this bus" — the loudest thing this
  /// platform can do. A driver being threatened at the door had the same
  /// options as a driver with a flat tyre, which is to say a phone call.
  ///
  /// studentId is deliberately omitted: this is about the bus, not one child,
  /// and the DTO makes it optional for exactly these types. The server dedupes
  /// on the minute, so a driver pressing it three times in a panic raises one
  /// alert rather than three.
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

  /// Confirm the cabin was walked to the back seat.
  ///
  /// MANUAL_ATTESTATION is the honest method for a phone with no tag reader: it
  /// records that somebody SAID they walked the aisle, and the platform grades
  /// it as weaker evidence than a tag scan precisely because it is. Claiming a
  /// scan the handset never performed would corrupt the one number a school
  /// would be judged on.
  /// The answer comes back, because the answer is sometimes no.
  ///
  /// This returned `Future<void>` and dropped the body on the floor, so a walk
  /// the server had refused to count was reported to the driver as a success.
  /// See [SweepVerdict].
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

  /// A child was still on the bus.
  ///
  /// The sweep had exactly one button and it asserted CLEAR — the bus was
  /// empty. A driver who walked to the back row and found a child asleep had
  /// nothing to press that said so, and the only honest thing left to him was
  /// to file the declaration that was untrue. The schema calls CHILD_FOUND
  /// "the reason this entire feature exists".
  ///
  /// The child is named, because the server insists: "Say which child was found
  /// on board." That is the point — the record has to say who, so the office
  /// knows which family to ring before the parent does.
  ///
  /// Same endpoint, and the server grades this one too — so the verdict is
  /// returned rather than discarded. CHILD_FOUND is never `genuine` (only CLEAR
  /// can be), and it is not meant to be: finding a child does not close the run.
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

  /// How many notices this crew member has not opened yet.
  ///
  /// Seeded by every fetch of [announcements] and moved by the screen itself
  /// as notices are read, the same way TeacherApi keeps its own dot live.
  /// Anything drawing a badge for it should listen to this rather than count
  /// rows a second time.
  final ValueNotifier<int> unreadAnnouncements = ValueNotifier<int>(0);

  /// What the office has told drivers and attendants.
  ///
  /// Resolved server-side against the routes and campuses this person has
  /// actually been rostered on — see the audience note on
  /// CrewAnnouncementsController — so the client asks for nothing more
  /// specific than a page size.
  Future<List<CrewAnnouncement>> announcements() async {
    final json = await _api.get('/crew/announcements?pageSize=50');
    final rows = Paged.from<CrewAnnouncement>(json, CrewAnnouncement.fromJson).rows;
    unreadAnnouncements.value = rows.where((a) => a.readAt == null).length;
    return rows;
  }

  /// This crew member opened one notice. Idempotent — a second call is a
  /// success, not an error.
  Future<void> markAnnouncementRead(String id) =>
      _api.post('/crew/announcements/$id/read');

  /// Everything this crew member can see, marked read in one sweep. Returns
  /// how many rows the server actually stamped, which covers more than the
  /// one page on screen.
  Future<int> markAllAnnouncementsRead() async {
    final json = await _api.post('/crew/announcements/read-all');
    return ((json as Map<String, dynamic>?)?['marked'] as num?)?.toInt() ?? 0;
  }

  /// "I have read this and I understand it" — offered only on a notice the
  /// office marked as requiring it, e.g. a changed release procedure or a road
  /// closed to buses. Twice is a success, same as the server.
  Future<void> acknowledgeAnnouncement(String id) =>
      _api.post('/crew/announcements/$id/acknowledge', const <String, dynamic>{});
}
