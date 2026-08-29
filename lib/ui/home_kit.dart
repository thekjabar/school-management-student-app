import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'kit.dart';

/// The pieces the parent home screen is made of.
///
/// Every measurement here was taken off the design rather than chosen: the card
/// gutter, the tile size, the rail offset, the ring weight. Where the two
/// disagree it is because the mockup is a picture — its type is drawn far
/// smaller relative to the screen than anything legible in the hand — so the
/// LAYOUT is the design's and the type is scaled up to the smallest size that
/// still reads at arm's length.

/// The page gutter, and the gap between two cards. 14 and 8 in the design.
const kGutter = 14.0;
const kCardGap = 9.0;
const kCardRadius = 18.0;

/* ---------------------------------------------------------------------------
 * The header
 * ------------------------------------------------------------------------- */

/// The name and class of whichever child the screen is about.
///
/// A tiny record rather than the full Child model so this widget can live in
/// the kit without importing the API layer — the header should not know how a
/// child is fetched.
class ChildBrief {
  const ChildBrief({required this.name, required this.className});

  final String name;
  final String className;
}

/// Menu, the child, the greeting, the bell.
///
/// The only header in the product that identifies TWO people at once: the
/// parent it greets and the child everything below it is about. The child is
/// the face; the parent is the name. Getting that the wrong way round — which
/// is the obvious way to build it — leaves a guardian of three children with no
/// way of telling which child's homework they are looking at.
class ParentHeader extends StatelessWidget {
  const ParentHeader({
    super.key,
    required this.greeting,
    required this.parentName,
    required this.child,
    required this.schoolName,
    required this.tint,
    required this.onMenu,
    required this.onBell,
    this.notificationCount = 0,
    this.canSwitchChild = false,
    this.onSwitchChild,
  });

