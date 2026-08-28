import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../i18n/strings.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import 'child_detail.dart';
import 'fees_screen.dart';
import 'homework_detail.dart';
import 'leave_screen.dart';

/// One child's day, at a glance.
///
/// Ordered by what a guardian actually opens the app to find out, which in this
/// market is the same thing in the same order every morning: how is she doing,
/// what is on today, what has the school told me, what do I need to do.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.child, required this.onOpenTab});

  final Child child;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final api = ParentApi.instance;
    final id = child.studentId;

    return Loader<_Home>(
      key: ValueKey(id),
      tint: Role.parent.tint,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
      load: () async {
        // Fired together rather than in sequence. On a congested cell at 07:00
        // six sequential round trips is the difference between a screen that
        // appears and one a parent gives up on.
        final r = await Future.wait([
          api.attendance(id),
          api.results(id),
          api.timetable(id),
          api.homework(id),
          api.announcements(),
          api.fees(),
        ]);
        return _Home(
          attendance: r[0] as AttendanceSummary,
          results: r[1] as List<ExamResultItem>,
          days: r[2] as List<DayOfLessons>,
          homework: r[3] as List<HomeworkItem>,
          notices: r[4] as List<Announcement>,
          fees: r[5] as FeeSummary,
        );
      },
      builder: (context, d) {
        final today = todayWeekday();
        final lessons = d.days
                .where((day) => day.weekday == today)
                .expand((day) => day.lessons)
                .where((l) => l.kind == 'LESSON')
                .toList()
              ..sort((a, b) => a.period.compareTo(b.period));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChildCard(child: child, data: d),

            Heading(
              t('home.todaysSchedule'),
              action: t('home.viewAll'),
              tint: Role.parent.tint,
              onAction: () => _openChild(context, 1),
            ),
            Card16(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: lessons.isEmpty
                  ? _Nothing(t('home.noLessons'))
                  : Column(
                      children: [
                        for (var i = 0; i < lessons.length && i < 4; i++)
                          TileRow(
                            icon: _subjectIcon(lessons[i].subject),
                            color: parseHex(lessons[i].colorHex, Role.parent.tint),
                            title: lessons[i].subject,
                            subtitle: lessons[i].teacher,
                            trailing: clock(lessons[i].startMinute),
                            trailingColor: AppTheme.text,
                            last: i == lessons.length - 1 || i == 3,
                          ),
                      ],
                    ),
            ),

            Heading(
              t('home.recentUpdates'),
              action: t('home.viewAll'),
              tint: Role.parent.tint,
              onAction: () => onOpenTab(2),
            ),
            Card16(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: d.updates.isEmpty
                  ? _Nothing(t('home.nothingNew'))
                  : Column(
                      children: [
                        for (var i = 0; i < d.updates.length && i < 3; i++)
                          TileRow(
                            onTap: d.updates[i].homework == null
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => HomeworkDetail(
                                          item: d.updates[i].homework!,
                                          childName: child.name,
                                        ),
                                      ),
                                    ),
                            icon: d.updates[i].icon,
                            color: d.updates[i].color,
                            title: d.updates[i].title,
                            subtitle: d.updates[i].subtitle,
                            trailing: d.updates[i].ago,
                            last: i == d.updates.length - 1 || i == 2,
                          ),
                      ],
                    ),
            ),

            Heading(t('home.quickActions')),
            QuickActions(
              actions: [
                QuickAction(
                  icon: Icons.receipt_long_rounded,
                  label: t('action.fees'),
                  color: AppTheme.violet,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FeesScreen()),
                  ),
                ),
                QuickAction(
                  icon: Icons.event_busy_rounded,
                  label: t('action.leave'),
                  color: AppTheme.amber,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LeaveScreen(child: child)),
                  ),
                ),
                QuickAction(
                  icon: Icons.calendar_month_rounded,
                  label: t('action.calendar'),
                  color: AppTheme.blue,
                  onTap: () => _openChild(context, 1),
                ),
                QuickAction(
                  icon: Icons.workspace_premium_rounded,
                  label: t('action.report'),
                  color: AppTheme.green,
                  onTap: () => _openChild(context, 3),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  void _openChild(BuildContext context, int section) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChildDetail(child: child, initialSection: section)),
    );
  }
}

/// Everything the home screen needs, fetched in one go.
class _Home {
  _Home({
    required this.attendance,
    required this.results,
    required this.days,
    required this.homework,
    required this.notices,
    required this.fees,
  });

  final AttendanceSummary attendance;
  final List<ExamResultItem> results;
  final List<DayOfLessons> days;
  final List<HomeworkItem> homework;
  final List<Announcement> notices;
  final FeeSummary fees;

  /// The average mark across everything published, as a percentage.
  int? get average {
    final marked = results.where((r) => r.percent != null).toList();
    if (marked.isEmpty) return null;
    return (marked.map((r) => r.percent!).reduce((a, b) => a + b) / marked.length).round();
  }

  /// A grade point out of 4, which is how schools here talk about an average.
  String get gpa {
    final avg = average;
    if (avg == null) return '—';
    final points = avg >= 90
        ? 4.0
        : avg >= 80
            ? 3.0 + (avg - 80) / 10
            : avg >= 70
                ? 2.0 + (avg - 70) / 10
                : avg >= 50
                    ? 1.0 + (avg - 50) / 20
                    : avg / 50;
    return points.toStringAsFixed(1);
  }

