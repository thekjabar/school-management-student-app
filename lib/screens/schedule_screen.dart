import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Today's timetable, what is due, and what is being examined — in that order,
/// because that is the order they become urgent.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late Future<_ScheduleData> _future = _load();

  Future<_ScheduleData> _load() async {
    final r = await Future.wait([
      repository.today(),
      repository.assignments(),
      repository.exams(),
    ]);
    return _ScheduleData(
      sessions: r[0] as List<Session>,
      assignments: r[1] as List<Assignment>,
      exams: r[2] as List<ExamEntry>,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 0, AppTheme.gutter, 10),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: AppTheme.hairline(),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: AppTheme.ink,
                  borderRadius: BorderRadius.circular(9),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Today'),
                  Tab(text: 'Assignments'),
                  Tab(text: 'Exams'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<_ScheduleData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppTheme.gutter),
              child: ErrorPanel(
                message: snap.error.toString(),
                onRetry: () => setState(() => _future = _load()),
              ),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppTheme.gutter),
              child: LoadingSkeleton(height: 72, count: 5),
            );
          }
          final d = snap.data!;
          return TabBarView(
            controller: _tabs,
            children: [
              _TodayTab(sessions: d.sessions),
              _AssignmentsTab(assignments: d.assignments),
              _ExamsTab(exams: d.exams),
            ],
          );
        },
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({required this.sessions});
  final List<Session> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.gutter),
        child: EmptyState(
          icon: Icons.beach_access_rounded,
          title: 'No lessons today',
          line: 'The school calendar has today down as a non-teaching day.',
        ),
      );
    }

    final now = DateTime.now();
    final nowMinute = now.hour * 60 + now.minute;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 4, AppTheme.gutter, 28),
      itemCount: sessions.length,
      itemBuilder: (context, i) {
        final s = sessions[i];
        final live = s.isNowAt(nowMinute);
        final past = s.isPastAt(nowMinute);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            dark: live,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The time rail. Fixed width so every row lines up down the
                // page and the column can be scanned without reading it.
                SizedBox(
                  width: 58,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Session.hhmm(s.startMinute).replaceAll(' ', ' '),
                        style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700,
                          color: live
                              ? Colors.white
                              : past
                                  ? AppTheme.textMuted
                                  : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Session.hhmm(s.endMinute).replaceAll(' ', ' '),
                        style: TextStyle(
                          fontSize: 11,
                          color: live ? const Color(0xFF8A8F98) : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 2, height: 34,
                  margin: const EdgeInsets.only(right: 13, top: 2),
                  decoration: BoxDecoration(
                    color: s.isBreak
                        ? AppTheme.border
                        : live
                            ? const Color(0xFF4ADE80)
                            : past
                                ? AppTheme.border
                                : AppTheme.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.subject,
                              style: TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: live
                                    ? Colors.white
                                    : past
                                        ? AppTheme.textMuted
                                        : AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (live)
                            Pill('Now',
                                color: const Color(0xFF4ADE80),
                                background:
                                    const Color(0xFF4ADE80).withValues(alpha: 0.14)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.isBreak
                            ? s.room
                            : '${s.room}${s.teacher.isEmpty ? '' : ' • ${s.teacher}'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: live ? const Color(0xFF9AA0A8) : AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab({required this.assignments});
  final List<Assignment> assignments;

  @override
  Widget build(BuildContext context) {
    final pending = assignments.where((a) => !a.submitted).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    final done = assignments.where((a) => a.submitted).toList();

    if (assignments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.gutter),
        child: EmptyState(
          icon: Icons.inbox_rounded,
          title: 'Nothing set',
          line: 'No homework has been published for your classes.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 0, AppTheme.gutter, 28),
      children: [
        if (pending.isNotEmpty) ...[
          SectionLabel('Due', trailing: '${pending.length}'),
          ...pending.map((a) => AssignmentRow(assignment: a)),
        ],
        if (done.isNotEmpty) ...[
          SectionLabel('Handed in', trailing: '${done.length}'),
          ...done.map((a) => AssignmentRow(assignment: a)),
        ],
      ],
    );
  }
}

class _ExamsTab extends StatelessWidget {
  const _ExamsTab({required this.exams});
  final List<ExamEntry> exams;

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.gutter),
        child: EmptyState(
          icon: Icons.event_available_rounded,
          title: 'No exams scheduled',
          line: 'Nothing has been published for this term yet.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 4, AppTheme.gutter, 28),
      itemCount: exams.length,
      itemBuilder: (context, i) {
        final e = exams[i];
        // Inside a week is the point at which this stops being information and
        // starts being pressure, so that is where the colour appears.
        final soon = e.daysAway <= 7;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: soon ? AppTheme.warmSoft : AppTheme.canvas,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${e.daysAway}',
                        style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, height: 1,
                          color: soon ? AppTheme.warm : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        e.daysAway == 1 ? 'day' : 'days',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: soon ? AppTheme.warm : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.subject,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        '${e.kind} • ${e.room} • ${Session.hhmm(e.startMinute)}',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScheduleData {
  const _ScheduleData({
    required this.sessions,
    required this.assignments,
    required this.exams,
  });
  final List<Session> sessions;
  final List<Assignment> assignments;
  final List<ExamEntry> exams;
}
