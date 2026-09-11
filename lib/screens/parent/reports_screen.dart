import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';
import 'attendance_screen.dart';
import 'attitude_screen.dart';
import 'marks_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.child});

  final Child child;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _loader = GlobalKey<LoaderState<_Report>>();

  int _tab = 0;

  String? _termId;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('quick.reports')),
            Expanded(
              child: Loader<_Report>(
                key: _loader,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                load: () async {
                  final api = ParentApi.instance;
                  final id = widget.child.studentId;
                  final cards = _slot(api.reportCards(id));
                  final terms = _slot(api.termGrades(id));
                  final exams = _slot(api.results(id));
                  final report = _Report(
                    cards: await cards,
                    terms: await terms,
                    exams: await exams,
                  );
                  final dead = report.totalFailure;
                  if (dead != null) throw dead;
                  return report;
                },
                builder: (context, report) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          if (report.unopened != null) ...[
                            _NewCard(report: report, onOpen: _open),
                            const SizedBox(height: kCardGap),
                          ],
                          _TermGrades(
                            groups: report.terms,
                            failed: report.termsError != null,
                            onRetry: _retry,
                            termId: _termId,
                            onTerm: (id) => setState(() => _termId = id),
                          ),
                          const SizedBox(height: kCardGap),
                          _Cards(report: report, onOpen: _open, onRetry: _retry),
                          const SizedBox(height: kCardGap),
                          _Recent(report: report, child: widget.child, onRetry: _retry),
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

  void _retry() => _loader.currentState?.reload();

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

  Future<void> _open(ReportCardSummary card) async {
    final gone = await showAppSheet<bool>(
      context,
      builder: (_) => _CardSheet(child: widget.child, card: card),
    );
    if (!mounted) return;
    if (gone == true) showNote(context, t('rep.cardGone'), bad: true);
    _loader.currentState?.reload(quiet: true);
  }
}

class _Slot<T> {
  _Slot.ok(this.value) : error = null;
  _Slot.failed(this.error) : value = null;

  final T? value;
  final Object? error;
}

Future<_Slot<T>> _slot<T>(Future<T> call) async {
  try {
    return _Slot<T>.ok(await call);
  } catch (e) {
    return _Slot<T>.failed(e);
  }
}

class _Report {
  _Report({
    required _Slot<List<ReportCardSummary>> cards,
    required _Slot<List<TermGradeGroup>> terms,
    required _Slot<List<ExamResultItem>> exams,
  })  : cards = cards.value ?? const [],
        terms = terms.value ?? const [],
        exams = exams.value ?? const [],
        cardsError = cards.error,
        termsError = terms.error,
        examsError = exams.error;

  final List<ReportCardSummary> cards;
  final List<TermGradeGroup> terms;
  final List<ExamResultItem> exams;

  final Object? cardsError;
  final Object? termsError;
  final Object? examsError;

  Object? get totalFailure =>
      cardsError != null && termsError != null && examsError != null ? cardsError : null;

  ReportCardSummary? get unopened {
    final waiting = cards.where((c) => c.openedAt == null).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return waiting.isEmpty ? null : waiting.first;
  }

  int get unopenedCount => cards.where((c) => c.openedAt == null).length;

  bool get groupsByYear {
    final years = cards.map((c) => c.academicYearName).toSet();
    return years.length > 1 && !years.contains('');
  }

  List<List<ReportCardSummary>> get cardRuns {
    if (!groupsByYear) return cards.isEmpty ? const [] : [cards];
    final runs = <String, List<ReportCardSummary>>{};
    for (final card in cards) {
      (runs[card.academicYearName] ??= <ReportCardSummary>[]).add(card);
    }
    return runs.values.toList();
  }

  bool showsVersion(ReportCardSummary card) {
    final siblings = cards.where(
      (c) => c.termId == card.termId && c.academicYearName == card.academicYearName,
    );
    return siblings.length > 1;
  }
}

Color colourFor(int percent) {
  if (percent >= 90) return AppTheme.green;
  if (percent >= 80) return AppTheme.blue;
  if (percent >= 65) return AppTheme.amber;
  return AppTheme.rose;
}

String _mark(num? value) {
  if (value == null) return '—';
  final d = value.toDouble();
  return d == d.roundToDouble() ? d.round().toString() : '$d';
}

class _NewCard extends StatelessWidget {
  const _NewCard({required this.report, required this.onOpen});

  final _Report report;
  final void Function(ReportCardSummary card) onOpen;

  @override
  Widget build(BuildContext context) {
    final card = report.unopened!;
    final waiting = report.unopenedCount;
    final title = card.wholeYear ? t('rep.wholeYear') : (card.termName ?? t('rep.reportCard'));
    final slots = {'title': title, 'date': shortDate(card.publishedAt), 'n': waiting};

    return NoticeBanner(
      icon: Icons.mark_email_unread_outlined,
      color: AppTheme.amber,
      title: t('rep.newCard'),
      body: waiting > 1 ? tv('rep.newCardsWaiting', slots) : tv('rep.newCardBody', slots),
      action: t('rep.openIt'),
      onAction: () => onOpen(card),
    );
  }
}

class _SectionFailed extends StatelessWidget {
  const _SectionFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 15, color: AppTheme.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t('rep.partDidNotLoad'),
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Text(
              t('common.tryAgain'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Role.parent.tint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermGrades extends StatelessWidget {
  const _TermGrades({
    required this.groups,
    required this.failed,
    required this.onRetry,
    required this.termId,
    required this.onTerm,
  });

  final List<TermGradeGroup> groups;

  final bool failed;
  final VoidCallback onRetry;
  final String? termId;
  final ValueChanged<String> onTerm;

  @override
  Widget build(BuildContext context) {
    final group = groups.isEmpty
        ? null
        : groups.firstWhere((g) => g.termId == termId, orElse: () => groups.first);

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('rep.termGrades')),
          if (failed)
            _SectionFailed(onRetry: onRetry)
          else if (group == null)
            Text(
              t('rep.nothingToShow'),
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            )
          else ...[
            if (groups.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final g in groups)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 7),
                        child: _TermChip(
                          label: g.termName,
                          selected: g.termId == group.termId,
                          onTap: () => onTerm(g.termId),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Text(
              [group.className, group.academicYearName]
                  .where((s) => s.isNotEmpty)
                  .join('  •  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${shortDate(group.startsOn)} – ${shortDate(group.endsOn)}',
              style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
            ),
            const SizedBox(height: 12),

            FigureStrip(
              figures: [
                Figure(
                  label: t('rep.averageMarks'),
                  value: group.averagePercent == null
                      ? '—'
                      : '${_mark(group.averagePercent)}%',
                  caption: tn('rep.subjectsReleased', group.subjectCount),
                ),
                if (group.subjectsPassed + group.subjectsFailed > 0) ...[
                  Figure(
                    label: t('rep.passed'),
                    value: '${group.subjectsPassed}',
                    captionColor: AppTheme.green,
                  ),
                  Figure(
                    label: t('rep.failed'),
                    value: '${group.subjectsFailed}',
                    captionColor: AppTheme.rose,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 12),

            for (final s in group.subjects)
              _GradeRow(
                subject: s.subject,
                colorHex: s.colorHex,
                score: s.score,
                maxScore: s.maxScore,
                percent: s.percent,
                gradeLetter: s.gradeLetter,
                gradePoint: s.gradePoint,
                isPass: s.isPass,
                classRank: s.classRank,
                teacherComment: s.teacherComment,
              ),
          ],
        ],
      ),
    );
  }
}

class _TermChip extends StatelessWidget {
  const _TermChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? tint.withValues(alpha: AppTheme.dark ? 0.22 : 0.11)
              : AppTheme.canvas,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? tint : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? tint : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({
    required this.subject,
    required this.colorHex,
    required this.score,
    required this.maxScore,
    required this.percent,
    required this.gradeLetter,
    required this.gradePoint,
    required this.isPass,
    required this.classRank,
    required this.teacherComment,
  });

  final String subject;
  final String? colorHex;
  final num? score;
  final num maxScore;
  final num? percent;
  final String? gradeLetter;
  final num? gradePoint;
  final bool? isPass;
  final int? classRank;
  final String? teacherComment;

  @override
  Widget build(BuildContext context) {
    final marked = score != null;
    final colour = percent == null ? AppTheme.textMuted : colourFor(percent!.round());
    final comment = teacherComment?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(
            icon: subjectIcon(subject),
            color: parseHex(colorHex, colour),
            background: parseHex(colorHex, colour)
                .withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      marked
                          ? tv('rep.outOf', {
                              'score': _mark(score),
                              'max': _mark(maxScore),
                            })
                          : t('rep.noMark'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: marked ? AppTheme.text : AppTheme.textFaint,
                      ),
                    ),
                  ],
                ),
                if (percent != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (percent!.toDouble() / 100).clamp(0, 1),
                            minHeight: 7,
                            backgroundColor: AppTheme.border,
                            valueColor: AlwaysStoppedAnimation(colour),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_mark(percent)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colour,
                        ),
                      ),
                    ],
                  ),
                ],
                if (gradeLetter != null ||
                    isPass != null ||
                    classRank != null ||
                    gradePoint != null) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (gradeLetter != null && gradeLetter!.isNotEmpty)
                        Tag(
                          gradeLetter!,
                          color: colour,
                          background: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
                        ),
                      if (isPass == true)
                        Tag(
                          t('rep.passed'),
                          color: AppTheme.green,
                          background: AppTheme.greenSoft,
                        ),
                      if (isPass == false)
                        Tag(
                          t('rep.failed'),
                          color: AppTheme.rose,
                          background: AppTheme.roseSoft,
                        ),
                      if (classRank != null)
                        Tag(
                          tn('rep.rankN', classRank!),
                          color: AppTheme.textMuted,
                          background: AppTheme.neutralSoft,
                        ),
                      if (gradePoint != null)
                        Tag(
                          '${t('rep.gradePointShort')} ${_mark(gradePoint)}',
                          color: AppTheme.textMuted,
                          background: AppTheme.neutralSoft,
                        ),
                    ],
                  ),
                ],
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    comment,
                    style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
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

