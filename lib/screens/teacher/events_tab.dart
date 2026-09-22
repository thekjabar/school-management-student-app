import 'package:flutter/material.dart';

import '../../api/school_life.dart' show EventReplyKind;
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

String _when(TeacherEvent event) {
  final at = hhmm(event.startsAt);
  final ends = event.endsAt;
  if (ends == null) return '${longDate(event.startsAt)}  •  $at';
  return '${longDate(event.startsAt)}  •  $at – ${hhmm(ends)}';
}

Color _replyTint(String? reply) => switch (reply) {
      EventReplyKind.yes => AppTheme.green,
      EventReplyKind.no => AppTheme.rose,
      EventReplyKind.maybe => AppTheme.amber,
      _ => AppTheme.textMuted,
    };

String _replyWord(String? reply) => switch (reply) {
      EventReplyKind.yes => t('events.going'),
      EventReplyKind.no => t('events.notGoing'),
      EventReplyKind.maybe => t('events.maybe'),
      _ => t('events.silent'),
    };

class TeacherEventsScreen extends StatefulWidget {
  const TeacherEventsScreen({super.key});

  @override
  State<TeacherEventsScreen> createState() => _TeacherEventsScreenState();
}

class _TeacherEventsScreenState extends State<TeacherEventsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('events.title')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: PillTabs(
                tint: tint,
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
                tabs: [
                  TabSpec(label: t('events.coming'), icon: Icons.event_rounded),
                  TabSpec(
                    label: t('events.past'),
                    icon: Icons.history_rounded,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),
            Expanded(
              child: Loader<List<TeacherEvent>>(
                tint: tint,
                watch: '$_tab',
                padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24)),
                load: () => TeacherApi.instance.events(
                  from: DateTime.now().subtract(const Duration(days: 120)),
                ),
                isEmpty: (rows) => _visible(rows).isEmpty,
                empty: t('events.none'),
                builder: (context, rows) => Column(
                  children: [
                    for (final e in _visible(rows))
                      Padding(
                        padding: const EdgeInsets.only(bottom: kCardGap),
                        child: _EventCard(
                          event: e,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => TeacherEventScreen(event: e)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TeacherEvent> _visible(List<TeacherEvent> rows) {
    final now = DateTime.now();
    final list = _tab == 1
        ? rows.where((e) => e.startsAt.isBefore(now)).toList()
        : rows.where((e) => !e.startsAt.isBefore(now)).toList();
    list.sort((a, b) => _tab == 1
        ? b.startsAt.compareTo(a.startsAt)
        : a.startsAt.compareTo(b.startsAt));
    return list;
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final TeacherEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = event.cancelled ? AppTheme.textMuted : Role.teacher.tint;
    final place = event.placeText;

    return Card16(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(icon: Icons.celebration_outlined, color: tint),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  event.titleText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppTheme.text,
                  ),
                ),
              ),
              if (event.cancelled)
                StatusChip(t('events.calledOff'), color: AppTheme.rose)
              else if (event.wholeSchool)
                StatusChip(t('events.wholeSchool'), color: AppTheme.violet),
            ],
          ),
          const SizedBox(height: 10),
          _Line(icon: Icons.schedule_rounded, text: _when(event)),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 5),
            _Line(icon: Icons.place_outlined, text: place),
          ],
          if (event.replyWanted) ...[
            const SizedBox(height: 5),
            _Line(icon: Icons.how_to_reg_outlined, text: t('events.repliesWanted')),
          ],
        ],
      ),
    );
  }
}

class TeacherEventScreen extends StatelessWidget {
  const TeacherEventScreen({super.key, required this.event});

  final TeacherEvent event;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: event.titleText),
            Expanded(
              child: Loader<TeacherEventDetail>(
                tint: tint,
                padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24)),
                load: () => TeacherApi.instance.event(event.id),
                builder: (context, detail) {
                  final about = detail.event.descriptionText;
                  final place = detail.event.placeText;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card16(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Line(icon: Icons.schedule_rounded, text: _when(detail.event)),
                            if (place.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              _Line(icon: Icons.place_outlined, text: place),
                            ],
                            if (detail.event.replyClosesAt != null) ...[
                              const SizedBox(height: 5),
                              _Line(
                                icon: Icons.event_available_outlined,
                                text: tn('events.replyBy', longDate(detail.event.replyClosesAt)),
                              ),
                            ],
                            if (about.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                about,
                                style: TextStyle(fontSize: 12.5, height: 1.55, color: AppTheme.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (detail.event.replyWanted && detail.classes.isNotEmpty) ...[
                        const SizedBox(height: kCardGap),
                        _TallyCard(tally: detail.total, headcount: detail.event.headcountWanted),
                      ],
                      const SizedBox(height: 18),
                      if (detail.classes.isEmpty)
                        Card16(
                          child: Text(
                            t('events.noClassOfYours'),
                            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                          ),
                        )
                      else
                        for (final c in detail.classes) ...[
                          SectionRow(title: c.classText),
                          _ClassCard(
                            replies: c,
                            wantsReplies: detail.event.replyWanted,
                            headcount: detail.event.headcountWanted,
                          ),
                          const SizedBox(height: kCardGap),
                        ],
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

class _TallyCard extends StatelessWidget {
  const _TallyCard({required this.tally, required this.headcount});

  final EventTally tally;
  final bool headcount;

  @override
  Widget build(BuildContext context) {
    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _Count(label: t('events.going'), value: tally.yes, color: AppTheme.green)),
              Expanded(child: _Count(label: t('events.maybe'), value: tally.maybe, color: AppTheme.amber)),
              Expanded(child: _Count(label: t('events.notGoing'), value: tally.no, color: AppTheme.rose)),
              Expanded(child: _Count(label: t('events.silent'), value: tally.silent, color: AppTheme.textMuted)),
            ],
          ),
          if (headcount) ...[
            const SizedBox(height: 12),
            _Line(icon: Icons.groups_outlined, text: tn('events.peopleComing', tally.people)),
          ],
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.replies,
    required this.wantsReplies,
    required this.headcount,
  });

  final EventClassReplies replies;
  final bool wantsReplies;
  final bool headcount;

  @override
  Widget build(BuildContext context) {
    if (replies.students.isEmpty) {
      return Card16(
        child: Text(
          t('events.noChildren'),
          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
        ),
      );
    }

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        children: [
          for (final s in replies.students)
            TileRow(
              icon: s.coming ? Icons.check_rounded : Icons.person_outline_rounded,
              color: wantsReplies ? _replyTint(s.reply) : Role.teacher.tint,
              title: s.childName,
              subtitle: [s.rollNumber, s.code].whereType<String>().join('  •  '),
              trailing: wantsReplies ? _replyWord(s.reply) : null,
              trailingSub: wantsReplies && headcount && s.coming ? '${s.headcount}' : null,
              trailingColor: wantsReplies ? _replyTint(s.reply) : null,
              last: s.studentId == replies.students.last.studentId,
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}
