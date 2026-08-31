import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/client.dart';
import '../../api/crew_api.dart' show uuidV4;
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// Giving a child to an adult, and the two things that happen when you cannot.
///
/// The platform has had this surface since the beginning — who may collect this
/// child, record the handover, refuse it, record that nobody came — and the app
/// had no way in. A driver on the afternoon run was tapping "handed over" on a
/// list, which wrote a custody row saying a child left the bus and nothing at
/// all about who took her. That row is the one a school is asked to produce six
/// months later, and it answered the wrong question.
///
/// Three rules run through this screen, and all three are the server's:
///
///  - A restriction is never explained to the crew. The handset says "do not
///    release, call the office" and nothing else, because the man at the kerb
///    is usually known to the driver and telling the driver WHY is asking him
///    to hold a conversation nobody has equipped him for.
///  - An adult who is not on the list is not refused by the driver, they are
///    referred to the office. The office rings, checks, and issues a one-time
///    authorisation against this run — which then appears in this list.
///  - Nobody at the stop is a protocol, not a decision. The child stays on the
///    bus and each rung of the ladder is written down as it is worked.
///
/// Nothing here fires on a single tap. Every write is a deliberate press-and-
/// hold, because the alternative is a thumb landing on a name while the bus is
/// still rolling.
enum HandoverOutcome { handedOver, refused, nobodyAtStop }

/// The one message key the schema ships with, mapped to the sentence the crew
/// reads. Anything else the office invents falls back to the same instruction
/// rather than showing a driver a raw key.
const Map<String, String> _holdMessages = {
  'restriction.crew.do_not_release_call_office': 'handover.holdBody',
};

/// The ladder, in the order the server accepts it.
const List<String> _nobodySteps = [
  'WAITED',
  'CALLED_GUARDIAN',
  'CALLED_ALTERNATE',
  'CALLED_OFFICE',
  'CARRIED_ON_ROUTE',
  'RETURNED_TO_SCHOOL',
  'RETURNED_TO_DEPOT',
  'RELEASED_TO_OFFICE_STAFF',
];

const List<String> _refusalReasons = [
  'NOT_ON_THE_LIST',
  'IDENTITY_NOT_SATISFIED',
  'RESTRICTION_IN_FORCE',
  'ADULT_APPEARED_UNFIT',
  'CHILD_REFUSED',
  'OTHER',
];

/* ---------------------------------------------------------------------------
 * Reading the server's answers
 * ------------------------------------------------------------------------- */

