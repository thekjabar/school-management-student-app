import 'package:flutter/material.dart';

import '../api/staff_leave_api.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import '../ui/async.dart';
import '../ui/format.dart';
import '../ui/home_kit.dart';
import '../ui/kit.dart';
import '../ui/pickers.dart';
import '../ui/screen_kit.dart';
import '../ui/sheets.dart';

/// Time off, for the member of staff carrying the phone.
///
/// ONE screen for two apps. The driver and the teacher ask the office for leave
/// in exactly the same words and get back exactly the same six states, so this
/// is written once and tinted by the caller. A second copy would drift, and the
/// half that drifted would be whichever of the two nobody was looking at.
///
/// The screen answers three questions and refuses to be vague about any of
/// them: what am I owed, what have I asked for, and what happened to it. The
/// third is the one that matters. A refusal shown as a red word and nothing
/// else is worse than no screen at all — the person is left knowing they were
/// told no and not knowing why, which is exactly the position the paper
/// notebook already put them in. So `decisionNote` is rendered in full wherever
/// it exists, and where it does NOT exist the screen says so out loud rather
/// than leaving a blank that reads as "no reason needed".

/// What the screen needs, both halves fetched together.
class _LeaveState {
  _LeaveState(this.rows, this.entitlement);

  final List<StaffLeave> rows;
  final StaffLeaveEntitlement entitlement;
}

/// The row that opens it, for a Profile tab.
///
/// A widget rather than a copied `TileRow` in each app, so the icon, the words
/// and the destination cannot drift apart between the two.
class StaffLeaveTile extends StatelessWidget {
  const StaffLeaveTile({super.key, required this.tint, this.last = true});

  final Color tint;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return TileRow(
      icon: Icons.event_busy_rounded,
      color: tint,
      title: t('staffLeave.title'),
      subtitle: t('staffLeave.tileSub'),
      last: last,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StaffLeaveScreen(tint: tint)),
      ),
    );
  }
}

class StaffLeaveScreen extends StatefulWidget {
  const StaffLeaveScreen({super.key, required this.tint});

  final Color tint;

  @override
  State<StaffLeaveScreen> createState() => _StaffLeaveScreenState();
}

class _StaffLeaveScreenState extends State<StaffLeaveScreen> {
  final GlobalKey<LoaderState<_LeaveState>> _loader = GlobalKey<LoaderState<_LeaveState>>();

  Future<_LeaveState> _load() async {
    // Both at once. The allowance is a separate route because it is a separate
    // table, but a screen that painted the list first and the allowance a
    // second later would flicker on every pull-to-refresh.
    final results = await Future.wait([
      StaffLeaveApi.instance.mine(),
      StaffLeaveApi.instance.entitlement(),
    ]);
    return _LeaveState(
      results[0] as List<StaffLeave>,
      results[1] as StaffLeaveEntitlement,
    );
  }

