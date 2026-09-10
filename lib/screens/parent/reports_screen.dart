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

/// What the school itself has said about this child's year.
///
/// Every figure on this screen was typed by the school: the term grades it
/// released, and the report cards it published with the marks frozen onto them.
/// This screen used to average the exam results and the homework itself and
/// print the answer as "Average marks" — a number no teacher gave, that no
/// office would stand behind, and that a parent would quote back at a meeting.
/// The term grade is the row the school defends after a re-mark, so it is the
/// row that is shown.
///
/// Only PUBLISHED work arrives here. A report the office is holding back and a
/// report that was never generated look identical — both are simply absent —
/// and that is the server's deliberate choice, because a school here withholds
/// a report over unpaid fees and will not have that conversation through a
/// phone screen at nine in the evening. So nothing on this screen may say the
/// school has produced nothing. It says only that there is nothing to show.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.child});

  final Child child;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _loader = GlobalKey<LoaderState<_Report>>();

  int _tab = 0;

  /// Which term's grades are on screen.
  ///
  /// The chips are built out of the terms inside the answer itself. Nothing in
  /// the API lists a family's terms, and asking the server to filter by a term
  /// id it does not know is not an error there — it answers with an empty list,
  /// which would show a parent nothing and explain nothing.
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
                  // Three separate answers, fetched together but allowed to
                  // fail apart. Future.wait fails fast: one endpoint returning
                  // 500 threw away the whole screen, so a report card that had
                  // arrived perfectly well went unread because the term grades
                  // beside it did not load. And an empty section here says
                  // "there is nothing to show" — which, printed over a fetch
                  // that failed, tells a family the school published nothing.
                  final api = ParentApi.instance;
                  final id = widget.child.studentId;
                  // All three are in flight before the first await, so this is
                  // still one round trip's worth of waiting. Awaited one at a
                  // time only because a wrapped call cannot throw, which keeps
                  // the types exact and spares the screen a cast.
                  final cards = _slot(api.reportCards(id));
                  final terms = _slot(api.termGrades(id));
                  final exams = _slot(api.results(id));
                  final report = _Report(
                    cards: await cards,
                    terms: await terms,
                    exams: await exams,
                  );
                  // Nothing at all arrived — no connection, or the session is
                  // gone. That is the Loader's own error page with its retry,
                  // not three little retry lines on an otherwise blank screen.
                  final dead = report.totalFailure;
                  if (dead != null) throw dead;
                  return report;
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
                          // Above everything, because a report card nobody has
                          // opened is the one thing on this screen that is
                          // waiting on the family rather than on the school.
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

  /// One section failed while the others arrived. Refetching all three is
  /// right: they are one request in practice, and a parent pressing "try
  /// again" on the report cards would not expect the term grades beside them
  /// to stay a minute out of date.
  void _retry() => _loader.currentState?.reload();

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

  /// Opening a card is the only thing that tells the office it reached the
  /// family: the server stamps the moment as a side effect of fetching the
  /// detail — once, and never again — and there is no acknowledgement to send
  /// afterwards. So the fetch happens here, on a tap, and nowhere else. Filling
  /// the list from the detail route, or fetching a card ahead of time, would
  /// sign for a report nobody had read.
  Future<void> _open(ReportCardSummary card) async {
    final gone = await showAppSheet<bool>(
      context,
      builder: (_) => _CardSheet(child: widget.child, card: card),
    );
    if (!mounted) return;
    if (gone == true) showNote(context, t('rep.cardGone'), bad: true);
    // Quietly. The list on screen is right apart from one date — the card just
    // opened now carries an opened-on stamp it did not have a minute ago — and
    // a full reload would drop the whole screen back to its skeleton for that.
    _loader.currentState?.reload(quiet: true);
  }
}

/* ---------------------------------------------------------------------------
 * What the school published
 * ------------------------------------------------------------------------- */