DateTime? _at(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// The value, if the server's own length rule would accept it back.
///
/// These are all optional snapshot fields, so a name the validator would refuse
/// is dropped rather than trimmed: a 400 at the kerb, on the one call that must
/// go through, is a far worse outcome than a row without a spare copy of a name
/// it already holds by id.
String? _fits(String? raw, int min, int max) {
  final v = raw?.trim() ?? '';
  return v.length >= min && v.length <= max ? v : null;
}

/// An absolute address for a photograph, or null when there is not one.
///
/// Null matters here more than anywhere else in the app: a missing photograph
/// must look like a missing photograph, never like a face somebody checked.
String? _photo(dynamic raw) {
  final v = (raw as String?)?.trim() ?? '';
  if (v.isEmpty) return null;
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  return '$kApiBase${v.startsWith('/') ? '' : '/'}$v';
}

/// FATHER → "Father", in whichever language the app is showing.
///
/// Kurdish has four different words where English says "uncle" and "aunt", and
/// which one it is carries real information at a door — so the enum is
/// translated rather than tidied up. A label the office typed by hand is shown
/// exactly as they typed it.
String relationLabel(String? raw) {
  final v = raw?.trim() ?? '';
  if (v.isEmpty) return '';
  if (!RegExp(r'^[A-Z_]+$').hasMatch(v)) return v;
  final label = t('rel.$v');
  return label == 'rel.$v' ? humanise(v) : label;
}

class _Allowed {
  _Allowed({
    required this.kind,
    required this.refId,
    required this.personId,
    required this.name,
    required this.relationship,
    required this.photoUrl,
    required this.isPrimary,
  });

  final String kind;
  final String refId;
  final String? personId;

  /// Null where the school holds no name. Kept nullable rather than filled with
  /// a placeholder, because this value is also written to the custody ledger
  /// and "Name not recorded" is not a person.
  final String? name;
  final String? relationship;
  final String? photoUrl;
  final bool isPrimary;

  bool get isGuardian => kind == 'GUARDIAN';
  String get display => name ?? t('handover.unnamed');

  factory _Allowed.from(Map<String, dynamic> j) {
    final name = (j['name'] as String?)?.trim() ?? '';
    return _Allowed(
      kind: (j['kind'] ?? '') as String,
      refId: (j['refId'] ?? '') as String,
      personId: j['personId'] as String?,
      name: name.isEmpty ? null : name,
      relationship: j['relationship'] as String?,
      photoUrl: _photo(j['photoUrl']),
      isPrimary: (j['isPrimary'] ?? false) as bool,
    );
  }
}

/// An authorisation the office issued over the phone, for this run only.
class _OneTime {
  _OneTime({
    required this.id,
    required this.name,
    required this.idNumber,
    required this.phone,
    required this.validUntil,
  });

  final String id;
  final String? name;
  final String? idNumber;
  final String? phone;
  final DateTime? validUntil;

  bool get expired => validUntil != null && validUntil!.isBefore(DateTime.now());
  String get display => name ?? t('handover.unnamed');

  factory _OneTime.from(Map<String, dynamic> j) {
    final name = (j['collectorName'] as String?)?.trim() ?? '';
    return _OneTime(
      id: (j['id'] ?? '') as String,
      name: name.isEmpty ? null : name,
      idNumber: (j['collectorIdNumber'] as String?)?.trim(),
      phone: (j['collectorPhoneE164'] as String?)?.trim(),
      validUntil: _at(j['validUntil']),
    );
  }
}

class _Collectors {
  _Collectors({
    required this.name,
    required this.code,
    required this.photoUrl,
    required this.mayLeaveAlone,
    required this.allowed,
    required this.oneTimes,
    required this.hold,
    required this.holdMessageKey,
    required this.siblingRule,
  });

  final String name;
  final String? code;
  final String? photoUrl;
  final bool mayLeaveAlone;
  final List<_Allowed> allowed;
  final List<_OneTime> oneTimes;

  /// "Do not release — call the office." The reason never travels to the phone.
  final bool hold;
  final String? holdMessageKey;
  final String? siblingRule;

  factory _Collectors.from(Map<String, dynamic> j) {
    final student = (j['student'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    final name = (student['name'] as String?)?.trim() ?? '';
    return _Collectors(
      name: name.isEmpty ? t('handover.unnamed') : name,
      code: (student['code'] as String?)?.trim(),
      photoUrl: _photo(student['photoUrl']),
      mayLeaveAlone: (student['mayLeaveAlone'] ?? false) as bool,
      allowed: ((j['allowed'] as List?) ?? const [])
          .map((e) => _Allowed.from(e as Map<String, dynamic>))
          .toList(),
      oneTimes: ((j['oneTimeAuthorizations'] as List?) ?? const [])
          .map((e) => _OneTime.from(e as Map<String, dynamic>))
          .toList(),
      hold: (j['holdAndCallOffice'] ?? false) as bool,
      holdMessageKey: j['holdMessageKey'] as String?,
      siblingRule: j['siblingRule'] as String?,
    );
  }
}

/// One row already written to the custody ledger for this child on this run.
class _Recorded {
  _Recorded({required this.type, required this.at, required this.note, required this.step});

  final String type;
  final DateTime? at;
  final String? note;
  final String? step;

  factory _Recorded.from(Map<String, dynamic> j) {
    final payload = j['payload'];
    final note = (j['manualReason'] as String?)?.trim() ?? '';
    return _Recorded(
      type: (j['type'] ?? '') as String,
      at: _at(j['effectiveTime']),
      note: note.isEmpty ? null : note,
      step: payload is Map ? payload['protocolStep'] as String? : null,
    );
  }

  String get label => switch (type) {
        'HANDOVER' => t('driver.handedOver'),
        'ONE_TIME_AUTH_USED' => t('handover.evOneTime'),
        'HANDOVER_REFUSED' => t('handover.evRefused'),
        'NOBODY_AT_STOP' => step == null ? t('handover.nobodyTitle') : t('nobody.$step'),
        _ => humanise(type),
      };

  Color get colour => switch (type) {
        'HANDOVER' || 'ONE_TIME_AUTH_USED' => AppTheme.green,
        'HANDOVER_REFUSED' => AppTheme.rose,
        _ => AppTheme.amber,
      };
}

/// How far down the ladder the crew already is, read off the ledger rather than
/// off the driver's memory.
class _Protocol {
  _Protocol({
    required this.resolved,
    required this.stepsTaken,
    required this.nextStep,
    required this.events,
  });

  final bool resolved;
  final List<String> stepsTaken;
  final String? nextStep;
  final List<_Recorded> events;

  factory _Protocol.from(Map<String, dynamic> j) => _Protocol(
        resolved: (j['resolved'] ?? false) as bool,
        stepsTaken: ((j['stepsTaken'] as List?) ?? const []).map((e) => '$e').toList(),
        nextStep: j['nextStep'] as String?,
        events: ((j['events'] as List?) ?? const [])
            .map((e) => _Recorded.from(e as Map<String, dynamic>))
            .toList(),
      );

  DateTime? get handedOverAt => events
      .where((e) => e.type == 'HANDOVER' || e.type == 'ONE_TIME_AUTH_USED')
      .map((e) => e.at)
      .lastOrNull;
}

class _Contact {
  _Contact({required this.name, required this.phone, required this.relationship});

  final String name;
  final String? phone;
  final String? relationship;
}

/// The parts of the trip pack this screen needs: numbers to ring, and the notes
/// the office wrote about handing this particular child over.
class _PackNotes {
  _PackNotes({
    required this.officeName,
    required this.officePhone,
    required this.contacts,
    required this.crewNote,
    required this.handoverNote,
    required this.doNotReleaseAlone,
  });

  final String? officeName;
  final String? officePhone;
  final List<_Contact> contacts;
  final String? crewNote;
  final String? handoverNote;
  final bool doNotReleaseAlone;

  static String? _text(dynamic v) {
    final s = (v as String?)?.trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static _PackNotes? from(Map<String, dynamic>? j, String studentId) {
    if (j == null) return null;
    final campus = (j['campus'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    final entry = ((j['roster'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .where((e) => e['studentId'] == studentId)
        .firstOrNull;
    final needs = (entry?['specialNeeds'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    final student = (entry?['student'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    return _PackNotes(
      officeName: _text(campus['name']),
      officePhone: _text(campus['phone']),
      contacts: ((entry?['guardians'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((g) => _Contact(
                name: _text(g['name']) ?? t('handover.unnamed'),
                phone: _text(g['phone']),
                relationship: g['relationship'] as String?,
              ))
          .toList(),
      crewNote: _text(student['crewNote']),
      handoverNote: _text(needs['handoverNote']),
      doNotReleaseAlone: (needs['doNotReleaseAlone'] ?? false) as bool,
    );
  }
}

class _Door {
  _Door({required this.collectors, required this.protocol, required this.notes});

  final _Collectors collectors;
  final _Protocol protocol;

  /// Null when the pack could not be fetched. The decision does not depend on
  /// it — only the phone numbers and the notes do — so a failure here never
  /// blocks the door.
  final _PackNotes? notes;
}

/* ---------------------------------------------------------------------------
 * The calls
 * ------------------------------------------------------------------------- */

String _collectorsPath(String tripId, String studentId) =>
    '/crew/handover/trips/$tripId/students/$studentId/collectors';

String _protocolPath(String tripId, String studentId) =>
    '/crew/handover/trips/$tripId/students/$studentId/protocol';

Future<_Protocol> _loadProtocol(String tripId, String studentId) async {
  final json = await ApiClient.instance.get(_protocolPath(tripId, studentId));
  return _Protocol.from(json as Map<String, dynamic>);
}

/* ---------------------------------------------------------------------------
 * The screen
 * ------------------------------------------------------------------------- */

class HandoverScreen extends StatefulWidget {
  const HandoverScreen({
    super.key,
    required this.tripId,
    required this.studentId,
    required this.studentName,
    this.stopId,
    this.stopName,
  });

  final String tripId;
  final String studentId;

  /// What the roster calls this child. Only used for the sub-screens' titles
  /// before the collectors call has answered.
  final String studentName;
  final String? stopId;
  final String? stopName;

  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  final _loaderKey = GlobalKey<LoaderState<_Door>>();

  /// What this visit ended up writing, handed back to the roster so the row
  /// stops inviting the driver to do it again.
  HandoverOutcome? _outcome;

  Future<Map<String, dynamic>?> _pack() async {
    try {
      final json = await ApiClient.instance.get('/crew/trips/${widget.tripId}/pack');
      return json as Map<String, dynamic>;
    } catch (_) {
      // The pack is forty children deep and this screen wants four phone
      // numbers out of it. Losing it costs the numbers, not the handover.
      return null;
    }
  }

  Future<_Door> _load() async {
    final api = ApiClient.instance;
    final answers = await Future.wait<dynamic>([
      api.get(_collectorsPath(widget.tripId, widget.studentId)),
      api.get(_protocolPath(widget.tripId, widget.studentId)),
      _pack(),
    ]);
    return _Door(
      collectors: _Collectors.from(answers[0] as Map<String, dynamic>),
      protocol: _Protocol.from(answers[1] as Map<String, dynamic>),
      notes: _PackNotes.from(answers[2] as Map<String, dynamic>?, widget.studentId),
    );
  }

  Future<void> _confirm(_Door door, {_Allowed? adult, _OneTime? oneTime}) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmHandover(
        tripId: widget.tripId,
        studentId: widget.studentId,
        studentName: door.collectors.name,
        stopId: widget.stopId,
        adult: adult,
        oneTime: oneTime,
      ),
    );
    if (done != true || !mounted) return;
    Navigator.of(context).pop(HandoverOutcome.handedOver);
  }

  Future<void> _refuse(_Door door) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _RefuseScreen(
          tripId: widget.tripId,
          studentId: widget.studentId,
          studentName: door.collectors.name,
        ),
      ),
    );
    if (done != true || !mounted) return;
    Navigator.of(context).pop(HandoverOutcome.refused);
  }

  Future<void> _nobody(_Door door) async {
    final recorded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _NobodyScreen(
          tripId: widget.tripId,
          studentId: widget.studentId,
          studentName: door.collectors.name,
          stopId: widget.stopId,
          stopName: widget.stopName,
          protocol: door.protocol,
          notes: door.notes,
        ),
      ),
    );
    if (!mounted) return;
    if (recorded == true) setState(() => _outcome = HandoverOutcome.nobodyAtStop);
    _loaderKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<HandoverOutcome?>(
      canPop: _outcome == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) return;
        Navigator.of(context).pop(_outcome);
      },
      child: Scaffold(
        backgroundColor: AppTheme.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ScreenHeader(title: t('handover.title')),
              Expanded(
                child: Loader<_Door>(
                  key: _loaderKey,
                  tint: Role.driver.tint,
                  padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 28),
                  load: _load,
                  builder: (context, door) => _TheDoor(
                    door: door,
                    stopName: widget.stopName,
                    onPick: (adult) => _confirm(door, adult: adult),
                    onPickOneTime: (auth) => _confirm(door, oneTime: auth),
                    onRefuse: () => _refuse(door),
                    onNobody: () => _nobody(door),
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

/// Everything the driver looks at while an adult is standing at the door.
class _TheDoor extends StatelessWidget {
  const _TheDoor({
    required this.door,
    required this.stopName,
    required this.onPick,
    required this.onPickOneTime,
    required this.onRefuse,
    required this.onNobody,
  });

  final _Door door;
  final String? stopName;
  final ValueChanged<_Allowed> onPick;
  final ValueChanged<_OneTime> onPickOneTime;
  final VoidCallback onRefuse;
  final VoidCallback onNobody;

  static String? _siblingLine(String? rule) => switch (rule) {
        'ALL_SIBLINGS_TOGETHER' => t('handover.siblingsTogether'),
        'ESCORTED_BY_NAMED_SIBLING' => t('handover.siblingEscort'),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final child = door.collectors;
    final notes = door.notes;
    final settled = door.protocol.resolved;
    final siblings = _siblingLine(child.siblingRule);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The restriction goes first and goes loud. Anywhere further down the
        // page it is a footnote, and a footnote is a thing that gets missed.
        if (child.hold) ...[
          _Alarm(
            title: t('handover.holdTitle'),
            body: t(_holdMessages[child.holdMessageKey] ?? 'handover.holdBody'),
            phone: notes?.officePhone,
          ),
          const SizedBox(height: kCardGap),
        ],

        if (settled) ...[
          NoticeBanner(
            icon: Icons.verified_rounded,
            title: t('handover.alreadyDone'),
            body: tn('handover.alreadyBody', hhmm(door.protocol.handedOverAt)),
            color: AppTheme.green,
          ),
          const SizedBox(height: kCardGap),
        ],

        _ChildCard(child: child, stopName: stopName),
        const SizedBox(height: kCardGap),

        if (notes?.handoverNote != null)
          _NoteCard(
            icon: Icons.sticky_note_2_rounded,
            colour: AppTheme.violet,
            title: t('handover.handoverNote'),
            body: notes!.handoverNote!,
          ),
        if (notes?.doNotReleaseAlone ?? false)
          _NoteCard(
            icon: Icons.escalator_warning_rounded,
            colour: AppTheme.rose,
            title: t('handover.doNotReleaseAlone'),
            body: t('handover.doNotReleaseAloneBody'),
          ),
        if (siblings != null)
          _NoteCard(
            icon: Icons.groups_2_rounded,
            colour: AppTheme.amber,
            title: t('handover.siblingRule'),
            body: siblings,
          ),
        if (child.mayLeaveAlone)
          _NoteCard(
            icon: Icons.directions_walk_rounded,
            colour: AppTheme.blue,
            title: t('handover.mayLeaveAlone'),
            body: t('handover.mayLeaveAloneBody'),
          ),
        if (notes?.crewNote != null)
          _NoteCard(
            icon: Icons.info_outline_rounded,
            colour: AppTheme.blue,
            title: t('handover.crewNote'),
            body: notes!.crewNote!,
          ),

        SectionHead(t('handover.whoMayCollect')),
        Text(
          settled
              ? t('handover.alreadyList')
              : child.hold
                  ? t('handover.holdList')
                  : t('handover.checkList'),
          style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 10),

        if (child.allowed.isEmpty && child.oneTimes.isEmpty)
          _NoteCard(
            icon: Icons.person_off_rounded,
            colour: AppTheme.rose,
            title: t('handover.nobodyAllowed'),
            body: t('handover.nobodyAllowedBody'),
          )
        else ...[
          for (final adult in child.allowed) ...[
            _CollectorTile(
              adult: adult,
              onTap: settled || child.hold ? null : () => onPick(adult),
            ),
            const SizedBox(height: 8),
          ],
          for (final auth in child.oneTimes) ...[
            _OneTimeTile(
              auth: auth,
              onTap: settled || child.hold || auth.expired ? null : () => onPickOneTime(auth),
            ),
            const SizedBox(height: 8),
          ],
        ],

        const SizedBox(height: 4),
        _OfficeCard(
          name: notes?.officeName,
          phone: notes?.officePhone,
          body: t('handover.notOnList'),
        ),

        if (!settled) ...[
          const SizedBox(height: 18),
          BigButton(
            label: t('handover.nobody'),
            color: AppTheme.amber,
            height: 58,
            onPressed: onNobody,
          ),
          const SizedBox(height: 10),
          BigButton(
            label: t('handover.refuse'),
            color: AppTheme.rose,
            height: 58,
            onPressed: onRefuse,
          ),
        ],

        if (door.protocol.events.isNotEmpty) ...[
          SectionHead(t('handover.recordSoFar')),
          _Ledger(events: door.protocol.events),
        ],
      ],
    );
  }
}

/* ---------------------------------------------------------------------------
 * Pieces
 * ------------------------------------------------------------------------- */

/// The red card. Deliberately the loudest thing the driver app can draw.
class _Alarm extends StatelessWidget {
  const _Alarm({required this.title, required this.body, this.phone});

  final String title;
  final String body;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.rose,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.front_hand_rounded, size: 30, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          if (phone != null) ...[
            const SizedBox(height: 14),
            _CopyNumber(label: t('handover.officeNumber'), phone: phone!, onWhite: true),
          ],
        ],
      ),
    );
  }
}

/// Who this is about.
class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.stopName});

  final _Collectors child;
  final String? stopName;

  @override
  Widget build(BuildContext context) {
    final line = [child.code, stopName].where((s) => s != null && s.isNotEmpty).join('  ·  ');

    return Card16(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          _Face(url: child.photoUrl, size: 62),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppTheme.text,
                  ),
                ),
                if (line.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A photograph, or an honest statement that there is not one.
///
/// The empty case draws no initials and no silhouette. A grey disc with two
/// letters in it looks like an identity somebody checked, and nothing on this
/// screen may look like that when the school holds no photograph.
class _Face extends StatelessWidget {
  const _Face({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.amber.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: AppTheme.amber.withValues(alpha: 0.55), width: 1.4),
        ),
        child: Icon(Icons.no_photography_outlined, size: size * 0.42, color: AppTheme.amber),
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.neutralSoft,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.image_not_supported_outlined,
          size: size * 0.4,
          color: AppTheme.textFaint,
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.icon,
    required this.colour,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color colour;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kCardGap),
      child: NoticeBanner(icon: icon, title: title, body: body, color: colour),
    );
  }
}

/// One adult the school says may take this child.
class _CollectorTile extends StatelessWidget {
  const _CollectorTile({required this.adult, required this.onTap});

  final _Allowed adult;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final relation = relationLabel(adult.relationship);

    return Card16(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      border: onTap == null ? null : Role.driver.tint.withValues(alpha: 0.35),
      child: Opacity(
        opacity: onTap == null ? 0.62 : 1,
        child: Row(
          children: [
            _Face(url: adult.photoUrl, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adult.display,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppTheme.text,
                    ),
                  ),
                  if (relation.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      relation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Pill(
                        adult.isGuardian ? t('handover.guardian') : t('handover.authorised'),
                        color: adult.isGuardian ? AppTheme.blue : AppTheme.violet,
                      ),
                      if (adult.isPrimary) Pill(t('handover.primary'), color: AppTheme.green),
                      if (adult.photoUrl == null)
                        Pill(t('handover.noPhoto'), color: AppTheme.amber),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 22, color: Role.driver.tint),
          ],
        ),
      ),
    );
  }
}

/// The office rang, checked, and issued this against this run only.
class _OneTimeTile extends StatelessWidget {
  const _OneTimeTile({required this.auth, required this.onTap});

  final _OneTime auth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      border: AppTheme.violet.withValues(alpha: 0.45),
      child: Opacity(
        opacity: onTap == null ? 0.62 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconChip(
                  icon: Icons.assignment_turned_in_rounded,
                  color: AppTheme.violet,
                  background: AppTheme.violetSoft,
                  size: 40,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.display,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        t('handover.oneTime'),
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded, size: 22, color: Role.driver.tint),
              ],
            ),
            if (auth.idNumber != null) ...[
              const SizedBox(height: 10),
              Text(
                tn('handover.idNumber', auth.idNumber!),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: AppTheme.text,
                ),
              ),
            ],
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill(
                  auth.expired
                      ? t('handover.oneTimeExpired')
                      : tn('handover.oneTimeValid', hhmm(auth.validUntil)),
                  color: auth.expired ? AppTheme.rose : AppTheme.green,
                ),
                Pill(t('handover.noPhoto'), color: AppTheme.amber),
              ],
            ),
            if (auth.phone != null) ...[
              const SizedBox(height: 10),
              _CopyNumber(label: t('handover.theirNumber'), phone: auth.phone!),
            ],
          ],
        ),
      ),
    );
  }
}

