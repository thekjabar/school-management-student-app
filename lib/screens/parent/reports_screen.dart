import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import 'attendance_screen.dart';
import 'attitude_screen.dart';
import 'marks_screen.dart';

/// How the term is going, in one screen.
///
/// Four figures, then the same term broken down by subject, then the results
/// those figures were drawn from. Nothing here is a grade the school did not
/// give: every percentage is a mark divided by the mark it was out of.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.child});

  final Child child;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('quick.reports'), onBell: () {}),
            Expanded(
              child: Loader<_Report>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                load: () async {
                  final r = await Future.wait([
                    ParentApi.instance.results(widget.child.studentId),
                    ParentApi.instance.homework(widget.child.studentId),
                  ]);
                  return _Report(
                    exams: r[0] as List<ExamResultItem>,
                    homework: r[1] as List<HomeworkItem>,
                  );
                },
                builder: (context, report) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The card on the left, the illustration on the right, in a
                    // block tall enough to hold it whole.
                    SizedBox(
                      height: 124,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          PositionedDirectional(
                            end: -6,
                            top: -4,
                            child: Image.asset(
                              'assets/art/reports_scene.png',
                              width: 162,
                            ),
                          ),
                          PositionedDirectional(
                            start: 0,
                            end: 140,
                            top: 8,
                            child: ChildCard(
                              name: widget.child.name,
                              line: '${widget.child.className}  •  ${widget.child.code}',
                              tint: tint,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: kGutter),
                      child: PillTabs(
                        tint: tint,
                        index: _tab,
                        onChanged: (i) => _go(context, i),
                        tabs: [
                          TabSpec(label: t('rep.academic'), icon: Icons.menu_book_rounded),
                          TabSpec(
                            label: t('rep.attendance'),
                            icon: Icons.verified_user_outlined,
                            color: AppTheme.green,
                          ),
                          TabSpec(
                            label: t('rep.behaviour'),
                            icon: Icons.sentiment_satisfied_alt_rounded,
                            color: AppTheme.rose,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: kCardGap),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: kGutter),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Overview(report: report),
                          const SizedBox(height: kCardGap),
                          _Subjects(report: report, child: widget.child),
                          const SizedBox(height: kCardGap),
                          _Recent(report: report, child: widget.child),
                          const SizedBox(height: kCardGap),
                          NoticeBanner(
                            icon: Icons.info_outline_rounded,
                            color: tint,
                            title: t('rep.updatedRegularly'),
                            body: tn(
                              'rep.keepSupporting',
                              widget.child.name.split(' ').first,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The other two tabs are whole screens of their own — the register and the
  /// conduct log — rather than a second, thinner copy of them here.
  void _go(BuildContext context, int i) {
    if (i == 0) {
      setState(() => _tab = 0);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => i == 1
            ? AttendanceScreen(child: widget.child)
            : AttitudeScreen(child: widget.child),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * The marks, gathered
 * ------------------------------------------------------------------------- */

class _Report {
  _Report({required this.exams, required this.homework});

  final List<ExamResultItem> exams;
  final List<HomeworkItem> homework;

  /// Every mark that carries a percentage, by subject.
  Map<String, List<double>> get bySubject {
    final out = <String, List<double>>{};
    for (final e in exams) {
      if (e.wasAbsent || e.percent == null) continue;
      (out[e.subject] ??= []).add(e.percent!.toDouble());
    }
    for (final h in homework) {
      if (h.score == null || (h.maxScore ?? 0) == 0) continue;
      (out[h.subject] ??= []).add(h.score!.toDouble() / h.maxScore!.toDouble() * 100);
    }
    return out;
  }

  Map<String, int> get averages => {
        for (final e in bySubject.entries)
          e.key: (e.value.reduce((a, b) => a + b) / e.value.length).round(),
      };

  int? get overall {
    final all = bySubject.values.expand((v) => v).toList();
    if (all.isEmpty) return null;
    return (all.reduce((a, b) => a + b) / all.length).round();
  }

  MapEntry<String, int>? get best {
    final rows = averages.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return rows.isEmpty ? null : rows.first;
  }

  MapEntry<String, int>? get worst {
    final rows = averages.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return rows.isEmpty ? null : rows.first;
  }

  int get marked => bySubject.values.fold(0, (n, v) => n + v.length);
}

String verdictFor(int percent) {
  if (percent >= 90) return t('rep.excellent');
  if (percent >= 80) return t('rep.veryGood');
  if (percent >= 65) return t('rep.good');
  return t('rep.needsWork');
}

Color colourFor(int percent) {
  if (percent >= 90) return AppTheme.green;
  if (percent >= 80) return AppTheme.blue;
  if (percent >= 65) return AppTheme.amber;
  return AppTheme.rose;
}

/* ---------------------------------------------------------------------------
 * The four figures
 * ------------------------------------------------------------------------- */

class _Overview extends StatelessWidget {
  const _Overview({required this.report});

  final _Report report;

  @override
  Widget build(BuildContext context) {
    final overall = report.overall;
    final best = report.best;
    final worst = report.worst;

    return Card16(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('rep.overview'),
            actionLabel: t('rep.thisTerm'),
            actionIcon: Icons.expand_more_rounded,
          ),
          if (overall == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                t('rep.nothingYet'),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _Box(
                    icon: Icons.trending_up_rounded,
                    label: t('rep.averageMarks'),
                    value: '$overall%',
                    caption: verdictFor(overall),
                    colour: AppTheme.violet,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _Box(
                    icon: Icons.star_outline_rounded,
                    label: t('rep.highestMarks'),
                    value: best == null ? '—' : '${best.value}%',
                    caption: best?.key ?? '—',
                    colour: AppTheme.green,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _Box(
                    icon: Icons.military_tech_outlined,
                    label: t('rep.lowestMarks'),
                    value: worst == null ? '—' : '${worst.value}%',
                    caption: worst?.key ?? '—',
                    colour: AppTheme.amber,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  // The design's fourth is a class ranking. The platform does
                  // not rank children against each other and should not start
                  // here, so this is how much the average is drawn FROM —
                  // which is the figure that tells a parent whether to trust
                  // the other three.
                  child: _Box(
                    icon: Icons.checklist_rounded,
                    label: t('rep.marked'),
                    value: '${report.marked}',
                    caption: t('rep.piecesOfWork'),
                    colour: AppTheme.blue,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.colour,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    Widget line(String text, TextStyle style) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, maxLines: 1, style: style),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: AppTheme.dark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: colour),
          ),
          const SizedBox(height: 8),
          line(label, TextStyle(fontSize: 9, color: AppTheme.textMuted, height: 1.3)),
          const SizedBox(height: 2),
          line(
            value,
            TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.1,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 2),
          line(
            caption,
            TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Subject by subject
 * ------------------------------------------------------------------------- */

class _Subjects extends StatelessWidget {
  const _Subjects({required this.report, required this.child});

  final _Report report;
  final Child child;

  @override
  Widget build(BuildContext context) {
    final rows = report.averages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('rep.subjectPerformance'),
            actionLabel: rows.isEmpty ? null : t('rep.detailed'),
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MarksScreen(child: child)),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                t('rep.nothingYet'),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
            )
          else
            for (final r in rows)
              _SubjectRow(
                subject: r.key,
                percent: r.value,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MarksScreen(child: child)),
                ),
              ),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.percent,
    required this.onTap,
  });

  final String subject;
  final int percent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = colourFor(percent);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(subjectIcon(subject), size: 20, color: colour),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 66,
              child: Text(
                subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  height: 1.2,
                  color: AppTheme.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (percent / 100).clamp(0, 1),
                  minHeight: 7,
                  backgroundColor: AppTheme.border,
                  valueColor: AlwaysStoppedAnimation(colour),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: Text(
                '$percent%',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: colour,
                ),
              ),
            ),
            const SizedBox(width: 7),
            // The word, not just the number. "82%" is a fact; "Very good" is
            // the thing a parent repeats at the dinner table.
            StatusChip(verdictFor(percent), color: colour),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * What the marks came from
 * ------------------------------------------------------------------------- */

class _Recent extends StatelessWidget {
  const _Recent({required this.report, required this.child});

  final _Report report;
  final Child child;

  @override
  Widget build(BuildContext context) {
    final rows = [...report.exams]..sort((a, b) => b.date.compareTo(a.date));

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('rep.recent'),
            actionLabel: rows.isEmpty ? null : t('home.viewAll'),
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MarksScreen(child: child)),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                t('rep.nothingYet'),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
            )
          else
            for (var i = 0; i < rows.take(4).length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppTheme.border),
              _ResultRow(item: rows[i], child: child),
            ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.item, required this.child});

  final ExamResultItem item;
  final Child child;

  @override
  Widget build(BuildContext context) {
    final percent = item.percent?.round();
    final colour = item.wasAbsent
        ? AppTheme.textMuted
        : percent == null
            ? AppTheme.textFaint
            : colourFor(percent);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MarksScreen(child: child)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.description_outlined, size: 20, color: colour),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.examTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 11, color: AppTheme.textFaint),
                      const SizedBox(width: 5),
                      Text(
                        longDate(item.date),
                        style: TextStyle(fontSize: 10, color: AppTheme.textFaint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(
              item.wasAbsent
                  ? t('marks.absent')
                  : percent == null
                      ? t('rep.awaiting')
                      : '$percent%',
              color: colour,
            ),
          ],
        ),
      ),
    );
  }
}
