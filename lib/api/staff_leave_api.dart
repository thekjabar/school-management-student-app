import 'client.dart';
import 'session.dart';

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

const List<String> kStaffLeaveStatuses = [
  'PENDING',
  'APPROVED',
  'REJECTED',
  'CANCELLED',
  'REVOKED',
  'TAKEN',
];

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

  final String kind;

  final String status;

  final DateTime fromDate;
  final DateTime toDate;

  final int? fromMinute;
  final int? toMinute;

  final String? reason;

  final double? workingDays;

  final bool paid;
  final DateTime? requestedAt;
  final DateTime? decidedAt;

  final String? decisionNote;

  final String? coverName;

  bool get pending => status == 'PENDING';

  bool get refused => status == 'REJECTED' || status == 'REVOKED';

  int get calendarDays => toDate.difference(fromDate).inDays + 1;

  bool get partDay => fromMinute != null && toMinute != null;

  static DateTime _day(Object? value) {
    final at = DateTime.parse(value as String).toUtc();
    return DateTime(at.year, at.month, at.day);
  }

  static DateTime? _at(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

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

  final String kind;

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

class StaffLeaveApi {
  StaffLeaveApi._();

  static final StaffLeaveApi instance = StaffLeaveApi._();

  final ApiClient _api = ApiClient.instance;

  String get _base => Session.instance.me?.active.tenantKind == 'OPERATOR'
      ? '/operator/staff-leave/mine'
      : '/school/staff-leave/mine';

  Future<List<StaffLeave>> mine() async {
    final json = await _api.get('$_base?pageSize=50');
    return Paged.from<StaffLeave>(json, StaffLeave.fromJson).rows;
  }

  Future<StaffLeaveEntitlement> entitlement() async =>
      StaffLeaveEntitlement.fromJson(await _api.get('$_base/balances') as Map<String, dynamic>);

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
      'reason': ?(why.isEmpty ? null : why),
    });
  }

  Future<void> cancel(String id) => _api.patch('$_base/$id/cancel', const <String, dynamic>{});

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
