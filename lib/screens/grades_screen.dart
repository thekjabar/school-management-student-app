import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Marks and attendance.
///
/// Only results the school has PUBLISHED appear here. That is enforced by the
/// API, not by this screen, and it matters: a teacher entering a class's marks
/// over three days must not have them surface on a student's phone one at a
/// time, with the student watching their own average move each evening.
class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  late Future<(List<SubjectGrade>, AttendanceSummary)> _future = _load();

  Future<(List<SubjectGrade>, AttendanceSummary)> _load() async {
    final r = await Future.wait([repository.grades(), repository.attendance()]);
    return (r[0] as List<SubjectGrade>, r[1] as AttendanceSummary);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grades')),
      body: FutureBuilder<(List<SubjectGrade>, AttendanceSummary)>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppTheme.gutter),
              child: ErrorPanel(
                message: snap.error.toString(),
                onRetry: () => setState(() => _future = _load()),
              ),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppTheme.gutter),
              child: LoadingSkeleton(height: 74, count: 5),
            );
          }

          final (grades, attendance) = snap.data!;
          final avg = grades.isEmpty
              ? 0.0
              : grades.map((g) => g.percent).reduce((a, b) => a + b) / grades.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 4, AppTheme.gutter, 28),
            children: [
              Panel(
                dark: true,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TERM AVERAGE',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        letterSpacing: 0.9, color: Color(0xFF8A8F98),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          avg.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 40, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -1.5, height: 1,
                          ),
                        ),
                        const Text('%',
                            style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600,
                              color: Color(0xFF8A8F98),
                            )),
                        const Spacer(),
                        Pill(
                          '${grades.length} subjects',
                          color: const Color(0xFFB9A6FF),
                          background: const Color(0xFFB9A6FF).withValues(alpha: 0.14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // A percentage rather than an average of raw marks: subjects
                    // are scored out of different totals, and averaging the raw
                    // numbers silently weights whichever has the largest one.
                    const Text(
                      'Averaged across subjects as a percentage, so a subject marked out of 50 counts the same as one marked out of 100.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF8A8F98), height: 1.4),
                    ),
                  ],
                ),
              ),

              const SectionLabel('Attendance'),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Rate',
                      value: attendance.rate.toStringAsFixed(0),
                      suffix: '%',
                      trend: attendance.trend,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Days absent',
                      value: '${attendance.absent}',
                      note: '${attendance.late} late • ${attendance.excused} excused',
                    ),
                  ),
                ],
              ),

              const SectionLabel('By subject'),
              ...grades.map((g) => _GradeRow(grade: g)),
            ],
          );
        },
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.grade});
  final SubjectGrade grade;

  /// Colour is reserved for the two ends. A row that is simply fine stays
  /// neutral, so the one that needs attention is the one that stands out.
  static Color _tint(double percent) {
    if (percent >= 90) return AppTheme.positive;
    if (percent >= 80) return const Color(0xFF0EA5E9);
    if (percent >= 70) return AppTheme.warm;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    final tint = _tint(grade.percent);
    final up = grade.trend >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(grade.subject,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(grade.teacher,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 11.5),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          grade.percent.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700,
                            color: tint, letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tint.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            grade.letter,
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: tint,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 10,
                          color: up ? AppTheme.positive : AppTheme.danger,
                        ),
                        Text(
                          '${up ? '+' : ''}${grade.trend.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w600,
                            color: up ? AppTheme.positive : AppTheme.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (grade.percent / 100).clamp(0, 1),
                minHeight: 5,
                backgroundColor: AppTheme.canvas,
                valueColor: AlwaysStoppedAnimation(tint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
