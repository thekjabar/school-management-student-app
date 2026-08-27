import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// The dark card at the top of the home screen.
///
/// The only element on the screen with weight. It answers the one question a
/// student opens the app for between lessons — *where am I meant to be* — and
/// everything below it is reference material.
class SessionHeaderCard extends StatelessWidget {
  const SessionHeaderCard({
    super.key,
    required this.student,
    required this.session,
    required this.isLive,
  });

  final Student student;
  final Session? session;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Panel(
      dark: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(student: student),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STUDENT ID: ${student.code}',
                      style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        letterSpacing: 0.9, color: Color(0xFF8A8F98),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Shown only when there is one. A streak rendered as "0 days" is a
              // reprimand, and this is not the place for one.
              if (student.streakDays > 0)
                Pill(
                  '${student.streakDays} day streak',
                  icon: Icons.local_fire_department_rounded,
                  color: AppTheme.warm,
                  background: AppTheme.warm.withValues(alpha: 0.16),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'CURRENT SESSION',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              letterSpacing: 0.9, color: Color(0xFF8A8F98),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  session?.subject ?? 'No lesson right now',
                  style: t.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (session != null) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: isLive
                      ? Pill(
                          'Active',
                          color: const Color(0xFF4ADE80),
                          background: const Color(0xFF4ADE80).withValues(alpha: 0.14),
                        )
                      : Pill(
                          'Next',
                          color: const Color(0xFFB9A6FF),
                          background: const Color(0xFFB9A6FF).withValues(alpha: 0.14),
                        ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            session == null
                ? 'Enjoy the break.'
                : '${session!.room} • ${session!.teacher.isEmpty ? session!.timeRange : session!.teacher}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF9AA0A8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2E36),
        borderRadius: BorderRadius.circular(10),
        image: student.photoUrl != null
            ? DecorationImage(image: NetworkImage(student.photoUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      // Initials rather than a stock silhouette: many families here do not
      // consent to a child's photograph, and that has to look deliberate rather
      // than like a picture failed to load.
      child: student.photoUrl == null
          ? Text(
              student.initials,
              style: const TextStyle(
                color: Color(0xFFB9A6FF), fontWeight: FontWeight.w700, fontSize: 14,
              ),
            )
          : null,
    );
  }
}

/// One large figure with a label and a movement indicator.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.note,
    this.trend,
    this.onTap,
  });

  final String label;
  final String value;
  final String? suffix;
  final String? note;
  final double? trend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final up = (trend ?? 0) >= 0;
    final t = Theme.of(context).textTheme;

    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: t.labelSmall),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: t.displayLarge),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(left: 1),
                  child: Text(
                    suffix!,
                    style: t.displayLarge?.copyWith(
                      fontSize: 20, color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (trend != null)
            Row(
              children: [
                Icon(
                  up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 12,
                  color: up ? AppTheme.positive : AppTheme.danger,
                ),
                const SizedBox(width: 2),
                Text(
                  '${up ? '+' : ''}${trend!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600,
                    color: up ? AppTheme.positive : AppTheme.danger,
                  ),
                ),
              ],
            )
          else if (note != null)
            Text(note!, style: t.bodySmall?.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// A row in the assignments list.
class AssignmentRow extends StatelessWidget {
  const AssignmentRow({super.key, required this.assignment, this.onTap});

  final Assignment assignment;
  final VoidCallback? onTap;

  static (IconData, Color) _glyph(AssignmentKind k) => switch (k) {
        AssignmentKind.lab => (Icons.science_outlined, Color(0xFF0EA5E9)),
        AssignmentKind.art => (Icons.palette_outlined, Color(0xFFEC4899)),
        AssignmentKind.essay => (Icons.edit_note_rounded, Color(0xFF8B5CF6)),
        AssignmentKind.problemSet => (Icons.functions_rounded, Color(0xFF14B8A6)),
        AssignmentKind.reading => (Icons.menu_book_outlined, Color(0xFFF59E0B)),
        AssignmentKind.project => (Icons.widgets_outlined, Color(0xFF6366F1)),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = _glyph(assignment.kind);
    final overdue = assignment.isOverdue;
    final done = assignment.submitted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: done ? AppTheme.canvas : tint.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                done ? Icons.check_rounded : icon,
                size: 19,
                color: done ? AppTheme.textMuted : tint,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: done ? AppTheme.textMuted : AppTheme.textPrimary,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: AppTheme.textMuted,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    done ? 'Handed in' : assignment.dueLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      // Overdue is the one state that earns colour. If every
                      // due date were red, none of them would mean anything.
                      color: overdue ? AppTheme.danger : AppTheme.textSecondary,
                      fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                      fontStyle: done ? FontStyle.normal : FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 17, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

/// One of the four squares in the quick-resources grid.
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.tint,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 19, color: tint),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tint, borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown instead of a list when the list is empty.
///
/// An empty screen with nothing on it reads as a failure to load. Saying what
/// is absent, and that it is fine, is the difference between "broken" and
/// "nothing due".
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.line});

  final IconData icon;
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 26, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            line,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The skeleton shown while data loads.
///
/// Laid out to the same rhythm as the real content, so the screen does not jump
/// when it arrives — which is the entire reason to have one rather than a
/// spinner.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key, this.height = 76, this.count = 3});
  final double height;
  final int count;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Column(
        children: List.generate(
          widget.count,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: Color.lerp(AppTheme.surface, AppTheme.border, _c.value * 0.7),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: AppTheme.hairline(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when a request fails.
///
/// Names what could not be reached and offers the one useful action. A red
/// triangle with "Error" tells a fifteen-year-old nothing they can act on.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.dangerSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.cloud_off_rounded, size: 16, color: AppTheme.danger),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  "Couldn't load this",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.canvas,
                foregroundColor: AppTheme.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
              child: const Text('Try again',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }
}