/// The office, and its number, always one tap from being copied.
class _OfficeCard extends StatelessWidget {
  const _OfficeCard({required this.name, required this.phone, required this.body});

  final String? name;
  final String? phone;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.support_agent_rounded,
                color: AppTheme.blue,
                background: AppTheme.blueSoft,
                size: 40,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  name ?? t('handover.office'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          if (phone != null)
            _CopyNumber(label: t('handover.officeNumber'), phone: phone!)
          else
            Text(
              t('handover.noOfficeNumber'),
              style: TextStyle(fontSize: 12, color: AppTheme.amber, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

/// A number, big enough to read at arm's length, copied by tapping it.
///
/// This build has nothing bound to the dialler, so the honest affordance is
/// "copy" rather than a call button that might do nothing at the one moment
/// somebody needs it.
class _CopyNumber extends StatelessWidget {
  const _CopyNumber({required this.label, required this.phone, this.onWhite = false});

  final String label;
  final String phone;
  final bool onWhite;

  @override
  Widget build(BuildContext context) {
    final ink = onWhite ? Colors.white : AppTheme.text;
    final quiet = onWhite ? Colors.white.withValues(alpha: 0.85) : AppTheme.textMuted;

    return Material(
      color: onWhite
          ? Colors.white.withValues(alpha: 0.18)
          : AppTheme.blue.withValues(alpha: AppTheme.dark ? 0.16 : 0.08),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: phone));
          if (context.mounted) showNote(context, t('bus.numberCopied'));
        },
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                Icon(Icons.phone_rounded, size: 20, color: onWhite ? Colors.white : AppTheme.blue),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: quiet),
                      ),
                      Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.copy_rounded, size: 17, color: quiet),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What has already been written down for this child on this run.
class _Ledger extends StatelessWidget {
  const _Ledger({required this.events});

