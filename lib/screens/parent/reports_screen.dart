import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';

/// How the term has gone, in one place.
///
/// Assembled from what the school has already published rather than from a
/// separate reporting endpoint: attendance, marked work, exam results and
/// conduct. A "report" in this product is a reading of records the family can
/// already see one at a time — it invents no figure a parent cannot trace back
/// to something with a date on it.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(t('quick.reports')),
        backgroundColor: Role.parent.wash,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Loader<_Report>(
        tint: Role.parent.tint,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        load: () async {
          final r = await Future.wait([
            ParentApi.instance.attendance(child.studentId),
            ParentApi.instance.homework(child.studentId),
            ParentApi.instance.results(child.studentId),
            ParentApi.instance.attitude(child.studentId),
          ]);
          return _Report(
            attendance: r[0] as AttendanceSummary,
            homework: r[1] as List<HomeworkItem>,
            results: r[2] as List<ExamResultItem>,
            attitude: r[3] as AttitudeSummary,
          );
        },
        builder: (context, d) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Attendance --------------------------------------------------
            Card16(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionRow(title: t('quick.attendance')),
                  if (d.attendance.total == 0)
                    _Quiet(t('home.notMarked'))
                  else
                    Row(
                      children: [
                        PercentRing(
                          percent: d.attendance.ratePercent.toDouble(),
                          color: d.attendance.ratePercent >= 95 ? AppTheme.green : AppTheme.amber,
                          size: 116,
                          label: t('attendance.present'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Line(t('attendance.present'), '${d.attendance.present}', AppTheme.green),
                              _Line(t('attendance.absent'), '${d.attendance.absent}', AppTheme.rose),
                              _Line(t('attendance.late'), '${d.attendance.late}', AppTheme.amber),
                              _Line(t('attendance.excused'), '${d.attendance.excused}', AppTheme.blue),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ---- Marked work -------------------------------------------------
            Card16(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionRow(title: t('reports.marks')),
                  if (d.bySubject.isEmpty)
                    _Quiet(t('reports.nothingMarked'))
                  else
                    for (final entry in d.bySubject.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SubjectBar(
                          subject: entry.key,
                          percent: entry.value,
                          color: entry.value >= 80
                              ? AppTheme.green
                              : entry.value >= 50
                                  ? AppTheme.amber
                                  : AppTheme.rose,
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ---- Homework handed in ------------------------------------------
            Card16(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionRow(title: t('quick.assignments')),
                  IconFigureStrip(
                    figures: [
                      IconFigure(
                        icon: Icons.check_circle_rounded,
                        label: t('reports.handedIn'),
                        value: '${d.handedIn}',
                        caption: t('reports.ofTotal').replaceAll('{n}', '${d.homework.length}'),
                        color: AppTheme.green,
                      ),
                      IconFigure(
                        icon: Icons.pending_actions_rounded,
                        label: t('home.pending'),
                        value: '${d.homework.length - d.handedIn}',
                        caption: t('reports.stillDue'),
                        color: AppTheme.amber,
                      ),
                      IconFigure(
                        icon: Icons.trending_up_rounded,
                        label: t('home.averageMarks'),
                        value: d.average == null ? '—' : '${d.average}%',
                        caption: t('home.thisTerm'),
                        color: AppTheme.violet,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ---- Conduct ------------------------------------------------------
            Card16(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionRow(title: t('quick.attitude')),
                  IconFigureStrip(
                    figures: [
                      IconFigure(
                        icon: Icons.star_rounded,
                        label: t('attitude.merits'),
                        value: '${d.attitude.merits}',
                        caption: t('attitude.thisTerm'),
                        color: AppTheme.green,
                      ),
                      IconFigure(
                        icon: Icons.error_outline_rounded,
                        label: t('attitude.concerns'),
                        value: '${d.attitude.concerns + d.attitude.incidents}',
                        caption: t('attitude.thisTerm'),
                        color: AppTheme.amber,
                      ),
                      IconFigure(
                        icon: Icons.sentiment_satisfied_rounded,
                        label: t('reports.overall'),
                        value: t('attitude.${d.attitude.verdict}'),
                        caption: t('attitude.running'),
                        color: AppTheme.rose,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ---- Exams --------------------------------------------------------
            if (d.results.isNotEmpty)
              Card16(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionRow(title: t('reports.exams')),
                    for (final r in d.results.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.examTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.text,
                                    ),
                                  ),
                                  Text(
                                    '${r.subject} · ${longDate(r.date)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                                  ),
                                ],
                              ),
                            ),
                            if (r.percent != null)
                              Pill(
                                '${r.percent!.round()}%',
                                color: r.percent! >= 50 ? AppTheme.green : AppTheme.rose,
                              ),
                          ],
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

class _Report {
  _Report({
    required this.attendance,
    required this.homework,
    required this.results,
    required this.attitude,
  });

  final AttendanceSummary attendance;
  final List<HomeworkItem> homework;
  final List<ExamResultItem> results;
  final AttitudeSummary attitude;

  int get handedIn => homework.where((h) => h.handedIn).length;

  /// The average across everything marked. Null when nothing is: a child with
  /// no marks has not scored nought, and showing 0% would say they had.
  int? get average {
    final marked = homework.where((h) => h.score != null && (h.maxScore ?? 0) > 0).toList();
    if (marked.isEmpty) return null;
    final total = marked.fold<double>(
      0,
      (sum, h) => sum + (h.score!.toDouble() / h.maxScore!.toDouble()) * 100,
    );
    return (total / marked.length).round();
  }

  /// Marked work averaged per subject, best first.
  Map<String, int> get bySubject {
    final sums = <String, List<double>>{};
    for (final h in homework) {
      if (h.score == null || (h.maxScore ?? 0) <= 0) continue;
      sums.putIfAbsent(h.subject, () => []).add(h.score!.toDouble() / h.maxScore!.toDouble() * 100);
    }
    final out = sums.map(
      (subject, marks) => MapEntry(subject, (marks.reduce((a, b) => a + b) / marks.length).round()),
    );
    final sorted = out.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({required this.subject, required this.percent, required this.color});

  final String subject;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 7,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(text, style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      ),
    );
  }
}