  Future<void> _refresh() async {
    final state = _loader.currentState;
    if (state != null) {
      await state.reload();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _ask() async {
    final sent = await showAppSheet<bool>(
      context,
      builder: (_) => _RequestSheet(tint: widget.tint),
    );
    if (sent != true || !mounted) return;
    showNote(context, t('staffLeave.sent'));
    await _refresh();
  }

  Future<void> _withdraw(StaffLeave leave) async {
    final bool yes = await confirmDialog(
      context,
      icon: Icons.undo_rounded,
      tone: AppTheme.amber,
      title: t('staffLeave.withdrawAsk'),
      body: t('staffLeave.withdrawBody'),
      confirmLabel: t('staffLeave.withdraw'),
      confirmIcon: Icons.undo_rounded,
    );
    if (!yes || !mounted) return;
    try {
      await StaffLeaveApi.instance.cancel(leave.id);
      if (!mounted) return;
      showNote(context, t('staffLeave.withdrawn'));
      await _refresh();
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('staffLeave.title')),
            Expanded(
              child: Loader<_LeaveState>(
                key: _loader,
                tint: widget.tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 28),
                load: _load,
                builder: (context, data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Allowance(entitlement: data.entitlement, tint: widget.tint),
                    const SizedBox(height: 14),
                    BigButton(
                      label: t('staffLeave.ask'),
                      color: widget.tint,
                      onPressed: _ask,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      t('staffLeave.yours').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: AppTheme.textFaint,
                      ),
                    ),
                    const SizedBox(height: 9),
                    if (data.rows.isEmpty)
                      Card16(
                        child: Text(
                          t('staffLeave.none'),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      )
                    else
                      for (final leave in data.rows) ...[
                        _LeaveCard(
                          leave: leave,
                          tint: widget.tint,
                          onWithdraw: leave.pending ? () => _withdraw(leave) : null,
                        ),
                        const SizedBox(height: kCardGap),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * What you are owed
 * ------------------------------------------------------------------------- */

/// The allowance, or an honest account of why there is not one.
///
/// Three different answers, and they are not the same answer:
///
///  * No employment record here at all — the supply teacher in week one. There
///    is nothing to show and nothing has gone wrong.
///  * An employment, but nobody has set this year's entitlement up yet.
///  * Real numbers.
///
/// Collapsing the first two into "0 days left" would tell somebody they had
/// used up an allowance that was never granted, and they would stop asking.
class _Allowance extends StatelessWidget {
  const _Allowance({required this.entitlement, required this.tint});

  final StaffLeaveEntitlement entitlement;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    if (!entitlement.employed) {
      return _Note(text: t('staffLeave.notEmployed'), color: AppTheme.blue);
    }
    if (entitlement.balances.isEmpty) {
      return _Note(text: t('staffLeave.noAllowance'), color: AppTheme.blue);
    }

    // Newest period only. An operator carrying three years of balances would
    // otherwise put last year's spent allowance on the same card as this
    // year's, which is a number nobody can act on.
    final newest = entitlement.balances.first.periodKey;
    final current = entitlement.balances.where((b) => b.periodKey == newest).toList();

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('staffLeave.allowance'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
              ),
              if (newest.isNotEmpty) Pill(newest, color: tint),
            ],
          ),
          const SizedBox(height: 11),
          for (int i = 0; i < current.length; i++) ...[
            if (i > 0) const SizedBox(height: 9),
            _AllowanceRow(balance: current[i], tint: tint),
          ],
        ],
      ),
    );
  }
}

class _AllowanceRow extends StatelessWidget {
  const _AllowanceRow({required this.balance, required this.tint});

  final StaffLeaveBalance balance;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final total = balance.entitledDays + balance.carriedOverDays;
    // Guarded, because a balance set up as nought entitled days is legal and a
    // division by it is not.
    final fraction = total <= 0 ? 0.0 : (balance.remainingDays / total).clamp(0.0, 1.0);
    final low = balance.remainingDays <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                leaveKindLabel(balance.kind),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
              ),
            ),
            Text(
              tv('staffLeave.leftOf', {
                'a': _days(balance.remainingDays),
                'b': _days(total),
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: low ? AppTheme.rose : tint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction.toDouble(),
            minHeight: 6,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(low ? AppTheme.rose : tint),
          ),
        ),
        if (balance.pendingDays > 0) ...[
          const SizedBox(height: 5),
          Text(
            tv('staffLeave.reserved', {'n': _days(balance.pendingDays)}),
            style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
          ),
        ],
      ],
    );
  }
}

/* ---------------------------------------------------------------------------
 * One request
 * ------------------------------------------------------------------------- */

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.leave, required this.tint, this.onWithdraw});

  final StaffLeave leave;
  final Color tint;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final tone = leaveStatusColor(leave.status);

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leaveKindLabel(leave.kind),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _dateLine(leave),
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(t('staffLeave.${leave.status}'), color: tone),
            ],
          ),

          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(_lengthLabel(leave), color: AppTheme.textMuted),
              if (leave.workingDays != null)
                Pill(
                  tv('staffLeave.cost', {'n': _days(leave.workingDays!)}),
                  color: AppTheme.textMuted,
                ),
              // Said only when it is UNPAID. "Paid" on every other card would be
              // a promise this screen is not the one making.
              if (!leave.paid) Pill(t('staffLeave.unpaidTag'), color: AppTheme.amber),
            ],
          ),

          if ((leave.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              leave.reason!,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.text),
            ),
          ],

          const SizedBox(height: 11),
          Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 10),
          _Outcome(leave: leave),

          if (onWithdraw != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onWithdraw,
                icon: const Icon(Icons.undo_rounded, size: 17),
                label: Text(t('staffLeave.withdraw')),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.rose,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The dates, and the hours where it is only part of a day.
  static String _dateLine(StaffLeave leave) {
    if (leave.partDay) {
      return '${longDate(leave.fromDate)} · '
          '${clock(leave.fromMinute)}–${clock(leave.toMinute)}';
    }
    if (leave.calendarDays == 1) return longDate(leave.fromDate);
    return '${shortDate(leave.fromDate)} – ${longDate(leave.toDate)}';
  }

  static String _lengthLabel(StaffLeave leave) {
    if (leave.partDay) return t('staffLeave.partDay');
    if (leave.calendarDays == 1) return t('staffLeave.oneDay');
    return tn('staffLeave.days', leave.calendarDays);
  }
}