  String get gpaBand {
    final avg = average;
    if (avg == null) return t('home.noMarks');
    return avg >= 90
        ? 'A+'
        : avg >= 80
            ? 'A'
            : avg >= 70
                ? 'B'
                : avg >= 50
                    ? 'C'
                    : 'needs help';
  }

  /// The three most recent things the school did that a parent would want to
  /// know about, mixed from notices, homework and published marks — because
  /// "recent updates" is a question about the school, not about one table.
  List<_Update> get updates {
    final items = <_Update>[
      for (final n in notices.take(4))
        _Update(
          icon: n.priority == 'HIGH' || n.priority == 'CRITICAL'
              ? Icons.priority_high_rounded
              : Icons.campaign_rounded,
          color: n.priority == 'HIGH' || n.priority == 'CRITICAL' ? AppTheme.rose : AppTheme.violet,
          title: n.title,
          subtitle: n.body,
          at: n.sentAt,
        ),
      for (final h in homework.take(3))
        _Update(
          icon: Icons.assignment_rounded,
          color: parseHex(h.colorHex, AppTheme.blue),
          title: h.title,
          subtitle: tn('hw.due', longDate(h.dueDate)),
          at: h.assignedOn,
          homework: h,
        ),
      for (final r in results.take(3))
        _Update(
          icon: Icons.grading_rounded,
          color: AppTheme.green,
          title: '${r.subject} result published',
          subtitle: r.wasAbsent ? t('marks.absent') : '${r.score} / ${r.maxScore}',
          at: r.date,
        ),
    ];
    items.sort((a, b) => (b.at ?? DateTime(2000)).compareTo(a.at ?? DateTime(2000)));
    return items;
  }
}

class _Update {
  _Update({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.at,
    this.homework,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime? at;

  /// Set when this update IS a piece of homework, so the row can open it.
  final HomeworkItem? homework;

  /// "2h ago", "1d ago" — the form the mockup uses, and the form somebody
  /// scanning a list actually reads.
  String get ago {
    if (at == null) return '';
    final diff = DateTime.now().difference(at!);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return shortDate(at);
  }
}

/// The card the whole screen hangs off: who the child is, and the three numbers
/// that answer "how is she doing".
class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.data});

  final Child child;
  final _Home data;

  @override
  Widget build(BuildContext context) {
    final rate = data.attendance.ratePercent;
    final marked = data.attendance.total > 0;

    // Below 90% is where a school here starts telephoning home, so the colour
    // changes at a threshold that means something rather than a round number.
    final attendanceColor = !marked
        ? AppTheme.textFaint
        : rate >= 95
            ? AppTheme.green
            : rate >= 85
                ? AppTheme.amber
                : AppTheme.rose;

    final owed = data.fees.outstandingIqd;
    final days = data.fees.daysUntilDue;

    return Card16(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChildDetail(child: child)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleInitials(label: child.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${child.className} · ${child.code}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textFaint),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 14),
          FigureStrip(
            figures: [
              Figure(
                label: t('home.attendance'),
                value: marked ? '$rate%' : '—',
                caption: !marked
                    ? t('home.notMarked')
                    : rate >= 95
                        ? t('home.excellent')
                        : rate >= 85
                            ? t('home.watchIt')
                            : t('home.concerning'),
                captionColor: attendanceColor,
              ),
              Figure(
                label: t('home.average'),
                value: data.gpa,
                caption: data.gpaBand,
                captionColor: data.average == null ? AppTheme.textFaint : AppTheme.violet,
              ),
              Figure(
                label: t('home.feesDue'),
                value: owed > 0 ? iqd(owed).replaceAll(' IQD', '') : t('home.paid'),
                caption: owed <= 0
                    ? t('home.nothingOwed')
                    : days == null
                        ? t('home.dueNow')
                        : days < 0
                            ? tn('home.daysLate', -days)
                            : tn('home.dueInDays', days),
                captionColor: owed <= 0
                    ? AppTheme.green
                    : (days ?? 0) < 0
                        ? AppTheme.rose
                        : AppTheme.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12.5, color: AppTheme.textFaint),
        ),
      ),
    );
  }
}

/// A recognisable glyph per subject.
///
/// Falls back to a book, which is honest: a school can add "Kurdish heritage"
/// tomorrow and the row should still look like a lesson rather than like a bug.
IconData _subjectIcon(String subject) {
  final s = subject.toLowerCase();
  if (s.contains('math')) return Icons.calculate_rounded;
  if (s.contains('scien')) return Icons.science_rounded;
  if (s.contains('english')) return Icons.translate_rounded;
  if (s.contains('arab')) return Icons.menu_book_rounded;
  if (s.contains('kurd')) return Icons.auto_stories_rounded;
  if (s.contains('islam') || s.contains('relig')) return Icons.mosque_rounded;
  if (s.contains('sport') || s.contains('art')) return Icons.sports_soccer_rounded;
  if (s.contains('social') || s.contains('histor')) return Icons.public_rounded;
  return Icons.book_rounded;
}
