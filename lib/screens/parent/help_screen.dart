import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/motion.dart';
import '../../ui/screen_kit.dart';
import 'driver_feedback_screen.dart';
import 'leave_screen.dart';

/// What a guardian can find out on their own, and what they cannot.
///
/// There is no support desk behind this app and no telephone number in anything
/// the handset holds — a membership carries a school's name and nothing else to
/// reach it by — so this screen does not pretend to put anybody through to
/// anyone. What it can honestly do is two things: say plainly that the office
/// owns every record shown here and is the only place a wrong one gets fixed,
/// and answer the five questions that otherwise become five telephone calls to
/// that office. The bus dot and the empty register account for most of them.
///
/// The two rows at the foot are the only things a parent can actually SEND from
/// this app, so they are the only actions offered. Both need a child to be
/// about; with none on the account the card is left out rather than shown dead.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, this.child});

  /// Which child the two send-something actions would be about. Null is a real
  /// case — an account whose children have not loaded — and drops the actions.
  final Child? child;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final school = Session.instance.me?.schoolName ?? '';
    final kid = child;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('profile.help')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
                children: [
                  Card16(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Chip36(icon: Icons.apartment_rounded, color: tint),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('help.officeTitle'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: AppTheme.text,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                t('help.officeBody'),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.55,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Heading(t('help.questions')),
                  Card16(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: Column(
                      children: [
                        _Question(
                          icon: Icons.directions_bus_outlined,
                          color: AppTheme.violet,
                          question: t('help.q1'),
                          answer: t('help.a1'),
                        ),
                        _Question(
                          icon: Icons.verified_user_outlined,
                          color: AppTheme.green,
                          question: t('help.q2'),
                          answer: t('help.a2'),
                        ),
                        _Question(
                          icon: Icons.event_busy_outlined,
                          color: AppTheme.amber,
                          question: t('help.q3'),
                          answer: t('help.a3'),
                        ),
                        _Question(
                          icon: Icons.groups_outlined,
                          color: AppTheme.blue,
                          question: t('help.q4'),
                          answer: t('help.a4'),
                        ),
                        _Question(
                          icon: Icons.badge_outlined,
                          color: AppTheme.rose,
                          question: t('help.q5'),
                          answer: t('help.a5'),
                          last: true,
                        ),
                      ],
                    ),
                  ),

                  // The two things this app can actually send. Nothing else on
                  // the parent side travels back to the school.
                  if (kid != null) ...[
                    Heading(t('help.doTitle')),
                    Card16(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: Column(
                        children: [
                          TileRow(
                            icon: Icons.event_available_outlined,
                            color: AppTheme.blue,
                            title: t('leave.ask'),
                            subtitle: t('help.leaveSub'),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => LeaveScreen(child: kid),
                              ),
                            ),
                          ),
                          TileRow(
                            icon: Icons.rate_review_outlined,
                            color: AppTheme.green,
                            title: t('crew.title'),
                            subtitle: t('help.crewSub'),
                            last: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => DriverFeedbackScreen(child: kid),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // The school's name, and nothing beside it. A version number
                  // belongs here too, but the only honest source of one is the
                  // installed package and this app does not read it — a number
                  // typed in by hand goes stale on the first release nobody
                  // remembers to edit, which is worse than no number at all.
                  if (school.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    Text(
                      school,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One question, and the answer folded under it.
///
/// Closed by default and independent of its neighbours: a parent arrives here
/// with one question, and an accordion that shuts the answer they are reading
/// because they tapped the next heading is a puzzle rather than a page.
class _Question extends StatefulWidget {
  const _Question({
    required this.icon,
    required this.color,
    required this.question,
    required this.answer,
    this.last = false,
  });

  final IconData icon;
  final Color color;
  final String question;
  final String answer;
  final bool last;

  @override
  State<_Question> createState() => _QuestionState();
}

class _QuestionState extends State<_Question> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final quick = motionOff(context) ? Duration.zero : const Duration(milliseconds: 200);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Chip36(icon: widget.icon, color: widget.color),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    widget.question,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  duration: quick,
                  curve: Curves.easeOutCubic,
                  turns: _open ? 0.5 : 0,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 21,
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: quick,
          sizeCurve: Curves.easeOutCubic,
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
          alignment: AlignmentDirectional.topStart,
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            // Indented past the chip so the answer hangs under the words of
            // the question rather than under its icon. Directional, so it
            // indents from the right in Kurdish and Arabic.
            padding: const EdgeInsetsDirectional.fromSTEB(47, 0, 0, 13),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                widget.answer,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ),
        ),
        if (!widget.last) Divider(height: 1, color: AppTheme.border),
      ],
    );
  }
}
