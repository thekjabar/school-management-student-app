import 'package:flutter/material.dart';

import '../../api/biometrics.dart';
import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

/// "She is not riding today."
///
/// The most frequent thing a family has to tell a school about transport, and
/// until now the one thing this app could not say. The server has answered
/// POST /parent/skip-rides, an eligibility check and a cancel since the feature
/// was built; the app only ever read the list back. So the actual instruction —
/// my daughter is going with her grandmother this morning — was a telephone
/// call, made by a parent at 06:50, to an office that may not be open yet.
///
/// It matters more than convenience, and the server's own docstring says why:
/// this SUPPRESSES A FALSE NO-SHOW ALARM. A child driven in by her mother all
/// week is otherwise recorded as a no-show three mornings running, and an
/// office that learns no-show alerts are noise will ignore the one in November
/// that means a seven year old is standing on the wrong road in the dark.
class SkipRideScreen extends StatefulWidget {
  const SkipRideScreen({super.key, required this.child});

  final Child child;

  @override
  State<SkipRideScreen> createState() => _SkipRideScreenState();
}

class _SkipRideScreenState extends State<SkipRideScreen> {
  final _loaderKey = GlobalKey<LoaderState<List<Map<String, dynamic>>>>();

  /// The list route answers for every child this guardian has; this screen is
  /// about one of them.
  List<Map<String, dynamic>> _mine(List<Map<String, dynamic>> rows) =>
      rows.where((r) => (r['studentId'] ?? '') == widget.child.studentId).toList();

