import 'package:flutter/material.dart';

import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';

class StudentMarks extends StatelessWidget {
  const StudentMarks({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;

    return Loader<_Report>(
      tint: tint,
      padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18)),
      load: _Report.fetch,
      builder: (context, report) {
        final counted = report.marks.where((m) => m.percent != null).toList(growable: false);
        final average = counted.isEmpty
            ? null
            : counted.map((m) => m.percent!).reduce((a, b) => a + b) / counted.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AttendanceCard(summary: report.attendance),
            const SizedBox(height: kCardGap),

            Card16(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  PercentRing(
                    percent: average ?? 0,
                    color: tint,
                    size: 88,
                    label: t('marks.average'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('marks.markedWork'),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          counted.isEmpty
                              ? t('marks.none')
                              : tn('marks.countedFrom', counted.length),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),

            Card16(
              padding: EdgeInsets.fromLTRB(14, 14, 14, report.marks.isEmpty ? 14 : 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionRow(title: t('marks.published')),
                  if (report.marks.isEmpty)
                    Text(
                      t('marks.none'),
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.45),
                    )
                  else
                    for (var i = 0; i < report.marks.length; i++)
                      TileRow(
                        icon: subjectIcon(report.marks[i].subject),
                        color: parseHex(report.marks[i].subjectColorHex, AppTheme.violet),
                        title: report.marks[i].subject,
                        subtitle: [
                          report.marks[i].examTitle,
                          if (report.marks[i].examDate != null)
                            shortDate(report.marks[i].examDate),
                        ].where((s) => s.isNotEmpty).join('  •  '),
                        trailing: _scoreLabel(report.marks[i]),
                        trailingSub: report.marks[i].gradeLetter ??
                            percent(report.marks[i].percent),
                        trailingColor: report.marks[i].isPass == false
                            ? AppTheme.rose
                            : AppTheme.green,
                        last: i == report.marks.length - 1,
                      ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _scoreLabel(Mark mark) {
  if (mark.wasAbsent) return t('marks.absent');
  if (mark.wasExempt) return t('attendance.excused');
  return '${_trim(mark.score)} / ${_trim(mark.maxScore)}';
}

String _trim(double? value) {
  if (value == null) return '—';
  return value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(1);
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final rate = summary.ratePercent;
    final tone = rate >= 90
        ? AppTheme.green
        : rate >= 75
            ? AppTheme.amber
            : AppTheme.rose;

    return Card16(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PercentRing(percent: rate, color: tone, size: 88, label: t('student.attendance')),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      termCaption(summary.termName, summary.from, summary.to),
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.3,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.total == 0
                          ? t('student.noAttendanceYet')
                          : tn('student.schoolDays', summary.total),
                      style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rate >= 90 ? t('attendance.keepItUp') : t('attendance.watchThis'),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tone),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 13),
          IconFigureStrip(
            figures: [
              IconFigure(
                icon: Icons.check_circle_outline_rounded,
                label: t('student.present'),
                value: '${summary.present}',
                caption: '',
                color: AppTheme.green,
              ),
              IconFigure(
                icon: Icons.schedule_rounded,
                label: t('student.late'),
                value: '${summary.late}',
                caption: '',
                color: AppTheme.amber,
              ),
              IconFigure(
                icon: Icons.cancel_outlined,
                label: t('student.absent'),
                value: '${summary.absent}',
                caption: '',
                color: AppTheme.rose,
              ),
              IconFigure(
                icon: Icons.verified_outlined,
                label: t('attendance.excused'),
                value: '${summary.excused}',
                caption: '',
                color: AppTheme.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Report {
  _Report({required this.marks, required this.attendance});

  final List<Mark> marks;
  final AttendanceSummary attendance;

  static Future<_Report> fetch() async {
    final api = StudentApi.instance;
    final results = await Future.wait([api.marks(), api.attendance()]);
    return _Report(
      marks: results[0] as List<Mark>,
      attendance: results[1] as AttendanceSummary,
    );
  }
}
