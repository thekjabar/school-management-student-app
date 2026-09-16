import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

const _pointSteps = <num>[-1, 1, 2, 3, 5];

const _reasonKeys = <String>[
  'EFFORT',
  'HELPED',
  'ANSWERED',
  'IMPROVED',
  'PREPARED',
  'KINDNESS',
];

Future<void> awardMark(
  BuildContext context, {
  required String studentId,
  required String studentName,
  String? classId,
  String? subjectId,
}) async {
  final banked = await showAppSheet<bool>(
    context,
    builder: (_) => AwardMarkSheet(
      studentId: studentId,
      studentName: studentName,
      classId: classId,
      subjectId: subjectId,
    ),
  );
  if (banked == true && context.mounted) {
    showNote(context, t('bank.bankedNote'));
  }
}

class AwardMarkSheet extends StatefulWidget {
  const AwardMarkSheet({
    super.key,
    required this.studentId,
    required this.studentName,
    this.classId,
    this.subjectId,
  });

  final String studentId;
  final String studentName;

  final String? classId;
  final String? subjectId;

  @override
  State<AwardMarkSheet> createState() => _AwardMarkSheetState();
}

class _AwardMarkSheetState extends State<AwardMarkSheet> {
  static String? _termId;
  static bool _termAsked = false;

  num _points = 2;
  String? _reasonKey;
  final _reason = TextEditingController();

  String? _evidenceId;
  bool _uploading = false;

