import 'package:flutter/material.dart';
import 'student_info_screen.dart';

import '../../api/parent_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../i18n/strings.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/motion.dart';
import 'leave_screen.dart';

/// Every child on this account, with the one number that matters next to each.
///
/// A family with three at the school gets three cards rather than a picker they
/// have to work through one at a time — this is the screen for "how are they
/// all doing", which the home screen deliberately cannot answer.
///
/// The card is the home screen's child card with a bus line and two actions
/// under it: the same gutter, the same gap, the same ringed avatar, the same
/// figure strip. It is the same child in the same product, so it is the same
/// card.
class ChildrenTab extends StatelessWidget {
  const ChildrenTab({super.key, required this.children, required this.selected});

  final List<Child> children;
  final Child selected;

  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, _Snapshot>>(
      tint: Role.parent.tint,
      // The page gutter and the gap between cards are the kit's, not this
      // screen's own: a 16 gutter beside every other screen's 14 is visible the
      // moment somebody moves between them.
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
      load: () async {
        // One pass per child, all in flight together. Three children on a slow
        // cell is three round trips either way; doing them in sequence just
        // makes the parent wait three times as long.
        final entries = await Future.wait(
          children.map((c) async {
            final r = await Future.wait([
              ParentApi.instance.attendance(c.studentId),
              ParentApi.instance.transport(c.studentId),
              ParentApi.instance.homework(c.studentId),
            ]);
            return MapEntry(
              c.studentId,
              _Snapshot(
                attendance: r[0] as AttendanceSummary,
                transport: r[1] as TransportInfo,
                homework: r[2] as List<HomeworkItem>,
              ),
            );
          }),
        );
        return Map.fromEntries(entries);
      },
      builder: (context, snaps) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: kCardGap),
            // The entrance every other stack of cards in the app arrives with:
            // a step apart, and capped, so a family of five does not queue.
            Rise(
              index: i,
              child: _ChildCard(
                child: children[i],
                snap: snaps[children[i].studentId],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Snapshot {
  _Snapshot({required this.attendance, required this.transport, required this.homework});

  final AttendanceSummary attendance;
  final TransportInfo transport;
  final List<HomeworkItem> homework;

  /// What is happening to this child on the bus right now, in one line.
  String get busLine {
    if (!transport.ridesTheBus) return t('children.notOnBus');
    if (transport.today.isEmpty) return t('children.noBusToday');
    final out = transport.today.where((t) => t.leg == 'OUT').firstOrNull;
    final back = transport.today.where((t) => t.leg == 'RETURN').firstOrNull;
    // The afternoon run is the live question after the morning one is done.
    if (back != null && (back.boardedAt != null || back.status == 'IN_PROGRESS')) {
      return '${t('children.homeRun')} · ${back.childLine.toLowerCase()}';
    }
    if (out != null) return '${t('children.morning')} · ${out.childLine.toLowerCase()}';
    return t('children.waitingForBus');
  }

  int get dueSoon {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return homework.where((h) => h.dueDate.difference(today).inDays <= 2).length;
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.snap});

  final Child child;
  final _Snapshot? snap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final rate = snap?.attendance.ratePercent;
    final marked = (snap?.attendance.total ?? 0) > 0;
    final dueSoon = snap?.dueSoon ?? 0;
    final onTrack = (rate ?? 100) >= 95;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StudentInfoScreen(child: child)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ringed and tinted, the way the home screen and every pushed
              // screen draw a child. Left untinted, CircleInitials hashes the
              // name into a hue of its own — so this one card came out pink in
              // an app that is violet throughout, which is most of why the
              // screen did not look like the others.
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.5),
                ),
                child: CircleInitials(label: child.name, tint: tint, size: 44),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${child.className} · ${child.code}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pill(humanise(child.relationship), color: tint),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
          // The strip the home screen, the profile and the attendance screen
          // all use for a child's figures — the only screen still on the plain
          // one was this. Each glyph carries the colour the caption used to
          // carry: green while the register is healthy, amber when it is not,
          // amber while something is due.
          IconFigureStrip(
            figures: [
              IconFigure(
                icon: Icons.verified_user_outlined,
                label: t('home.attendance'),
                value: marked ? '$rate%' : '—',
                caption: marked
                    ? tn('children.absent', snap!.attendance.absent)
                    : t('home.notMarked'),
                color: onTrack ? AppTheme.green : AppTheme.amber,
              ),
              IconFigure(
                icon: Icons.assignment_outlined,
                label: t('children.homework'),
                value: '${snap?.homework.length ?? 0}',
                caption: dueSoon > 0
                    ? tn('children.dueSoon', dueSoon)
                    : t('children.nothingUrgent'),
                color: dueSoon > 0 ? AppTheme.amber : AppTheme.blue,
              ),
              IconFigure(
                icon: Icons.directions_bus_rounded,
                label: t('children.bus'),
                value: snap?.transport.ridesTheBus == true
                    ? t('children.yes')
                    : t('children.no'),
                caption: snap?.transport.routeName?.split('—').last.trim() ?? '—',
                color: tint,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // A fact inside a card sits on the page's own ground inside a
          // hairline — the kit's StatBox, the attendance tallies and the leave
          // screen's date field are all this shape. This was a bare canvas
          // block with no edge, which on the dark theme is no edge at all.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_bus_rounded, size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    snap?.busLine ?? t('bus.checking'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  label: t('children.open'),
                  tint: tint,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => StudentInfoScreen(child: child)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CardAction(
                  label: t('children.askLeave'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LeaveScreen(child: child)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One of the two actions at the foot of a child's card.
///
/// The kit has BigButton for the single thing a screen is about, and the home
/// screen's tinted chip for one action on a card; it has nothing for a PAIR
/// sitting side by side, so this is that shape drawn from the same tokens — a
/// soft tint for the action the card is for, the page's own ground inside a
/// hairline for the quieter one.
///
/// Not an OutlinedButton: that arrives with its own radius, its own height and
/// its own grey, and none of the three are the app's. Correcting all of them by
/// hand at the call site is what left this screen looking like somebody else's.
class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, required this.onTap, this.tint});

  final String label;
  final VoidCallback onTap;

  /// Set on the action the card is for. Left off, the button stays quiet.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusSm);
    final colour = tint;

    return Material(
      color: colour == null
          ? AppTheme.canvas
          : colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: colour == null ? Border.all(color: AppTheme.border) : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: colour ?? AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
