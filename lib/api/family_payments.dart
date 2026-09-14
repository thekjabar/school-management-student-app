import '../i18n/strings.dart';

enum PaymentPayee {
  ksp('/parent/package'),
  school('/parent/school-fees');

  const PaymentPayee(this.base);

  final String base;

  String get noticesPath => '$base/notices';
}

abstract final class NoticeStatus {
  static const pending = 'PENDING';
  static const confirmed = 'CONFIRMED';
  static const rejected = 'REJECTED';
  static const withdrawn = 'WITHDRAWN';
}

abstract final class SchoolFeesCode {
  static const notInApp = 'SCHOOL_FEES_NOT_IN_APP';
}

class LocalText {
  const LocalText({this.ckb, this.ar, this.en});

  final String? ckb;
  final String? ar;
  final String? en;

  static const empty = LocalText();

  static LocalText fromJson(Object? raw) {
    if (raw is! Map) return empty;
    String? read(String key) {
      final v = raw[key];
      return v is String && v.trim().isNotEmpty ? v : null;
    }

    return LocalText(ckb: read('ckb'), ar: read('ar'), en: read('en'));
  }

  String? inLang(Lang lang) => switch (lang) {
        Lang.ckb => ckb,
        Lang.ar => ar,
        Lang.en => en,
      };

  String pick(String? fallback) =>
      inLang(AppLocale.current.value) ?? _blankToNull(fallback) ?? ckb ?? en ?? ar ?? '';
}

String? _blankToNull(String? value) => value == null || value.trim().isEmpty ? null : value;

DateTime? _day(Object? raw) {
  if (raw is! String || raw.length < 10) return null;
  final parts = raw.substring(0, 10).split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

DateTime? _instant(Object? raw) => raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

int _int(Object? raw) => raw is num ? raw.toInt() : 0;

String? _text(Object? raw) => raw is String && raw.trim().isNotEmpty ? raw : null;

List<String> _methods(Object? raw) => [
      for (final m in (raw is List ? raw : const []))
        if (m is String && m.isNotEmpty) m,
    ];

String isoDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

class PaymentNotice {
  const PaymentNotice({
    required this.id,
    required this.payee,
    required this.studentId,
    required this.schoolId,
    required this.studentName,
    required this.studentNames,
    required this.schoolName,
    required this.schoolNames,
    required this.amountIqd,
    required this.method,
    required this.paidOn,
    required this.reference,
    required this.senderName,
    required this.notes,
    required this.hasProof,
    required this.status,
    required this.decidedAt,
    required this.rejectedReason,
    required this.withdrawnAt,
    required this.coverFrom,
    required this.coverUntil,
    required this.sentByMe,
    required this.createdAt,
  });

  final String id;
  final PaymentPayee payee;
  final String studentId;
  final String schoolId;
  final String studentName;
  final LocalText studentNames;
  final String? schoolName;
  final LocalText schoolNames;
  final int amountIqd;
  final String method;
  final DateTime? paidOn;
  final String? reference;
  final String? senderName;
  final String? notes;
  final bool hasProof;
  final String status;
  final DateTime? decidedAt;
  final String? rejectedReason;
  final DateTime? withdrawnAt;
  final DateTime? coverFrom;
  final DateTime? coverUntil;
  final bool sentByMe;
  final DateTime? createdAt;

  bool get pending => status == NoticeStatus.pending;
  bool get confirmed => status == NoticeStatus.confirmed;
  bool get rejected => status == NoticeStatus.rejected;
  bool get withdrawn => status == NoticeStatus.withdrawn;

  String get childName => studentNames.pick(studentName);

  factory PaymentNotice.fromJson(Map<String, dynamic> j) => PaymentNotice(
        id: (j['id'] ?? '') as String,
        payee: j['payee'] == 'SCHOOL' ? PaymentPayee.school : PaymentPayee.ksp,
        studentId: (j['studentId'] ?? '') as String,
        schoolId: (j['schoolId'] ?? '') as String,
        studentName: (j['studentName'] ?? '') as String,
        studentNames: LocalText.fromJson(j['studentNames']),
        schoolName: _text(j['schoolName']),
        schoolNames: LocalText.fromJson(j['schoolNames']),
        amountIqd: _int(j['amountIqd']),
        method: (j['method'] ?? 'OTHER') as String,
        paidOn: _day(j['paidOn']),
        reference: _text(j['reference']),
        senderName: _text(j['senderName']),
        notes: _text(j['notes']),
        hasProof: j['hasProof'] == true,
        status: (j['status'] ?? NoticeStatus.pending) as String,
        decidedAt: _instant(j['decidedAt']),
        rejectedReason: _text(j['rejectedReason']),
        withdrawnAt: _instant(j['withdrawnAt']),
        coverFrom: _day(j['coverFrom']),
        coverUntil: _day(j['coverUntil']),
        sentByMe: j['sentByMe'] == true,
        createdAt: _instant(j['createdAt']),
      );
}

class NoticePage {
  const NoticePage({required this.rows, required this.nextCursor, required this.hasMore});

  final List<PaymentNotice> rows;
  final String? nextCursor;
  final bool hasMore;

  static const empty = NoticePage(rows: [], nextCursor: null, hasMore: false);

  factory NoticePage.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    return NoticePage(
      rows: [
        for (final r in (map['rows'] is List ? map['rows'] as List : const []))
          if (r is Map<String, dynamic>) PaymentNotice.fromJson(r),
      ],
      nextCursor: _text(map['nextCursor']),
      hasMore: map['hasMore'] == true,
    );
  }
}

