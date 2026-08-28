import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../i18n/strings.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';

/// Asking the school to excuse a child, and seeing what was decided.
///
/// The type and the reason are both required, and that is not bureaucracy: an
/// approved leave writes a SkipRide as well as an attendance mark, so the bus
/// stops expecting the child. A request with no reason is one the office cannot
/// decide without telephoning, which is the thing this screen exists to avoid.
class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key, required this.child});

  final Child child;

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final _loaderKey = GlobalKey<LoaderState<List<LeaveRequestItem>>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(t('leave.title')),
        backgroundColor: Role.parent.wash,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ask,
        backgroundColor: Role.parent.tint,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(t('leave.ask')),
      ),
      body: Loader<List<LeaveRequestItem>>(
        key: _loaderKey,
        tint: Role.parent.tint,
        load: () async {
          final all = await ParentApi.instance.leaveRequests();
          // The API returns every child on the account; this screen is about
          // one of them, and mixing siblings here has caused a parent to think
          // a request was approved when it was their other child's.
          return all.where((r) => r.studentId == null || r.studentId == widget.child.studentId).toList();
        },
        isEmpty: (rows) => rows.isEmpty,
        empty: t('leave.none'),
        builder: (context, rows) => Column(
          children: [
            const SizedBox(height: 8),
            ...rows.map((r) => _RequestCard(item: r, onCancelled: () => _loaderKey.currentState?.reload())),
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }

  Future<void> _ask() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AskSheet(child: widget.child),
    );
    if (saved == true) {
      _loaderKey.currentState?.reload();
      if (mounted) showNote(context, t('leave.sent'));
    }
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item, required this.onCancelled});

  final LeaveRequestItem item;
  final VoidCallback onCancelled;

  @override
  Widget build(BuildContext context) {
    final (Color colour, Color wash) = switch (item.status) {
      'APPROVED' => (AppTheme.green, AppTheme.greenSoft),
      'REJECTED' => (AppTheme.rose, AppTheme.roseSoft),
      'PENDING' => (AppTheme.amber, AppTheme.amberSoft),
      _ => (AppTheme.textMuted, const Color(0xFFF1F3F6)),
    };

    final sameDay = item.fromDate.difference(item.toDate).inDays == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card16(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sameDay
                        ? longDate(item.fromDate)
                        : '${shortDate(item.fromDate)} – ${longDate(item.toDate)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Pill(humanise(item.status), color: colour, background: wash),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              humanise(item.kind),
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            ),
            if (item.reason != null && item.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.reason!,
                style: const TextStyle(fontSize: 13, height: 1.45, color: AppTheme.text),
              ),
            ],
            if (item.decisionNote != null && item.decisionNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                child: Text(
                  item.decisionNote!,
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: colour),
                ),
              ),
            ],
            if (item.status == 'PENDING') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    try {
                      await ParentApi.instance.cancelLeave(item.id);
                      onCancelled();
                      if (context.mounted) showNote(context, t('leave.withdrawn'));
                    } on ApiException catch (e) {
                      if (context.mounted) showNote(context, e.message, bad: true);
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.rose,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(t('leave.withdraw')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The form. Type, dates, reason — in that order, because the type changes what
/// a sensible reason looks like.
class _AskSheet extends StatefulWidget {
  const _AskSheet({required this.child});

  final Child child;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  List<(String, String, IconData)> get _kinds => [
    ('SICK', t('leave.sick'), Icons.sick_rounded),
    ('MEDICAL_APPOINTMENT', t('leave.medical'), Icons.medical_services_rounded),
    ('FAMILY', t('leave.family'), Icons.family_restroom_rounded),
    ('TRAVEL', t('leave.travel'), Icons.flight_rounded),
    ('BEREAVEMENT', t('leave.bereavement'), Icons.local_florist_rounded),
    ('RELIGIOUS', t('leave.religious'), Icons.mosque_rounded),
    ('OTHER', t('leave.other'), Icons.more_horiz_rounded),
  ];

  String _kind = 'SICK';
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      // Leave can be asked for retrospectively — a child sent home unwell at
      // eleven is a real case — but only a few days back, because a month-old
      // request is a conversation with the office, not a form.
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 120)),
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
  }

  Future<void> _send() async {
    if (_reason.text.trim().length < 4) {
      setState(() => _error = t('leave.reasonNeeded'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ParentApi.instance.requestLeave(
        studentId: widget.child.studentId,
        kind: _kind,
        from: _from,
        to: _to,
        reason: _reason.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
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
        decoration: const BoxDecoration(
          color: AppTheme.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tn('leave.for', widget.child.name.split(' ').first),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4),
              ),
              const SizedBox(height: 16),
              Text(t('leave.why'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kinds.map((k) {
                  final on = k.$1 == _kind;
                  return GestureDetector(
                    onTap: () => setState(() => _kind = k.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: on ? Role.parent.tint : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: on ? Role.parent.tint : AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(k.$3, size: 15, color: on ? Colors.white : AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            k.$2,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: on ? Colors.white : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _DateField(label: t('leave.from'), value: _from, onTap: () => _pick(start: true))),
                  const SizedBox(width: 12),
                  Expanded(child: _DateField(label: t('leave.to'), value: _to, onTap: () => _pick(start: false))),
                ],
              ),
              const SizedBox(height: 18),
              Text(t('leave.reason'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                maxLines: 3,
                maxLength: 400,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: t('leave.reasonHint')),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Role.parent.wash,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_bus_rounded, size: 17, color: Role.parent.tint),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        t('leave.busNote'),
                        style: const TextStyle(fontSize: 12, height: 1.45, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppTheme.rose, fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: Role.parent.tint,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(t('leave.send'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 15, color: AppTheme.textFaint),
                const SizedBox(width: 9),
                Text(shortDate(value), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