class _Cards extends StatelessWidget {
  const _Cards({required this.report, required this.onOpen, required this.onRetry});

  final _Report report;
  final void Function(ReportCardSummary card) onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final runs = report.cardRuns;
    final byYear = report.groupsByYear;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('rep.reportCards')),
          if (report.cardsError != null)
            _SectionFailed(onRetry: onRetry)
          else if (runs.isEmpty)
            Text(
              t('rep.nothingToShow'),
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            )
          else ...[
            for (var r = 0; r < runs.length; r++) ...[
              if (byYear)
                _YearHeading(name: runs[r].first.academicYearName, first: r == 0),
              for (var i = 0; i < runs[r].length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppTheme.border),
                _CardRow(
                  card: runs[r][i],
                  showVersion: report.showsVersion(runs[r][i]),
                  showYear: !byYear,
                  onTap: () => onOpen(runs[r][i]),
                ),
              ],
            ],
            const SizedBox(height: 4),
            Text(
              t('rep.openRecorded'),
              style: TextStyle(fontSize: 11, height: 1.4, color: AppTheme.textFaint),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.showVersion,
    required this.showYear,
    required this.onTap,
  });

  final ReportCardSummary card;
  final bool showVersion;

  final bool showYear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final line = [if (showYear) card.academicYearName, card.className ?? '']
        .where((s) => s.isNotEmpty)
        .join('  •  ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            IconChip(
              icon: Icons.article_outlined,
              color: tint,
              background: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
              size: 42,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          card.wholeYear ? t('rep.wholeYear') : (card.termName ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                      if (showVersion) ...[
                        const SizedBox(width: 7),
                        Pill(tn('rep.version', card.version), color: AppTheme.textMuted),
                      ],
                    ],
                  ),
                  if (line.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 11, color: AppTheme.textFaint),
                          const SizedBox(width: 5),
                          Text(
                            tv('rep.publishedOn', {'date': shortDate(card.publishedAt)}),
                            style: TextStyle(fontSize: 10, color: AppTheme.textFaint),
                          ),
                        ],
                      ),
                      if (card.overallGrade != null && card.overallGrade!.isNotEmpty)
                        StatusChip(card.overallGrade!, color: tint),
                      if (card.subjectCount > 0)
                        StatusChip(
                          tn('rep.subjectsOnCard', card.subjectCount),
                          color: AppTheme.textMuted,
                        ),
                      if (card.promoted == true)
                        StatusChip(t('rep.promoted'), color: AppTheme.green),
                      if (card.promoted == false)
                        StatusChip(t('rep.notPromoted'), color: AppTheme.rose),
                      StatusChip(
                        card.openedAt == null
                            ? t('rep.notOpenedYet')
                            : tv('rep.openedOn', {'date': shortDate(card.openedAt)}),
                        color: card.openedAt == null ? AppTheme.amber : AppTheme.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

class _YearHeading extends StatelessWidget {
  const _YearHeading({required this.name, required this.first});

  final String name;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 2 : 12, bottom: 2),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: AppTheme.textFaint,
        ),
      ),
    );
  }
}