class NoticeSent {
  const NoticeSent({required this.replayed, required this.notice, required this.message, required this.messages});

  final bool replayed;
  final PaymentNotice? notice;
  final String? message;
  final LocalText messages;

  String text(String fallback) {
    final said = messages.pick(message);
    return said.isEmpty ? fallback : said;
  }

  factory NoticeSent.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    final notice = map['notice'];
    return NoticeSent(
      replayed: map['replayed'] == true,
      notice: notice is Map<String, dynamic> ? PaymentNotice.fromJson(notice) : null,
      message: _text(map['message']),
      messages: LocalText.fromJson(map['messages']),
    );
  }
}

enum PackageStatus { active, startsLater, expired, none }

PackageStatus _packageStatus(Object? raw) => switch (raw) {
      'ACTIVE' => PackageStatus.active,
      'STARTS_LATER' => PackageStatus.startsLater,
      'EXPIRED' => PackageStatus.expired,
      _ => PackageStatus.none,
    };

class PendingNotice {
  const PendingNotice({required this.id, required this.amountIqd, required this.method, required this.paidOn});

  final String id;
  final int amountIqd;
  final String method;
  final DateTime? paidOn;

  factory PendingNotice.fromJson(Map<String, dynamic> j) => PendingNotice(
        id: (j['id'] ?? '') as String,
        amountIqd: _int(j['amountIqd']),
        method: (j['method'] ?? 'OTHER') as String,
        paidOn: _day(j['paidOn']),
      );
}

abstract class FamilyChildFees {
  String get studentId;
  String get schoolId;
  String get studentName;
  LocalText get studentNames;
  String get schoolName;
  LocalText get schoolNames;

  String get childName => studentNames.pick(studentName);
  String get school => schoolNames.pick(schoolName);
}

class PackageChild extends FamilyChildFees {
  PackageChild({
    required this.studentId,
    required this.schoolId,
    required this.studentName,
    required this.studentNames,
    required this.schoolName,
    required this.schoolNames,
    required this.status,
    required this.since,
    required this.until,
    required this.pendingNotices,
  });

  @override
  final String studentId;
  @override
  final String schoolId;
  @override
  final String studentName;
  @override
  final LocalText studentNames;
  @override
  final String schoolName;
  @override
  final LocalText schoolNames;
  final PackageStatus status;
  final DateTime? since;
  final DateTime? until;
  final List<PendingNotice> pendingNotices;

  factory PackageChild.fromJson(Map<String, dynamic> j) => PackageChild(
        studentId: (j['studentId'] ?? '') as String,
        schoolId: (j['schoolId'] ?? '') as String,
        studentName: (j['studentName'] ?? '') as String,
        studentNames: LocalText.fromJson(j['studentNames']),
        schoolName: (j['schoolName'] ?? '') as String,
        schoolNames: LocalText.fromJson(j['schoolNames']),
        status: _packageStatus(j['status']),
        since: _day(j['since']),
        until: _day(j['until']),
        pendingNotices: [
          for (final p in (j['pendingNotices'] is List ? j['pendingNotices'] as List : const []))
            if (p is Map<String, dynamic>) PendingNotice.fromJson(p),
        ],
      );
}

class PackageOverview {
  const PackageOverview({required this.methods, required this.children});

  final List<String> methods;
  final List<PackageChild> children;

  factory PackageOverview.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    return PackageOverview(
      methods: _methods(map['methods']),
      children: [
        for (final c in (map['children'] is List ? map['children'] as List : const []))
          if (c is Map<String, dynamic>) PackageChild.fromJson(c),
      ],
    );
  }
}

enum InstalmentState { paid, partial, due, overdue }

InstalmentState _instalmentState(Object? raw) => switch (raw) {
      'PAID' => InstalmentState.paid,
      'PARTIAL' => InstalmentState.partial,
      'OVERDUE' => InstalmentState.overdue,
      _ => InstalmentState.due,
    };

class FeeInstalment {
  const FeeInstalment({
    required this.planId,
    required this.sequenceNo,
    required this.dueOn,
    required this.amountIqd,
    required this.discountIqd,
    required this.payableIqd,
    required this.paidIqd,
    required this.remainingIqd,
    required this.state,
  });

