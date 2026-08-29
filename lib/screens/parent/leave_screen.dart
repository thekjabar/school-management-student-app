import 'package:flutter/material.dart';

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

/// Every day off the family has asked the office for.
///
/// The list is the point, not the form: a parent opens this far more often to
/// check whether Tuesday was approved than to ask for a new day. So the request
/// button floats over the list rather than sitting at the top of it, and the
/// tabs are the four answers the office can give.
class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key, required this.child});

  final Child child;

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final _loaderKey = GlobalKey<LoaderState<List<LeaveRequestItem>>>();
  int _tab = 0;

  static const _states = [null, 'PENDING', 'APPROVED', 'REJECTED'];

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('leave.title'), onBell: () {}),
            ChildCard(
              name: widget.child.name,
              line: '${widget.child.className}  •  ${widget.child.code}',
              tint: tint,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: PillTabs(
                tint: tint,
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
                tabs: [
                  TabSpec(label: t('leave.all'), icon: Icons.grid_view_rounded),
                  TabSpec(
                    label: t('leave.pending'),
                    icon: Icons.schedule_rounded,
                    color: AppTheme.amber,
                  ),
                  TabSpec(
                    label: t('leave.approved'),
                    icon: Icons.check_circle_outline_rounded,
                    color: AppTheme.green,
                  ),
                  TabSpec(
                    label: t('leave.rejected'),
                    icon: Icons.cancel_outlined,
                    color: AppTheme.rose,
                  ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),
            Expanded(
              child: Stack(
                children: [
                  Loader<List<LeaveRequestItem>>(
                    key: _loaderKey,
                    tint: tint,
                    padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 90),
                    load: () async {
                      final all = await ParentApi.instance.leaveRequests();
                      // The API returns every child on the account; this screen
                      // is about one of them, and mixing siblings here has
                      // caused a parent to think a request was approved when it
                      // was their other child's.
                      return all
                          .where((r) =>
                              r.studentId == null || r.studentId == widget.child.studentId)
                          .toList();
                    },
                    isEmpty: (rows) => _visible(rows).isEmpty,
                    empty: t('leave.none'),
                    builder: (context, rows) => Column(
                      children: [
                        for (final r in _visible(rows))
                          Padding(
                            padding: const EdgeInsets.only(bottom: kCardGap),
                            child: _RequestCard(
                              item: r,
                              onCancelled: () => _loaderKey.currentState?.reload(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    end: kGutter,
                    bottom: 16,
                    child: _AskButton(onTap: _ask),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<LeaveRequestItem> _visible(List<LeaveRequestItem> rows) {
    final want = _states[_tab];
    final list = want == null ? [...rows] : rows.where((r) => r.status == want).toList();
    // Newest first: a decision on last week's request is the thing being
    // looked for, not the summer holiday six weeks ago.
    list.sort((a, b) => b.fromDate.compareTo(a.fromDate));
    return list;
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

/// The one thing this screen is FOR, floating over the one thing it shows.
class _AskButton extends StatelessWidget {
  const _AskButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 20, 14),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              t('leave.ask'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * One request
 * ------------------------------------------------------------------------- */

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item, required this.onCancelled});

  final LeaveRequestItem item;
  final VoidCallback onCancelled;

  @override
  Widget build(BuildContext context) {
    final days = item.toDate.difference(item.fromDate).inDays + 1;
    final (statusColour, statusWord) = _status(item.status);
    // The circle is coloured by the REASON — a plane is always amber, a doctor
    // always green — because that is what makes a list of six scannable. A
    // refusal overrides it, because that is the one row a parent must not miss.
    final tint = item.status == 'REJECTED' ? AppTheme.rose : _tintFor(item.kind);

    return Card16(
      padding: const EdgeInsets.all(14),
      onTap: () => _open(context),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Level with the title, not floating in the middle of a card
            // whose height depends on how long the reason ran.
            Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconFor(item.kind), size: 24, color: tint),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t('leave.${item.kind.toLowerCase()}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _Line(
                    icon: Icons.calendar_today_rounded,
                    text: days == 1
                        ? longDate(item.fromDate)
                        : '${shortDate(item.fromDate)} – ${longDate(item.toDate)}',
                  ),
                  const SizedBox(height: 3),
                  _Line(
                    icon: Icons.schedule_rounded,
                    text: days == 1 ? t('leave.oneDay') : tn('leave.days', days),
                  ),
                  if ((item.reason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      item.reason!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.textMuted),
                    ),
                  ],
                  if ((item.decisionNote ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.decisionNote!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: statusColour,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(statusWord, color: statusColour),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textFaint),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    // Only a request the office has not answered can be taken back.
    if (item.status != 'PENDING') return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('leave.withdraw')),
        content: Text(t('leave.${item.kind.toLowerCase()}')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.rose),
            child: Text(t('leave.withdraw')),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ParentApi.instance.cancelLeave(item.id);
      onCancelled();
      if (context.mounted) showNote(context, t('leave.withdrawn'));
    } catch (e) {
      if (context.mounted) showNote(context, '$e');
    }
  }

  static (Color, String) _status(String status) => switch (status) {
        'PENDING' => (AppTheme.amber, t('leave.pending')),
        'APPROVED' => (AppTheme.green, t('leave.approved')),
        'REJECTED' => (AppTheme.rose, t('leave.rejected')),
        _ => (AppTheme.textMuted, t('leave.cancelled')),
      };

  static Color _tintFor(String kind) => switch (kind.toUpperCase()) {
        'MEDICAL' => AppTheme.green,
        'TRAVEL' => AppTheme.amber,
        'FAMILY' => AppTheme.blue,
        'BEREAVEMENT' => AppTheme.textMuted,
        _ => AppTheme.violet,
      };

  static IconData _iconFor(String kind) => switch (kind.toUpperCase()) {
        'SICK' => Icons.sick_rounded,
        'MEDICAL' => Icons.medical_services_rounded,
        'FAMILY' => Icons.family_restroom_rounded,
        'TRAVEL' => Icons.flight_rounded,
        'BEREAVEMENT' => Icons.local_florist_rounded,
        'RELIGIOUS' => Icons.mosque_rounded,
        _ => Icons.more_horiz_rounded,
      };
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.textFaint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}

class _AskSheet extends StatefulWidget {
  const _AskSheet({required this.child});

  final Child child;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  /// The seven reasons a child misses school here, in the order a parent is
  /// likeliest to need them. Cards rather than a dropdown: choosing why is the
  /// whole form, and a list you have to open is a list nobody reads.
  List<(String, String, IconData)> get _kinds => [
        ('SICK', t('leave.sick'), Icons.sick_rounded),
        ('MEDICAL_APPOINTMENT', t('leave.medical'), Icons.medical_services_rounded),
        ('FAMILY', t('leave.family'), Icons.family_restroom_rounded),
        ('TRAVEL', t('leave.travel'), Icons.flight_rounded),
        ('BEREAVEMENT', t('leave.bereavement'), Icons.local_florist_rounded),
        ('RELIGIOUS', t('leave.religious'), Icons.mosque_rounded),
        ('OTHER', t('leave.other'), Icons.more_horiz_rounded),
      ];

  static const _maxReason = 250;

  String _kind = 'SICK';
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  final _reason = TextEditingController();
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

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final picked = await pickDate(
      context,
      initial: start ? _from : _to,
      first: now.subtract(const Duration(days: 7)),
      last: now.add(const Duration(days: 120)),
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
  }

  Future<void> _send() async {
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
    final tint = Role.parent.tint;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
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
                t('leave.requestTitle'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                tn('leave.absentLine', widget.child.name.split(' ').first),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),

              _Label(t('leave.why')),
              const SizedBox(height: 9),
              LayoutBuilder(
                builder: (context, box) {
                  // Three across, as the design lays them out. A Wrap would
                  // reflow into ragged rows the moment a translation is one
                  // word longer, and this grid is the form's backbone.
                  const gap = 8.0;
                  final w = (box.maxWidth - gap * 2) / 3;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final k in _kinds)
                        SizedBox(
                          width: w,
                          child: _ReasonCard(
                            label: k.$2,
                            icon: k.$3,
                            on: k.$1 == _kind,
                            onTap: () => setState(() => _kind = k.$1),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(t('leave.from')),
                        const SizedBox(height: 8),
                        _DateField(value: _from, onTap: () => _pick(start: true)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(t('leave.to')),
                        const SizedBox(height: 8),
                        _DateField(value: _to, onTap: () => _pick(start: false)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _Label(t('leave.reasonOptional')),
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                maxLines: 4,
                maxLength: _maxReason,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: t('leave.reasonHint'),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '${_reason.text.characters.length}/$_maxReason',
                  style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: AppTheme.dark ? 0.14 : 0.07),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.dark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.directions_bus_rounded, size: 17, color: tint),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        t('leave.busNote'),
                        style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12, color: AppTheme.rose),
                ),
              ],
              const SizedBox(height: 16),

              GestureDetector(
                onTap: _busy ? null : _send,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _busy ? tint.withValues(alpha: 0.5) : tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_busy)
                        const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      else
                        const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        t('leave.send'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
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
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppTheme.text,
      ),
    );
  }
}

/// One reason, with a tick on the chosen one.
class _ReasonCard extends StatelessWidget {
  const _ReasonCard({
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

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            decoration: BoxDecoration(
              color: on
                  ? tint.withValues(alpha: AppTheme.dark ? 0.18 : 0.08)
                  : AppTheme.canvas,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: on ? tint : AppTheme.border,
                width: on ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 19, color: on ? tint : AppTheme.textMuted),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: on ? tint : AppTheme.text,
                  ),
                ),
              ],
            ),
          ),
          if (on)
            PositionedDirectional(
              top: -7,
              end: -7,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.surface, width: 2),
                ),
                child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 15, color: AppTheme.textMuted),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '${value.day} ${t('month.${value.month}')} ${value.year}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}
