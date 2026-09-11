import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
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
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
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

  bool _busy = false;

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

  void _toggle(MarkBankEntry entry) {
    if (!entry.isBanked) return;
    setState(() {
      if (!_picked.remove(entry.id)) _picked.add(entry.id);
    });
  }

  void _pickAllFor(List<MarkBankEntry> rows) {
    final ids = rows.where((e) => e.isBanked).map((e) => e.id).toList();
    final allOn = ids.isNotEmpty && ids.every(_picked.contains);
    setState(() {
      if (allOn) {
        _picked.removeAll(ids);
      } else {
        _picked.addAll(ids);
      }
    });
  }

  Future<void> _redeem(List<String> ids) async {
    if (ids.isEmpty || _busy) return;
    final into = await showAppSheet<String>(
      context,
      builder: (_) => _RedeemSheet(count: ids.length, points: _pointsFor(ids)),
    );
    if (into == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await TeacherApi.instance.redeemMarks(entryIds: ids, redeemedAs: into);
      if (!mounted) return;
      _picked.clear();
      showNote(context, tn('bank.redeemedNote', ids.length));
      await _loaderKey.currentState?.reload();
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                  final rows = await TeacherApi.instance.markBank();
                  _all = rows;
                  _picked.removeWhere(
                    (id) => !rows.any((e) => e.id == id && e.isBanked),
                  );
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
                            onRedeemOne: (e) => _redeem([e.id]),
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
              child: _RedeemBar(
                count: _picked.length,
                points: _pickedPoints,
                busy: _busy,
                onClear: () => setState(_picked.clear),
                onRedeem: () => _redeem(_picked.toList()),
              ),
            ),
    );
  }
}

String _signed(num v) {
  final whole = v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);
  return v > 0 ? '+$whole' : whole;
}

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
                  t('bank.redeemExplains'),
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
    required this.onRedeemOne,
    required this.onWithdraw,
  });

  final String name;
  final List<MarkBankEntry> rows;
  final Set<String> picked;
  final void Function(MarkBankEntry) onToggle;
  final VoidCallback onPickAll;
  final void Function(MarkBankEntry) onRedeemOne;
  final void Function(MarkBankEntry) onWithdraw;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    final banked = rows.where((e) => e.isBanked).toList();
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
              if (banked.length > 1) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onPickAll,
                  borderRadius: BorderRadius.circular(9),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      banked.every((e) => picked.contains(e.id))
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
              onRedeem: () => onRedeemOne(entry),
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
    required this.onRedeem,
    required this.onWithdraw,
  });

  final MarkBankEntry entry;
  final bool picked;
  final VoidCallback onToggle;
  final VoidCallback onRedeem;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    final spent = !entry.isBanked;
    final colour = entry.points < 0 ? AppTheme.amber : tint;

    return InkWell(
      onTap: spent ? null : onToggle,
      onLongPress: spent ? null : onWithdraw,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: spent ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!spent)
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
                    entry.state == 'VOIDED'
                        ? Icons.undo_rounded
                        : Icons.redeem_rounded,
                    size: 18,
                    color: AppTheme.textFaint,
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
                              if (spent) t('bank.state.${entry.state}'),
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
              if (!spent) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onRedeem,
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

class _RedeemBar extends StatelessWidget {
  const _RedeemBar({
    required this.count,
    required this.points,
    required this.busy,
    required this.onClear,
    required this.onRedeem,
  });

  final int count;
  final num points;
  final bool busy;
  final VoidCallback onClear;
  final VoidCallback onRedeem;

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
              onPressed: busy ? null : onRedeem,
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
                      tv('bank.redeemN', {'n': count, 'points': _signed(points)}),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RedeemSheet extends StatelessWidget {
  const _RedeemSheet({required this.count, required this.points});

  final int count;
  final num points;

  static const _targets = <String, IconData>{
    'EXAM_RESULT': Icons.assignment_turned_in_outlined,
    'TERM_GRADE': Icons.workspace_premium_outlined,
    'MERIT': Icons.star_outline_rounded,
    'REPORT_COMMENT': Icons.notes_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Grabber(),
            const SizedBox(height: 16),
            Text(
              tv('bank.redeemTitle', {'n': count, 'points': _signed(points)}),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t('bank.redeemBody'),
              style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            for (final target in _targets.entries) ...[
              Card16(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                color: AppTheme.canvas,
                onTap: () => Navigator.of(context).pop(target.key),
                child: Row(
                  children: [
                    Icon(target.value, size: 19, color: AppTheme.amber),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        t('bank.into.${target.key}'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textFaint),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
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
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
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
