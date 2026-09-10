import 'client.dart';
import 'session.dart';

/// Staff leave, for the member of staff themselves.
///
/// One file for both flavours. The driver app and the teacher app ask exactly
/// the same four questions — what have I asked for, what am I owed, may I have
/// these days, and take that back — and a second copy of this would be a
/// second place for a field name to drift out of step with the server.
///
/// WHAT THIS TALKS TO. `StaffLeaveController` in identity-service is mounted on
/// `school/`, `operator/` and `admin/staff-leave`, and every route on it that
/// existed before this screen is gated on `hr.read`, `hr.write` or
/// `hr.leave.decide`. The `teacher`, `driver` and `attendant` role templates
/// hold none of the three, on purpose — a driver who held `hr.read` would be
/// able to read the whole depot's sick notes. So the app talks to the `mine`
/// routes on the same controller, which carry no permission: a permission
/// cannot say "staff, about themselves" without either locking these two
/// builds out or letting every parent through.
///
/// They are gated on the ROLE instead — `@RequireRole` on all four `mine`
/// routes, naming every RoleType except GUARDIAN — and that gate is load
/// bearing rather than decoration. `mine` is not a private corner: filing one
/// puts a PENDING row on the office absence board and in the `hr.leave.decide`
/// queue, so while the routes carried no gate at all, any parent at the school
/// could put HR paperwork there under their own name. The scope is still the
/// caller's own person id and the membership the guard resolved, so nothing on
/// the wire can point these at anybody else either.
///
/// The roles these builds sign in as — DRIVER, ATTENDANT and TEACHER, see
/// `_membershipForThisApp` in main.dart — are all on that list, so the gate
/// costs a real member of staff nothing.

/// `StaffLeaveKind`, copied from LEAVE_KINDS at the top of
/// identity-service's staff-leave.controller.ts.
///
/// Written out rather than guessed at: `@IsIn(LEAVE_KINDS)` refuses anything
/// else outright, so a value that is nearly right is a request that cannot be
/// filed at all.
const List<String> kStaffLeaveKinds = [
  'SICK',
  'ANNUAL',
  'UNPAID',
  'MATERNITY',
  'PATERNITY',
  'BEREAVEMENT',
  'PILGRIMAGE',
  'STUDY_OR_EXAM',
  'PUBLIC_DUTY',
  'COMPASSIONATE',
  'OTHER',
];

/// `StaffLeaveStatus`, from LEAVE_STATUSES in the same file.
///
/// Six, not three. A refusal is not the only unhappy ending: an approval can
/// be REVOKED afterwards, and a screen that only knew PENDING/APPROVED/REJECTED
/// would show a revoked fortnight as still granted.
const List<String> kStaffLeaveStatuses = [
  'PENDING',
  'APPROVED',
  'REJECTED',
  'CANCELLED',
  'REVOKED',
  'TAKEN',
];

/// One absence this person has asked the office for.
///
/// The fields are LEAVE_SELECT in identity-service's hr.service.ts, plus the
/// `coverName` the `mine` route adds on the way out. Two of them are not what
/// their names suggest and both have caught somebody out before:
///
///  * `fromDate` and `toDate` are `@db.Date` columns. They arrive as UTC
///    midnight and are read back as the CALENDAR DAY they name — parsing them
///    as instants and converting to local time is how a day of leave lands on
///    the day before in half the world.
///  * `workingDays` is a Prisma Decimal, which JSON.stringify turns into a
///    STRING. `as num` on it throws; the console reads it as
///    `string | number | null` and so does this.
class StaffLeave {
  StaffLeave({
    required this.id,
    required this.kind,
    required this.status,
    required this.fromDate,
    required this.toDate,
    required this.fromMinute,
    required this.toMinute,
    required this.reason,
    required this.workingDays,
    required this.paid,
    required this.requestedAt,
    required this.decidedAt,
    required this.decisionNote,
    required this.coverName,
  });

  final String id;

  /// One of [kStaffLeaveKinds].
  final String kind;