  Future<void> _open() async {
    final made = await showAppSheet<bool>(
      context,
      builder: (_) => _SkipSheet(child: widget.child),
    );
    if (made == true) _loaderKey.currentState?.reload();
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    final id = (row['id'] ?? '') as String;
    if (id.isEmpty) return;
    final sure = await confirmDialog(
      context,
      icon: Icons.undo_rounded,
      title: t('skip.cancelTitle'),
      body: t('skip.cancelBody'),
      confirmLabel: t('skip.cancelConfirm'),
      confirmIcon: Icons.check_rounded,
      // Not the danger red. Putting a child back ON the bus is the safe
      // direction of this control — the alarming one was taking her off it.
      tone: Role.parent.tint,
    );
    if (!sure) return;
    try {
      await ParentApi.instance.cancelSkipRide(id);
      _loaderKey.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        backgroundColor: tint,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.event_busy_rounded),
        label: Text(t('skip.new')),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('skip.title')),
            ChildCard(
              name: widget.child.name,
              line: '${widget.child.className}  •  ${widget.child.code}',
              tint: tint,
            ),
            Expanded(
              child: Loader<List<Map<String, dynamic>>>(
                key: _loaderKey,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 96),
                load: () => ParentApi.instance.skipRides(),
                // Emptiness is judged AFTER filtering to this child. A family
                // with two children would otherwise see the other one's
                // requests counted as "something here" and get a blank list.
                isEmpty: (rows) => _mine(rows).isEmpty,
                empty: tn('skip.none', widget.child.name.split(' ').first),
                builder: (context, rows) {
                  final mine = _mine(rows);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in mine) ...[
                        _SkipCard(row: r, onCancel: () => _cancel(r)),
                        const SizedBox(height: kCardGap),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One filed request.
class _SkipCard extends StatelessWidget {
  const _SkipCard({required this.row, required this.onCancel});

  final Map<String, dynamic> row;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final status = (row['status'] ?? '') as String;
    final from = DateTime.tryParse((row['dateFrom'] ?? '') as String)?.toLocal();
    final to = DateTime.tryParse((row['dateTo'] ?? '') as String)?.toLocal();
    final leg = (row['legScope'] ?? 'BOTH') as String;
    final reason = (row['reason'] ?? '') as String;

    // LATE_REJECTED is the one status a parent must not misread. It does not
    // mean "refused" in the sense of somebody saying no — it means the bus had
    // already gone, so nothing was suppressed and the crew is still expecting
    // the child. Saying that plainly is the difference between a parent who
    // makes a second telephone call and one who assumes it was handled.
    final (Color colour, String label) = switch (status) {
      'ACCEPTED' => (AppTheme.green, t('skip.accepted')),
      'LATE_REJECTED' => (AppTheme.amber, t('skip.tooLate')),
      'CANCELLED' => (AppTheme.textMuted, t('skip.cancelled')),
      _ => (AppTheme.textMuted, status),
    };
    final cancellable = status == 'ACCEPTED' &&
        to != null &&
        !to.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  from == null
                      ? ''
                      : (to == null || _sameDay(from, to)
                          ? longDate(from)
                          : '${shortDate(from)} — ${shortDate(to)}'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
              ),
              Pill(label, color: colour),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${t('skip.leg.$leg')}  •  ${t('skip.reason.$reason')}',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
          if (status == 'LATE_REJECTED') ...[
            const SizedBox(height: 8),
            Text(
              t('skip.tooLateNote'),
              style: TextStyle(fontSize: 12, color: AppTheme.amber, height: 1.35),
            ),
          ],
          if (cancellable) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.undo_rounded, size: 17),
                label: Text(t('skip.sheIsRiding')),
                style: TextButton.styleFrom(
                  foregroundColor: Role.parent.tint,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// The form.
class _SkipSheet extends StatefulWidget {
  const _SkipSheet({required this.child});

  final Child child;

  @override
  State<_SkipSheet> createState() => _SkipSheetState();
}

class _SkipSheetState extends State<_SkipSheet> {
  static const _reasons = <(String, IconData)>[
    ('SICK', Icons.sick_rounded),
    ('FAMILY_PICKUP', Icons.directions_car_rounded),
    ('FAMILY_DROPOFF', Icons.family_restroom_rounded),
    ('APPOINTMENT', Icons.event_note_rounded),
    ('TRAVEL', Icons.flight_rounded),
    ('OTHER', Icons.more_horiz_rounded),
  ];

  /// The server refuses anything longer and tells the family to ask the office
  /// for a hold. Enforced here too so the refusal is not the first a parent
  /// hears of it, after they have filled the whole form in.
  static const _maxDays = 14;

  String _reason = 'FAMILY_PICKUP';
  String _leg = 'BOTH';
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;
  SkipEligibility? _eligibility;

  /// Minted ONCE, when the form opens, and reused for every retry.
  ///
  /// It has to be stable across attempts or it defeats its own purpose: a
  /// parent who taps send, loses signal, and taps again would otherwise file
  /// two skips, suppress the lines twice and send two notifications. Generated
  /// from the child and the moment the form opened rather than a random value
  /// so that it is stable even if this widget is rebuilt.
  late final String _idempotencyKey =
      '${widget.child.studentId}:${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
    _checkEligibility();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Ask, before the parent fills anything in, whether today can still be
  /// skipped at all — so the answer is "the bus has already left" rather than a
  /// refusal after the form is complete.
  Future<void> _checkEligibility() async {
    try {
      final e = await ParentApi.instance.skipRideEligibility(
        widget.child.studentId,
        on: _from,
      );
      if (mounted) setState(() => _eligibility = e);
    } on ApiException {
      // Not fatal. The server enforces the cut-off regardless; losing this only
      // costs the warning, and blocking the form because a hint failed to load
      // would be worse than letting them try.
    }
  }

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await pickDate(
      context,
      initial: start ? _from : _to,
      // No past days. A skip cannot suppress a run that has already happened,
      // and the server refuses them — so offering them would only produce an
      // error the parent could have been spared.
      first: today,
      last: today.add(const Duration(days: 120)),
      tint: Role.parent.tint,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _from = picked;
        if (_to.isBefore(_from)) _to = picked;
      } else {
        _to = picked.isBefore(_from) ? _from : picked;
      }
    });
    if (start) _checkEligibility();
  }

  int get _days => _to.difference(_from).inDays + 1;

  bool get _isToday {
    final now = DateTime.now();
    return _from.year == now.year && _from.month == now.month && _from.day == now.day;
  }

  /// The warning shown when today's chosen legs have already departed.
  String? get _cutoffWarning {
    final e = _eligibility;
    if (!_isToday || e == null) return null;
    final out = e.leg('OUT');
    final ret = e.leg('RETURN');
    final wantsOut = _leg == 'OUT' || _leg == 'BOTH';
    final wantsReturn = _leg == 'RETURN' || _leg == 'BOTH';
    final outShut = wantsOut && out != null && !out.open;
    final retShut = wantsReturn && ret != null && !ret.open;
    if (outShut && retShut) return t('skip.bothGone');
    if (outShut) return t('skip.morningGone');
    if (retShut) return t('skip.afternoonGone');
    return null;
  }

  Future<void> _send() async {
    if (_days > _maxDays) {
      setState(() => _error = tn('skip.tooLong', '$_maxDays'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The same proof the leave request asks for, and for the same reason:
      // this acts on the school on the child's behalf. It takes her off the
      // manifest and tells the crew not to wait — so it must be the guardian
      // holding the phone, not whoever picked it up off the table.
      final ok = await Biometrics.confirm(reason: t('skip.confirmWithBiometrics'));
      if (!ok) {
        if (mounted) setState(() => _error = t('skip.notConfirmed'));
        return;
      }
      final row = await ParentApi.instance.createSkipRide(
        studentId: widget.child.studentId,
        from: _from,
        to: _to,
        legScope: _leg,
        reason: _reason,
        note: _note.text,
        idempotencyKey: _idempotencyKey,
      );
      if (!mounted) return;
      // The server accepts a late request and stores it, deliberately, so that
      // "the family did tell us, at 07:12" survives — but it suppresses
      // nothing. Saying so here is what stops a parent believing the bus has
      // been told when it has not.
      final late = (row['status'] ?? '') == 'LATE_REJECTED';
      Navigator.of(context).pop(true);
      showNote(context, late ? t('skip.filedButLate') : t('skip.filed'));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final warning = _cutoffWarning;

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
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t('skip.newTitle'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                tn('skip.newLine', widget.child.name.split(' ').first),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),

              _Label(t('skip.which')),
              const SizedBox(height: 9),
              Row(
                children: [
                  for (final l in const ['OUT', 'RETURN', 'BOTH']) ...[
                    Expanded(
                      child: _Choice(
                        label: t('skip.leg.$l'),
                        on: l == _leg,
                        onTap: () => setState(() => _leg = l),
                      ),
                    ),
                    if (l != 'BOTH') const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 18),

              _Label(t('skip.why')),
              const SizedBox(height: 9),
              LayoutBuilder(
                builder: (context, box) {
                  const gap = 8.0;
                  final w = (box.maxWidth - gap * 2) / 3;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final r in _reasons)
                        SizedBox(
                          width: w,
                          child: _ReasonTile(
                            label: t('skip.reason.${r.$1}'),
                            icon: r.$2,
                            on: r.$1 == _reason,
                            onTap: () => setState(() => _reason = r.$1),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: PickerField(
                      label: t('skip.from'),
                      value: shortDate(_from),
                      icon: Icons.calendar_today_rounded,
                      onTap: () => _pick(start: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PickerField(
                      label: t('skip.to'),
                      value: shortDate(_to),
                      icon: Icons.calendar_today_rounded,
                      onTap: () => _pick(start: false),
                    ),
                  ),
                ],
              ),

              if (warning != null) ...[
                const SizedBox(height: 14),
                _Warning(text: warning),
              ],

              const SizedBox(height: 16),
              _Label(t('skip.note')),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLength: 300,
                maxLines: 2,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: t('skip.notePlaceholder'),
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

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.rose, height: 1.35),
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _busy ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: tint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          t('skip.send'),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: AppTheme.textMuted,
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: 0.10) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: on ? tint : AppTheme.border, width: on ? 1.4 : 1),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: on ? FontWeight.w700 : FontWeight.w600,
            color: on ? tint : AppTheme.text,
          ),
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: 0.10) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? tint : AppTheme.border, width: on ? 1.4 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: on ? tint : AppTheme.textMuted),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                color: on ? tint : AppTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.amber.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.amber.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_rounded, size: 17, color: AppTheme.amber),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, height: 1.35, color: AppTheme.amber),
              ),
            ),
          ],
        ),
      );
}