class _CardSheet extends StatefulWidget {
  const _CardSheet({required this.child, required this.card});

  final Child child;
  final ReportCardSummary card;

  @override
  State<_CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<_CardSheet> {
  ReportCardDetail? _detail;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail = await ParentApi.instance.reportCard(
        widget.child.studentId,
        widget.card.id,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.status == 404) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _error = errorText(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final detail = _detail;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              t('rep.reportCard'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppTheme.textFaint,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.card.wholeYear
                        ? t('rep.wholeYear')
                        : (widget.card.termName ?? ''),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                Pill(tn('rep.version', widget.card.version), color: AppTheme.textMuted),
              ],
            ),

            if (_busy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: tint)),
              )
            else if (_error != null)
              _SheetError(message: _error!, tint: tint, onRetry: _load)
            else if (detail != null)
              _CardBody(detail: detail, preparedCopy: widget.card.hasPdf),
          ],
        ),
      ),
    );
  }
}

class _SheetError extends StatelessWidget {
  const _SheetError({required this.message, required this.tint, required this.onRetry});

  final String message;
  final Color tint;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.wifi_off_rounded,
                color: AppTheme.rose,
                background: AppTheme.roseSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t('common.didNotLoad'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(color: AppTheme.textMuted, height: 1.45, fontSize: 13),
          ),
          const SizedBox(height: 14),
          BigButton(label: t('common.tryAgain'), color: tint, height: 48, onPressed: onRetry),
        ],
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.detail, required this.preparedCopy});

  final ReportCardDetail detail;

  final bool preparedCopy;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final line = [d.academicYearName, d.className ?? '']
        .where((s) => s.isNotEmpty)
        .join('  •  ');

    final figures = <Figure>[
      if (d.overallScore != null)
        Figure(label: t('rep.overallScore'), value: _mark(d.overallScore)),
      if (d.overallGrade != null && d.overallGrade!.isNotEmpty)
        Figure(label: t('rep.overallGrade'), value: d.overallGrade!),
      if (d.gpa != null) Figure(label: t('rep.gpa'), value: _mark(d.gpa)),
    ];

    final days = <Widget>[
      if (d.daysPresent != null)
        _Box(
          icon: Icons.check_circle_outline,
          label: t('rep.daysPresent'),
          value: '${d.daysPresent}',
          colour: AppTheme.green,
        ),
      if (d.daysAbsent != null)
        _Box(
          icon: Icons.cancel_outlined,
          label: t('rep.daysAbsent'),
          value: '${d.daysAbsent}',
          colour: AppTheme.rose,
        ),
      if (d.daysLate != null)
        _Box(
          icon: Icons.schedule_rounded,
          label: t('rep.daysLate'),
          value: '${d.daysLate}',
          colour: AppTheme.amber,
        ),
      if (d.daysExcused != null)
        _Box(
          icon: Icons.event_available_outlined,
          label: t('rep.daysExcused'),
          value: '${d.daysExcused}',
          colour: AppTheme.blue,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (line.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(line, style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            StatusChip(
              tv('rep.publishedOn', {'date': longDate(d.publishedAt)}),
              color: AppTheme.textMuted,
            ),
            StatusChip(
              tv('rep.firstOpened', {'date': longDate(d.openedAt)}),
              color: AppTheme.green,
            ),
            if (d.classRank != null)
              StatusChip(
                d.classSize == null
                    ? tn('rep.rankN', d.classRank!)
                    : tv('rep.rankOf', {'rank': d.classRank!, 'size': d.classSize!}),
                color: Role.parent.tint,
              ),
            if (d.promoted == true)
              StatusChip(t('rep.promoted'), color: AppTheme.green),
            if (d.promoted == false)
              StatusChip(t('rep.notPromoted'), color: AppTheme.rose),
          ],
        ),

        if (figures.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card16(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionRow(title: t('rep.overview'), dense: true),
                FigureStrip(figures: figures),
              ],
            ),
          ),
        ],

        if (days.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card16(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionRow(title: t('rep.attendanceOnCard'), dense: true),
                Row(
                  children: [
                    for (var i = 0; i < days.length; i++) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Expanded(child: days[i]),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],

        if ((d.homeroomComment ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _Comment(title: t('rep.homeroomComment'), body: d.homeroomComment!.trim()),
        ],
        if ((d.principalComment ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _Comment(title: t('rep.principalComment'), body: d.principalComment!.trim()),
        ],

        const SizedBox(height: 12),
        Card16(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionRow(title: t('rep.subjects'), dense: true),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  tn('rep.subjectsOnCard', d.lines.length),
                  style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                ),
              ),
              if (d.lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    t('rep.nothingToShow'),
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  ),
                )
              else
                for (final l in d.lines)
                  _GradeRow(
                    subject: l.subject,
                    colorHex: l.colorHex,
                    score: l.score,
                    maxScore: l.maxScore,
                    percent: l.percent,
                    gradeLetter: l.gradeLetter,
                    gradePoint: l.gradePoint,
                    isPass: l.isPass,
                    classRank: l.classRank,
                    teacherComment: l.teacherComment,
                  ),
            ],
          ),
        ),

        if (preparedCopy) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.description_outlined, size: 14, color: AppTheme.textFaint),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  t('rep.preparedCopy'),
                  style: TextStyle(fontSize: 11, height: 1.45, color: AppTheme.textFaint),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Comment extends StatelessWidget {
  const _Comment({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.text),
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
    required this.colour,
  });

  final IconData icon;
  final String label;
  final String value;
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
          line(label, TextStyle(fontSize: 9, color: AppTheme.textMuted, height: 1.3)),
        ],
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.report, required this.child, required this.onRetry});

  final _Report report;
  final Child child;
  final VoidCallback onRetry;

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
          if (report.examsError != null)
            _SectionFailed(onRetry: onRetry)
          else if (rows.isEmpty)
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
