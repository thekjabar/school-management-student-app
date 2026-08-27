import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'bus_screen.dart';

/// The screen the app opens on.
///
/// Ordered by what a student actually wants at the moment they unlock the
/// phone, which is not the same as what a school thinks is important:
///
///   1. Where am I meant to be right now.
///   2. Am I in trouble — attendance and grade at a glance.
///   3. What is due.
///   4. Everything else, one tap away.
///
/// Timetable, marks and the bus come from three different services behind the
/// gateway, and they are loaded in parallel and rendered independently. One
/// slow service must never hold up the whole screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// Jumps the shell to another tab, so "3 pending" can open the schedule.
  final void Function(int index) onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future = _load();

  Future<_HomeData> _load() async {
    final results = await Future.wait([
      repository.student(),
      repository.today(),
      repository.assignments(),
      repository.attendance(),
      repository.grades(),
    ]);
    return _HomeData(
      student: results[0] as Student,
      sessions: results[1] as List<Session>,
      assignments: results[2] as List<Assignment>,
      attendance: results[3] as AttendanceSummary,
      grades: results[4] as List<SubjectGrade>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.accent,
          backgroundColor: AppTheme.surface,
          child: FutureBuilder<_HomeData>(
            future: _future,
            builder: (context, snap) {
              return CustomScrollView(
                // Always scrollable, or pull-to-refresh does not work on a
                // screen whose content happens to fit.
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  const SliverToBoxAdapter(child: _Masthead()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.gutter, 0, AppTheme.gutter, 28,
                    ),
                    sliver: SliverList.list(
                      children: switch (snap.connectionState) {
                        ConnectionState.done when snap.hasError => [
                            const SizedBox(height: 8),
                            ErrorPanel(
                              message: snap.error.toString(),
                              onRetry: _refresh,
                            ),
                          ],
                        ConnectionState.done => _content(context, snap.data!),
                        _ => const [
                            SizedBox(height: 8),
                            LoadingSkeleton(height: 150, count: 1),
                            SizedBox(height: 22),
                            LoadingSkeleton(height: 104, count: 1),
                            SizedBox(height: 22),
                            LoadingSkeleton(height: 66, count: 2),
                          ],
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, _HomeData d) {
    final now = DateTime.now();
    final nowMinute = now.hour * 60 + now.minute;

    // The lesson happening now; failing that, the next one today. A screen that
    // shows a finished lesson because it was the last match is worse than one
    // that says there is nothing on.
    final live = d.sessions
        .where((s) => !s.isBreak && s.isNowAt(nowMinute))
        .firstOrNull;
    final next = d.sessions
        .where((s) => !s.isBreak && s.startMinute > nowMinute)
        .firstOrNull;
    final session = live ?? next;

    final pending = d.assignments.where((a) => !a.submitted).toList()
      ..sort((a, b) => a.due.compareTo(b.due));

    final gpa = d.grades.isEmpty
        ? 0.0
        : d.grades.map((g) => g.percent).reduce((a, b) => a + b) /
            d.grades.length /
            25.0; // percent → 4.0 scale

    return [
      const SizedBox(height: 8),
      SessionHeaderCard(student: d.student, session: session, isLive: live != null),

      const SectionLabel('Academic performance'),
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Attendance rate',
              value: d.attendance.rate.toStringAsFixed(0),
              suffix: '%',
              trend: d.attendance.trend,
              onTap: () => widget.onOpenTab(1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              label: 'GPA (current term)',
              value: gpa.toStringAsFixed(2),
              note: 'Across ${d.grades.length} subjects',
              onTap: () => widget.onOpenTab(2),
            ),
          ),
        ],
      ),

      SectionLabel(
        'Assignments registry',
        trailing: pending.isEmpty ? null : '${pending.length} pending',
      ),
      if (pending.isEmpty)
        const EmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'Nothing due',
          line: 'Everything set so far has been handed in.',
        )
      else
        // Two on the home screen. A list that runs past the fold stops being a
        // summary and becomes a second schedule tab.
        ...pending.take(2).map(
              (a) => AssignmentRow(
                assignment: a,
                onTap: () => widget.onOpenTab(1),
              ),
            ),
      if (pending.length > 2)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: TextButton(
            onPressed: () => widget.onOpenTab(1),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'See all ${pending.length}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),

      const SectionLabel('Quick resources'),
      Row(
        children: [
          const Expanded(
            child: QuickAction(
              icon: Icons.menu_book_rounded,
              label: 'Digital Library',
              tint: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: QuickAction(
              icon: Icons.event_note_rounded,
              label: 'Exam Schedule',
              tint: const Color(0xFFF59E0B),
              onTap: () => widget.onOpenTab(1),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Expanded(
            child: QuickAction(
              icon: Icons.forum_rounded,
              label: 'Student Hub',
              tint: Color(0xFF14B8A6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: QuickAction(
              icon: Icons.directions_bus_rounded,
              label: 'Bus Tracker',
              tint: AppTheme.accent,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BusScreen()),
              ),
            ),
          ),
        ],
      ),
    ];
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 14, AppTheme.gutter, 6),
      child: Row(
        children: [
          const Text(
            'EduPulse',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              letterSpacing: -0.3, color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Text('— Student Home',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
          const Spacer(),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: AppTheme.hairline(),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 18, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.student,
    required this.sessions,
    required this.assignments,
    required this.attendance,
    required this.grades,
  });

  final Student student;
  final List<Session> sessions;
  final List<Assignment> assignments;
  final AttendanceSummary attendance;
  final List<SubjectGrade> grades;
}
