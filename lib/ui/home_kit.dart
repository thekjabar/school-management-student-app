import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'kit.dart';
import 'motion.dart';

const kGutter = 14.0;
const kCardGap = 9.0;
const kCardRadius = 18.0;

class ChildBrief {
  const ChildBrief({required this.name, required this.className});

  final String name;
  final String className;
}

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

class ScheduleTimeline extends StatelessWidget {
  const ScheduleTimeline({
    super.key,
    required this.entries,
    this.onTap,
    this.trailingIcon = Icons.chevron_right_rounded,
  });

  final List<ScheduleEntry> entries;
  final void Function(int index)? onTap;

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
      child: CountUp(
        value: percent.clamp(0, 100).toDouble(),
        builder: (context, shown) => CustomPaint(
          painter: _RingPainter(
            percent: shown / 100,
            color: color,
            track: AppTheme.border,
            stroke: stroke,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${shown.round()}%',
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
              Rise(
                index: i,
                distance: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Container(width: 1, color: AppTheme.border),
                ),
              ),
            Expanded(
              child: Rise(
                index: i,
                child: _Figure(figure: figures[i], first: i == 0, index: i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.figure, required this.first, required this.index});

  final IconFigure figure;
  final bool first;

  final int index;

  @override
  Widget build(BuildContext context) {
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
          Pop(
            index: index,
            extraDelay: const Duration(milliseconds: 60),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: figure.color.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                shape: BoxShape.circle,
              ),
              child: Icon(figure.icon, size: 13, color: figure.color),
            ),
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
