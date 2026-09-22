import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

Color eventTint(SchoolEventItem event) {
  if (event.cancelled) return AppTheme.textMuted;
  if (event.awaitingReply) return AppTheme.amber;
  return switch (event.myReply?.reply) {
    EventReplyKind.yes => AppTheme.green,
    EventReplyKind.no => AppTheme.rose,
    EventReplyKind.maybe => AppTheme.amber,
    _ => AppTheme.violet,
  };
}

String eventStateWord(SchoolEventItem event) {
  if (event.cancelled) return t('events.calledOff');
  final mine = event.myReply;
  if (mine != null) {
    return switch (mine.reply) {
      EventReplyKind.yes => t('events.going'),
      EventReplyKind.no => t('events.notGoing'),
      _ => t('events.maybe'),
    };
  }
  if (event.canReply) return t('events.replyNeeded');
  if (event.replyWanted && event.replyClosed) return t('events.replyClosed');
  return t('events.forYou');
}

String eventWhen(SchoolEventItem event) {
  final starts = event.startsAt;
  final at = hhmm(starts);
  final ends = event.endsAt;
  if (ends == null) return '${longDate(starts)}  •  $at';
  return '${longDate(starts)}  •  $at – ${hhmm(ends)}';
}

Future<bool> showEventSheet(
  BuildContext context, {
  required Child child,
  required SchoolEventItem event,
}) async {
  final replied = await showAppSheet<bool>(
    context,
    builder: (_) => _EventSheet(child: child, event: event),
  );
  return replied == true;
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.child});

  final Child child;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _loaderKey = GlobalKey<LoaderState<List<SchoolEventItem>>>();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('events.title')),
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
                  TabSpec(label: t('events.coming'), icon: Icons.event_rounded),
                  TabSpec(
                    label: t('events.needsReply'),
                    icon: Icons.mark_email_unread_outlined,
                    color: AppTheme.amber,
                  ),
                  TabSpec(
                    label: t('events.past'),
                    icon: Icons.history_rounded,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),
            Expanded(
              child: Loader<List<SchoolEventItem>>(
                key: _loaderKey,
                tint: tint,
                padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24)),
                load: () => ParentApi.instance.schoolEvents(
                  widget.child.studentId,
                  from: DateTime.now().subtract(const Duration(days: 120)),
                  tenantId: widget.child.tenantId,
                ),
                isEmpty: (rows) => _visible(rows).isEmpty,
                empty: t('events.none'),
                builder: (context, rows) => Column(
                  children: [
                    for (final e in _visible(rows))
                      Padding(
                        padding: const EdgeInsets.only(bottom: kCardGap),
                        child: EventCard(
                          event: e,
                          onTap: () => _open(e),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SchoolEventItem> _visible(List<SchoolEventItem> rows) {
    final now = DateTime.now();
    final list = switch (_tab) {
      1 => rows.where((e) => e.awaitingReply).toList(),
      2 => rows.where((e) => e.startsAt.isBefore(now)).toList(),
      _ => rows.where((e) => !e.startsAt.isBefore(now)).toList(),
    };
    list.sort((a, b) => _tab == 2
        ? b.startsAt.compareTo(a.startsAt)
        : a.startsAt.compareTo(b.startsAt));
    return list;
  }

  Future<void> _open(SchoolEventItem event) async {
    final replied = await showEventSheet(context, child: widget.child, event: event);
    if (replied) _loaderKey.currentState?.reload();
  }
}

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.onTap});

  final SchoolEventItem event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = eventTint(event);
    final place = event.placeText;

    return Card16(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${event.startsAt.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: tint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t('monthShort.${event.startsAt.month}'),
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: tint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.titleText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    decoration: event.cancelled ? TextDecoration.lineThrough : null,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 5),
                _Line(icon: Icons.schedule_rounded, text: eventWhen(event)),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _Line(icon: Icons.place_outlined, text: place),
                ],
                if (event.myReply != null && event.myReply!.headcount > 0) ...[
                  const SizedBox(height: 3),
                  _Line(
                    icon: Icons.groups_outlined,
                    text: tn('events.peopleComing', event.myReply!.headcount),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(eventStateWord(event), color: tint),
        ],
      ),
    );
  }
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

class _EventSheet extends StatefulWidget {
  const _EventSheet({required this.child, required this.event});

  final Child child;
  final SchoolEventItem event;

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  static const _maxNote = 300;

