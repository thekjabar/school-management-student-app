import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/attachments.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/sheets.dart';
import '../../ui/screen_kit.dart';
import 'conversation_screen.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key, required this.onRead});

  final VoidCallback onRead;

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  int _tab = 0;

  final Set<String> _read = <String>{};

  final Set<String> _sending = <String>{};

  bool _markingAll = false;

  List<Announcement>? _all;

  bool _bellCleared = false;

  bool _isRead(Announcement a) => a.readAt != null || _read.contains(a.id);

  void _syncBell() {
    final all = _all;
    if (all == null) return;
    final settled = all.every(
      (a) => a.readAt != null || (_read.contains(a.id) && !_sending.contains(a.id)),
    );
    if (!settled) {
      _bellCleared = false;
      return;
    }
    if (_bellCleared) return;
    _bellCleared = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRead();
    });
  }

  Future<void> _markRead(Announcement item) async {
    if (_isRead(item) || _sending.contains(item.id)) return;
    setState(() {
      _read.add(item.id);
      _sending.add(item.id);
    });
    try {
      await ParentApi.instance.markAnnouncementRead(item.id);
      if (!mounted) return;
      setState(() => _sending.remove(item.id));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _read.remove(item.id);
        _sending.remove(item.id);
      });
      showNote(context, errorText(e), bad: true);
    }
  }

  Future<void> _markAll(List<Announcement> all) async {
    if (_markingAll) return;
    final ids = all.where((a) => !_isRead(a)).map((a) => a.id).toSet();
    if (ids.isEmpty) return;

    setState(() {
      _markingAll = true;
      _read.addAll(ids);
      _sending.addAll(ids);
    });
    try {
      final marked = await ParentApi.instance.markAllAnnouncementsRead();
      if (!mounted) return;
      setState(() {
        _markingAll = false;
        _sending.removeAll(ids);
      });
      if (marked > 0) showNote(context, tn('msg.markedRead', marked));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _markingAll = false;
        _read.removeAll(ids);
        _sending.removeAll(ids);
      });
      showNote(context, errorText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Loader<List<Announcement>>(
      tint: tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18),
      load: () => ParentApi.instance.announcements(),
      builder: (context, all) {
        _all = all;
        _syncBell();
        final unread = all.where((a) => !_isRead(a)).length;

        final rows = all.where((a) {
          return switch (_tab) {
            1 => a.category == 'ANNOUNCEMENT' || a.category == 'EVENT',
            2 => a.category == 'POLICY' || a.category == 'NOTICE',
            3 => a.priority == 'URGENT' || a.priority == 'HIGH',
            _ => true,
          };
        }).toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return (b.sentAt ?? DateTime(0)).compareTo(a.sentAt ?? DateTime(0));
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card16(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('nav.messages'),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  UnderlineTabs(
                    tint: tint,
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                    tabs: [
                      TabSpec(label: t('msg.all'), icon: Icons.forum_outlined),
                      TabSpec(
                        label: t('msg.announcements'),
                        icon: Icons.campaign_outlined,
                        color: AppTheme.violet,
                      ),
                      TabSpec(
                        label: t('msg.notices'),
                        icon: Icons.description_outlined,
                        color: AppTheme.blue,
                      ),
                      TabSpec(
                        label: t('msg.urgent'),
                        icon: Icons.priority_high_rounded,
                        color: AppTheme.rose,
                      ),
                      TabSpec(
                        label: t('msg.conversations'),
                        icon: Icons.chat_bubble_outline_rounded,
                        color: AppTheme.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),

            if (_tab == 4)
              const _Conversations()
            else if (rows.isEmpty)
              Card16(
                padding: const EdgeInsets.symmetric(vertical: 34),
                child: Center(
                  child: Text(
                    t('msg.nothing'),
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              Card16(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(
                  children: [
                    SectionRow(
                      title: t('msg.fromSchool'),
                      actionLabel: unread > 0 ? t('msg.markAllRead') : null,
                      actionIcon: Icons.done_all_rounded,
                      onAction: _markingAll ? null : () => _markAll(all),
                    ),
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: AppTheme.border),
                      _MessageRow(
                        item: rows[i],
                        read: _isRead(rows[i]),
                        onOpen: () => _markRead(rows[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.item, required this.read, required this.onOpen});

  final Announcement item;

  final bool read;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final urgent = item.priority == 'URGENT' || item.priority == 'HIGH';
    final (colour, icon) = switch (item.category) {
      'EVENT' => (AppTheme.green, Icons.event_rounded),
      'POLICY' || 'NOTICE' => (AppTheme.blue, Icons.description_rounded),
      'TRANSPORT' => (AppTheme.amber, Icons.directions_bus_rounded),
      'HEALTH' => (AppTheme.rose, Icons.favorite_rounded),
      _ => (Role.parent.tint, Icons.account_balance_rounded),
    };
    final tint = urgent ? AppTheme.rose : colour;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        onOpen();
        showDialog<void>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: AppTheme.dark ? 0.62 : 0.34),
          builder: (context) => _AnnouncementDialog(
            item: item,
            icon: urgent ? Icons.priority_high_rounded : icon,
            tint: tint,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(urgent ? Icons.priority_high_rounded : icon, size: 22, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.authorName.isEmpty ? t('msg.school') : item.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: tint,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _when(item.sentAt),
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 6),
                if (!read)
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Role.parent.tint,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '1',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (item.pinned)
                  Icon(Icons.push_pin_rounded, size: 15, color: AppTheme.amber),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 19, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }

  String _when(DateTime? at) {
    if (at == null) return '—';
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final days = midnight.difference(DateTime(at.year, at.month, at.day)).inDays;
    if (days <= 0) return hhmm(at);
    if (days == 1) return t('due.yesterday');
    if (days < 7) return t('day.${at.weekday}');
    return shortDate(at);
  }
}

class _AnnouncementDialog extends StatelessWidget {
  const _AnnouncementDialog({
    required this.item,
    required this.icon,
    required this.tint,
  });

  final Announcement item;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.76,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(icon, size: 34, color: tint),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.2,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: tint,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 4,
                                  margin: const EdgeInsetsDirectional.only(start: 3, end: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.border,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: t('common.close'),
                    iconSize: 22,
                    color: AppTheme.textMuted,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.62,
                        color: AppTheme.text,
                      ),
                    ),
                    if (item.attachmentCount > 0) ...[
                      const SizedBox(height: 18),
                      AttachmentList(
                        count: item.attachmentCount,
                        tint: tint,
                        load: () => ParentApi.instance.announcementAttachments(item.id),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _GotIt(
                  tint: tint,
                  onTap: () async {
                    if (item.requiresAcknowledgement && item.acknowledgedAt == null) {
                      try {
                        await ParentApi.instance.acknowledgeAnnouncement(item.id);
                      } catch (e) {
                        if (context.mounted) showNote(context, errorText(e), bad: true);
                        return;
                      }
                    }
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GotIt extends StatelessWidget {
  const _GotIt({required this.tint, required this.onTap});

  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('msg.gotIt'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 9),
              const Icon(Icons.check_circle_outline_rounded, size: 19, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _Conversations extends StatefulWidget {
  const _Conversations();

  @override
  State<_Conversations> createState() => _ConversationsState();
}

class _ConversationsState extends State<_Conversations> {
  late Future<List<ThreadSummary>> _threads = ParentApi.instance.threads();

  void _reload() => setState(() => _threads = ParentApi.instance.threads());

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        children: [
          SectionRow(
            title: t('conv.title'),
            actionLabel: t('conv.start'),
            actionIcon: Icons.add_rounded,
            onAction: () async {
              await _startConversation(context);
              if (mounted) _reload();
            },
          ),
          FutureBuilder<List<ThreadSummary>>(
            future: _threads,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Column(
                    children: [
                      Text(
                        errorText(snap.error),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 10),
                      TextButton(onPressed: _reload, child: Text(t('common.tryAgain'))),
                    ],
                  ),
                );
              }
              final rows = snap.data ?? const <ThreadSummary>[];
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  child: Center(
                    child: Text(
                      t('conv.none'),
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppTheme.border),
                    _ThreadRow(
                      thread: rows[i],
                      tint: tint,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ConversationScreen(thread: rows[i]),
                          ),
                        );
                        if (mounted) _reload();
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread, required this.tint, required this.onTap});

  final ThreadSummary thread;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: thread.unread ? FontWeight.w800 : FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    thread.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (thread.resolved)
              StatusChip(t('conv.resolved'), color: AppTheme.textMuted)
            else if (thread.unread)
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _startConversation(BuildContext context) async {
  final children = await ParentApi.instance.children();
  if (!context.mounted) return;
  if (children.isEmpty) {
    showNote(context, t('conv.none'), bad: true);
    return;
  }
  final opened = await showAppSheet<ThreadSummary>(
    context,
    builder: (_) => _NewConversationSheet(children: children),
  );
  if (opened == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ConversationScreen(thread: opened)),
  );
}

const _topics = <String>[
  'GENERAL',
  'ABSENCE',
  'TRANSPORT',
  'ACADEMIC',
  'BEHAVIOUR',
  'HEALTH',
  'BILLING',
];

class _NewConversationSheet extends StatefulWidget {
  const _NewConversationSheet({required this.children});

  final List<Child> children;

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  late Child _child = widget.children.first;
  String _topic = 'GENERAL';
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickChild() async {
    final picked = await pickOne<String>(
      context,
      tint: Role.parent.tint,
      selected: _child.studentId,
      title: t('conv.whichChild'),
      options: [
        for (final c in widget.children)
          PickOption(value: c.studentId, label: c.name),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _child = widget.children.firstWhere((c) => c.studentId == picked));
  }

  Future<void> _pickTopic() async {
    final picked = await pickOne<String>(
      context,
      tint: Role.parent.tint,
      selected: _topic,
      title: t('conv.topic'),
      options: [
        for (final k in _topics) PickOption(value: k, label: t('conv.topic.$k')),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _topic = picked);
  }

  Future<void> _open() async {
    final subject = _subject.text.trim();
    final body = _body.text.trim();
    if (subject.length < 2 || body.isEmpty) {
      showNote(context, t('conv.needBoth'), bad: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ParentApi.instance.openThread(
        studentId: _child.studentId,
        subject: subject,
        body: body,
        topic: _topic,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        ThreadSummary(
          id: id,
          subject: subject,
          topic: _topic,
          status: 'OPEN',
          studentId: _child.studentId,
          studentName: _child.name,
          lastMessageAt: DateTime.now(),
          lastMessageBy: 'FAMILY',
          messageCount: 1,
          unread: false,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showNote(context, e.message, bad: true);
      }
    }
  }

  InputDecoration _box(String hint) => InputDecoration(
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
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
                t('conv.start'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.children.length > 1) ...[
                PickerField(
                  label: t('conv.whichChild'),
                  value: _child.name,
                  onTap: _pickChild,
                ),
                const SizedBox(height: 14),
              ],
              PickerField(
                label: t('conv.topic'),
                value: t('conv.topic.$_topic'),
                onTap: _pickTopic,
              ),
              const SizedBox(height: 14),
              _label(t('conv.subject')),
              TextField(
                controller: _subject,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: _box(t('conv.subjectHint')),
              ),
              const SizedBox(height: 14),
              _label(t('conv.message')),
              TextField(
                controller: _body,
                maxLines: 4,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: _box(t('conv.writeSomething')),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: BigButton(
                  label: _busy ? t('conv.sending') : t('conv.send'),
                  color: tint,
                  onPressed: _busy ? null : _open,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
