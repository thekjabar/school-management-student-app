import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// Everything the school has sent this family.
///
/// One list, filtered by what the message IS: a notice about the whole school,
/// something for this class, or something urgent. The design draws a second
/// list of teacher conversations beside it; there is no messaging service
/// behind this app — announcements travel one way, from the office outward —
/// so that list would be furniture and a compose box would open onto nothing.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key, required this.onRead});

  final VoidCallback onRead;

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  int _tab = 0;

  /// The notices this screen has marked read since it was opened.
  ///
  /// An overlay of ids rather than an edit to the list: [Announcement] is
  /// immutable and the list belongs to the [Loader], so a set is the smallest
  /// thing that can be put back when the server refuses a mark.
  final Set<String> _read = <String>{};

  /// The marks still in flight. They count as read on the screen — that is the
  /// point of marking optimistically — but NOT to the bell, which is told
  /// nothing until the server has agreed.
  final Set<String> _sending = <String>{};

  bool _markingAll = false;

  /// The last list the loader handed us, so the mark handlers can reason about
  /// every notice rather than about the tab that happens to be open.
  List<Announcement>? _all;

  /// Whether the shell's bell has already been told there is nothing unread.
  /// Reset the moment something unread turns up again.
  bool _bellCleared = false;

  bool _isRead(Announcement a) => a.readAt != null || _read.contains(a.id);

  /// Tell the shell's bell when there is genuinely nothing left unread.
  ///
  /// [MessagesTab.onRead] can only say one thing — "zero" — so it is only ever
  /// said once the SERVER has agreed. Clearing the bell on an optimistic mark
  /// that then fails would hide a notice nobody has read, and the badge that
  /// cleared merely because this tab was opened is the fiction this screen now
  /// exists to end.
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
    // After the frame: this runs inside build, and the shell rebuilds itself
    // when it is told.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRead();
    });
  }

  /// Opening a notice is reading it.
  ///
  /// The row changes under the finger and the mark goes out behind it. If the
  /// server refuses, the row goes back to unread and the parent is told —
  /// a row that says "read" against a server that says otherwise is worse than
  /// no mark at all, because the badge comes back tomorrow with no explanation.
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

  /// Every notice at once, for the family that has been away a fortnight.
  ///
  /// Only the ones actually unread are ticked off locally, so a failure puts
  /// back exactly what this call claimed and leaves an earlier single mark
  /// alone.
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
      // The server's number, not ours: another handset may have read some of
      // these already, and saying so is the difference between a confirmation
      // and an echo.
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
        // Counted over everything the school has sent, not over the tab in
        // front of us: the bell counts notices, not the filter.
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
            // Title and tabs on one card, as the design has them.
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
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),

            if (rows.isEmpty)
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
                    // Where the rest of the parent app puts a list's second
                    // action: in the heading beside the name of the list, in
                    // the role's colour, rather than as a button competing
                    // with the notices themselves. It is there only when there
                    // is something to mark — an action that can do nothing
                    // should not be on the screen — and goes quiet while the
                    // call it started is still out.
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

/* ---------------------------------------------------------------------------
 * One message
 * ------------------------------------------------------------------------- */

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.item, required this.read, required this.onOpen});

  final Announcement item;

  /// Read as far as this screen is concerned — the server's `readAt`, or a
  /// mark this screen has just made and not yet had refused.
  final bool read;

  /// Called as the notice opens. Reading it is what marks it.
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
        // The mark goes with the opening, not with the "Got it" button: a
        // parent who reads a notice and swipes the dialog away has read it.
        onOpen();
        showDialog<void>(
          context: context,
          // Dimmed by the app's own scrim rather than Material's near-black,
          // which sits oddly over a page that is already dark.
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

  /// "08:30", "Yesterday", "Mon", then the date — the way a message list reads
  /// time, which is by how recently rather than by when.
  String _when(DateTime? at) {
    if (at == null) return '—';
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final days = midnight.difference(DateTime(at.year, at.month, at.day)).inDays;
    if (days <= 0) return hhmm(at);
    if (days == 1) return t('due.yesterday');
    if (days < 7) return t('day.${at.weekday}').characters.take(3).toString();
    return shortDate(at);
  }
}

/// One announcement, opened.
///
/// Carries the same glyph and the same tint as the row that was tapped, so the
/// dialog reads as that row expanding rather than as a different screen
/// arriving. An urgent notice keeps its rose colouring here too — the one place
/// a parent will actually read the words.
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
        // A long notice scrolls INSIDE the card. Without a ceiling the dialog
        // grows until the button is off the bottom of the screen, which is the
        // one control it has.
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
                          // A short rule in the notice's own colour, sitting on
                          // a longer track — the design's way of tying the
                          // title to the tile beside it.
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
                  // Sized to the finger rather than to the glyph.
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
                child: Text(
                  item.body,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.62,
                    color: AppTheme.text,
                  ),
                ),
              ),
            ),

            // No band behind the button. A footer strip separates several
            // actions from the content above them, and there is one action.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _GotIt(tint: tint, onTap: () => Navigator.of(context).pop()),
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
