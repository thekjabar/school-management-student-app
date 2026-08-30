import 'package:flutter/material.dart';
import '../../ui/screen_kit.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';

/// One piece of homework, in full.
///
/// The list could only ever show a title and a date, so the sentence that says
/// what to actually do — the part a parent needs at seven in the evening — was
/// truncated or missing. Worse, the API has been returning whether the work was
/// handed in, the mark and the teacher's comment all along, and none of it was
/// shown anywhere: a parent could see that homework existed and never learn
/// what became of it.
class HomeworkDetail extends StatelessWidget {
  const HomeworkDetail({super.key, required this.item, required this.childName});

  final HomeworkItem item;
  final String childName;

  @override
  Widget build(BuildContext context) {
    final tint = parseHex(item.colorHex, Role.parent.tint);
    final late = item.daysLeft < 0 && !item.handedIn;

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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    Card16(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Chip36(icon: Icons.assignment_rounded, color: tint, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.subject,
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tint),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // The due date said as a state, not only as a date. "Two days
                          // overdue" is the thing a parent acts on.
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: item.handedIn
                                  ? AppTheme.greenSoft
                                  : late
                                      ? AppTheme.roseSoft
                                      : AppTheme.canvas,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.handedIn
                                      ? Icons.check_circle_rounded
                                      : late
                                          ? Icons.error_outline_rounded
                                          : Icons.event_rounded,
                                  size: 18,
                                  color: item.handedIn
                                      ? AppTheme.green
                                      : late
                                          ? AppTheme.rose
                                          : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.handedIn ? t('hw.handedIn') : dueWord(item.daysLeft),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: item.handedIn
                                              ? AppTheme.green
                                              : late
                                                  ? AppTheme.rose
                                                  : AppTheme.text,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        tn('hw.due', longDate(item.dueDate)),
                                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
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

                    Heading(t('hw.whatToDo')),
                    Card16(
                      child: Text(
                        (item.description == null || item.description!.trim().isEmpty)
                            ? t('hw.noDescription')
                            : item.description!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: (item.description == null || item.description!.trim().isEmpty)
                              ? AppTheme.textFaint
                              : AppTheme.text,
                        ),
                      ),
                    ),

                    Heading(t('hw.details')),
                    Card16(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: Column(
                        children: [
                          TileRow(
                            icon: Icons.menu_book_rounded,
                            color: tint,
                            title: t('hw.subject'),
                            trailing: item.subject,
                            trailingColor: AppTheme.text,
                          ),
                          TileRow(
                            icon: Icons.person_rounded,
                            color: AppTheme.blue,
                            title: t('hw.teacher'),
                            trailing: item.teacher ?? '—',
                            trailingColor: AppTheme.text,
                          ),
                          TileRow(
                            icon: Icons.event_available_rounded,
                            color: AppTheme.textMuted,
                            title: t('hw.setOn').replaceAll(' {n}', ''),
                            trailing: shortDate(item.assignedOn),
                            trailingColor: AppTheme.text,
                          ),
                          if (item.estimatedMinutes != null)
                            TileRow(
                              icon: Icons.schedule_rounded,
                              color: AppTheme.amber,
                              title: t('hw.effort'),
                              trailing: tn('hw.about', item.estimatedMinutes!),
                              trailingColor: AppTheme.text,
                            ),
                          TileRow(
                            icon: Icons.grade_rounded,
                            color: AppTheme.green,
                            title: t('hw.outOf'),
                            trailing: item.maxScore != null ? '${item.maxScore}' : '—',
                            trailingColor: AppTheme.text,
                            last: true,
                          ),
                        ],
                      ),
                    ),

                    // Only when there is something to say. An empty "Mark: —" panel on
                    // every piece of homework is noise that makes the one that does
                    // have a mark harder to notice.
                    if (item.handedIn || item.score != null || (item.feedback?.isNotEmpty ?? false)) ...[
                      Heading(t('hw.mark')),
                      Card16(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Chip36(
                                  icon: Icons.workspace_premium_rounded,
                                  color: AppTheme.green,
                                  size: 42,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.score != null
                                            ? '${item.score}${item.maxScore != null ? ' / ${item.maxScore}' : ''}'
                                            : t('hw.notHandedIn'),
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      if (item.submittedAt != null)
                                        Text(
                                          '${t('hw.handedIn')} · ${longDate(item.submittedAt)}',
                                          style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (item.feedback?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 14),
                              Divider(height: 1, color: AppTheme.border),
                              const SizedBox(height: 12),
                              Text(
                                t('hw.feedback'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.feedback!,
                                style: const TextStyle(fontSize: 13.5, height: 1.55),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
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
