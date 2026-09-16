import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/attachments.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import 'alert_routes.dart';
import '../../ui/insets.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({
    super.key,
    required this.child,
    required this.onRead,
    required this.onOpenAlert,
    required this.focus,
  });

  final Child child;

  final VoidCallback onRead;

  final Future<void> Function(AlertLink link) onOpenAlert;

  final ValueNotifier<MessagesFocus?> focus;

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _Inbox {
  const _Inbox(this.announcements, this.alerts, this.alertsError);

  final List<Announcement> announcements;
  final List<ParentAlert>? alerts;
  final Object? alertsError;
}

class _Entry {
  _Entry.announcement(Announcement this.announcement)
      : alert = null,
        at = announcement.sentAt ?? DateTime(0),
        pinned = announcement.pinned;

  _Entry.alert(ParentAlert this.alert)
      : announcement = null,
        at = alert.createdAt,
        pinned = false;

  final Announcement? announcement;
  final ParentAlert? alert;
  final DateTime at;
  final bool pinned;
}

class _MessagesTabState extends State<MessagesTab> {
  MessagesFilter _filter = MessagesFilter.all;

  final _loader = GlobalKey<LoaderState<_Inbox>>();

  final Set<String> _read = <String>{};

  final Set<String> _sending = <String>{};

  final Set<String> _readAlerts = <String>{};

  bool _markingAll = false;

  _Inbox? _inbox;

  bool _bellCleared = false;