/// One of the three fetches: what came back, or why it did not.
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

  /// Non-null when that one fetch failed, and kept apart from an empty list on
  /// purpose. "The school has published nothing" and "this did not load" are
  /// different sentences, and printing the first when the second is true tells
  /// a family the school produced no report for their child when it may well
  /// have published one an hour ago.
  final Object? cardsError;
  final Object? termsError;
  final Object? examsError;

  /// All three failed: no connection, or the session has gone.
  Object? get totalFailure =>
      cardsError != null && termsError != null && examsError != null ? cardsError : null;

  /// The newest published card this family has never opened.
  ///
  /// Only published cards reach the app at all — the server filters on the
  /// state and a withheld card is simply absent — so an unopened one here is
  /// always a document the school meant them to have. `openedAt` is null until
  /// the family first opens it, and it is the very flag the office checks
  /// before telephoning a family who says the report never arrived: worth one
  /// line at the top of the screen rather than a row they have to scroll to.
  ReportCardSummary? get unopened {
    final waiting = cards.where((c) => c.openedAt == null).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return waiting.isEmpty ? null : waiting.first;
  }

  int get unopenedCount => cards.where((c) => c.openedAt == null).length;

  /// Whether the list is long enough, and mixed enough, to need year headings.
  /// A family with one year of cards gets no headings; a family holding four
  /// years of them gets one per year, and the rows stop repeating the year.
  bool get groupsByYear {
    final years = cards.map((c) => c.academicYearName).toSet();
    return years.length > 1 && !years.contains('');
  }

  /// The cards as the list draws them: one run per academic year, each run
  /// headed exactly once.
  ///
  /// The server orders by publishedAt and then version — NOT by year — so the
  /// years arrive interleaved. A correction is published as a new card long
  /// after the year it corrects has ended, so it sorts above the cards of the
  /// year that followed it: 2024-2025, then 2023-2024, then 2024-2025 again.
  /// A heading emitted wherever the year changed printed that year twice and
  /// left rows standing under a heading that did not describe them.
  ///
  /// Grouping here, instead of trusting the order the wire happened to bring,
  /// keeps every card of a year together. The runs stay in the order the
  /// newest-first list first reaches each year — which is the year holding the
  /// most recently published card, first — and inside a run the server's own
  /// order is untouched, so the newest document is still the one on top. The
  /// year names are whatever the registrar typed and are not compared as dates
  /// or sorted: nothing here knows that '2024-2025' follows '2023-2024'.
  ///
  /// This only RE-ARRANGES the rows the server sent. No card is added, kept
  /// from an earlier answer or invented, so a card the school withheld — which
  /// the server never sends at all — still cannot appear.
  ///
  /// One run holding everything when there are no headings to draw, so the
  /// list has a single shape to render either way.
  List<List<ReportCardSummary>> get cardRuns {
    if (!groupsByYear) return cards.isEmpty ? const [] : [cards];
    final runs = <String, List<ReportCardSummary>>{};
    for (final card in cards) {
      (runs[card.academicYearName] ??= <ReportCardSummary>[]).add(card);
    }
    return runs.values.toList();
  }

  /// A correction is published as a NEW card with a higher version, and the old
  /// one can still be live while it happens, so a family may hold two documents
  /// for one term. The version number is what tells them apart; on a term with
  /// only one card it is noise.
  ///
  /// Matched on the year as well as the term, because a whole-year card has no
  /// term at all — two of them from two different years would otherwise look
  /// like two versions of one document.
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

/// A mark as the school wrote it: 82 rather than 82.0, and 82.5 kept whole.
///
/// Callers deal with null themselves before they get here. A subject with no
/// mark and a subject marked zero are different answers — "not marked" and
/// "nothing right" — and printing them the same is the one mistake on this
/// screen a parent could not recover from.
String _mark(num? value) {
  if (value == null) return '—';
  final d = value.toDouble();
  return d == d.roundToDouble() ? d.round().toString() : '$d';
}

/* ---------------------------------------------------------------------------
 * A card the family has not opened yet
 * ------------------------------------------------------------------------- */