  /// One of [kStaffLeaveStatuses].
  final String status;

  final DateTime fromDate;
  final DateTime toDate;

  /// Minutes from midnight, for part of a day — a clinic appointment at
  /// eleven. Both are set or neither is, and only ever on a single day.
  final int? fromMinute;
  final int? toMinute;

  final String? reason;

  /// What this costs the entitlement, in WORKING days — a Sunday-to-Thursday
  /// week is five, not seven, and a two-hour appointment is a fraction.
  /// Computed by the server against this person's own working pattern.
  final double? workingDays;

  final bool paid;
  final DateTime? requestedAt;
  final DateTime? decidedAt;

  /// Why the office said what it said. The one part of an answer a person
  /// actually reads, and the reason a refusal on this screen is never shown
  /// as a bare red word.
  final String? decisionNote;

  /// Who is taking the classes or the run, once somebody has been named.
  final String? coverName;

  /// Still waiting on the office, so it can still be withdrawn.
  bool get pending => status == 'PENDING';

  /// Settled against the person: refused outright, or an approval taken back.
  /// Both owe them an explanation, and [decisionNote] is where it is.
  bool get refused => status == 'REJECTED' || status == 'REVOKED';

  /// Calendar days covered, inclusive. Not [workingDays] — this is what a
  /// person means by "three days off", the other is what it costs.
  int get calendarDays => toDate.difference(fromDate).inDays + 1;

  /// Part of one day, rather than whole days off.
  bool get partDay => fromMinute != null && toMinute != null;

  /// A `@db.Date` read as the day it names.
  ///
  /// The UTC parts are taken and rebuilt as a local date, so the day on the
  /// screen is the day in the database whatever the handset's timezone.
  static DateTime _day(Object? value) {
    final at = DateTime.parse(value as String).toUtc();
    return DateTime(at.year, at.month, at.day);
  }

  static DateTime? _at(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  /// A Decimal column, which reaches us as a string.
  static double? _decimal(Object? value) => switch (value) {
        num n => n.toDouble(),
        String s => double.tryParse(s),
        _ => null,
      };

  factory StaffLeave.fromJson(Map<String, dynamic> j) => StaffLeave(
        id: j['id'] as String,
        kind: (j['kind'] ?? 'OTHER') as String,
        status: (j['status'] ?? 'PENDING') as String,
        fromDate: _day(j['fromDate']),
        toDate: _day(j['toDate']),
        fromMinute: (j['fromMinute'] as num?)?.toInt(),
        toMinute: (j['toMinute'] as num?)?.toInt(),
        reason: j['reason'] as String?,
        workingDays: _decimal(j['workingDays']),
        paid: (j['paid'] ?? true) as bool,
        requestedAt: _at(j['requestedAt']),
        decidedAt: _at(j['decidedAt']),
        decisionNote: j['decisionNote'] as String?,
        coverName: j['coverName'] as String?,
      );
}

/// One line of entitlement: how many days of one kind, for one period.
///
/// `remainingDays` is derived by the server from the other four rather than
/// stored, and `pendingDays` is subtracted alongside `takenDays` — days already
/// promised are not days that can be booked twice.
class StaffLeaveBalance {
  StaffLeaveBalance({
    required this.kind,
    required this.periodKey,
    required this.entitledDays,
    required this.carriedOverDays,
    required this.takenDays,
    required this.pendingDays,
    required this.remainingDays,
  });

  /// One of [kStaffLeaveKinds].
  final String kind;

  /// "2025-2026" at a school, "2026" at an operator on calendar years.
  final String periodKey;

  final double entitledDays;
  final double carriedOverDays;
  final double takenDays;
  final double pendingDays;
  final double remainingDays;