  final List<_Recorded> events;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(color: events[i].colour, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          events[i].label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        if (events[i].note != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            events[i].note!,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hhmm(events[i].at),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The sentence a driver must be shown when a write did not land.
///
/// A snackbar is the wrong shape for this: it fades, and "the handover was not
/// recorded" may not fade while the child is already walking away. It stays on
/// the sheet until the write succeeds or the driver leaves.
class _NotRecorded extends StatelessWidget {
  const _NotRecorded({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.rose.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.rose, width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 22, color: AppTheme.rose),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('handover.notRecorded'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.rose),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Press, and keep pressing.
///
/// Every write on this screen goes through one of these. A target big enough
/// for a gloved hand is also a target big enough to hit by accident while the
/// bus is moving, and the thing on the other side of it decides whether a child
/// leaves with a particular adult.
class _HoldToConfirm extends StatefulWidget {
  const _HoldToConfirm({
    required this.label,
    required this.colour,
    required this.onConfirmed,
    this.enabled = true,
    this.busy = false,
  });

  final String label;
  final Color colour;
  final VoidCallback onConfirmed;
  final bool enabled;
  final bool busy;

  @override
  State<_HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<_HoldToConfirm> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..addStatusListener(_finished);

  void _finished(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    HapticFeedback.heavyImpact();
    // Wound back before the call goes out, not after: whatever onConfirmed does
    // to this subtree — including taking it off the screen — the controller has
    // already been left in a state nothing else has to touch.
    _hold.value = 0;
    widget.onConfirmed();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  bool get _live => widget.enabled && !widget.busy;

  void _down() {
    if (!_live) return;
    HapticFeedback.selectionClick();
    _hold.forward();
  }

  void _up() {
    if (_hold.value == 0) return;
    _hold.animateBack(0, duration: const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context) {
    final colour = _live ? widget.colour : widget.colour.withValues(alpha: 0.45);

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => Container(
            width: double.infinity,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Stack(
              children: [
                // The fill is the whole of the feedback: it says how much
                // longer, and it says that letting go undoes it.
                FractionallySizedBox(
                  widthFactor: _hold.value,
                  child: Container(color: Colors.white.withValues(alpha: 0.30)),
                ),
                Center(
                  child: widget.busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _hold.value > 0 ? Icons.touch_app_rounded : Icons.lock_open_rounded,
                              size: 21,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                _hold.value > 0 ? t('handover.keepHolding') : widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Recording the handover
 * ------------------------------------------------------------------------- */

/// The last thing between a tap on a name and a child leaving the bus.
class _ConfirmHandover extends StatefulWidget {
  const _ConfirmHandover({
    required this.tripId,
    required this.studentId,
    required this.studentName,
    required this.stopId,
    required this.adult,
    required this.oneTime,
  });

  final String tripId;
  final String studentId;
  final String studentName;
  final String? stopId;
  final _Allowed? adult;
  final _OneTime? oneTime;

  @override
  State<_ConfirmHandover> createState() => _ConfirmHandoverState();
}

class _ConfirmHandoverState extends State<_ConfirmHandover> {
  bool _busy = false;
  String? _error;

  /// Minted once, before the first attempt, and reused on every retry. That is
  /// what makes "try again" free over a connection that drops halfway: the
  /// server reads the repeat as the same event rather than a second release.
  String? _uuid;

  String get _name => widget.adult?.display ?? widget.oneTime?.display ?? '';
  String? get _photoUrl => widget.adult?.photoUrl;

  /// A photo tap where there is a photograph to tap. Where there is not, the
  /// weaker method with a reason attached — claiming a face was matched against
  /// a photograph the school never held is the one lie this record could not
  /// survive.
  String get _method => _photoUrl != null ? 'PHOTO_TAP' : 'MANUAL_WITH_REASON';

  /// Kept in English deliberately: it is written to the custody ledger, which
  /// the office reads alongside every other crew's rows, not to the screen.
  String? get _reason {
    if (_photoUrl != null) return null;
    if (widget.oneTime != null) {
      return widget.oneTime!.idNumber != null
          ? 'One-time authorisation issued by the office for this run. The crew checked the identity document number shown on the handset.'
          : 'One-time authorisation issued by the office for this run. No identity document number was recorded against it.';
    }
    return 'No photograph on file for this collector. The crew identified them by name and relationship at the stop.';
  }

  String get _attestation {
    if (_photoUrl != null) return t('handover.photoAttest');
    if (widget.oneTime != null) return t('handover.oneTimeAttest');
    return t('handover.noPhotoAttest');
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final uuid = _uuid ??= uuidV4();
    final adult = widget.adult;
    final auth = widget.oneTime;
    // Snapshots, beside the foreign keys rather than instead of them. The
    // office may edit or remove a collector next term; the row that says who
    // took this child home has to still say it.
    final name = _fits(adult?.name ?? auth?.name, 2, 120);
    final relation = _fits(adult?.relationship, 2, 60);
    try {
      await ApiClient.instance.post('/crew/handover', {
        'clientUuid': uuid,
        'tripInstanceId': widget.tripId,
        'studentId': widget.studentId,
        'stopId': ?widget.stopId,
        'authorizedCollectorId': ?(adult != null && !adult.isGuardian ? adult.refId : null),
        'collectorPersonId': ?adult?.personId,
        'oneTimeAuthorizationId': ?auth?.id,
        'collectorName': ?name,
        'collectorRelation': ?relation,
        'captureMethod': _method,
        'manualReason': ?_reason,
        'deviceTime': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final relation = relationLabel(widget.adult?.relationship);
    final hasPhoto = _photoUrl != null;

    return _Sheet(
      // Not while the write is in the air. A sheet swiped away mid-request
      // leaves the driver with no idea whether a child was signed for.
      locked: _busy,
      children: [
        Text(
          tv('handover.releasing', {'child': widget.studentName, 'adult': _name}),
          style: TextStyle(
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _Face(url: _photoUrl, size: 96),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppTheme.text,
                    ),
                  ),
                  if (relation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      relation,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                  if (widget.oneTime?.idNumber != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      tn('handover.idNumber', widget.oneTime!.idNumber!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppTheme.text,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (hasPhoto ? AppTheme.blue : AppTheme.amber)
                .withValues(alpha: AppTheme.dark ? 0.16 : 0.09),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasPhoto ? Icons.face_rounded : Icons.no_photography_outlined,
                size: 20,
                color: hasPhoto ? AppTheme.blue : AppTheme.amber,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _attestation,
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.text),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _NotRecorded(message: _error!),
        ],
        const SizedBox(height: 18),
        _HoldToConfirm(
          label: t('handover.holdToHandOver'),
          colour: AppTheme.green,
          busy: _busy,
          onConfirmed: _submit,
        ),
      ],
    );
  }
}

/// The bottom sheet a confirmation is poured into.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.children, this.locked = false});

  final List<Widget> children;

  /// Holds the sheet open while a write is in flight.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: !locked,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ...children,
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: locked ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    t('common.cancel'),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
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

/* ---------------------------------------------------------------------------
 * Refusing
 * ------------------------------------------------------------------------- */

/// The crew declined to release the child.
///
/// A first-class outcome with its own row, not the absence of one. A driver who
/// refused an adult he was not sure about did exactly the right thing, and this
/// record is what stands behind him when the complaint reaches the office an
/// hour later.
class _RefuseScreen extends StatefulWidget {
  const _RefuseScreen({
    required this.tripId,
    required this.studentId,
    required this.studentName,
  });

  final String tripId;
  final String studentId;
  final String studentName;

  @override
  State<_RefuseScreen> createState() => _RefuseScreenState();
}

class _RefuseScreenState extends State<_RefuseScreen> {
  final _note = TextEditingController();
  final _who = TextEditingController();
  String? _reason;
  bool _busy = false;
  String? _error;
  String? _uuid;

  @override
  void dispose() {
    _note.dispose();
    _who.dispose();
    super.dispose();
  }

  /// The server asks for at least four characters, and it is right to: "no" is
  /// not a record anybody can act on three weeks later.
  bool get _ready => _reason != null && _note.text.trim().length >= 4;

  Future<void> _submit() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final uuid = _uuid ??= uuidV4();
    final who = _fits(_who.text, 2, 120);
    try {
      await ApiClient.instance.post('/crew/handover/refuse', {
        'clientUuid': uuid,
        'tripInstanceId': widget.tripId,
        'studentId': widget.studentId,
        'reason': _reason,
        'note': _note.text.trim(),
        'collectorName': ?who,
        'deviceTime': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: !_busy,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('handover.refuseTitle')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 28),
                children: [
                  NoticeBanner(
                    icon: Icons.shield_rounded,
                    title: tv('handover.refuseFor', {'child': widget.studentName}),
                    body: t('handover.refuseBody'),
                    color: AppTheme.rose,
                  ),
                  const SizedBox(height: 14),
                  SectionHead(t('handover.refuseWhy')),
                  for (final reason in _refusalReasons) ...[
                    _PickRow(
                      label: t('refuse.$reason'),
                      selected: _reason == reason,
                      colour: AppTheme.rose,
                      onTap: () => setState(() => _reason = reason),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 6),
                  SectionHead(t('handover.refuseWho')),
                  TextField(
                    controller: _who,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 120,
                    decoration: InputDecoration(
                      hintText: t('handover.refuseWhoHint'),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionHead(t('handover.refuseNote')),
                  TextField(
                    controller: _note,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(hintText: t('handover.refuseNoteHint')),
                  ),
                  if (!_ready)
                    Text(
                      t('handover.refuseNeeds'),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.amber,
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _NotRecorded(message: _error!),
                  ],
                  const SizedBox(height: 18),
                  _HoldToConfirm(
                    label: t('handover.holdToRefuse'),
                    colour: AppTheme.rose,
                    enabled: _ready,
                    busy: _busy,
                    onConfirmed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A big single-select row. Nothing on these screens is a radio button — a
/// radio button is four millimetres wide.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.selected,
    required this.colour,
    required this.onTap,
    this.trailing,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final Color colour;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      onTap: enabled ? onTap : null,
      border: selected ? colour : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 24,
                color: selected ? colour : AppTheme.textFaint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Nobody at the stop
 * ------------------------------------------------------------------------- */

/// The ladder.
///
/// The child is never put down on the pavement. The crew works a fixed order —
/// wait, ring the guardian, ring the alternate, ring the office, carry the
/// child on — and each rung is written as it happens, because the question
/// afterwards is always "what did you actually do, and when". One note typed at
/// the depot forty minutes later cannot answer that.
class _NobodyScreen extends StatefulWidget {
  const _NobodyScreen({
    required this.tripId,
    required this.studentId,
    required this.studentName,
    required this.stopId,
    required this.stopName,
    required this.protocol,
    required this.notes,
  });

  final String tripId;
  final String studentId;
  final String studentName;
  final String? stopId;
  final String? stopName;
  final _Protocol protocol;
  final _PackNotes? notes;

  @override
  State<_NobodyScreen> createState() => _NobodyScreenState();
}

class _NobodyScreenState extends State<_NobodyScreen> {
  late _Protocol _protocol = widget.protocol;
  final _note = TextEditingController();
  String? _step;
  bool _busy = false;
  bool _wroteSomething = false;
  String? _error;
  String? _uuid;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final step = _step;
    if (step == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final uuid = _uuid ??= uuidV4();
    final note = _fits(_note.text, 2, 500);

    try {
      await ApiClient.instance.post('/crew/handover/nobody-at-stop', {
        'clientUuid': uuid,
        'tripInstanceId': widget.tripId,
        'studentId': widget.studentId,
        'stopId': ?widget.stopId,
        'step': step,
        'note': ?note,
        'deviceTime': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e);
      });
      return;
    }

    // The rung is written. Nothing after this line may tell the driver
    // otherwise — the re-read below is a convenience, and it used to share a
    // catch with the write, so a refresh that failed on a weak signal reported
    // "NOT recorded" over a step the server had already accepted.
    final taken = [..._protocol.stepsTaken, step];
    _Protocol? fresh;
    try {
      fresh = await _loadProtocol(widget.tripId, widget.studentId);
    } catch (_) {
      fresh = null;
    }
    if (!mounted) return;
    setState(() {
      _protocol = fresh ??
          _Protocol(
            resolved: _protocol.resolved,
            stepsTaken: taken,
            nextStep: _nobodySteps.where((s) => !taken.contains(s)).firstOrNull,
            events: _protocol.events,
          );
      _busy = false;
      _wroteSomething = true;
      // A fresh key for the next rung. This one is written, and must never be
      // sent again under the same id.
      _uuid = null;
      _step = null;
      _note.clear();
    });
    showNote(context, t('handover.stepRecorded'));
  }

  @override
  Widget build(BuildContext context) {
    final contacts = widget.notes?.contacts.where((c) => c.phone != null).toList() ?? const [];
    final officePhone = widget.notes?.officePhone;

    return PopScope<bool>(
      canPop: !_wroteSomething && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted || _busy) return;
        Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: AppTheme.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ScreenHeader(title: t('handover.nobodyTitle')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 28),
                  children: [
                    NoticeBanner(
                      icon: Icons.airline_seat_recline_normal_rounded,
                      title: tv('handover.nobodyFor', {
                        'child': widget.studentName,
                        'stop': widget.stopName ?? t('handover.thisStop'),
                      }),
                      body: t('handover.nobodyBody'),
                      color: AppTheme.amber,
                    ),

                    if (contacts.isNotEmpty || officePhone != null) ...[
                      const SizedBox(height: 14),
                      SectionHead(t('handover.numbersToCall')),
                      for (final contact in contacts) ...[
                        _CopyNumber(
                          label: [contact.name, relationLabel(contact.relationship)]
                              .where((s) => s.isNotEmpty)
                              .join('  ·  '),
                          phone: contact.phone!,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (officePhone != null)
                        _CopyNumber(label: t('handover.officeNumber'), phone: officePhone),
                    ] else ...[
                      const SizedBox(height: 14),
                      _NoteCard(
                        icon: Icons.wifi_off_rounded,
                        colour: AppTheme.amber,
                        title: t('handover.noNumbers'),
                        body: t('handover.noNumbersBody'),
                      ),
                    ],

                    const SizedBox(height: 14),
                    SectionHead(t('handover.theLadder')),
                    for (final step in _nobodySteps) ...[
                      _PickRow(
                        label: t('nobody.$step'),
                        selected: _step == step,
                        colour: AppTheme.amber,
                        enabled: !_protocol.stepsTaken.contains(step),
                        onTap: () => setState(() => _step = step),
                        trailing: _protocol.stepsTaken.contains(step)
                            ? Pill(t('handover.stepDone'), color: AppTheme.green)
                            : _protocol.nextStep == step
                                ? Pill(t('handover.stepNext'), color: Role.driver.tint)
                                : null,
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (_step != null) ...[
                      const SizedBox(height: 6),
                      SectionHead(t('handover.stepNote')),
                      TextField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(hintText: t('handover.stepNoteHint')),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _NotRecorded(message: _error!),
                    ],

                    const SizedBox(height: 14),
                    _HoldToConfirm(
                      label: t('handover.holdToRecordStep'),
                      colour: AppTheme.amber,
                      enabled: _step != null,
                      busy: _busy,
                      onConfirmed: _submit,
                    ),

                    if (_protocol.events.isNotEmpty) ...[
                      SectionHead(t('handover.recordSoFar')),
                      _Ledger(events: _protocol.events),
                    ],
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
