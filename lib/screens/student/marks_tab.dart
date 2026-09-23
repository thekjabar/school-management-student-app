import 'package:flutter/material.dart';

import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/motion.dart';
import '../../ui/pickers.dart';
import 'student_kit.dart';

class StudentMarks extends StatelessWidget {
  const StudentMarks({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;

    return Loader<_Report>(
      tint: tint,
      padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18)),
      load: _Report.fetch,
      builder: (context, report) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Rise(index: 0, child: _AttendanceCard(summary: report.attendance)),
          const SizedBox(height: kCardGap),
          Rise(index: 1, child: _MarkedWorkCard(marks: report.marks, tint: tint)),
          const SizedBox(height: kCardGap),
          Rise(index: 2, child: _PublishedMarks(marks: report.marks, tint: tint)),
        ],
      ),
    );
  }
}

class _MarkedWorkCard extends StatelessWidget {
  const _MarkedWorkCard({required this.marks, required this.tint});

  final List<Mark> marks;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final counted = marks.where((m) => m.percent != null).toList(growable: false);
    final average = counted.isEmpty
        ? null
        : counted.map((m) => m.percent!).reduce((a, b) => a + b) / counted.length;

    return Card16(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PercentRing(
            percent: average ?? 0,
            color: tint,
            size: 84,
            label: t('marks.average'),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('marks.markedWork'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  counted.isEmpty ? t('marks.none') : tn('marks.countedFrom', counted.length),
                  style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.textMuted),
                ),
                if (average != null) ...[
                  const SizedBox(height: 9),
                  SoftNote(
                    icon: Icons.insights_rounded,
                    text: average >= 75
                        ? t('marks.strongWork')
                        : average >= 50
                            ? t('marks.keepGoing')
                            : t('marks.needsTime'),
                    color: average >= 75
                        ? AppTheme.green
                        : average >= 50
                            ? tint
                            : AppTheme.amber,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishedMarks extends StatefulWidget {
  const _PublishedMarks({required this.marks, required this.tint});

  final List<Mark> marks;
  final Color tint;

  @override
  State<_PublishedMarks> createState() => _PublishedMarksState();
}

class _PublishedMarksState extends State<_PublishedMarks> {
  String? _subject;

  @override
  Widget build(BuildContext context) {
    final subjects = <String>{for (final m in widget.marks) m.subject}.toList()..sort();
    final shown = _subject == null
        ? widget.marks
        : widget.marks.where((m) => m.subject == _subject).toList(growable: false);

    return Card16(
      padding: EdgeInsets.fromLTRB(14, 14, 14, shown.isEmpty ? 14 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('marks.published'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.text,
                  ),
                ),
              ),
              if (subjects.length > 1)
                _SubjectFilter(
                  label: _subject ?? t('marks.allSubjects'),
                  tint: widget.tint,
                  onTap: () => _pick(subjects),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            Text(
              t('marks.none'),
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.45),
            )
          else
            for (var i = 0; i < shown.length; i++)
              _MarkRow(mark: shown[i], tint: widget.tint, last: i == shown.length - 1),
        ],
      ),
    );
  }

  Future<void> _pick(List<String> subjects) async {
    final picked = await pickOne<String>(
      context,
      tint: widget.tint,
      title: t('marks.published'),
      selected: _subject ?? '',
      options: [
        PickOption(value: '', label: t('marks.allSubjects')),
        for (final s in subjects) PickOption(value: s, label: s),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _subject = picked.isEmpty ? null : picked);
  }
}

class _SubjectFilter extends StatelessWidget {
  const _SubjectFilter({required this.label, required this.tint, required this.onTap});

  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 148),
        padding: const EdgeInsetsDirectional.fromSTEB(11, 7, 7, 7),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: AppTheme.dark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tint),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 16, color: tint),
          ],
        ),
      ),
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({required this.mark, required this.tint, required this.last});

  final Mark mark;
  final Color tint;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colour = parseHex(mark.subjectColorHex, tint);
    final letter = mark.gradeLetter;
    final tone = mark.isPass == false ? AppTheme.rose : AppTheme.green;
    final sub = [
      mark.examTitle,
      if (mark.examDate != null) shortDate(mark.examDate),
    ].where((s) => s.isNotEmpty).join('  •  ');

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 10 : 0),
      child: Column(
        children: [
          Row(
            children: [
              Chip36(icon: subjectIcon(mark.subject), color: colour, size: 38),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mark.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AppTheme.text,
                      ),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _scoreLabel(mark),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: tone,
                ),
              ),
              if (letter != null && letter.isNotEmpty) ...[
                const SizedBox(width: 9),
                LetterBadge(letter: letter, color: tone),
              ],
            ],
          ),
          if (!last) ...[
            const SizedBox(height: 11),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 11),
          ],
        ],
      ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PercentRing(percent: rate, color: tone, size: 84, label: t('student.attendance')),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      termCaption(summary.termName, summary.from, summary.to),
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 15,
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
                    if (summary.total > 0) ...[
                      const SizedBox(height: 9),
                      SoftNote(
                        icon: Icons.insights_rounded,
                        text: rate >= 90 ? t('attendance.keepItUp') : t('attendance.watchThis'),
                        color: tone,
                      ),
                    ],
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