  final String greeting;
  final String parentName;
  final ChildBrief? child;
  final String schoolName;
  final Color tint;
  final VoidCallback onMenu;
  final VoidCallback onBell;
  final int notificationCount;
  final bool canSwitchChild;
  final VoidCallback? onSwitchChild;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 12),
      child: Row(
        children: [
          SquareButton(icon: Icons.menu_rounded, onTap: onMenu),
          const SizedBox(width: 10),
          _Face(
            label: child?.name ?? parentName,
            tint: tint,
            canSwitch: canSwitchChild,
            onTap: canSwitchChild ? onSwitchChild : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$parentName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                // School, then class — an emoji rather than an icon because the
                // design's glyph is a rendered building, and a flat Material
                // outline beside it reads as a different app.
                Row(
                  children: [
                    const Text('🏫', style: TextStyle(fontSize: 11.5)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        schoolName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ),
                    if ((child?.className ?? '').isNotEmpty) ...[
                      Text(
                        '  •  ',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                      ),
                      Text(
                        child!.className,
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SquareButton(
            icon: Icons.notifications_none_rounded,
            onTap: onBell,
            badge: notificationCount,
          ),
        ],
      ),
    );
  }
}

/// The child's face, ringed, with the switcher on it.
class _Face extends StatelessWidget {
  const _Face({required this.label, required this.tint, required this.canSwitch, this.onTap});

  final String label;
  final Color tint;
  final bool canSwitch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tint, width: 1.6),
              ),
              child: CircleInitials(label: label, tint: tint, size: 41),
            ),
            PositionedDirectional(
              bottom: -1,
              end: -1,
              child: Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.canvas, width: 1.8),
                ),
                child: Icon(
                  canSwitch ? Icons.expand_more_rounded : Icons.check_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rounded square either side of the header.
class SquareButton extends StatelessWidget {
  const SquareButton({super.key, required this.icon, required this.onTap, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: AppTheme.dark ? Border.all(color: AppTheme.border) : null,
              boxShadow: AppTheme.dark
                  ? null
                  : const [BoxShadow(color: Color(0x0A101828), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Icon(icon, size: 20, color: AppTheme.text),
          ),
          if (badge > 0)
            PositionedDirectional(
              top: -6,
              end: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                height: 20,
                constraints: const BoxConstraints(minWidth: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.brand,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.canvas, width: 2),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Today's schedule
 * ------------------------------------------------------------------------- */

class ScheduleEntry {
  const ScheduleEntry({
    required this.time,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.color,
  });

  final String time;
  final String subject;
  final String? teacher;
  final String? room;
  final Color color;
}

/// The day as a rail with the times down one side.
///
/// A timetable read as rows of "period 3, Maths, room 100" is a table nobody
/// scans. The rail exists so the shape of the day is visible before a single
/// word is read — which is the only reason to show a parent a timetable at all.
class ScheduleTimeline extends StatelessWidget {
  const ScheduleTimeline({
    super.key,
    required this.entries,
    this.onTap,
    this.trailingIcon = Icons.chevron_right_rounded,
  });

  final List<ScheduleEntry> entries;
  final void Function(int index)? onTap;

  /// A chevron on the parent's screen — the row opens the timetable — and a
  /// vertical ellipsis on the teacher's, where it opens what they can DO with
  /// that lesson. Same row, two different promises.
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 42,
                  child: Center(
                    child: Text(
                      entries[i].time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
                _Rail(
                  colour: entries[i].color,
                  first: i == 0,
                  last: i == entries.length - 1,
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap == null ? null : () => onTap!(i),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: _Lesson(entry: entries[i], trailing: trailingIcon),
                        ),
                        if (i != entries.length - 1)
                          Container(height: 1, color: AppTheme.border),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The vertical line with one dot on it.
///
/// Drawn as three pieces rather than one line behind the dots so the run above
/// the first dot and below the last one can simply not exist — a rail that
/// overshoots the day looks like the list has been cut off.
class _Rail extends StatelessWidget {
  const _Rail({required this.colour, required this.first, required this.last});

  final Color colour;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    Widget line(bool draw) => Expanded(
          child: Center(
            child: Container(
              width: 1.5,
              color: draw ? AppTheme.border : Colors.transparent,
            ),
          ),
        );

    return SizedBox(
      width: 26,
      child: Column(
        children: [
          line(!first),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          line(!last),
        ],
      ),
    );
  }
}

class _Lesson extends StatelessWidget {
  const _Lesson({required this.entry, required this.trailing});

  final ScheduleEntry entry;
  final IconData trailing;

  @override
  Widget build(BuildContext context) {
    final under = [
      if ((entry.teacher ?? '').isNotEmpty) entry.teacher!,
      if ((entry.room ?? '').isNotEmpty) entry.room!,
    ].join('  •  ');

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: entry.color.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(subjectIcon(entry.subject), size: 17, color: entry.color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: AppTheme.text,
                ),
              ),
              if (under.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  under,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
        ),
        Icon(trailing, size: 19, color: AppTheme.textFaint),
      ],
    );
  }
}

/// A glyph for a subject, so the timetable is scannable by shape.
///
/// Matched against the Kurdish and Arabic names as well as the English, because
/// the API returns whatever the school typed in whichever language the phone
/// asked for — and a screen that only recognises "Mathematics" shows a book
/// beside every lesson for most of its users.
IconData subjectIcon(String subject) {
  final s = subject.toLowerCase();
  bool has(List<String> words) => words.any(s.contains);

  if (has(['math', 'بیرکاری', 'ریاض', 'حساب'])) return Icons.calculate_rounded;
  if (has(['science', 'physic', 'chem', 'bio', 'زانست', 'علوم', 'فيزياء', 'كيمياء'])) {
    return Icons.science_rounded;
  }
  if (has(['sport', 'physical', 'gym', 'وەرزش', 'رياضة بدنية'])) {
    return Icons.sports_soccer_rounded;
  }
  if (has(['art', 'draw', 'music', 'هونەر', 'فن', 'موسيق'])) return Icons.palette_rounded;
  if (has(['comput', 'ict', 'کۆمپیوتەر', 'حاسوب'])) return Icons.computer_rounded;
  if (has(['islam', 'relig', 'ئایین', 'اسلامية', 'إسلامية', 'دين'])) return Icons.mosque_rounded;
  if (has(['histor', 'geograph', 'social', 'مێژوو', 'جغراف', 'تاريخ', 'کۆمەڵایەتی', 'اجتماع'])) {
    return Icons.public_rounded;
  }
  return Icons.menu_book_rounded;
}

/* ---------------------------------------------------------------------------
 * The ring
 * ------------------------------------------------------------------------- */

/// A percentage as a ring rather than a number.
///
/// The number is in the middle regardless — the ring is there so a glance says
/// "nearly full" without reading it, which is what a parent checking on the way
/// out of the door actually needs.
class PercentRing extends StatelessWidget {
  const PercentRing({
    super.key,
    required this.percent,
    required this.color,
    this.size = 96,
    this.label,
  });

  final double percent;
  final Color color;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final stroke = size * 0.095;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          percent: percent.clamp(0, 100) / 100,
          color: color,
          track: AppTheme.border,
          stroke: stroke,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percent.round()}%',
                style: TextStyle(
                  fontSize: size * 0.24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.1,
                  color: AppTheme.text,
                ),
              ),
              if (label != null)
                Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: size * 0.115, color: AppTheme.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.percent,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double percent;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    if (percent <= 0) return;
    // From the top, clockwise — the direction a dial is read.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * percent,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percent != percent || old.color != color || old.track != track;
}

/* ---------------------------------------------------------------------------
 * A figure in a strip, with an icon
 * ------------------------------------------------------------------------- */

class IconFigure {
  const IconFigure({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color color;
}

/// Four figures across the bottom of the child card.
///
/// Every line is scaled down to fit rather than wrapped or clipped: "Average
/// Marks" is a third longer than "Attitude" and in four columns on a narrow
/// phone something has to give. A shrunk label still answers the question; a
/// label reading "Average Mar…" does not.
class IconFigureStrip extends StatelessWidget {
  const IconFigureStrip({super.key, required this.figures});

  final List<IconFigure> figures;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < figures.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Container(width: 1, color: AppTheme.border),
              ),
            Expanded(child: _Figure(figure: figures[i], first: i == 0)),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.figure, required this.first});

  final IconFigure figure;
  final bool first;

  @override
  Widget build(BuildContext context) {
    // Fixed sizes, not scale-to-fit. Sizing each line to its own text made
    // "Assignments" visibly smaller than "Attendance" in the column beside it,
    // which reads as a rendering fault rather than as a strip of four figures.
    Widget line(String text, TextStyle style) => Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );

    return Padding(
      padding: EdgeInsetsDirectional.only(start: first ? 0 : 5, end: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: figure.color.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(figure.icon, size: 13, color: figure.color),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      figure.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 9,
                        color: AppTheme.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                line(
                  figure.value,
                  TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.3,
                    color: AppTheme.text,
                  ),
                ),
                line(
                  figure.caption,
                  TextStyle(fontSize: 7.5, color: AppTheme.textFaint, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * The updates feed
 * ------------------------------------------------------------------------- */

class UpdateEntry {
  const UpdateEntry({
    required this.icon,
    required this.category,
    required this.title,
    required this.when,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String category;
  final String title;
  final String when;
  final Color color;
  final VoidCallback? onTap;
}

class UpdatesFeed extends StatelessWidget {
  const UpdatesFeed({super.key, required this.entries, this.dense = false});

  /// Half-width, beside the attendance card. Drops the chevron and tightens the
  /// type — the same row at full width would wrap every title to three lines.
  final bool dense;

  final List<UpdateEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: entries[i].onTap,
            child: Padding(
              padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 10),
              child: Row(
                children: [
                  Container(
                    width: dense ? 30 : 36,
                    height: dense ? 30 : 36,
                    decoration: BoxDecoration(
                      color: entries[i].color.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                      borderRadius: BorderRadius.circular(dense ? 9 : 11),
                    ),
                    child: Icon(
                      entries[i].icon,
                      size: dense ? 16 : 19,
                      color: entries[i].color,
                    ),
                  ),
                  SizedBox(width: dense ? 8 : 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entries[i].category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: dense ? 9 : 10,
                            fontWeight: FontWeight.w700,
                            color: entries[i].color,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          entries[i].title,
                          maxLines: dense ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: dense ? 11.5 : 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.25,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          entries[i].when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: dense ? 9.5 : 10.5,
                            color: AppTheme.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: dense ? 16 : 19,
                    color: AppTheme.textFaint,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/* ---------------------------------------------------------------------------
 * A section heading with an action on the right
 * ------------------------------------------------------------------------- */

class SectionRow extends StatelessWidget {
  const SectionRow({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.dense = false,
    this.actionIcon = Icons.chevron_right_rounded,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dense;

  /// What follows the action word. A chevron for "go there"; a caret for
  /// "change this" — the attendance card's period is a choice, not a link, and
  /// pointing it sideways would promise a screen that does not exist.
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 10 : 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 12.5 : 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppTheme.text,
              ),
            ),
          ),
          if (actionLabel != null)
            // The role's colour, not a fixed violet. This heading is on the
            // teacher's screens too, where every other accent is green and a
            // violet "View all" was the only violet on the page.
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: dense ? 10 : 12.5,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (actionIcon != null)
                    Icon(
                      actionIcon,
                      size: dense ? 15 : 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