  late SchoolEventItem _event = widget.event;
  late String _reply = widget.event.myReply?.reply ?? EventReplyKind.yes;
  late int _headcount = widget.event.myReply?.headcount ?? 1;
  late final TextEditingController _note =
      TextEditingController(text: widget.event.myReply?.note ?? '');

  bool _busy = false;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _countsPeople => _event.headcountWanted && _reply != EventReplyKind.no;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ParentApi.instance.replyToEvent(
        eventId: _event.id,
        studentId: widget.child.studentId,
        reply: _reply,
        headcount: _countsPeople ? _headcount : null,
        note: _note.text,
        tenantId: widget.child.tenantId,
      );
      if (!mounted) return;
      setState(() {
        _event = saved;
        _saved = true;
      });
      showNote(context, t('events.replySent'));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final event = _event;
    final about = event.descriptionText;
    final place = event.placeText;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                event.titleText,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 8),
              _Line(icon: Icons.schedule_rounded, text: eventWhen(event)),
              if (place.isNotEmpty) ...[
                const SizedBox(height: 4),
                _Line(icon: Icons.place_outlined, text: place),
              ],
              if (about.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  about,
                  style: TextStyle(fontSize: 13, height: 1.55, color: AppTheme.text),
                ),
              ],

              if (event.cancelled) ...[
                const SizedBox(height: 14),
                NoticeBanner(
                  icon: Icons.event_busy_rounded,
                  color: AppTheme.rose,
                  title: t('events.calledOff'),
                  body: t('events.calledOffNote'),
                ),
              ] else if (event.replyWanted && event.replyClosed) ...[
                const SizedBox(height: 14),
                NoticeBanner(
                  icon: Icons.lock_clock,
                  color: AppTheme.amber,
                  title: t('events.replyClosed'),
                  body: t('events.replyClosedNote'),
                ),
              ],

              if (event.canReply) ...[
                const SizedBox(height: 18),
                Text(
                  t('events.areYouComing'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
                if (event.replyClosesAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    tn('events.replyBy', longDate(event.replyClosesAt)),
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ReplyCard(
                        label: t('events.going'),
                        icon: Icons.check_circle_outline_rounded,
                        colour: AppTheme.green,
                        on: _reply == EventReplyKind.yes,
                        onTap: () => setState(() => _reply = EventReplyKind.yes),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ReplyCard(
                        label: t('events.maybe'),
                        icon: Icons.help_outline_rounded,
                        colour: AppTheme.amber,
                        on: _reply == EventReplyKind.maybe,
                        onTap: () => setState(() => _reply = EventReplyKind.maybe),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ReplyCard(
                        label: t('events.notGoing'),
                        icon: Icons.cancel_outlined,
                        colour: AppTheme.rose,
                        on: _reply == EventReplyKind.no,
                        onTap: () => setState(() => _reply = EventReplyKind.no),
                      ),
                    ),
                  ],
                ),
                if (_countsPeople) ...[
                  const SizedBox(height: 16),
                  Text(
                    t('events.howMany'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tn('events.howManyMost', event.headcountMax),
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 9),
                  _Stepper(
                    value: _headcount,
                    min: 1,
                    max: event.headcountMax,
                    onChanged: (v) => setState(() => _headcount = v),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  t('events.noteOptional'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  maxLength: _maxNote,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: t('events.noteHint'),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(_error!, style: TextStyle(fontSize: 12, color: AppTheme.rose)),
                ],
                const SizedBox(height: 10),
                BigButton(
                  label: event.myReply == null ? t('events.send') : t('events.change'),
                  color: tint,
                  busy: _busy,
                  onPressed: _busy ? null : _send,
                ),
              ] else ...[
                const SizedBox(height: 18),
                BigButton(
                  label: t('common.close'),
                  color: tint,
                  onPressed: () => Navigator.of(context).pop(_saved),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.label,
    required this.icon,
    required this.colour,
    required this.on,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color colour;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        decoration: BoxDecoration(
          color: on ? colour.withValues(alpha: AppTheme.dark ? 0.18 : 0.08) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: on ? colour : AppTheme.border, width: on ? 1.5 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: on ? colour : AppTheme.textMuted),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: on ? colour : AppTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Row(
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 60,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tint),
          ),
        ),
        _StepButton(
          icon: Icons.add_rounded,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppTheme.text : AppTheme.textFaint,
        ),
      ),
    );
  }
}
