import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/motion.dart';

ScheduleEntry lessonEntry(Lesson lesson, Color tint) {
  final parts = clock12(lesson.startMinute).split(' ');
  return ScheduleEntry(
    time: parts.first,
    timeSuffix: parts.length > 1 ? parts[1] : null,
    subject: lesson.subject,
    teacher: lesson.teacherName,
    room: lesson.room,
    color: parseHex(lesson.subjectColorHex, tint),
    railColor: tint,
    nowLabel: lesson.inProgress ? t('student.now') : null,
  );
}

class StudentHero extends StatelessWidget {
  const StudentHero({
    super.key,
    required this.label,
    required this.title,
    required this.facts,
    required this.badge,
    this.onOpen,
    this.openLabel,
  });

  final String label;
  final String title;
  final List<(IconData, String)> facts;
  final String? badge;
  final VoidCallback? onOpen;
  final String? openLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient(Role.student.tint),
        borderRadius: BorderRadius.circular(kCardRadius + 2),
        boxShadow: AppTheme.dark
            ? null
            : [
                BoxShadow(
                  color: Role.student.tint.withValues(alpha: 0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius + 2),
        child: Stack(
          children: [
            PositionedDirectional(
              end: -14,
              bottom: -18,
              child: Image.asset(
                'assets/art/student_study.png',
                width: 168,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            if (badge != null)
              PositionedDirectional(
                end: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  constraints: const BoxConstraints(maxWidth: 96),
                  decoration: BoxDecoration(
                    color: const Color(0xFF04333A).withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    badge!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(17, 17, 17, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    width: 210,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 210,
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          for (final (icon, text) in facts)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 14, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  text,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (onOpen != null && openLabel != null) ...[
                    const SizedBox(height: 14),
                    _GhostButton(label: openLabel!, onTap: onOpen!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(15, 9, 12, 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C3B45),
                ),
              ),
              const SizedBox(width: 7),
              const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF0C3B45)),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentTile {
  const StudentTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class StudentTiles extends StatelessWidget {
  const StudentTiles({super.key, required this.tiles});

  final List<StudentTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < tiles.length; i++)
            Expanded(child: _Tile(tile: tiles[i], index: i)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile, required this.index});

  final StudentTile tile;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tile.onTap,
      behavior: HitTestBehavior.opaque,
      child: Rise(
        index: index,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pop(
              index: index,
              extraDelay: const Duration(milliseconds: 60),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tile.color.withValues(alpha: AppTheme.dark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(tile.icon, size: 23, color: tile.color),
              ),
            ),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                tile.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  height: 1.25,
                  color: AppTheme.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NowCard extends StatelessWidget {
  const NowCard({
    super.key,
    required this.minutesLeft,
    required this.fraction,
    required this.subject,
    required this.under,
    required this.color,
  });

  final int minutesLeft;
  final double fraction;
  final String subject;
  final String under;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(12, 13, 14, 13),
      child: Row(
        children: [
          CountRing(
            value: '$minutesLeft',
            caption: t('student.minLeft'),
            fraction: fraction,
            color: color,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('student.nowIn').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppTheme.textFaint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppTheme.text,
                  ),
                ),
                if (under.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    under,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Chip36(icon: subjectIcon(subject), color: color, size: 42),
        ],
      ),
    );
  }
}

class CountRing extends StatelessWidget {
  const CountRing({
    super.key,
    required this.value,
    required this.caption,
    required this.fraction,
    required this.color,
    this.size = 70,
  });

  final String value;
  final String caption;
  final double fraction;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ArcPainter(
          fraction: fraction.clamp(0.0, 1.0),
          color: color,
          track: AppTheme.border,
          stroke: size * 0.085,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.1,
                  color: AppTheme.text,
                ),
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: size * 0.125, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

class SoftNote extends StatelessWidget {
  const SoftNote({super.key, required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(9, 7, 11, 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LetterBadge extends StatelessWidget {
  const LetterBadge({super.key, required this.letter, required this.color});

  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        letter,
        maxLines: 1,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class DayChips extends StatelessWidget {
  const DayChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onPick,
    required this.tint,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onPick;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = i == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onPick(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              decoration: BoxDecoration(
                color: on ? tint : AppTheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: on || !AppTheme.dark ? null : Border.all(color: AppTheme.border),
                boxShadow: on || AppTheme.dark
                    ? null
                    : const [
                        BoxShadow(color: Color(0x0A101828), blurRadius: 10, offset: Offset(0, 3)),
                      ],
              ),
              child: Text(
                labels[i],
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : AppTheme.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class StudentSectionLabel extends StatelessWidget {
  const StudentSectionLabel(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 9),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppTheme.textFaint,
        ),
      ),
    );
  }
}