/// Said at the top of the screen, because until now a published report card
/// sat in a list below the term grades and a family who did not scroll never
/// learned it existed. The school's side of that is worse: the office cannot
/// tell a report that was ignored from one that was never found.
///
/// It names the newest unopened card and opens THAT card, not the list. The
/// button is the same tap as the row, so the opened-on stamp is written the
/// one way it is ever written.
class _NewCard extends StatelessWidget {
  const _NewCard({required this.report, required this.onOpen});

  final _Report report;
  final void Function(ReportCardSummary card) onOpen;

  @override
  Widget build(BuildContext context) {
    final card = report.unopened!;
    final waiting = report.unopenedCount;
    // The document's own name, in the school's words: a term name it typed, or
    // the whole-year card the server flags rather than leaving to be guessed.
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

/* ---------------------------------------------------------------------------
 * One section that did not load
 * ------------------------------------------------------------------------- */

/// What a section says instead of "there is nothing to show here yet" when its
/// own fetch failed. The distinction is the whole point: a family must never
/// be told the school published nothing because a request timed out.
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

/* ---------------------------------------------------------------------------
 * The grades the school released, by term
 * ------------------------------------------------------------------------- */

class _TermGrades extends StatelessWidget {
  const _TermGrades({
    required this.groups,
    required this.failed,
    required this.onRetry,
    required this.termId,
    required this.onTerm,
  });

  final List<TermGradeGroup> groups;

  /// This one fetch failed while the rest of the screen arrived.
  final bool failed;
  final VoidCallback onRetry;
  final String? termId;
  final ValueChanged<String> onTerm;

  @override
  Widget build(BuildContext context) {
    // Resolved against what actually arrived rather than trusted: a term can
    // stop being published between one load and the next, and a selection
    // pointing at nothing would leave a parent on an empty card with no way
    // back to the terms that are there.
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

            // The school's own words: the class the child sat in, the year the
            // term belongs to, and the days it ran. None of it is translated
            // here — a school types these itself.
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
                  // How much of the term this average is drawn from. Subjects
                  // arrive as the school releases them, so four of nine is an
                  // ordinary answer rather than a half-finished load — and the
                  // five that are missing are not failures and are not counted
                  // as any.
                  caption: tn('rep.subjectsReleased', group.subjectCount),
                ),
                // Only when the school actually marked subjects pass or fail.
                // isPass is a three-state field, and a term where nobody set it
                // would otherwise read "Passed 0" over a page of good marks.
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

/* ---------------------------------------------------------------------------
 * One subject line — on a term, or on a card
 * ------------------------------------------------------------------------- */

/// The same row for both, because they are the same row: a term grade and a
/// line on a report card carry exactly these fields, and drawing them twice
/// would let them drift apart.
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
    // The percentage decides the colour, not the pass flag: a school that never
    // sets isPass still gets a page that reads at a glance.
    final colour = percent == null ? AppTheme.textMuted : colourFor(percent!.round());
    final comment = teacherComment?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(
            icon: subjectIcon(subject),
            // The subject's own colour when the school picked one.
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
                        // Already in the reader's language, and on a card it is
                        // the label frozen on at generation — a subject renamed
                        // in March must not rewrite a document printed in
                        // January.
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
                    // "No mark" rather than a dash or a zero. An unmarked
                    // subject and a subject marked nothing are different facts.
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
                      // The school's own letter, whatever alphabet it is in.
                      if (gradeLetter != null && gradeLetter!.isNotEmpty)
                        Tag(
                          gradeLetter!,
                          color: colour,
                          background: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
                        ),
                      // Three states. A null pass flag means the school did not
                      // say, and printing that as "Failed" would be a lie about
                      // a child.
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

/* ---------------------------------------------------------------------------
 * The report cards themselves
 * ------------------------------------------------------------------------- */

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
              // One heading per year, taken from the run it heads rather than
              // from a comparison with the row above, so it cannot be printed
              // twice for one year or stand over rows from another. Only for a
              // family who holds cards from more than one year. It replaces the
              // divider rather than sitting under it — a rule and a heading
              // together read as two separations of the same list.
              if (byYear)
                _YearHeading(name: runs[r].first.academicYearName, first: r == 0),
              for (var i = 0; i < runs[r].length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppTheme.border),
                _CardRow(
                  card: runs[r][i],
                  showVersion: report.showsVersion(runs[r][i]),
                  // The year is already the heading above it; repeating it on
                  // every row leaves the class name fighting for the same line.
                  showYear: !byYear,
                  onTap: () => onOpen(runs[r][i]),
                ),
              ],
            ],
            const SizedBox(height: 4),
            // Said out loud, because it is true and because a family should not
            // discover it from the office. Opening a card is what records that
            // it arrived; there is nothing else to press.
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

  /// False when a year heading above the row already says it.
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
                          // A card with no term is the whole-year document, and
                          // the server flags it rather than leaving it to be
                          // guessed from the missing term.
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
                      // The school's own word for the result, when it printed
                      // one. Not a percentage worked out from it.
                      if (card.overallGrade != null && card.overallGrade!.isNotEmpty)
                        StatusChip(card.overallGrade!, color: tint),
                      // How much of the year the document covers, so a card
                      // with two subjects on it is not mistaken for the full
                      // report at a glance.
                      if (card.subjectCount > 0)
                        StatusChip(
                          tn('rep.subjectsOnCard', card.subjectCount),
                          color: AppTheme.textMuted,
                        ),
                      // Three states. A card that printed no promotion decision
                      // gets no chip — never "Not promoted".
                      if (card.promoted == true)
                        StatusChip(t('rep.promoted'), color: AppTheme.green),
                      if (card.promoted == false)
                        StatusChip(t('rep.notPromoted'), color: AppTheme.rose),
                      // The receipt, from the family's side: which reports they
                      // have actually looked at.
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

/// The school year a run of cards belongs to, in the school's own words. Never
/// translated: '2024–2025' or whatever the registrar typed is what every other
/// school document calls that year.
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

/* ---------------------------------------------------------------------------
 * One card, opened
 * ------------------------------------------------------------------------- */

/// The document itself, fetched when a parent opens it and at no other moment.
///
/// Popping `true` means the card is gone: the school superseded or withheld it
/// between the list arriving and this tap. The server answers the same way
/// whether the card never existed, belongs to another child or has been pulled,
/// so the screen does not guess which — it says the card is no longer there and
/// refreshes the list.
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

  /// Safe to run again on retry: the server stamps the opened moment only when
  /// it is still empty, so a second read cannot move the date the office quotes
  /// back to a family.
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

            // Titled from the row that was tapped, so the sheet has a heading
            // before the document arrives.
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
                // Always here, unlike the list: on the document itself the
                // version is part of what a parent is holding.
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
              // hasPdf is on the LIST row, not on the document: the detail
              // answers with the address of the rendered file, which nothing
              // in the app may fetch. So the flag travels from the row that
              // was tapped.
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

  /// The school attached a rendered document to this card. It is NOT an
  /// address the app can open — no parent-facing route serves a report-card
  /// file, and the asset must not be publicly fetchable — so this says the
  /// document exists and where to ask for it, and offers no button that would
  /// fail.
  final bool preparedCopy;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final line = [d.academicYearName, d.className ?? '']
        .where((s) => s.isNotEmpty)
        .join('  •  ');

    // Each of these is separately nullable on a real card: a school can print a
    // rank with no class size, or attendance with no GPA. Only what was printed
    // is shown, and "Rank 4 of null" is never one of the answers.
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
            // What the office sees. Never null on the document — reading it is
            // what sets it — so the first time a parent opens a card this is
            // today, and it stays that day for good.
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
            // Three states again: no promotion decision printed means no chip,
            // not "Not promoted".
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

        // Typed by a teacher about this child, in whatever language they typed
        // it. Nothing is done to it.
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
              // Plain text, not the section's action slot: the count is a fact
              // about the document, and putting it where a link goes offers a
              // tap that leads nowhere.
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

/* ---------------------------------------------------------------------------
 * What the marks came from
 * ------------------------------------------------------------------------- */

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
