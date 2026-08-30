import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import 'homework_detail.dart';

/// Everything the school has set, in the order it falls due.
///
/// The tabs are the four states a piece of work can be in, and the top card is
/// only ever the ones still ahead — because a parent opening this screen is
/// asking "what does he still have to do", and a list that mixes that with six
/// weeks of marked work answers a different question.
class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key, required this.child});

  final Child child;

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  int _tab = 0;
  String _query = '';
  String? _subject;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('quick.assignments')),
            Expanded(
              child: Loader<List<HomeworkItem>>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
                load: () => ParentApi.instance.homework(widget.child.studentId),
                builder: (context, all) {
                  final midnight = DateTime.now()
                      .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);

                  bool pending(HomeworkItem h) => !h.handedIn;
                  bool submitted(HomeworkItem h) => h.handedIn && h.score == null;
                  bool completed(HomeworkItem h) => h.score != null;

                  final subjects = {for (final h in all) h.subject}.toList()..sort();

                  final filtered = all.where((h) {
                    if (_subject != null && h.subject != _subject) return false;
                    if (_query.isNotEmpty &&
                        !h.title.toLowerCase().contains(_query) &&
                        !h.subject.toLowerCase().contains(_query)) {
                      return false;
                    }
                    return switch (_tab) {
                      1 => pending(h),
                      2 => submitted(h),
                      3 => completed(h),
                      _ => true,
                    };
                  }).toList();

                  final upcoming = filtered
                      .where((h) => pending(h) && !h.dueDate.isBefore(midnight))
                      .toList()
                    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
                  final recent = filtered.where((h) => h.handedIn).toList()
                    ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Search(onChanged: (v) => setState(() => _query = v.trim().toLowerCase())),
                      const SizedBox(height: 10),

                      UnderlineTabs(
                        tint: tint,
                        index: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                        tabs: [
                          TabSpec(label: t('hw.all'), icon: Icons.description_outlined),
                          TabSpec(
                            label: t('hw.pending'),
                            icon: Icons.schedule_rounded,
                            color: AppTheme.amber,
                          ),
                          TabSpec(
                            label: t('hw.submitted'),
                            icon: Icons.check_circle_outline_rounded,
                            color: AppTheme.green,
                          ),
                          TabSpec(
                            label: t('hw.completed'),
                            icon: Icons.assignment_turned_in_outlined,
                            color: AppTheme.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (subjects.length > 1) ...[
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _Chip(
                                label: t('hw.allSubjects'),
                                on: _subject == null,
                                onTap: () => setState(() => _subject = null),
                              ),
                              for (final s in subjects) ...[
                                const SizedBox(width: 8),
                                _Chip(
                                  label: s,
                                  on: _subject == s,
                                  onTap: () => setState(() => _subject = s),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: kCardGap),
                      ],

                      if (upcoming.isNotEmpty) ...[
                        _ListCard(
                          title: t('hw.upcoming'),
                          items: upcoming.take(6).toList(),
                          child: widget.child,
                          midnight: midnight,
                        ),
                        const SizedBox(height: kCardGap),
                      ],

                      if (recent.isNotEmpty) ...[
                        _ListCard(
                          title: t('hw.recentSubmitted'),
                          items: recent.take(4).toList(),
                          child: widget.child,
                          midnight: midnight,
                        ),
                        const SizedBox(height: kCardGap),
                      ],

                      if (upcoming.isEmpty && recent.isEmpty)
                        Card16(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              t('hw.nothing'),
                              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                            ),
                          ),
                        ),

                      const SizedBox(height: kCardGap),
                      _Overview(
                        total: all.length,
                        pending: all.where(pending).length,
                        submitted: all.where(submitted).length,
                        completed: all.where(completed).length,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: t('common.search'),
        prefixIcon: Icon(Icons.search_rounded, size: 19, color: AppTheme.textFaint),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: AppTheme.dark ? 0.22 : 0.10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? tint.withValues(alpha: 0.5) : AppTheme.border),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: on ? tint : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.items,
    required this.child,
    required this.midnight,
  });

  final String title;
  final List<HomeworkItem> items;
  final Child child;
  final DateTime midnight;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: title),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppTheme.border),
            _Row(
              item: items[i],
              child: child,
              days: items[i].dueDate.difference(midnight).inDays,
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.child, required this.days});

  final HomeworkItem item;
  final Child child;
  final int days;

  static String _caps(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final colour = parseHex(item.colorHex, AppTheme.violet);

    // The pill carries the urgency, and its colour is the whole reason a parent
    // can read this list without doing date arithmetic in their head.
    final (word, chipColour) = item.score != null
        ? (t('hw.marked'), AppTheme.blue)
        : item.handedIn
            ? (t('hw.submitted'), AppTheme.green)
            : days < 0
                ? (t('due.overdue').replaceAll('{n}', '${-days}'), AppTheme.rose)
                : days == 0
                    ? (t('due.today'), AppTheme.rose)
                    : days == 1
                        ? (t('due.tomorrow'), AppTheme.rose)
                        : days <= 3
                            ? (tn('due.inDays', days), AppTheme.amber)
                            : (tn('due.inDays', days), AppTheme.green);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HomeworkDetail(item: item, childName: child.name)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsetsDirectional.only(end: 9),
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(subjectIcon(item.subject), size: 21, color: colour),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
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
                      CircleInitials(label: child.name, tint: Role.parent.tint, size: 18),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${child.name}  •  ${child.className}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: AppTheme.textFaint),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // The design capitalises these; the shared due-word strings are
            // written for mid-sentence use.
            StatusChip(_caps(word), color: chipColour),
                const SizedBox(height: 4),
                Text(
                  shortDate(item.dueDate),
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.total,
    required this.pending,
    required this.submitted,
    required this.completed,
  });

  final int total;
  final int pending;
  final int submitted;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('hw.overview'),
            actionLabel: t('att.thisTerm'),
            actionIcon: Icons.expand_more_rounded,
          ),
          IconFigureStrip(
            figures: [
              IconFigure(
                icon: Icons.assignment_outlined,
                label: t('hw.total'),
                value: '$total',
                caption: t('att.thisTerm'),
                color: AppTheme.violet,
              ),
              IconFigure(
                icon: Icons.schedule_rounded,
                label: t('hw.pending'),
                value: '$pending',
                caption: t('att.thisTerm'),
                color: AppTheme.amber,
              ),
              IconFigure(
                icon: Icons.check_circle_outline_rounded,
                label: t('hw.submitted'),
                value: '$submitted',
                caption: t('att.thisTerm'),
                color: AppTheme.green,
              ),
              IconFigure(
                icon: Icons.assignment_turned_in_outlined,
                label: t('hw.completed'),
                value: '$completed',
                caption: t('att.thisTerm'),
                color: AppTheme.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