  String? _photoWarning;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
    if (!_termAsked) {
      _termAsked = true;
      TeacherApi.instance.currentTermId().then((id) {
        _termId = id;
      }).catchError((_) => null);
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String get _sentence {
    final typed = _reason.text.trim();
    if (typed.isNotEmpty) return typed;
    if (_reasonKey != null) return t('bank.reason.$_reasonKey');
    return '';
  }

  bool get _ready => _sentence.isNotEmpty && !_busy;

  Future<void> _attach() async {
    setState(() {
      _uploading = true;
      _photoWarning = null;
    });
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 75,
      );
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      final id = await TeacherApi.instance.uploadMarkEvidence(
        bytes: bytes,
        filename: 'work.jpg',
        mime: 'image/jpeg',
        studentId: widget.studentId,
      );
      if (mounted) setState(() => _evidenceId = id);
    } catch (_) {
      if (mounted) setState(() => _photoWarning = t('bank.photoFailed'));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _bank() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TeacherApi.instance.bankMark(
        studentId: widget.studentId,
        points: _points,
        reason: _sentence,
        classId: widget.classId,
        subjectId: widget.subjectId,
        termId: _termId,
        evidenceMediaId: _evidenceId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final positive = _points >= 0;
    final colour = positive ? tint : AppTheme.amber;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: withBottomInset(context, const EdgeInsets.fromLTRB(18, 10, 18, 18)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Grabber(),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const _PrivatePill(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                t('bank.privateBody'),
                style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 15),

              Row(
                children: [
                  for (var i = 0; i < _pointSteps.length; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    Expanded(
                      child: _PointChip(
                        value: _pointSteps[i],
                        on: _points == _pointSteps[i],
                        onTap: () => setState(() => _points = _pointSteps[i]),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 15),

              Text(
                t('bank.why'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in _reasonKeys)
                    _ReasonChip(
                      label: t('bank.reason.$key'),
                      colour: colour,
                      on: _reasonKey == key,
                      onTap: () => setState(() => _reasonKey = _reasonKey == key ? null : key),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _reason,
                maxLines: 2,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: t('bank.reasonHint'),
                  counterText: '',
                  filled: true,
                  fillColor: AppTheme.canvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              InkWell(
                onTap: _uploading ? null : _attach,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  decoration: BoxDecoration(
                    color: _evidenceId != null ? colour.withValues(alpha: 0.10) : AppTheme.canvas,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _evidenceId != null ? colour : AppTheme.border,
                      width: _evidenceId != null ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_uploading)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: colour),
                        )
                      else
                        Icon(
                          _evidenceId != null
                              ? Icons.check_circle_rounded
                              : Icons.photo_camera_outlined,
                          size: 19,
                          color: _evidenceId != null ? colour : AppTheme.textMuted,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _evidenceId != null ? t('bank.photoOn') : t('bank.photo'),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: _evidenceId != null ? FontWeight.w700 : FontWeight.w600,
                            color: _evidenceId != null ? colour : AppTheme.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_photoWarning != null) ...[
                const SizedBox(height: 7),
                Text(
                  _photoWarning!,
                  style: TextStyle(fontSize: 11.5, height: 1.35, color: AppTheme.amber),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.rose),
                ),
              ],

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _ready ? _bank : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: colour,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.neutralSoft,
                    disabledForegroundColor: AppTheme.textFaint,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          tv('bank.bankIt', {'points': _signed(_points)}),
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
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

class MarkBankScreen extends StatefulWidget {
  const MarkBankScreen({super.key});

  @override
  State<MarkBankScreen> createState() => _MarkBankScreenState();
}

class _MarkBankScreenState extends State<MarkBankScreen> {
  final _loaderKey = GlobalKey<LoaderState<List<MarkBankEntry>>>();

  List<MarkBankEntry> _all = const [];

  String? _termId;

  bool _showSpent = false;

  final Set<String> _picked = <String>{};
  String? _pickedStudentId;

  MarkBankRules? _rules;

  bool _busy = false;

  List<num> get _steps {
    final steps = _rules?.pointSteps ?? const <num>[];
    return steps.isEmpty ? _pointSteps : steps;
  }

  List<MarkBankEntry> get _visible => _all
      .where((e) => _showSpent || e.isBanked)
      .where((e) => _termId == null || e.termId == _termId)
      .toList();

  List<({String id, String name})> get _terms {
    final seen = <String, String>{};
    for (final e in _all) {
      final id = e.termId;
      if (id != null && !seen.containsKey(id)) seen[id] = e.termName ?? t('bank.term');
    }
    return [for (final entry in seen.entries) (id: entry.key, name: entry.value)];
  }

  num get _balance =>
      _visible.where((e) => e.isBanked).fold<num>(0, (sum, e) => sum + e.points);

  num get _pickedPoints => _all
      .where((e) => _picked.contains(e.id))
      .fold<num>(0, (sum, e) => sum + e.points);

  List<({String id, String name, List<MarkBankEntry> rows})> get _byChild {
    final order = <String>[];
    final groups = <String, List<MarkBankEntry>>{};
    for (final e in _visible) {
      final rows = groups.putIfAbsent(e.studentId, () {
        order.add(e.studentId);
        return <MarkBankEntry>[];
      });
      rows.add(e);
    }
    return [
      for (final id in order)
        (id: id, name: groups[id]!.first.studentName, rows: groups[id]!),
    ];
  }

  /// Credit is awarded one child at a time, so picking a second child's credit
  /// starts a fresh selection rather than silently failing at the server.
  void _toggle(MarkBankEntry entry) {
    if (!entry.canSpend) return;
    setState(() {
      if (_picked.remove(entry.id)) return;
      if (_pickedStudentId != null && _pickedStudentId != entry.studentId) {
        _picked.clear();
      }
      _pickedStudentId = entry.studentId;
      _picked.add(entry.id);
    });
  }

  void _pickAllFor(List<MarkBankEntry> rows) {
    final ids = rows.where((e) => e.canSpend).map((e) => e.id).toList();
    if (ids.isEmpty) return;
    final allOn = ids.every(_picked.contains);
    setState(() {
      if (allOn) {
        _picked.removeAll(ids);
        return;
      }
      if (_pickedStudentId != rows.first.studentId) _picked.clear();
      _pickedStudentId = rows.first.studentId;
      _picked.addAll(ids);
    });
  }

  Future<void> _award(List<String> ids) async {
    if (ids.isEmpty || _busy) return;
    final entries = _all.where((e) => ids.contains(e.id)).toList();
    if (entries.isEmpty) return;

    setState(() => _busy = true);
    final given = await showAppSheet<MarkBankAward>(
      context,
      builder: (_) => _AwardSheet(
        entryIds: ids,
        studentName: entries.first.studentName,
        points: _pointsFor(ids),
        subjectName: entries.first.subjectName,
        principalApproves: _rules?.principalApproves ?? false,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (given == null) return;

    setState(() {
      _picked.clear();
      _pickedStudentId = null;
    });
    showNote(context, given.isWaiting ? t('bank.sentToHead') : t('bank.awardedNote'));
    await _loaderKey.currentState?.reload();
  }

  Future<void> _edit(MarkBankEntry entry) async {
    final changed = await showAppSheet<bool>(
      context,
      builder: (_) => _EditSheet(entry: entry, steps: _steps),
    );
    if (changed != true || !mounted) return;
    showNote(context, t('bank.changedNote'));
    await _loaderKey.currentState?.reload();
  }

  String _termName(List<({String id, String name})> terms) {
    if (_termId == null) return t('bank.allTerms');
    for (final term in terms) {
      if (term.id == _termId) return term.name;
    }
    return t('bank.term');
  }

  num _pointsFor(List<String> ids) =>
      _all.where((e) => ids.contains(e.id)).fold<num>(0, (sum, e) => sum + e.points);

  Future<void> _withdraw(MarkBankEntry entry) async {
    final reason = await showAppSheet<String>(
      context,
      builder: (_) => _WithdrawSheet(entry: entry),
    );
    if (reason == null || !mounted) return;
    try {
      await TeacherApi.instance.voidMark(entry.id, reason);
      if (!mounted) return;
      showNote(context, t('bank.withdrawnNote'));
      await _loaderKey.currentState?.reload();
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    final terms = _terms;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: t('bank.title'),
              subtitle: _all.isEmpty ? null : tn('bank.entriesN', _visible.length),
            ),
            Expanded(
              child: Loader<List<MarkBankEntry>>(
                key: _loaderKey,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
                load: () async {
                  final api = TeacherApi.instance;
                  final (rows, rules) =
                      await (api.markBank(), api.markBankRules()).wait;
                  _all = rows;
                  _rules = rules;
                  _picked.removeWhere(
                    (id) => !rows.any((e) => e.id == id && e.canSpend),
                  );
                  if (_picked.isEmpty) _pickedStudentId = null;
                  return rows;
                },
                isEmpty: (rows) => rows.isEmpty,
                empty: t('bank.empty'),
                builder: (context, rows) {
                  final groups = _byChild;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      NoticeBanner(
                        icon: Icons.lock_outline_rounded,
                        title: t('bank.privateTitle'),
                        body: t('bank.privateLedger'),
                        color: tint,
                      ),
                      const SizedBox(height: kCardGap),

                      _BalanceCard(
                        balance: _balance,
                        entries: _visible.where((e) => e.isBanked).length,
                        children: groups.length,
                        termName: _termName(terms),
                      ),
                      const SizedBox(height: kCardGap),

                      if (terms.length > 1) ...[
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _FilterChip(
                                label: t('bank.allTerms'),
                                on: _termId == null,
                                onTap: () => setState(() => _termId = null),
                              ),
                              for (final term in terms) ...[
                                const SizedBox(width: 7),
                                _FilterChip(
                                  label: term.name,
                                  on: _termId == term.id,
                                  onTap: () => setState(() => _termId = term.id),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: kCardGap),
                      ],

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t('bank.byChild'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                          _FilterChip(
                            label: t('bank.showSpent'),
                            on: _showSpent,
                            onTap: () => setState(() => _showSpent = !_showSpent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (groups.isEmpty)
                        Card16(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          child: Text(
                            t('bank.noneHere'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        )
                      else
                        for (final group in groups) ...[
                          _ChildBlock(
                            name: group.name,
                            rows: group.rows,
                            picked: _picked,
                            onToggle: _toggle,
                            onPickAll: () => _pickAllFor(group.rows),
                            onAwardOne: (e) => _award([e.id]),
                            onEdit: _edit,
                            onWithdraw: _withdraw,
                          ),
                          const SizedBox(height: kCardGap),
                        ],

                      if (_picked.isNotEmpty) const SizedBox(height: 78),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _picked.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 10),
              child: _AwardBar(
                count: _picked.length,
                points: _pickedPoints,
                busy: _busy,
                principalApproves: _rules?.principalApproves ?? false,
                onClear: () => setState(() {
                  _picked.clear();
                  _pickedStudentId = null;
                }),
                onAward: () => _award(_picked.toList()),
              ),
            ),
    );
  }
}

String _plain(num v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

String _signed(num v) => v > 0 ? '+${_plain(v)}' : _plain(v);

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _PrivatePill extends StatelessWidget {
  const _PrivatePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.neutralSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 5),
          Text(
            t('bank.privateTitle'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointChip extends StatelessWidget {
  const _PointChip({required this.value, required this.on, required this.onTap});

  final num value;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = value >= 0 ? Role.teacher.tint : AppTheme.amber;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? colour.withValues(alpha: 0.12) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: on ? colour : AppTheme.border, width: on ? 1.5 : 1),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _signed(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: on ? FontWeight.w800 : FontWeight.w700,
              color: on ? colour : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.colour,
    required this.on,
    required this.onTap,
  });

  final String label;
  final Color colour;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: on ? colour.withValues(alpha: 0.12) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? colour : AppTheme.border, width: on ? 1.4 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? colour : AppTheme.text,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: 0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? tint : AppTheme.border, width: on ? 1.3 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: on ? FontWeight.w700 : FontWeight.w600,
            color: on ? tint : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.entries,
    required this.children,
    required this.termName,
  });

  final num balance;
  final int entries;
  final int children;
  final String termName;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    return Card16(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            termName,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _signed(balance),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.4,
                  height: 1,
                  color: balance < 0 ? AppTheme.amber : tint,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  t('bank.unbanked'),
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${tn('bank.entriesN', entries)} · ${tn('bank.childrenN', children)}',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppTheme.border),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.redeem_rounded, size: 15, color: AppTheme.amber),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  t('bank.awardExplains'),
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChildBlock extends StatelessWidget {
  const _ChildBlock({
    required this.name,
    required this.rows,
    required this.picked,
    required this.onToggle,
    required this.onPickAll,
    required this.onAwardOne,
    required this.onEdit,
    required this.onWithdraw,
  });

  final String name;
  final List<MarkBankEntry> rows;
  final Set<String> picked;
  final void Function(MarkBankEntry) onToggle;
  final VoidCallback onPickAll;
  final void Function(MarkBankEntry) onAwardOne;
  final void Function(MarkBankEntry) onEdit;
  final void Function(MarkBankEntry) onWithdraw;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    final banked = rows.where((e) => e.isBanked).toList();
    final spendable = rows.where((e) => e.canSpend).toList();
    final balance = banked.fold<num>(0, (sum, e) => sum + e.points);

    return Card16(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleInitials(label: name, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Pill(
                _signed(balance),
                color: balance < 0 ? AppTheme.amber : tint,
                background: (balance < 0 ? AppTheme.amber : tint).withValues(alpha: 0.12),
              ),
              if (spendable.length > 1) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onPickAll,
                  borderRadius: BorderRadius.circular(9),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      spendable.every((e) => picked.contains(e.id))
                          ? Icons.select_all_rounded
                          : Icons.checklist_rounded,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          for (final entry in rows)
            _EntryRow(
              entry: entry,
              picked: picked.contains(entry.id),
              onToggle: () => onToggle(entry),
              onAward: () => onAwardOne(entry),
              onEdit: () => onEdit(entry),
              onWithdraw: () => onWithdraw(entry),
            ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.picked,
    required this.onToggle,
    required this.onAward,
    required this.onEdit,
    required this.onWithdraw,
  });

  final MarkBankEntry entry;
  final bool picked;
  final VoidCallback onToggle;
  final VoidCallback onAward;
  final VoidCallback onEdit;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    final spent = !entry.isBanked;
    final open = entry.canSpend;
    final colour = entry.points < 0 ? AppTheme.amber : tint;

    return InkWell(
      onTap: open ? onToggle : null,
      onLongPress: open ? onWithdraw : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: spent ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (open)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    picked ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 19,
                    color: picked ? tint : AppTheme.border,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    entry.awaitingApproval
                        ? Icons.hourglass_empty_rounded
                        : entry.state == 'VOIDED'
                            ? Icons.undo_rounded
                            : Icons.redeem_rounded,
                    size: 18,
                    color: entry.awaitingApproval ? AppTheme.amber : AppTheme.textFaint,
                  ),
                ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.reason,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (entry.evidenceMediaId != null) ...[
                          Icon(Icons.image_outlined, size: 12, color: AppTheme.textFaint),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            [
                              shortDate(entry.occurredAt),
                              ?entry.subjectName,
                              if (entry.awaitingApproval)
                                t('bank.waitingOnHead')
                              else if (spent)
                                t('bank.state.${entry.state}'),
                            ].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _signed(entry.points),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: spent ? AppTheme.textFaint : colour,
                ),
              ),
              if (open) ...[
                const SizedBox(width: 2),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(9),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(Icons.edit_outlined, size: 16, color: AppTheme.textFaint),
                  ),
                ),
                InkWell(
                  onTap: onAward,
                  borderRadius: BorderRadius.circular(9),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(Icons.redeem_rounded, size: 17, color: AppTheme.amber),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AwardBar extends StatelessWidget {
  const _AwardBar({
    required this.count,
    required this.points,
    required this.busy,
    required this.principalApproves,
    required this.onClear,
    required this.onAward,
  });

  final int count;
  final num points;
  final bool busy;
  final bool principalApproves;
  final VoidCallback onClear;
  final VoidCallback onAward;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: busy ? null : onClear,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textMuted,
              side: BorderSide(color: AppTheme.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: Text(t('bank.clear')),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: busy ? null : onAward,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(
                      tv(
                        principalApproves ? 'bank.proposeN' : 'bank.awardN',
                        {'n': count, 'points': _signed(points)},
                      ),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration _reasonBox(String hint) => InputDecoration(
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: AppTheme.canvas,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.border),
      ),
    );

/// Awarding is the moment private credit turns into a mark or a merit the
/// family can see, so the sheet asks the server what would change and shows it
/// before the teacher can confirm. Nothing is sent until the reason is typed.
class _AwardSheet extends StatefulWidget {
  const _AwardSheet({
    required this.entryIds,
    required this.studentName,
    required this.points,
    required this.principalApproves,
    this.subjectName,
  });

  final List<String> entryIds;
  final String studentName;
  final num points;
  final bool principalApproves;
  final String? subjectName;

  @override
  State<_AwardSheet> createState() => _AwardSheetState();
}

class _AwardSheetState extends State<_AwardSheet> {
  String _kind = 'TERM_MARK';

  final _reason = TextEditingController();

  AwardPreview? _preview;
  bool _looking = true;
  bool _acceptCap = false;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
    _look();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _look() async {
    setState(() {
      _looking = true;
      _error = null;
      _acceptCap = false;
    });
    try {
      final preview = await TeacherApi.instance.previewAward(
        entryIds: widget.entryIds,
        kind: _kind,
      );
      if (mounted) setState(() => _preview = preview);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  void _pick(String kind) {
    if (_kind == kind) return;
    setState(() {
      _kind = kind;
      _preview = null;
    });
    _look();
  }

  bool get _ready {
    final preview = _preview;
    if (preview == null || _busy || !preview.canGo) return false;
    if (preview.capped && !_acceptCap) return false;
    return _reason.text.trim().length >= 4;
  }

  Future<void> _give() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final award = await TeacherApi.instance.awardBanked(
        entryIds: widget.entryIds,
        kind: _kind,
        reason: _reason.text.trim(),
        acceptCap: _acceptCap,
      );
      if (!mounted) return;
      Navigator.of(context).pop(award);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final preview = _preview;
    final waits = preview?.needsApproval ?? widget.principalApproves;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: withBottomInset(context, const EdgeInsets.fromLTRB(18, 10, 18, 18)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Grabber(),
              const SizedBox(height: 16),
              Text(
                tv('bank.awardTitle', {
                  'name': widget.studentName,
                  'points': _signed(widget.points),
                }),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t('bank.awardBody'),
                style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),

              for (final kind in const ['TERM_MARK', 'MERIT']) ...[
                Card16(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  color: _kind == kind ? AppTheme.amber.withValues(alpha: 0.10) : AppTheme.canvas,
                  onTap: _busy ? null : () => _pick(kind),
                  child: Row(
                    children: [
                      Icon(
                        kind == 'MERIT'
                            ? Icons.star_outline_rounded
                            : Icons.workspace_premium_outlined,
                        size: 19,
                        color: _kind == kind ? AppTheme.amber : AppTheme.textFaint,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('bank.kind.$kind'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t('bank.kindBody.$kind'),
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _kind == kind
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 18,
                        color: _kind == kind ? AppTheme.amber : AppTheme.border,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 4),
              if (_looking)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.amber),
                    ),
                  ),
                )
              else if (preview != null)
                _ChangeCard(preview: preview, subjectName: widget.subjectName),

              if (preview != null && preview.capped) ...[
                const SizedBox(height: 8),
                Card16(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  color: AppTheme.amber.withValues(alpha: 0.10),
                  onTap: () => setState(() => _acceptCap = !_acceptCap),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _acceptCap
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 19,
                        color: AppTheme.amber,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          preview.capMessage ??
                              tv('bank.capLoses', {'points': _signed(preview.pointsLost)}),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (preview != null && preview.canGo) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _reason,
                  maxLines: 2,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 14, color: AppTheme.text),
                  decoration: _reasonBox(t('bank.awardWhy')),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.rose),
                ),
              ],

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _ready ? _give : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.amber,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.neutralSoft,
                    disabledForegroundColor: AppTheme.textFaint,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          waits
                              ? t('bank.sendToHead')
                              : tv('bank.giveIt', {
                                  'points': _signed(preview?.pointsToAward ?? widget.points),
                                }),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              if (waits) ...[
                const SizedBox(height: 8),
                Text(
                  t('bank.headMustAgree'),
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard({required this.preview, this.subjectName});

  final AwardPreview preview;
  final String? subjectName;

  @override
  Widget build(BuildContext context) {
    if (preview.refusal != null) {
      return Card16(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        color: AppTheme.rose.withValues(alpha: 0.10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.block_rounded, size: 18, color: AppTheme.rose),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preview.refusalMessage ?? t('bank.refusal.${preview.refusal}'),
                style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.text),
              ),
            ),
          ],
        ),
      );
    }

    final before = preview.scoreBefore;
    final after = preview.scoreAfter;
    final isMark = preview.kind == 'TERM_MARK' && before != null && after != null;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      color: AppTheme.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('bank.whatChanges'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          if (isMark)
            Row(
              children: [
                Text(
                  _plain(before),
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textFaint,
                  ),
                ),
                const SizedBox(width: 9),
                Icon(Icons.arrow_forward_rounded, size: 17, color: AppTheme.textFaint),
                const SizedBox(width: 9),
                Text(
                  _plain(after),
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.amber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subjectName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              ],
            )
          else
            Text(
              tv('bank.meritOf', {'points': _plain(preview.pointsToAward)}),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
          const SizedBox(height: 7),
          Text(
            tv('bank.spends', {
              'n': preview.entryCount,
              'points': _plain(preview.pointsToAward),
            }),
            style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Banked credit is still the teacher's own note, so it can be corrected until
/// it is awarded or sent to the principal.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.entry, required this.steps});

  final MarkBankEntry entry;
  final List<num> steps;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late num _points = widget.entry.points;
  late final _reason = TextEditingController(text: widget.entry.reason);

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _changed =>
      _points != widget.entry.points || _reason.text.trim() != widget.entry.reason;

  bool get _ready => _changed && !_busy && _reason.text.trim().length >= 2;

  Future<void> _save() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TeacherApi.instance.reviseMark(
        widget.entry.id,
        points: _points == widget.entry.points ? null : _points,
        reason: _reason.text.trim() == widget.entry.reason ? null : _reason.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: withBottomInset(context, const EdgeInsets.fromLTRB(18, 10, 18, 18)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Grabber(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t('bank.editTitle'),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  const _PrivatePill(),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                t('bank.editBody'),
                style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final step in widget.steps)
                    _PointChip(
                      value: step,
                      on: _points == step,
                      onTap: () => setState(() => _points = step),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _reason,
                maxLines: 2,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: _reasonBox(t('bank.why')),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.rose),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _ready ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Role.teacher.tint,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.neutralSoft,
                    disabledForegroundColor: AppTheme.textFaint,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          t('bank.saveChange'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.entry});

  final MarkBankEntry entry;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final ready = _reason.text.trim().length >= 3;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: withBottomInset(context, const EdgeInsets.fromLTRB(18, 10, 18, 18)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Grabber(),
              const SizedBox(height: 16),
              Text(
                t('bank.withdrawTitle'),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${widget.entry.studentName} · ${_signed(widget.entry.points)} · ${widget.entry.reason}',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                maxLines: 2,
                maxLength: 300,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: t('bank.withdrawWhy'),
                  counterText: '',
                  filled: true,
                  fillColor: AppTheme.canvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: ready
                      ? () => Navigator.of(context).pop(_reason.text.trim())
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.rose,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.neutralSoft,
                    disabledForegroundColor: AppTheme.textFaint,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                    t('bank.withdraw'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
