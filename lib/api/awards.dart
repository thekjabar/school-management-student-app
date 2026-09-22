import 'family_payments.dart' show LocalText;

class Certificate {
  Certificate({
    required this.id,
    required String title,
    required this.titleNames,
    required String body,
    required this.bodyNames,
    required this.reason,
    required this.issuedOn,
    required this.className,
    required this.revoked,
    required this.revokedReason,
  })  : _title = title,
        _body = body;

  final String id;
  final String _title;
  final LocalText titleNames;
  final String _body;
  final LocalText bodyNames;
  final String? reason;
  final DateTime? issuedOn;
  final String? className;
  final bool revoked;
  final String? revokedReason;

  String get title => titleNames.pick(_title);
  String get body => bodyNames.pick(_body);

  factory Certificate.fromJson(Map<String, dynamic> j) => Certificate(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        titleNames: LocalText.fromJson(j['titleNames']),
        body: (j['body'] ?? '') as String,
        bodyNames: LocalText.fromJson(j['bodyNames']),
        reason: j['reason'] as String?,
        issuedOn: j['issuedOn'] == null
            ? null
            : DateTime.tryParse('${j['issuedOn']}')?.toLocal(),
        className: j['className'] as String?,
        revoked: (j['revoked'] ?? false) as bool,
        revokedReason: j['revokedReason'] as String?,
      );
}

class AwardsWall {
  AwardsWall({required this.rows, required this.held});

  final List<Certificate> rows;
  final int held;

  factory AwardsWall.fromJson(Map<String, dynamic> j) => AwardsWall(
        rows: ((j['rows'] as List?) ?? const [])
            .map((c) => Certificate.fromJson((c as Map).cast<String, dynamic>()))
            .toList(growable: false),
        held: (j['held'] as num?)?.toInt() ?? 0,
      );
}
