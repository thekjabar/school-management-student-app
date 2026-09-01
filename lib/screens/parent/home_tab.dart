import 'package:flutter/material.dart';

import '../../api/boot.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/motion.dart';
import '../../ui/pickers.dart';
import '../../ui/nav_glyphs.dart';
import 'assignments_screen.dart';
import 'bus_screen.dart';
import 'driver_feedback_screen.dart';
import 'attendance_screen.dart';
import 'attitude_screen.dart';
import 'homework_detail.dart';
import 'marks_screen.dart';
import 'memories_screen.dart';
import 'reports_screen.dart';
import 'student_info_screen.dart';
import 'timetable_screen.dart';
import 'track_screen.dart';

/// The one screen a parent opens on the way out of the door.
///
/// Ordered by how quickly the answer goes stale. The bus is first because it is
/// the only thing on this page that changes minute to minute and the only thing
/// they can still act on; the register and the marks are yesterday's news by
/// comparison and sit lower, however much a school cares about them.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.child, required this.onOpenTab});

  final Child child;

  /// Asked for when a card leads somewhere the SHELL owns — the messages
  /// tab, for instance. Anything that lives on the child's own screen is
  /// pushed directly rather than routed through a tab index.
  final void Function(int tab) onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Loader<_Home>(
      tint: Role.parent.tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18),
      load: () async {
        // One pass, all at once. Six sequential round trips on a school
        // connection is the difference between a screen and a wait.
        final payload = await HomePayload.fetch(child.studentId);
        return _Home.from(payload);
      },
      // The five blocks arrive in the order they are read, a step apart. It is
      // the page's own entrance and nothing more: it plays when the screen
      // appears — see the latch in motion.dart — not every time the Loader
      // refetches, or the screen would ripple at every poll.
      builder: (context, home) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Rise(
            child: _BusCard(
              child: child,
              transport: home.transport,
              onTap: () => _push(context, BusScreen(child: child)),
            ),
          ),
          const SizedBox(height: kCardGap),

          Rise(
            index: 1,
            child: QuickActions(
              actions: [
                // First in the row, and off.
                //
                // It leads deliberately: this is the thing parents ask for, and
                // putting it where the eye lands is the point of showing it at
                // all. It is still disabled, because no vehicle has a camera
                // fitted and there is no stream to open, and the note says that
                // rather than "coming soon" — a promise nobody is in a position
                // to make about hardware that has not been bought.
                QuickAction(
                  icon: Icons.videocam_outlined,
                  label: t('quick.liveVideo'),
                  color: AppTheme.blue,
                  enabled: false,
                  note: t('quick.liveVideoSoon'),
                ),
                QuickAction(
                  icon: Icons.my_location_rounded,
                  label: t('quick.track'),
                  color: AppTheme.green,
                  onTap: () => _push(context, TrackScreen(child: child)),
                ),
                QuickAction(
                  icon: Icons.directions_bus_outlined,
                  label: t('quick.bus'),
                  color: AppTheme.violet,
                  onTap: () => _push(context, BusScreen(child: child)),
                ),
                QuickAction(
                  icon: Icons.description_outlined,
                  label: t('quick.assignments'),
                  color: AppTheme.violet,
                  onTap: () => _push(context, AssignmentsScreen(child: child)),
                ),
                QuickAction(
                  icon: Icons.verified_user_outlined,
                  label: t('quick.attendance'),
                  color: AppTheme.green,
                  onTap: () => _push(context, AttendanceScreen(child: child)),
                ),
                QuickAction(
                  icon: Icons.bar_chart_rounded,
                  label: t('quick.marks'),
                  color: AppTheme.blue,
                  onTap: () => _push(context, MarksScreen(child: child)),
                ),
                QuickAction(
                  icon: Icons.favorite_border_rounded,
                  glyph: (colour, size) => HeartPersonIcon(color: colour, size: size),
                  label: t('quick.attitude'),
                  color: AppTheme.rose,
                  onTap: () => _push(context, AttitudeScreen(child: child)),
                ),
                QuickAction(
                  icon: Icons.calendar_today_outlined,
                  label: t('quick.timetable'),
                  color: AppTheme.amber,
                  onTap: () => _push(context, TimetableScreen(child: child)),
                ),
                QuickAction(
                  icon: Icons.pie_chart_outline_rounded,
                  label: t('quick.reports'),
                  color: AppTheme.violet,
                  onTap: () => _push(context, ReportsScreen(child: child)),
                ),
                QuickAction(
                  icon: Icons.badge_outlined,
                  label: t('quick.info'),
                  color: AppTheme.blue,
                  onTap: () => _push(context, StudentInfoScreen(child: child)),
                ),
                QuickAction(
                  icon: Icons.photo_library_outlined,
                  label: t('quick.memories'),
                  color: AppTheme.rose,
                  onTap: () => _push(context, MemoriesScreen(child: child)),
                ),
                QuickAction(
                  icon: Icons.rate_review_outlined,
                  label: t('quick.driverFeedback'),
                  color: AppTheme.green,
                  onTap: () => _push(context, DriverFeedbackScreen(child: child)),
                ),
              ],
            ),
          ),
          const SizedBox(height: kCardGap),

          // ---- Today's schedule -------------------------------------------
          Rise(
            index: 2,
            child: Card16(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionRow(
                    title: t('home.todaySchedule'),
                    actionLabel: t('home.fullTimetable'),
                    onAction: () => _push(context, TimetableScreen(child: child)),
                  ),
                  if (home.today.isEmpty)
                    _Quiet(text: t('home.nothingToday'))
                  else
                    // The lessons are NOT staggered inside the card. The rail
                    // down the left is one continuous line through every dot,
                    // and drawing it a row at a time reads as a list being cut
                    // off rather than as a day arriving.
                    ScheduleTimeline(
                      onTap: (_) => _push(context, TimetableScreen(child: child)),
                      entries: [
                        for (final l in home.today)
                          ScheduleEntry(
                            time: clock(l.startMinute),
                            subject: l.subject,
                            teacher: l.teacher,
                            room: l.room,
                            color: parseHex(l.colorHex, AppTheme.violet),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: kCardGap),

          // ---- The child ---------------------------------------------------
          Rise(index: 3, child: _ChildCard(child: child, home: home)),
          const SizedBox(height: kCardGap),

          // ---- Attendance, and what has happened ---------------------------
          //
          // Side by side, as the design has them. Two half-width cards read as
          // "here is the summary" in one glance where two stacked full-width
          // ones read as two more sections to scroll past.
          Rise(
            index: 4,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _AttendanceCard(child: child, summary: home.attendance),
                  ),
                  const SizedBox(width: kCardGap),
                  Expanded(
                    child: _UpdatesCard(
                      home: home,
                      child: child,
                      onSeeAll: () => onOpenTab(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// Everything the home screen needs, fetched together.
class _Home {
  _Home({
    required this.transport,
    required this.week,
    required this.attendance,
    required this.homework,
    required this.attitude,
    required this.announcements,
  });

  /// The same six answers, however they arrived — fetched here, or prefetched
  /// during the splash. The screen must not be able to tell the difference.
  factory _Home.from(HomePayload p) => _Home(
        transport: p.transport,
        week: p.week,
        attendance: p.attendance,
        homework: p.homework,
        attitude: p.attitude,
        announcements: p.announcements,
      );

  final TransportInfo transport;
  final List<DayOfLessons> week;
  final AttendanceSummary attendance;
  final List<HomeworkItem> homework;
  final AttitudeSummary attitude;
  final List<Announcement> announcements;

  /// Today's lessons, in the order they happen.
  List<Lesson> get today {
    final name = todayWeekday();
    final day = week.where((d) => d.weekday == name).toList();
    if (day.isEmpty) return const [];
    final lessons = [...day.first.lessons]
      ..sort((a, b) => (a.startMinute ?? 0).compareTo(b.startMinute ?? 0));
    return lessons;
  }

  int get dueSoon {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return homework.where((h) => !h.handedIn && h.dueDate.difference(midnight).inDays <= 7).length;
  }

  /// The average of whatever has been marked. Null rather than zero when
  /// nothing has: a child with no marks yet has not scored nought.
  int? get averageMark {
    final marked = homework.where((h) => h.score != null && (h.maxScore ?? 0) > 0).toList();
    if (marked.isEmpty) return null;
    final total = marked.fold<double>(
      0,
      (sum, h) => sum + (h.score!.toDouble() / h.maxScore!.toDouble()) * 100,
    );
    return (total / marked.length).round();
  }
}

/* ---------------------------------------------------------------------------
 * The bus
 * ------------------------------------------------------------------------- */

class _BusCard extends StatelessWidget {
  const _BusCard({required this.child, required this.transport, required this.onTap});

  final Child child;
  final TransportInfo transport;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    if (!transport.ridesTheBus) {
      return Card16(
        child: Row(
          children: [
            Chip36(icon: Icons.directions_walk_rounded, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t('bus.notOnBus'),
                style: TextStyle(fontSize: 13.5, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    final run = _liveRun;
    final headline = run == null ? t('bus.noRunToday') : run.childLine;
    final eta = run?.scheduledDepartureAt;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          // Sampled from the design: a lavender barely off the page in the
          // light theme, and a violet-leaning navy in the dark one.
          color: AppTheme.dark ? const Color(0xFF101627) : const Color(0xFFF7F3FF),
          borderRadius: BorderRadius.circular(kCardRadius),
          border: Border.all(
            color: AppTheme.dark ? const Color(0xFF212A3D) : const Color(0xFFEDE7FD),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kCardRadius),
          child: LayoutBuilder(
            builder: (context, box) {
              return Stack(
                children: [
                  // The scene sits against the right edge and the text is held
                  // clear of it; the house end of the picture is allowed to run
                  // under nothing, which is why the column is the narrower half.
                  PositionedDirectional(
                    end: 0,
                    top: 0,
                    bottom: 0,
                    width: box.maxWidth * 0.55,
                    child: Image.asset(
                      'assets/art/bus_scene.png',
                      fit: BoxFit.contain,
                      alignment: AlignmentDirectional.bottomEnd,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 15, 0, 15),
                    child: SizedBox(
                      width: box.maxWidth * 0.47,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // The design draws this chip on the dark canvas
                              // only: on white the violet title carries the
                              // card without it.
                              if (AppTheme.dark) ...[
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: tint.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    Icons.directions_bus_rounded,
                                    size: 18,
                                    color: tint,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      run == null ? t('bus.noRunTitle') : t('bus.onTheWay'),
                                      maxLines: 2,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                        height: 1.2,
                                        color: tint,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      headline,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        height: 1.45,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (eta != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.dark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.dark
                                      ? const Color(0xFF2A3348)
                                      : const Color(0xFFEBE5FB),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.directions_bus_rounded, size: 15, color: tint),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      '${t('bus.eta')} ${hhmm(eta)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: tint,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
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

  /// The run that answers "where is my child now" — the afternoon one once it
  /// is under way, the morning one until then.
  TripToday? get _liveRun {
    if (transport.today.isEmpty) return null;
    final back = transport.today.where((t) => t.leg == 'RETURN').toList();
    if (back.isNotEmpty && (back.first.boardedAt != null || back.first.status == 'IN_PROGRESS')) {
      return back.first;
    }
    final out = transport.today.where((t) => t.leg == 'OUT').toList();
    return out.isNotEmpty ? out.first : transport.today.first;
  }
}

/* ---------------------------------------------------------------------------
 * The child
 * ------------------------------------------------------------------------- */

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.home});

  final Child child;
  final _Home home;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.5),
                ),
                child: CircleInitials(label: child.name, tint: tint, size: 44),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${child.className} • ${tn('home.studentId', child.code)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _ProfileButton(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => StudentInfoScreen(child: child)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
          IconFigureStrip(
            figures: [
              IconFigure(
                icon: Icons.verified_user_outlined,
                label: t('quick.attendance'),
                value: home.attendance.total > 0 ? '${home.attendance.ratePercent}%' : '—',
                caption: t('home.thisWeek'),
                color: AppTheme.green,
              ),
              IconFigure(
                icon: Icons.assignment_turned_in_outlined,
                label: t('quick.assignments'),
                value: '${home.dueSoon}',
                caption: t('home.pending'),
                color: AppTheme.blue,
              ),
              IconFigure(
                icon: Icons.trending_up_rounded,
                label: t('home.average'),
                value: home.averageMark == null ? '—' : '${home.averageMark}%',
                caption: t('home.thisTerm'),
                color: AppTheme.violet,
              ),
              IconFigure(
                icon: Icons.sentiment_satisfied_alt_rounded,
                label: t('quick.attitude'),
                value: t('attitude.${home.attitude.verdict}'),
                caption: '${home.attitude.merits} ${t('attitude.merits')}',
                color: AppTheme.rose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(9, 8, 5, 8),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded, size: 14, color: tint),
            const SizedBox(width: 5),
            Text(
              t('home.viewProfile'),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tint),
            ),
            Icon(Icons.chevron_right_rounded, size: 15, color: tint),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Attendance
 * ------------------------------------------------------------------------- */

/// How much of a window a period covers, and what to call it.
enum _Period { week, month, term }

class _AttendanceCard extends StatefulWidget {
  const _AttendanceCard({required this.child, required this.summary});

  final Child child;

  /// What came with the home payload: the term, which is what the endpoint
  /// answers when it is asked for no window at all.
  final AttendanceSummary summary;

  @override
  State<_AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<_AttendanceCard> {
  _Period _period = _Period.week;

  /// Null until a different window has been fetched. The term figure arrives
  /// with the page, so the first frame costs no request.
  AttendanceSummary? _fetched;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The card opens on the week, which is the number a parent checks; the
    // payload carries the term. So one request, once, rather than a figure
    // whose caption says one thing and whose value means another.
    _load(_Period.week);
  }

  String get _label => switch (_period) {
        _Period.week => t('home.thisWeek'),
        _Period.month => t('home.thisMonth'),
        _Period.term => t('home.thisTerm'),
      };

  ({DateTime? from, DateTime? to}) _window(_Period p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (p) {
      // Monday of this week. weekday is 1..7 with Monday at 1.
      _Period.week => (from: today.subtract(Duration(days: today.weekday - 1)), to: today),
      _Period.month => (from: DateTime(today.year, today.month, 1), to: today),
      // No window: the endpoint answers for the term, which is its default.
      _Period.term => (from: null, to: null),
    };
  }

  Future<void> _load(_Period p) async {
    setState(() {
      _period = p;
      _busy = true;
    });
    final w = _window(p);
    try {
      final got = await ParentApi.instance.attendance(
        widget.child.studentId,
        from: w.from,
        to: w.to,
      );
      if (!mounted) return;
      setState(() {
        _fetched = got;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      // The figure on screen stays as it was rather than emptying itself.
      setState(() => _busy = false);
      showNote(context, errorText(e), bad: true);
    }
  }

  Future<void> _pick() async {
    final picked = await pickOne<_Period>(
      context,
      title: t('quick.attendance'),
      tint: Role.parent.tint,
      options: [
        PickOption(value: _Period.week, label: t('home.thisWeek'), icon: Icons.view_week_outlined),
        PickOption(value: _Period.month, label: t('home.thisMonth'), icon: Icons.calendar_month_outlined),
        PickOption(value: _Period.term, label: t('home.thisTerm'), icon: Icons.school_outlined),
      ],
    );
    if (picked != null && picked != _period) await _load(picked);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _fetched ?? widget.summary;
    final marked = summary.total > 0;
    final rate = summary.ratePercent.toDouble();
    final good = rate >= 95;

    return Card16(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('quick.attendance'),
            actionLabel: _label,
            actionIcon: Icons.expand_more_rounded,
            dense: true,
            onAction: _busy ? null : _pick,
          ),
          if (!marked)
            _Quiet(text: t('home.notMarked'))
          else ...[
            Row(
              children: [
                PercentRing(
                  percent: rate,
                  color: good ? AppTheme.green : AppTheme.amber,
                  size: 74,
                  label: t('att.present'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      _Tally(label: t('att.present'), value: summary.present, color: AppTheme.green),
                      Divider(height: 13, color: AppTheme.border),
                      _Tally(label: t('att.absent'), value: summary.absent, color: AppTheme.rose),
                      Divider(height: 13, color: AppTheme.border),
                      _Tally(label: t('att.late'), value: summary.late, color: AppTheme.amber),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: (good ? AppTheme.green : AppTheme.amber)
                    .withValues(alpha: AppTheme.dark ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                '${good ? '🎉' : '👀'}  ${good ? t('attendance.keepItUp') : t('attendance.watchThis')}',
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: good ? AppTheme.green : AppTheme.amber,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}

/* ---------------------------------------------------------------------------
 * Recent updates
 * ------------------------------------------------------------------------- */

class _UpdatesCard extends StatelessWidget {
  const _UpdatesCard({required this.home, required this.child, required this.onSeeAll});

  final _Home home;
  final Child child;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final entries = <UpdateEntry>[];

    // Newest first, across every kind — a parent does not think in sources.
    for (final a in home.attitude.notes.take(1)) {
      entries.add(UpdateEntry(
        icon: a.isMerit ? Icons.star_rounded : Icons.error_outline_rounded,
        category: t('quick.attitude'),
        title: a.note ?? t('attitude.${a.category.toLowerCase()}'),
        when: longDate(a.occurredAt),
        color: a.isMerit ? AppTheme.green : AppTheme.amber,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AttitudeScreen(child: child)),
        ),
      ));
    }
    for (final h in home.homework.take(1)) {
      entries.add(UpdateEntry(
        icon: Icons.description_outlined,
        category: t('quick.assignments'),
        title: h.title,
        when: tn('home.dueOn', longDate(h.dueDate)),
        color: AppTheme.blue,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => HomeworkDetail(item: h, childName: child.name)),
        ),
      ));
    }
    for (final a in home.announcements.take(1)) {
      entries.add(UpdateEntry(
        icon: Icons.campaign_outlined,
        category: t('nav.messages'),
        title: a.title,
        when: longDate(a.sentAt),
        color: AppTheme.violet,
        onTap: onSeeAll,
      ));
    }

    return Card16(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('home.recentUpdates'),
            actionLabel: entries.isEmpty ? null : t('home.viewAll'),
            onAction: onSeeAll,
            dense: true,
          ),
          if (entries.isEmpty)
            _Quiet(text: t('home.nothingNew'))
          else
            UpdatesFeed(entries: entries.take(3).toList(), dense: true),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Small shared bits
 * ------------------------------------------------------------------------- */

class _Quiet extends StatelessWidget {
  const _Quiet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ),
    );
  }
}
