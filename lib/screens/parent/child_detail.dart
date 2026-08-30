import 'dart:async';
import '../../ui/screen_kit.dart';

import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../i18n/strings.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import 'homework_detail.dart';

/// Everything about one child, behind five chips.
///
/// One screen rather than five destinations in the bottom bar, because these
/// are all answers to "how is she getting on", asked about once a week. The
/// bottom bar is reserved for the things asked every day.
class ChildDetail extends StatefulWidget {
  const ChildDetail({super.key, required this.child, this.initialSection = 0});

  final Child child;
  final int initialSection;

  @override
  State<ChildDetail> createState() => _ChildDetailState();
}

class _ChildDetailState extends State<ChildDetail> {
  late int _section = widget.initialSection;

  List<String> get _sections =>
      [t('tab.bus'), t('tab.timetable'), t('tab.homework'), t('tab.marks'), t('tab.attendance')];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: widget.child.name.split(' ').first),
            Expanded(
              child: Column(
                children: [
                  Container(
                    color: Role.parent.wash,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _sections.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final on = i == _section;
                          return GestureDetector(
                            onTap: () => setState(() => _section = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: on ? Role.parent.tint : AppTheme.surface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _sections[i],
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: on ? Colors.white : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: switch (_section) {
                      0 => _BusSection(child: widget.child),
                      1 => _TimetableSection(child: widget.child),
                      2 => _HomeworkSection(child: widget.child),
                      3 => _MarksSection(child: widget.child),
                      _ => _AttendanceSection(child: widget.child),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Bus
 * ------------------------------------------------------------------------- */

class _BusSection extends StatefulWidget {
  const _BusSection({required this.child});

  final Child child;

  @override
  State<_BusSection> createState() => _BusSectionState();
}

class _BusSectionState extends State<_BusSection> {
  Timer? _ticker;
  LiveBus? _live;

  @override
  void initState() {
    super.initState();
    _poll();
    // Twenty seconds. The server samples positions at fifteen while a trip is
    // running, so polling faster only costs the parent's battery without ever
    // showing them a newer fix.
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) => _poll());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final all = await ParentApi.instance.live();
      if (!mounted) return;
      setState(() {
        _live = all.where((l) => l.studentId == widget.child.studentId).firstOrNull;
      });
    } catch (_) {
      // A failed poll is not worth an error state; the card below still shows
      // what is known and the next tick may well succeed.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<TransportInfo>(
      key: ValueKey('bus-${widget.child.studentId}'),
      tint: Role.parent.tint,
      load: () => ParentApi.instance.transport(widget.child.studentId),
      builder: (context, info) {
        if (!info.ridesTheBus) {
          return Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                Icon(Icons.directions_walk_rounded, size: 38, color: AppTheme.textFaint),
                const SizedBox(height: 14),
                Text(
                  tn('bus.notOnBus', widget.child.name.split(' ').first),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  t('bus.askOffice'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LiveCard(live: _live),
            Heading(t('bus.today')),
            ...info.today.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RunCard(trip: t),
                )),
            if (info.today.isEmpty)
              Card16(
                child: Text(
                  t('bus.noBusToday'),
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ),
            Heading(t('bus.arrangement')),
            Card16(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip36(
                        icon: Icons.route_rounded,
                        color: parseHex(info.routeColorHex, Role.parent.tint),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          info.routeName ?? t('bus.vehicle'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      if (info.seatNumber != null)
                        Pill(tn('bus.seat', info.seatNumber!), color: AppTheme.textMuted),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Detail(label: t('bus.morningStop'), value: info.pickupStopName ?? '—'),
                  if (info.pickupLandmark != null) _Detail(label: '', value: info.pickupLandmark!, faint: true),
                  _Detail(label: t('bus.afternoonStop'), value: info.dropoffStopName ?? '—'),
                  if (info.dropoffLandmark != null) _Detail(label: '', value: info.dropoffLandmark!, faint: true),
                ],
              ),
            ),
            Heading(t('bus.dropElsewhere')),
            _DropoffCard(child: widget.child),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.live});

  final LiveBus? live;

  @override
  Widget build(BuildContext context) {
    final l = live;

    if (l == null || !l.visible) {
      return Card16(
        child: Row(
          children: [
            Chip36(
              icon: Icons.location_off_rounded,
              color: AppTheme.textMuted,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('bus.mapClosed'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 3),
                  Text(
                    l?.reasonText ?? t('bus.checking'),
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final fresh = !l.stale;
    return Card16(
      color: fresh ? AppTheme.greenSoft : AppTheme.amberSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(
                icon: Icons.directions_bus_filled_rounded,
                color: fresh ? AppTheme.green : AppTheme.amber,
                background: AppTheme.surface,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.etaMinutes != null
                          ? tn('bus.minutesAway', l.etaMinutes!)
                          : t('bus.moving'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.stopName != null ? tn('bus.headingFor', l.stopName!) : t('bus.onRoute'),
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // The age of the fix, always. A position shown without one invites a
          // parent to believe a four-minute-old dot is where the bus is now.
          Text(
            l.ageSeconds == null
                ? t('bus.ageUnknown')
                : tn('bus.reportedAgo', l.ageSeconds! < 60 ? '${l.ageSeconds}s' : '${(l.ageSeconds! / 60).round()} min') +
                    (l.stale ? t('bus.notRecent') : ''),
            style: TextStyle(
              fontSize: 11.5,
              color: fresh ? AppTheme.green : AppTheme.amber,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.trip});

  final TripToday trip;

  @override
  Widget build(BuildContext context) {
    final done = trip.alightedAt != null;
    final onboard = trip.boardedAt != null && trip.alightedAt == null;
    final missed = trip.resolution == 'NO_SHOW';

    final (Color colour, IconData icon) = missed
        ? (AppTheme.rose, Icons.person_off_rounded)
        : onboard
            ? (AppTheme.blue, Icons.directions_bus_filled_rounded)
            : done
                ? (AppTheme.green, Icons.check_circle_rounded)
                : (AppTheme.textMuted, Icons.schedule_rounded);

    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(icon: icon, color: colour, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.heading == 'to school' ? t('bus.morningToSchool') : t('bus.afternoonHome'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trip.childLine,
                      style: TextStyle(fontSize: 12.5, color: colour, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Text(
                hhmm(trip.alightedAt ?? trip.boardedAt ?? trip.startedAt ?? trip.scheduledDepartureAt),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
          _Detail(label: t('bus.stop'), value: trip.stopName ?? '—'),
          _Detail(label: t('bus.vehicle'), value: [trip.vehicleLabel, trip.plate].where((e) => e != null).join(' · ')),
          _Detail(label: t('bus.driver'), value: trip.driverName ?? t('bus.notAssigned')),
          if (trip.boardedAt != null) _Detail(label: t('bus.gotOn'), value: hhmm(trip.boardedAt)),
          if (trip.alightedAt != null)
            _Detail(
              label: trip.leg == 'OUT' ? t('bus.atSchool') : t('bus.handedOver'),
              value: hhmm(trip.alightedAt),
            ),
        ],
      ),
    );
  }
}

/// Asking for today's drop-off to be somewhere else.
///
/// The parent CHOOSES from addresses the office has already approved and
/// pinned; they never type one. An address typed into a phone at 13:40 produces
/// a pin in the wrong neighbourhood, and the person who finds that out is a
/// child standing on a street they do not know.
class _DropoffCard extends StatefulWidget {
  const _DropoffCard({required this.child});

  final Child child;

  @override
  State<_DropoffCard> createState() => _DropoffCardState();
}

class _DropoffCardState extends State<_DropoffCard> {
  bool _loading = true;
  String? _usual;
  String _note = '';
  List<DropoffOption> _options = const [];
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ParentApi.instance.dropoffOptions(widget.child.studentId);
      if (!mounted) return;
      setState(() {
        _usual = data.usualStop;
        _options = data.options;
        _note = data.note;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(DropoffOption option) async {
    setState(() => _busyId = option.id);
    try {
      await ParentApi.instance.requestDropoffChange(
        studentId: widget.child.studentId,
        alternateStopId: option.id,
      );
      if (!mounted) return;
      showNote(context, t('bus.sentToOffice'));
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 92,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEFF3),
          borderRadius: BorderRadius.circular(16),
        ),
      );
    }

    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_usual != null) ...[
            Text(
              tn('bus.usuallyAt', _usual!),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
          if (_options.isEmpty)
            Text(
              _note.isEmpty ? 'No other address has been approved for this child yet.' : _note,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.5),
            )
          else ...[
            ..._options.map(
              (o) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            o.landmark ?? o.stopName,
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _busyId == null ? () => _request(o) : null,
                      style: TextButton.styleFrom(foregroundColor: Role.parent.tint),
                      child: Text(_busyId == o.id ? t('bus.sending') : t('bus.useToday')),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              // The cut-off, said before it bites rather than as a refusal at
              // 14:05. Once the bus has left, its manifest is on a phone that
              // may have no signal, so this stops being data and becomes a call.
              t('bus.cutOff'),
              style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Timetable
 * ------------------------------------------------------------------------- */

class _TimetableSection extends StatelessWidget {
  const _TimetableSection({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Loader<List<DayOfLessons>>(
      key: ValueKey('tt-${child.studentId}'),
      tint: Role.parent.tint,
      load: () => ParentApi.instance.timetable(child.studentId),
      isEmpty: (days) => days.isEmpty,
      empty: t('hw.none'),
      builder: (context, days) {
        final today = todayWeekday();
        return Column(
          children: [
            const SizedBox(height: 10),
            ...days.map((d) {
              final isToday = d.weekday == today;
              final lessons = d.lessons.where((l) => l.kind == 'LESSON').toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card16(
                  color: isToday ? Role.parent.wash : null,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            humanise(d.weekday),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                          ),
                          const SizedBox(width: 8),
                          if (isToday) Pill(t('bus.today'), color: Role.parent.tint, background: AppTheme.surface),
                          const Spacer(),
                          Text(
                            '${lessons.length} lessons',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < lessons.length; i++)
                        TileRow(
                          icon: Icons.schedule_rounded,
                          color: parseHex(lessons[i].colorHex, Role.parent.tint),
                          title: lessons[i].subject,
                          subtitle: [
                            if (lessons[i].teacher != null) lessons[i].teacher!,
                            if (lessons[i].room != null) lessons[i].room!,
                          ].join(' · '),
                          trailing: clock(lessons[i].startMinute),
                          trailingColor: AppTheme.text,
                          last: i == lessons.length - 1,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/* ---------------------------------------------------------------------------
 * Homework
 * ------------------------------------------------------------------------- */

class _HomeworkSection extends StatelessWidget {
  const _HomeworkSection({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Loader<List<HomeworkItem>>(
      key: ValueKey('hw-${child.studentId}'),
      tint: Role.parent.tint,
      load: () => ParentApi.instance.homework(child.studentId),
      isEmpty: (rows) => rows.isEmpty,
      empty: t('hw.none'),
      builder: (context, rows) {
        // Overdue first, then due soonest. Sorting by the date it was set —
        // which is what the API returns — buries the piece due tomorrow under
        // three set this morning.
        final sorted = [...rows]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        return Column(
          children: [
            const SizedBox(height: 10),
            ...sorted.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card16(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HomeworkDetail(item: h, childName: child.name),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Chip36(
                            icon: Icons.assignment_rounded,
                            color: parseHex(h.colorHex, Role.parent.tint),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(
                                  '${h.subject}${h.teacher != null ? ' · ${h.teacher}' : ''}',
                                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Pill(
                            dueWord(h.daysLeft),
                            color: h.daysLeft < 0 ? AppTheme.rose : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textFaint),
                        ],
                      ),
                      if (h.description != null && h.description!.isNotEmpty) ...[
                        const SizedBox(height: 11),
                        Text(
                          h.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.event_rounded, size: 13, color: AppTheme.textFaint),
                          const SizedBox(width: 5),
                          Text(
                            tn('hw.due', longDate(h.dueDate)),
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                          ),
                          if (h.estimatedMinutes != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.schedule_rounded, size: 13, color: AppTheme.textFaint),
                            const SizedBox(width: 5),
                            Text(
                              'about ${h.estimatedMinutes} min',
                              style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/* ---------------------------------------------------------------------------
 * Marks
 * ------------------------------------------------------------------------- */

class _MarksSection extends StatelessWidget {
  const _MarksSection({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Loader<({List<ExamResultItem> results, List<UpcomingExam> upcoming})>(
      key: ValueKey('marks-${child.studentId}'),
      tint: Role.parent.tint,
      load: () async {
        final both = await Future.wait([
          ParentApi.instance.results(child.studentId),
          ParentApi.instance.upcomingExams(child.studentId),
        ]);
        return (results: both[0] as List<ExamResultItem>, upcoming: both[1] as List<UpcomingExam>);
      },
      isEmpty: (d) => d.results.isEmpty && d.upcoming.isEmpty,
      empty: t('marks.none'),
      builder: (context, data) {
        final marked = data.results.where((r) => r.percent != null).toList();
        final average = marked.isEmpty
            ? null
            : (marked.map((r) => r.percent!).reduce((a, b) => a + b) / marked.length).round();
        final passed = marked.where((r) => r.isPass == true).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            if (average != null)
              Card16(
                child: FigureStrip(
                  figures: [
                    Figure(label: t('marks.average'), value: '$average%', caption: tn('marks.across', marked.length)),
                    Figure(
                      label: t('marks.passed'),
                      value: '$passed',
                      caption: tn('marks.of', marked.length),
                      captionColor: AppTheme.green,
                    ),
                    Figure(
                      label: t('marks.best'),
                      value: '${marked.map((r) => r.percent!).reduce((a, b) => a > b ? a : b).round()}%',
                      caption: t('marks.topMark'),
                      captionColor: AppTheme.violet,
                    ),
                  ],
                ),
              ),
            if (data.upcoming.isNotEmpty) ...[
              Heading(t('marks.comingUp')),
              Card16(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: Column(
                  children: [
                    for (var i = 0; i < data.upcoming.length; i++)
                      TileRow(
                        icon: Icons.event_note_rounded,
                        color: parseHex(data.upcoming[i].colorHex, Role.parent.tint),
                        title: data.upcoming[i].title,
                        subtitle: '${data.upcoming[i].subject} · ${longDate(data.upcoming[i].date)}',
                        trailing: clock(data.upcoming[i].startMinute),
                        last: i == data.upcoming.length - 1,
                      ),
                  ],
                ),
              ),
            ],
            if (data.results.isNotEmpty) Heading(t('marks.published')),
            ...data.results.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ResultCard(item: r),
                )),
          ],
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item});

  final ExamResultItem item;

  @override
  Widget build(BuildContext context) {
    final pct = item.percent?.round();
    final colour = item.wasAbsent
        ? AppTheme.textMuted
        : item.isPass == false
            ? AppTheme.rose
            : (pct ?? 0) >= 85
                ? AppTheme.green
                : AppTheme.blue;

    return Card16(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              item.wasAbsent ? '—' : (item.gradeLetter ?? '$pct'),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: colour),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.examTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  '${item.subject} · ${shortDate(item.date)}',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Text(
            item.wasAbsent ? t('marks.absent') : '${item.score}/${item.maxScore}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: colour),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Attendance
 * ------------------------------------------------------------------------- */

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Loader<AttendanceSummary>(
      key: ValueKey('att-${child.studentId}'),
      tint: Role.parent.tint,
      load: () => ParentApi.instance.attendance(child.studentId),
      isEmpty: (a) => a.total == 0,
      empty: t('att.none'),
      builder: (context, a) {
        final rate = a.ratePercent;
        final colour = rate >= 95
            ? AppTheme.green
            : rate >= 85
                ? AppTheme.amber
                : AppTheme.rose;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Card16(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$rate%',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          color: colour,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          tn('att.ofDays', a.total),
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FigureStrip(
                    figures: [
                      Figure(label: t('att.present'), value: '${a.present}', captionColor: AppTheme.green),
                      Figure(label: t('att.absent'), value: '${a.absent}', captionColor: AppTheme.rose),
                      Figure(label: t('att.late'), value: '${a.late}', captionColor: AppTheme.amber),
                    ],
                  ),
                ],
              ),
            ),
            if (a.exceptions.isNotEmpty) ...[
              Heading(t('att.notPresent')),
              Card16(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: Column(
                  children: [
                    for (var i = 0; i < a.exceptions.length; i++)
                      TileRow(
                        icon: a.exceptions[i].status == 'ABSENT'
                            ? Icons.event_busy_rounded
                            : Icons.schedule_rounded,
                        color: a.exceptions[i].status == 'ABSENT' ? AppTheme.rose : AppTheme.amber,
                        title: longDate(a.exceptions[i].date),
                        subtitle: a.exceptions[i].reason,
                        trailing: a.exceptions[i].minutesLate != null
                            ? '${a.exceptions[i].minutesLate} min late'
                            : humanise(a.exceptions[i].status),
                        trailingColor:
                            a.exceptions[i].status == 'ABSENT' ? AppTheme.rose : AppTheme.amber,
                        last: i == a.exceptions.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/* ------------------------------------------------------------------------- */

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value, this.faint = false});

  final String label;
  final String value;
  final bool faint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: faint ? 12 : 13,
                fontWeight: faint ? FontWeight.w400 : FontWeight.w600,
                color: faint ? AppTheme.textFaint : AppTheme.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
