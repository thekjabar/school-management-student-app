import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// One piece of homework, in full.
///
/// The list could only ever show a title and a date, so the sentence that says
/// what to actually do — the part a parent needs at seven in the evening — was
/// truncated or missing. Worse, the API has been returning whether the work was
/// handed in, the mark and the teacher's comment all along, and none of it was
/// shown anywhere: a parent could see that homework existed and never learn
/// what became of it.
///
/// The design draws two buttons at the foot of this screen — "View attachment"
/// and "Mark as done" — and neither is built. The parent homework route is a
/// GET whose response carries no attachment field, so the first would open
/// nothing; there is no parent write endpoint at all, so the second would be a
/// button that silently does nothing, which is worse than no button. What sits
/// there instead is the submission state, which is data that genuinely exists.
class HomeworkDetail extends StatelessWidget {
  const HomeworkDetail({super.key, required this.item, required this.childName});

  final HomeworkItem item;
  final String childName;

  @override
  Widget build(BuildContext context) {
    final tint = parseHex(item.colorHex, Role.parent.tint);
    final description = item.description?.trim() ?? '';

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('hw.details')),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Role.parent.wash, AppTheme.canvas],
                    stops: const [0, 0.22],
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 28),
                  children: [
                    _Hero(item: item, tint: tint),

                    // Only when the teacher wrote something. An empty "What to
                    // do" card under every piece of homework teaches a parent
                    // that the section is never worth reading.
                    if (description.isNotEmpty) ...[
                      _BlockHeading(
                        icon: Icons.edit_note_rounded,
                        title: t('hw.whatToDo'),
                        color: tint,
                      ),
                      _Description(text: description, tint: tint),
                    ],

                    _BlockHeading(
                      icon: Icons.list_alt_rounded,
                      title: t('hw.detailsSection'),
                      color: AppTheme.textMuted,
                    ),
                    _Facts(item: item, tint: tint),

                    _Submission(item: item),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * The hero
 * ------------------------------------------------------------------------- */

/// The title, the subject, and the two facts a parent came for.
///
/// Tinted in the subject's own colour, so a screen opened from a list of eight
/// assignments is recognisably the maths one before a word is read.
class _Hero extends StatelessWidget {
  const _Hero({required this.item, required this.tint});

  final HomeworkItem item;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final days = item.daysLeft;
    final past = days < 0;

    // Rose is for a deadline that has been missed — not for one that passed
    // after the work went in. A family whose child handed the work in should
    // not be shown a red panel about it.
    final missed = past && !item.handedIn;

    return Card16(
      color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.09),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip36(
                icon: Icons.assignment_rounded,
                color: Colors.white,
                background: tint,
                size: 62,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: StatusChip(item.subject.toUpperCase(), color: tint),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.25,
                        color: AppTheme.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // The deadline said as a state, not only as a date. "Two days
          // overdue" is the thing a parent acts on; "12 September" is the thing
          // they would have to work it out from.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _Half(
                      icon: past ? Icons.event_busy_rounded : Icons.event_rounded,
                      colour: missed ? AppTheme.rose : tint,
                      // Value first, label under: the state is what is read at
                      // a glance and the date is what confirms it.
                      strong: _dueHeadline(days, item.handedIn),
                      strongColour: missed ? AppTheme.rose : AppTheme.text,
                      muted: longDate(item.dueDate),
                      mutedFirst: false,
                    ),
                  ),
                  // Dropped whole when the teacher gave no estimate, rather
                  // than left as a column with a dash in it.
                  if (item.estimatedMinutes != null) ...[
                    const SizedBox(width: 10),
                    Container(width: 1, color: AppTheme.border),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Half(
                        icon: Icons.schedule_rounded,
                        colour: AppTheme.amber,
                        strong: tn('hw.about', item.estimatedMinutes!),
                        strongColour: AppTheme.text,
                        muted: t('hw.effort'),
                        mutedFirst: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One side of the hero's sub-card: a chip, a bold line and a muted one.
class _Half extends StatelessWidget {
  const _Half({
    required this.icon,
    required this.colour,
    required this.strong,
    required this.strongColour,
    required this.muted,
    required this.mutedFirst,
  });

  final IconData icon;
  final Color colour;
  final String strong;
  final Color strongColour;
  final String muted;

  /// The label above the value, or the value above the label.
  final bool mutedFirst;

  @override
  Widget build(BuildContext context) {
    final strongLine = Text(
      strong,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        height: 1.25,
        color: strongColour,
      ),
    );
    final mutedLine = Text(
      muted,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
      style: TextStyle(fontSize: 11, height: 1.3, color: AppTheme.textMuted),
    );

    return Row(
      children: [
        Chip36(icon: icon, color: colour, size: 34),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: mutedFirst
                ? [mutedLine, const SizedBox(height: 2), strongLine]
                : [strongLine, const SizedBox(height: 2), mutedLine],
          ),
        ),
      ],
    );
  }
}