  String? _pendingAnnouncement;

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(_focusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusChanged());
  }

  @override
  void didUpdateWidget(covariant MessagesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focus != widget.focus) {
      oldWidget.focus.removeListener(_focusChanged);
      widget.focus.addListener(_focusChanged);
    }
  }

  @override
  void dispose() {
    widget.focus.removeListener(_focusChanged);
    super.dispose();
  }

  void _focusChanged() {
    final focus = widget.focus.value;
    if (focus == null || !mounted) return;
    widget.focus.value = null;
    setState(() {
      _filter = focus.filter;
      _pendingAnnouncement = focus.announcementId;
    });
    if (focus.announcementId != null) _loader.currentState?.reload();
  }

  Future<_Inbox> _load() async {
    final alerts = ParentApi.instance.alerts().then<Object>((v) => v, onError: (Object e) => e);
    final announcements = await ParentApi.instance.announcements();
    final got = await alerts;
    return got is List<ParentAlert>
        ? _Inbox(announcements, got, null)
        : _Inbox(announcements, null, got);
  }

  bool _isRead(Announcement a) => a.readAt != null || _read.contains(a.id);

  bool _alertRead(ParentAlert a) => a.readAt != null || _readAlerts.contains(a.id);

  void _syncBell() {
    final inbox = _inbox;
    if (inbox == null) return;
    final settled = inbox.announcements.every(
          (a) => a.readAt != null || (_read.contains(a.id) && !_sending.contains(a.id)),
        ) &&
        (inbox.alerts ?? const <ParentAlert>[]).every(_alertRead);
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
      widget.onRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _read.remove(item.id);
        _sending.remove(item.id);
      });
      showNote(context, errorText(e), bad: true);
    }
  }

  Future<void> _openAlert(ParentAlert alert) async {
    setState(() => _readAlerts.add(alert.id));
    await widget.onOpenAlert(AlertLink.fromAlert(alert));
    if (mounted) await _loader.currentState?.reload(quiet: true);
  }

  Future<void> _markAll(_Inbox inbox) async {
    if (_markingAll) return;
    final ids = inbox.announcements.where((a) => !_isRead(a)).map((a) => a.id).toSet();
    final alertIds = (inbox.alerts ?? const <ParentAlert>[])
        .where((a) => !_alertRead(a))
        .map((a) => a.id)
        .toSet();
    if (ids.isEmpty && alertIds.isEmpty) return;

    setState(() {
      _markingAll = true;
      _read.addAll(ids);
      _sending.addAll(ids);
      _readAlerts.addAll(alertIds);
    });
    try {
      final marked = await Future.wait([
        if (ids.isNotEmpty) ParentApi.instance.markAllAnnouncementsRead(),
        if (alertIds.isNotEmpty) ParentApi.instance.markAllAlertsRead(),
      ]);
      if (!mounted) return;
      setState(() {
        _markingAll = false;
        _sending.removeAll(ids);
      });
      final total = marked.fold<int>(0, (sum, n) => sum + n);
      widget.onRead();
      if (total > 0) showNote(context, tn('msg.markedRead', total));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _markingAll = false;
        _read.removeAll(ids);
        _sending.removeAll(ids);
        _readAlerts.removeAll(alertIds);
      });
      showNote(context, errorText(e), bad: true);
    }
  }

  List<_Entry> _entries(_Inbox inbox) {
    final alerts = inbox.alerts ?? const <ParentAlert>[];
    final rows = <_Entry>[
      if (_filter != MessagesFilter.alerts)
        for (final a in inbox.announcements)
          if (switch (_filter) {
            MessagesFilter.announcements => a.category == 'ANNOUNCEMENT' || a.category == 'EVENT',
            MessagesFilter.notices => a.category == 'POLICY' || a.category == 'NOTICE',
            MessagesFilter.urgent => a.priority == 'URGENT' || a.priority == 'HIGH',
            _ => true,
          })
            _Entry.announcement(a),
      if (_filter == MessagesFilter.all || _filter == MessagesFilter.alerts)
        for (final a in alerts) _Entry.alert(a),
      if (_filter == MessagesFilter.urgent)
        for (final a in alerts)
          if (a.urgent) _Entry.alert(a),
    ];
    rows.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.at.compareTo(a.at);
    });
    return rows;
  }

  void _openPending(_Inbox inbox) {
    final id = _pendingAnnouncement;
    if (id == null) return;
    _pendingAnnouncement = null;
    Announcement? found;
    for (final a in inbox.announcements) {
      if (a.id == id) found = a;
    }
    final item = found;
    if (item == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markRead(item);
      _showAnnouncement(context, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Loader<_Inbox>(
      key: _loader,
      tint: tint,
      padding: withBottomInset(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18)),
      load: _load,
      builder: (context, inbox) {
        _inbox = inbox;
        _syncBell();
        _openPending(inbox);
        final unread = inbox.announcements.where((a) => !_isRead(a)).length +
            (inbox.alerts ?? const <ParentAlert>[]).where((a) => !_alertRead(a)).length;

        final rows = _entries(inbox);
        final alertsFailed = inbox.alerts == null && _filter == MessagesFilter.alerts;

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
                    index: _filter.index,
                    onChanged: (i) => setState(() => _filter = MessagesFilter.values[i]),
                    tabs: [
                      TabSpec(label: t('msg.all'), icon: Icons.forum_outlined),
                      TabSpec(
                        label: t('msg.alerts'),
                        icon: Icons.notifications_active_outlined,
                        color: AppTheme.amber,
                      ),
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
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),

            if (rows.isEmpty)
              Card16(
                padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
                child: Center(
                  child: Text(
                    alertsFailed
                        ? '${t('msg.alertsFailed')} ${errorText(inbox.alertsError)}'
                        : t('msg.nothing'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              Card16(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(
                  children: [
                    SectionRow(
                      title: _filter == MessagesFilter.alerts ? t('msg.alertsTitle') : t('msg.fromSchool'),
                      actionLabel: unread > 0 ? t('msg.markAllRead') : null,
                      actionIcon: Icons.done_all_rounded,
                      onAction: _markingAll ? null : () => _markAll(inbox),
                    ),
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: AppTheme.border),
                      if (rows[i].alert case final alert?)
                        _AlertRow(
                          item: alert,
                          read: _alertRead(alert),
                          onOpen: () => _openAlert(alert),
                        )
                      else if (rows[i].announcement case final announcement?)
                        _MessageRow(
                          item: announcement,
                          read: _isRead(announcement),
                          onOpen: () => _markRead(announcement),
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

(Color, IconData) _announcementLook(Announcement item) {
  final urgent = item.priority == 'URGENT' || item.priority == 'HIGH';
  final (colour, icon) = switch (item.category) {
    'EVENT' => (AppTheme.green, Icons.event_rounded),
    'POLICY' || 'NOTICE' => (AppTheme.blue, Icons.description_rounded),
    'TRANSPORT' => (AppTheme.amber, Icons.directions_bus_rounded),
    'HEALTH' => (AppTheme.rose, Icons.favorite_rounded),
    _ => (Role.parent.tint, Icons.account_balance_rounded),
  };
  return urgent ? (AppTheme.rose, Icons.priority_high_rounded) : (colour, icon);
}

void _showAnnouncement(BuildContext context, Announcement item) {
  final (tint, icon) = _announcementLook(item);
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: AppTheme.dark ? 0.62 : 0.34),
    builder: (context) => _AnnouncementDialog(item: item, icon: icon, tint: tint),
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

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.tint,
    required this.icon,
    required this.title,
    required this.byline,
    required this.body,
    required this.at,
    required this.read,
    required this.onTap,
    this.pinned = false,
  });

  final Color tint;
  final IconData icon;
  final String title;
  final String byline;
  final String body;
  final DateTime? at;
  final bool read;
  final bool pinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
              child: Icon(icon, size: 22, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                    byline,
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
                    body,
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
                  _when(at),
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 6),
                if (!read)
                  const _UnreadDot()
                else if (pinned)
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
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.item, required this.read, required this.onOpen});

  final Announcement item;

  final bool read;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (tint, icon) = _announcementLook(item);
    return _InboxRow(
      tint: tint,
      icon: icon,
      title: item.title,
      byline: item.authorName.isEmpty ? t('msg.school') : item.authorName,
      body: item.body,
      at: item.sentAt,
      read: read,
      pinned: item.pinned,
      onTap: () {
        onOpen();
        _showAnnouncement(context, item);
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.item, required this.read, required this.onOpen});

  final ParentAlert item;

  final bool read;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (colour, icon) = switch (alertDestinationFor(item.templateKey, item.category)) {
      AlertDestination.track || AlertDestination.bus => (AppTheme.amber, Icons.directions_bus_rounded),
      AlertDestination.dropoff => (AppTheme.amber, Icons.pin_drop_rounded),
      AlertDestination.appFee || AlertDestination.schoolFees => (AppTheme.green, Icons.receipt_long_rounded),
      AlertDestination.attendance => (AppTheme.green, Icons.verified_user_rounded),
      AlertDestination.attitude => (AppTheme.violet, Icons.emoji_events_rounded),
      AlertDestination.marks ||
      AlertDestination.assignments ||
      AlertDestination.reports =>
        (AppTheme.violet, Icons.school_rounded),
      AlertDestination.conversation => (AppTheme.green, Icons.chat_bubble_rounded),
      AlertDestination.announcement => (AppTheme.violet, Icons.campaign_rounded),
      AlertDestination.alerts => (Role.parent.tint, Icons.notifications_rounded),
    };
    final title = item.title?.trim() ?? '';
    return _InboxRow(
      tint: item.urgent ? AppTheme.rose : colour,
      icon: item.urgent ? Icons.priority_high_rounded : icon,
      title: title.isEmpty ? tOr('alert.cat.${item.category}', t('msg.alert')) : title,
      byline: item.studentName?.isNotEmpty == true ? item.studentName! : t('msg.school'),
      body: item.body,
      at: item.createdAt,
      read: read,
      onTap: onOpen,
    );
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
