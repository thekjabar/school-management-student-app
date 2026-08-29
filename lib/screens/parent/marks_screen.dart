import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';

/// Every mark the child has been given.
///
/// Separate from Reports on purpose. Reports answers "how is the term going" in
/// four figures; this answers "what did they get for the Unit 3 quiz", which is
/// the question a parent asks the evening it comes back. Same records, two
/// different questions, and squeezing both into one screen serves neither.
class MarksScreen extends StatelessWidget {
  const MarksScreen({super.key, required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(t('quick.marks')),
        backgroundColor: Role.parent.wash,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Loader<_Marks>(
        tint: Role.parent.tint,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        load: () async {
          final r = await Future.wait([
            ParentApi.instance.results(child.studentId),
            ParentApi.instance.homework(child.studentId),
          ]);
          return _Marks(
            exams: r[0] as List<ExamResultItem>,
            homework: r[1] as List<HomeworkItem>,
          );
        },
        empty: t('marks.none'),
        isEmpty: (d) => d.exams.isEmpty && d.markedHomework.isEmpty,
        builder: (context, d) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The one figure a parent came for, before the list.
            if (d.average != null)
              Card16(
                child: Row(
                  children: [
                    PercentRing(
                      percent: d.average!.toDouble(),
                      color: d.average! >= 80
                          ? AppTheme.green
                          : d.average! >= 50
                              ? AppTheme.amber
                              : AppTheme.rose,
                      size: 104,
                      label: t('marks.average'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('marks.acrossEverything'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tn('marks.countedFrom', d.markedHomework.length + d.exams.length),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textMuted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (d.average != null) const SizedBox(height: 14),

            if (d.exams.isNotEmpty) ...[
              Card16(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionRow(title: t('reports.exams')),
                    for (final r in d.exams)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MarkRow(
                          title: r.examTitle,
                          subtitle: '${r.subject} · ${longDate(r.date)}',
                          score: r.score?.toDouble(),
                          outOf: r.maxScore.toDouble(),
                          percent: r.percent?.toDouble(),
                          absent: r.wasAbsent,
                          grade: r.gradeLetter,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (d.markedHomework.isNotEmpty)
              Card16(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionRow(title: t('marks.markedWork')),
                    for (final h in d.markedHomework)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MarkRow(
                          title: h.title,
                          subtitle: '${h.subject} · ${longDate(h.dueDate)}',
                          score: h.score?.toDouble(),
                          outOf: (h.maxScore ?? 0).toDouble(),
                          percent: h.maxScore == null || h.maxScore == 0
                              ? null
                              : h.score!.toDouble() / h.maxScore!.toDouble() * 100,
                          absent: false,
                          grade: null,
                          feedback: h.feedback,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Marks {
  _Marks({required this.exams, required this.homework});

  final List<ExamResultItem> exams;
  final List<HomeworkItem> homework;

  /// Only work that has actually been marked. Homework that is set but not yet
  /// returned belongs on the assignments screen, not here.
  List<HomeworkItem> get markedHomework =>
      homework.where((h) => h.score != null && (h.maxScore ?? 0) > 0).toList();

  int? get average {
    final percents = <double>[
      for (final h in markedHomework) h.score!.toDouble() / h.maxScore!.toDouble() * 100,
      for (final e in exams)
        if (e.percent != null && !e.wasAbsent) e.percent!.toDouble(),
    ];
    if (percents.isEmpty) return null;
    return (percents.reduce((a, b) => a + b) / percents.length).round();
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.title,
    required this.subtitle,
    required this.score,
    required this.outOf,
    required this.percent,
    required this.absent,
    required this.grade,
    this.feedback,
  });

  final String title;
  final String subtitle;
  final double? score;
  final double outOf;
  final double? percent;
  final bool absent;
  final String? grade;
  final String? feedback;

  @override
  Widget build(BuildContext context) {
    final colour = percent == null
        ? AppTheme.textFaint
        : percent! >= 80
            ? AppTheme.green
            : percent! >= 50
                ? AppTheme.amber
                : AppTheme.rose;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (absent)
              Pill(t('marks.absent'), color: AppTheme.textMuted)
            else ...[
              // The raw mark, because "17 out of 20" is what the child came
              // home saying, and a percentage alone makes a parent do the sum
              // backwards to check it.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score == null ? '—' : '${_trim(score!)} / ${_trim(outOf)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text,
                    ),
                  ),
                  if (percent != null)
                    Text(
                      grade == null
                          ? '${percent!.round()}%'
                          : '${percent!.round()}% · $grade',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: colour),
                    ),
                ],
              ),
            ],
          ],
        ),
        if (percent != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (percent! / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
        ],
        if ((feedback ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.canvas,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              feedback!,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
            ),
          ),
        ],
      ],
    );
  }

  /// 17 rather than 17.0 — a mark is written the way a teacher writes it.
  String _trim(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}