  final String planId;
  final int sequenceNo;
  final DateTime? dueOn;
  final int amountIqd;
  final int discountIqd;
  final int payableIqd;
  final int paidIqd;
  final int remainingIqd;
  final InstalmentState state;

  factory FeeInstalment.fromJson(Map<String, dynamic> j) => FeeInstalment(
        planId: (j['planId'] ?? '') as String,
        sequenceNo: _int(j['sequenceNo']),
        dueOn: _day(j['dueOn']),
        amountIqd: _int(j['amountIqd']),
        discountIqd: _int(j['discountIqd']),
        payableIqd: _int(j['payableIqd']),
        paidIqd: _int(j['paidIqd']),
        remainingIqd: _int(j['remainingIqd']),
        state: _instalmentState(j['state']),
      );
}

class SchoolFeeStatement {
  const SchoolFeeStatement({
    required this.hasPlan,
    required this.discountIqd,
    required this.exempt,
    required this.dueIqd,
    required this.paidIqd,
    required this.pendingIqd,
    required this.balanceIqd,
    required this.overdueIqd,
    required this.nextDueOn,
    required this.nextDueIqd,
    required this.instalments,
  });

  final bool hasPlan;
  final int discountIqd;
  final bool exempt;
  final int dueIqd;
  final int paidIqd;
  final int pendingIqd;
  final int balanceIqd;
  final int overdueIqd;
  final DateTime? nextDueOn;
  final int? nextDueIqd;
  final List<FeeInstalment> instalments;

  factory SchoolFeeStatement.fromJson(Map<String, dynamic> j) {
    final next = j['nextDue'];
    return SchoolFeeStatement(
      hasPlan: j['level'] is String || (j['planIds'] is List && (j['planIds'] as List).isNotEmpty),
      discountIqd: _int(j['discountIqd']),
      exempt: j['exempt'] == true,
      dueIqd: _int(j['dueIqd']),
      paidIqd: _int(j['paidIqd']),
      pendingIqd: _int(j['pendingIqd']),
      balanceIqd: _int(j['balanceIqd']),
      overdueIqd: _int(j['overdueIqd']),
      nextDueOn: next is Map ? _day(next['dueOn']) : null,
      nextDueIqd: next is Map && next['amountIqd'] is num ? (next['amountIqd'] as num).toInt() : null,
      instalments: [
        for (final i in (j['instalments'] is List ? j['instalments'] as List : const []))
          if (i is Map<String, dynamic>) FeeInstalment.fromJson(i),
      ],
    );
  }
}

class SchoolYear {
  const SchoolYear({required this.id, required this.name});

  final String id;
  final String name;

  static SchoolYear? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return SchoolYear(id: (raw['id'] ?? '') as String, name: (raw['name'] ?? '') as String);
  }
}

class SchoolFeeChild extends FamilyChildFees {
  SchoolFeeChild({
    required this.studentId,
    required this.schoolId,
    required this.studentName,
    required this.studentNames,
    required this.schoolName,
    required this.schoolNames,
    required this.allowsAppPayment,
    required this.code,
    required this.message,
    required this.messages,
    required this.year,
    required this.statement,
  });

  @override
  final String studentId;
  @override
  final String schoolId;
  @override
  final String studentName;
  @override
  final LocalText studentNames;
  @override
  final String schoolName;
  @override
  final LocalText schoolNames;
  final bool allowsAppPayment;
  final String? code;
  final String? message;
  final LocalText messages;
  final SchoolYear? year;
  final SchoolFeeStatement? statement;

  String notInAppText() {
    final said = messages.pick(message);
    if (said.isNotEmpty) return said;
    return tv('schoolFees.notInApp', {'school': school});
  }

  factory SchoolFeeChild.fromJson(Map<String, dynamic> j) {
    final statement = j['statement'];
    return SchoolFeeChild(
      studentId: (j['studentId'] ?? '') as String,
      schoolId: (j['schoolId'] ?? '') as String,
      studentName: (j['studentName'] ?? '') as String,
      studentNames: LocalText.fromJson(j['studentNames']),
      schoolName: (j['schoolName'] ?? '') as String,
      schoolNames: LocalText.fromJson(j['schoolNames']),
      allowsAppPayment: j['schoolAllowsAppPayment'] == true,
      code: _text(j['code']),
      message: _text(j['message']),
      messages: LocalText.fromJson(j['messages']),
      year: SchoolYear.fromJson(j['year']),
      statement: statement is Map<String, dynamic> ? SchoolFeeStatement.fromJson(statement) : null,
    );
  }
}

class SchoolFeesOverview {
  const SchoolFeesOverview({required this.methods, required this.children});

  final List<String> methods;
  final List<SchoolFeeChild> children;

  factory SchoolFeesOverview.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    return SchoolFeesOverview(
      methods: _methods(map['methods']),
      children: [
        for (final c in (map['children'] is List ? map['children'] as List : const []))
          if (c is Map<String, dynamic>) SchoolFeeChild.fromJson(c),
      ],
    );
  }
}