/// "Due in 4 days", "Due today", "3 days overdue" — never "in -3 days".
String _dueHeadline(int days, bool handedIn) {
  if (days < 0) {
    // Handed in after the fact is not a red flag, it is history. The date under
    // this line says when the deadline was.
    if (handedIn) return t('hw.wasDue');
    return days < -1 ? tn('due.overdue', -days) : t('hw.overdue');
  }
  if (days == 0) return t('hw.dueToday');
  if (days == 1) return t('hw.dueTomorrow');
  return tn('hw.dueIn', days);
}

/* ---------------------------------------------------------------------------
 * The sections
 * ------------------------------------------------------------------------- */

/// A small glyph and a heading, above a card.
class _BlockHeading extends StatelessWidget {
  const _BlockHeading({required this.icon, required this.title, required this.color});

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 20, 2, 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the teacher actually asked for, with the subject's colour down the
/// leading edge so the paragraph is anchored to the work rather than floating.
class _Description extends StatelessWidget {
  const _Description({required this.text, required this.tint});

  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: tint),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 15, 16, 15),
                  child: Text(
                    text,
                    textAlign: TextAlign.start,
                    style: TextStyle(fontSize: 15, height: 1.65, color: AppTheme.text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subject, teacher, dates — the facts, each dropped when the API did not send
/// one rather than shown as a dash.
class _Facts extends StatelessWidget {
  const _Facts({required this.item, required this.tint});

  final HomeworkItem item;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    // Only what the hero has NOT already said. The subject is the chip at the
    // top of it, the estimated effort is the right half of its panel, and the
    // total is the denominator of the mark below — repeating all three here
    // made three of five rows an echo.
    final rows = <Widget>[
      if ((item.teacher ?? '').trim().isNotEmpty)
        _Fact(
          icon: Icons.person_rounded,
          colour: AppTheme.blue,
          label: t('hw.teacher'),
          value: item.teacher!.trim(),
        ),
      _Fact(
        icon: Icons.event_available_rounded,
        colour: AppTheme.violet,
        label: t('hw.assignedOn'),
        value: longDate(item.assignedOn),
      ),
      // What it is worth, but only while there is no mark yet — once a mark
      // exists it is shown as "18 / 20" and the total is already in it.
      if (item.maxScore != null && item.score == null)
        _Fact(
          icon: Icons.star_rounded,
          colour: AppTheme.green,
          label: t('hw.outOf'),
          value: _plain(item.maxScore!),
        ),
    ];

    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) Divider(height: 1, color: AppTheme.border),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.colour,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color colour;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Chip36(icon: icon, color: colour, size: 32),
          const SizedBox(width: 11),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * What became of it
 * ------------------------------------------------------------------------- */

/// The submission, the mark and the teacher's words.
///
/// This is what stands where the design draws its two buttons. A parent cannot
/// hand work in through this app, and cannot open an attachment the API does
/// not send — but they can be told, plainly, whether the school has the work
/// and what it was given.
class _Submission extends StatelessWidget {
  const _Submission({required this.item});

  final HomeworkItem item;

  @override
  Widget build(BuildContext context) {
    final feedback = item.feedback?.trim() ?? '';
    final scored = item.score != null && item.maxScore != null;

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 20),
      child: Card16(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.handedIn)
              Row(
                children: [
                  Chip36(
                    icon: Icons.check_circle_rounded,
                    color: AppTheme.green,
                    size: 38,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      tn('hw.handedInOn', longDate(item.submittedAt)),
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppTheme.green,
                      ),
                    ),
                  ),
                ],
              )
            else
              // Not "your child has not done it" — the app does not know that.
              // All it knows is that the school has recorded nothing yet, and
              // claiming more than that from a GET is a guess a parent would
              // act on.
              Row(
                children: [
                  Icon(Icons.schedule_outlined, size: 18, color: AppTheme.textFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('hw.notRecorded'),
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            // The mark, whenever both halves of it exist — and deliberately NOT
            // nested inside the handed-in branch.
            //
            // The grading endpoint writes score and feedback and never touches
            // submittedAt; submission rows are pre-seeded for a whole class
            // with it null. So work marked from paper leaves a child with a
            // score and no recorded hand-in, and hiding the mark there had the
            // screen assert that the school had recorded nothing while holding
            // the teacher's comment on that very work.
            if (scored) ...[
              const SizedBox(height: 13),
              Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip36(icon: Icons.star_rounded, color: AppTheme.green, size: 34),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      t('hw.mark'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    // "18" on its own is not a mark, it is a number.
                    '${_plain(item.score!)} / ${_plain(item.maxScore!)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppTheme.text,
                    ),
                  ),
                ],
              ),
            ],

            if (feedback.isNotEmpty) ...[
              const SizedBox(height: 13),
              Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: 12),
              Text(
                t('hw.feedback'),
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                feedback,
                textAlign: TextAlign.start,
                style: TextStyle(fontSize: 13.5, height: 1.55, color: AppTheme.text),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A mark without the decimal point the JSON put on it: 18, not 18.0.
String _plain(num value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toString();