/// What happened, and what happens next.
///
/// Every one of the six states says something. The two that settle against the
/// person — REJECTED and REVOKED — say WHY, and when the office recorded no
/// reason they say that instead of falling silent. Silence there is read as
/// "there was a reason and you are not being told it", which is the worst of
/// the three possible readings and the only one this screen can rule out.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.leave});

  final StaffLeave leave;

  @override
  Widget build(BuildContext context) {
    final note = (leave.decisionNote ?? '').trim();
    final tone = leaveStatusColor(leave.status);

    final List<Widget> lines = [];

    switch (leave.status) {
      case 'PENDING':
        lines.add(_line(Icons.schedule_rounded, t('staffLeave.waiting'), AppTheme.amber));
      case 'APPROVED':
      case 'TAKEN':
        lines.add(
          _line(
            Icons.check_circle_rounded,
            leave.coverName != null && leave.coverName!.isNotEmpty
                ? tv('staffLeave.cover', {'name': leave.coverName!})
                : t('staffLeave.noCover'),
            AppTheme.green,
          ),
        );
      case 'REJECTED':
      case 'REVOKED':
        lines.add(
          _line(
            Icons.cancel_rounded,
            leave.status == 'REVOKED' ? t('staffLeave.revokedLine') : t('staffLeave.refusedLine'),
            AppTheme.rose,
          ),
        );
      case 'CANCELLED':
        lines.add(
          _line(Icons.undo_rounded, t('staffLeave.cancelledLine'), AppTheme.textMuted),
        );
      default:
        lines.add(_line(Icons.info_outline_rounded, humanise(leave.status), AppTheme.textMuted));
    }

    if (note.isNotEmpty) {
      lines.add(const SizedBox(height: 8));
      lines.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: AppTheme.dark ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('staffLeave.officeSaid'),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: tone,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                note,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.text),
              ),
            ],
          ),
        ),
      );
    } else if (leave.refused) {
      // The honest version of a blank. The office refused and wrote nothing
      // down, and the person is entitled to know that is what happened rather
      // than to be shown an empty space.
      lines.add(const SizedBox(height: 8));
      lines.add(
        Text(
          t('staffLeave.refusedNoReason'),
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            fontStyle: FontStyle.italic,
            color: AppTheme.textMuted,
          ),
        ),
      );
    }

    final stamp = leave.decidedAt ?? leave.requestedAt;
    if (stamp != null) {
      lines.add(const SizedBox(height: 8));
      lines.add(
        Text(
          leave.decidedAt != null
              ? tv('staffLeave.decidedOn', {'d': longDate(leave.decidedAt)})
              : tv('staffLeave.askedOn', {'d': longDate(leave.requestedAt)}),
          style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines);
  }

  static Widget _line(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.text),
          ),
        ),
      ],
    );
  }
}

/* ---------------------------------------------------------------------------
 * Asking
 * ------------------------------------------------------------------------- */

/// The request form.
///
/// Whole days only. `fromMinute`/`toMinute` exist on the server for a clinic
/// appointment at eleven, but they are refused unless BOTH are given and the
/// two dates are the same day, and a form that let somebody set one of them
/// would produce a 400 they could not read their way out of. Part days are
/// still displayed when the office records one.
class _RequestSheet extends StatefulWidget {
  const _RequestSheet({required this.tint});

  final Color tint;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final TextEditingController _reason = TextEditingController();
  String? _kind;
  DateTime? _from;
  DateTime? _to;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickKind() async {
    final chosen = await pickOne<String>(
      context,
      tint: widget.tint,
      title: t('staffLeave.kindPick'),
      selected: _kind,
      options: [
        for (final kind in kStaffLeaveKinds)
          PickOption(value: kind, label: leaveKindLabel(kind)),
      ],
    );
    if (chosen != null && mounted) setState(() => _kind = chosen);
  }