  factory StaffLeaveBalance.fromJson(Map<String, dynamic> j) => StaffLeaveBalance(
        kind: (j['kind'] ?? 'OTHER') as String,
        periodKey: (j['periodKey'] ?? '') as String,
        entitledDays: StaffLeave._decimal(j['entitledDays']) ?? 0,
        carriedOverDays: StaffLeave._decimal(j['carriedOverDays']) ?? 0,
        takenDays: StaffLeave._decimal(j['takenDays']) ?? 0,
        pendingDays: StaffLeave._decimal(j['pendingDays']) ?? 0,
        remainingDays: StaffLeave._decimal(j['remainingDays']) ?? 0,
      );
}

/// What this person is owed, and whether anybody has said.
///
/// [employed] is false when there is no Employee row at this tenant — the
/// supply teacher in week one, whose paperwork lands on the Monday. That is a
/// different answer from "nought days left", and the screen says so rather than
/// showing an empty allowance to somebody who simply has not been set up yet.
class StaffLeaveEntitlement {
  StaffLeaveEntitlement({required this.employed, required this.balances});

  final bool employed;
  final List<StaffLeaveBalance> balances;

  factory StaffLeaveEntitlement.fromJson(Map<String, dynamic> j) => StaffLeaveEntitlement(
        employed: (j['employed'] ?? false) as bool,
        balances: ((j['balances'] as List?) ?? const [])
            .map((e) => StaffLeaveBalance.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// The four self-service routes, shared by the driver app and the teacher app.
class StaffLeaveApi {
  StaffLeaveApi._();

  static final StaffLeaveApi instance = StaffLeaveApi._();

  final ApiClient _api = ApiClient.instance;

  /// Where the `mine` routes answer for this session.
  ///
  /// The controller is mounted on all three prefixes and the path decides
  /// nothing — the scope comes from the caller's active tenant, re-read from
  /// the database by the guard. The prefix is chosen to match that tenant
  /// anyway, because the EDGE routes by path: nginx has one location for
  /// `/api/school/staff-leave` and another for `/api/operator/staff-leave`,
  /// both pointing at identity-service, and a prefix matching neither would be
  /// handed to whichever service owns the rest of that namespace.
  String get _base => Session.instance.me?.active.tenantKind == 'OPERATOR'
      ? '/operator/staff-leave/mine'
      : '/school/staff-leave/mine';

  /// Every absence this person has asked for, newest first.
  Future<List<StaffLeave>> mine() async {
    final json = await _api.get('$_base?pageSize=50');
    return Paged.from<StaffLeave>(json, StaffLeave.fromJson).rows;
  }

  /// How many days are left, per kind.
  Future<StaffLeaveEntitlement> entitlement() async =>
      StaffLeaveEntitlement.fromJson(await _api.get('$_base/balances') as Map<String, dynamic>);

  /// Ask the office for time off.
  ///
  /// Lands PENDING — approving it is a separate act by somebody who holds
  /// `hr.leave.decide`, and nothing is booked until they do.
  ///
  /// `paid` is deliberately not sent, and the route would not accept it: the
  /// server defaults it to paid for every kind except UNPAID, which is the way
  /// round that fails safely for the employee, and it is not the absentee's to
  /// declare about their own absence.
  Future<void> request({
    required String kind,
    required DateTime from,
    required DateTime to,
    String? reason,
  }) async {
    final why = (reason ?? '').trim();
    await _api.post(_base, {
      'kind': kind,
      'fromDate': _dateOnly(from),
      'toDate': _dateOnly(to),
      // Left out when blank rather than sent empty: the field is optional, but
      // @Length(2, 500) WHEN PRESENT, so an empty string is refused outright.
      'reason': ?(why.isEmpty ? null : why),
    });
  }

  /// Take a request back before anybody has decided it.
  ///
  /// PATCH, not POST, and only while it is still PENDING — once the office has
  /// said yes the days are reserved against a balance and only they can revoke
  /// it. The row is kept rather than deleted: "I did ask, in September" is a
  /// claim the record has to be able to settle.
  Future<void> cancel(String id) => _api.patch('$_base/$id/cancel', const <String, dynamic>{});

  /// A `@db.Date`, written as the day it is.
  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
