import 'package:flutter/material.dart';

import '../api/awards.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import '../ui/async.dart';
import '../ui/format.dart';
import '../ui/home_kit.dart';
import '../ui/kit.dart';
import '../ui/screen_kit.dart';

typedef AwardsWords = ({
  String title,
  String held,
  String none,
  String why,
  String givenOn,
  String takenBack,
  String takenBackWhy,
});

const AwardsWords studentAwardsWords = (
  title: 'student.awards',
  held: 'student.awardsHeld',
  none: 'student.awardsNone',
  why: 'student.awardWhy',
  givenOn: 'student.awardGivenOn',
  takenBack: 'student.awardTakenBack',
  takenBackWhy: 'student.awardTakenBackWhy',
);

const AwardsWords childAwardsWords = (
  title: 'awards.title',
  held: 'awards.held',
  none: 'awards.none',
  why: 'awards.why',
  givenOn: 'awards.givenOn',
  takenBack: 'awards.takenBack',
  takenBackWhy: 'awards.takenBackWhy',
);

class AwardsScreen extends StatelessWidget {
  const AwardsScreen({
    super.key,
    required this.load,
    required this.words,
    required this.tint,
    this.subtitle,
  });

  final Future<AwardsWall> Function() load;
  final AwardsWords words;
  final Color tint;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Column(
        children: [
          ScreenHeader(title: t(words.title), subtitle: subtitle),
          Expanded(
            child: Loader<AwardsWall>(
              tint: tint,
              padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 28),
              load: load,
              isEmpty: (wall) => wall.rows.isEmpty,
              empty: t(words.none),
              builder: (context, wall) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 2),
                    child: Pill(tn(words.held, wall.held), color: tint),
                  ),
                  for (final award in wall.rows) ...[
                    _AwardCard(award: award, words: words, tint: tint),
                    const SizedBox(height: kCardGap),
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

class _AwardCard extends StatelessWidget {
  const _AwardCard({required this.award, required this.words, required this.tint});

  final Certificate award;
  final AwardsWords words;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final gone = award.revoked;
    final colour = gone ? AppTheme.textFaint : tint;

    return Card16(
      padding: const EdgeInsets.all(16),
      color: gone ? null : colour.withValues(alpha: 0.07),
      border: gone ? null : colour.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(
                icon: gone ? Icons.remove_circle_outline_rounded : Icons.workspace_premium_rounded,
                color: colour,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      award.title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.25,
                        color: gone ? AppTheme.textMuted : AppTheme.text,
                        decoration: gone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (award.issuedOn != null)
                          Pill(
                            tv(words.givenOn, {'name': shortDate(award.issuedOn)}),
                            color: AppTheme.textMuted,
                          ),
                        if ((award.className ?? '').isNotEmpty)
                          Pill(award.className!, color: AppTheme.blue),
                        if (gone) Pill(t(words.takenBack), color: AppTheme.rose),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (award.body.isNotEmpty) ...[
            const SizedBox(height: 13),
            Text(
              award.body,
              style: TextStyle(fontSize: 13.5, height: 1.65, color: AppTheme.text),
            ),
          ],
          if ((award.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 13),
            Text(
              t(words.why),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppTheme.textFaint,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              award.reason!,
              style: TextStyle(fontSize: 13, height: 1.6, color: AppTheme.textMuted),
            ),
          ],
          if (gone && (award.revokedReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tv(words.takenBackWhy, {'name': award.revokedReason!}),
              style: TextStyle(fontSize: 12.5, height: 1.55, color: AppTheme.rose),
            ),
          ],
        ],
      ),
    );
  }
}