  Future<void> _pickFrom() async {
    // A year back and a year forward. Leave is recorded after the fact at least
    // as often as before it — the driver who was off sick on the Thursday and
    // is filling it in on the Monday — so a picker that started today would
    // make the commonest case impossible.
    final chosen = await pickDate(
      context,
      initial: _from ?? _today,
      first: DateTime(_today.year - 1, _today.month, _today.day),
      last: DateTime(_today.year + 1, _today.month, _today.day),
      tint: widget.tint,
      title: t('staffLeave.first'),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _from = chosen;
      // A last day left behind the new first day is a 400 waiting to happen,
      // so it follows rather than being left wrong.
      if (_to == null || _to!.isBefore(chosen)) _to = chosen;
    });
  }

  Future<void> _pickTo() async {
    final start = _from ?? _today;
    final chosen = await pickDate(
      context,
      initial: _to ?? start,
      first: start,
      last: DateTime(start.year + 1, start.month, start.day),
      tint: widget.tint,
      title: t('staffLeave.last'),
    );
    if (chosen != null && mounted) setState(() => _to = chosen);
  }

  Future<void> _submit() async {
    final kind = _kind;
    final from = _from;
    final to = _to;
    if (kind == null || from == null || to == null) {
      setState(() => _error = t('staffLeave.needAll'));
      return;
    }
    if (to.isBefore(from)) {
      setState(() => _error = t('staffLeave.datesWrong'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await StaffLeaveApi.instance.request(
        kind: kind,
        from: from,
        to: to,
        reason: _reason.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // The server's own words. It refuses a double booking, leave that starts
      // after somebody left, and a reason of one character, and each of those
      // messages names the thing to change — replacing them with "that did not
      // work" would strip the only instruction in the answer.
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t('staffLeave.ask'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t('staffLeave.askSub'),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),

              PickerField(
                label: t('staffLeave.kindLabel'),
                value: _kind == null ? null : leaveKindLabel(_kind!),
                placeholder: t('staffLeave.kindPick'),
                onTap: _pickKind,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PickerField(
                      label: t('staffLeave.first'),
                      value: _from == null ? null : longDate(_from),
                      placeholder: t('staffLeave.pickDay'),
                      icon: Icons.calendar_today_rounded,
                      onTap: _pickFrom,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PickerField(
                      label: t('staffLeave.last'),
                      value: _to == null ? null : longDate(_to),
                      placeholder: t('staffLeave.pickDay'),
                      icon: Icons.calendar_today_rounded,
                      onTap: _pickTo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                t('staffLeave.reasonLabel'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                // 500 on the server, and a field that let somebody type 600
                // characters would throw the whole request away at the end of
                // it rather than at the 501st.
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: t('staffLeave.reasonHint'),
                  counterText: '',
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: AppTheme.rose, fontSize: 12.5, height: 1.45),
                ),
              ],

              const SizedBox(height: 16),
              _Note(text: t('staffLeave.whatNext'), color: widget.tint),
              const SizedBox(height: 14),
              BigButton(
                label: _busy ? t('staffLeave.sending') : t('staffLeave.send'),
                color: widget.tint,
                height: 50,
                busy: _busy,
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Small shared pieces
 * ------------------------------------------------------------------------- */

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.dark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// The kind of leave, in the reader's own language.
///
/// Keyed on the enum value itself, exactly as `format.dart` keys month names on
/// their number, so a kind the server adds later shows as its own name rather
/// than as a blank while the translations catch up.
String leaveKindLabel(String kind) {
  final label = t('staffLeave.$kind');
  return label == 'staffLeave.$kind' ? humanise(kind) : label;
}

/// The colour a status is read in. Refusals and revocations are the same red:
/// both end with the person not getting the days.
Color leaveStatusColor(String status) => switch (status) {
      'PENDING' => AppTheme.amber,
      'APPROVED' => AppTheme.green,
      'TAKEN' => AppTheme.green,
      'REJECTED' => AppTheme.rose,
      'REVOKED' => AppTheme.rose,
      _ => AppTheme.textMuted,
    };

/// A day count with no trailing nought: half a day is "0.5", three days is "3".
String _days(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
