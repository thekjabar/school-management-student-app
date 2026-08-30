import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// What the school has said about how a child is getting on.
///
/// A verdict first, in a word, because that is what a parent came for — and
/// then the records it was drawn from, because a verdict nobody can check is
/// a verdict nobody believes. Everything here is a note a teacher wrote and
/// deliberately shared; nothing is inferred.
class AttitudeScreen extends StatefulWidget {
  const AttitudeScreen({super.key, required this.child});

  final Child child;

  @override
  State<AttitudeScreen> createState() => _AttitudeScreenState();
}

class _AttitudeScreenState extends State<AttitudeScreen> {
  int _tab = 0;
  final _seen = <String>{};

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('quick.attitude')),
            Expanded(
              child: Loader<AttitudeSummary>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
                load: () => ParentApi.instance.attitude(widget.child.studentId),
                empty: t('attitude.nothingYet'),
                isEmpty: (a) => a.notes.isEmpty && a.merits == 0 && a.concerns == 0,
                builder: (context, a) {
                  final notes = [...a.notes]
                    ..sort((x, y) => y.occurredAt.compareTo(x.occurredAt));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PillTabs(
                        tint: tint,
                        index: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                        tabs: [
                          TabSpec(label: t('att.overview'), icon: Icons.grid_view_rounded),
                          TabSpec(label: t('attitude.areas'), icon: Icons.list_rounded),
                          TabSpec(label: t('attitude.history'), icon: Icons.history_rounded),
                        ],
                      ),
                      const SizedBox(height: kCardGap),

                      if (_tab == 0) ...[
                        _VerdictCard(summary: a, name: widget.child.name),
                        const SizedBox(height: kCardGap),
                        _AreasCard(notes: notes),
                      ] else if (_tab == 1)
                        _AreasCard(notes: notes)
                      else
                        _TrendCard(notes: notes),
                      const SizedBox(height: kCardGap),

                      Card16(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionRow(title: t('attitude.whatTheySaid')),
                            for (var i = 0; i < notes.take(8).length; i++) ...[
                              if (i > 0) Divider(height: 1, color: AppTheme.border),
                              _NoteRow(
                                note: notes[i],
                                seen: _seen.contains(notes[i].id) || notes[i].seen,
                                onSeen: () => _acknowledge(notes[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: kCardGap),

                      NoticeBanner(
                        icon: a.concerns == 0
                            ? Icons.emoji_events_rounded
                            : Icons.visibility_outlined,
                        color: a.concerns == 0 ? AppTheme.green : AppTheme.amber,
                        title: a.concerns == 0
                            ? t('attitude.keepItUp')
                            : t('attitude.worthAWord'),
                        body: tn('attitude.summaryLine', widget.child.name.split(' ').first),
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

  Future<void> _acknowledge(AttitudeNote note) async {
    setState(() => _seen.add(note.id));
    try {
      await ParentApi.instance.markAttitudeSeen(note.id);
    } catch (_) {
      // The tick is a courtesy to the school, not a transaction. Leaving it
      // ticked locally is better than bouncing it back under the parent's
      // finger because the connection dropped in a school car park.
    }
  }
}

/* ---------------------------------------------------------------------------
 * The verdict
 * ------------------------------------------------------------------------- */

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.summary, required this.name});

  final AttitudeSummary summary;
  final String name;

  @override
  Widget build(BuildContext context) {
    final verdict = summary.verdict;
    final (colour, face) = switch (verdict) {
      'excellent' => (AppTheme.green, '😄'),
      'good' => (AppTheme.green, '🙂'),
      'settled' => (AppTheme.blue, '🙂'),
      'mixed' => (AppTheme.amber, '😐'),
      _ => (AppTheme.rose, '😟'),
    };

    // Five stars' worth of standing, from the records themselves: every merit
    // pulls up, every concern pulls down, and the scale is the same one the
    // school's own points use.
    final total = summary.merits + summary.concerns;
    final score = total == 0 ? 0.0 : (summary.merits / total) * 5;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('attitude.current')),
          Row(
            children: [
              Container(
                width: 78,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: AppTheme.dark ? 0.18 : 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(color: colour.withValues(alpha: 0.45), width: 2.5),
                ),
                child: Text(face, style: const TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('attitude.$verdict'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: colour,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tn('attitude.summaryLine', name),
                      style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: StatBox(
                  icon: Icons.trending_up_rounded,
                  value: total == 0 ? '—' : score.toStringAsFixed(1),
                  label: t('attitude.score'),
                  caption: t('attitude.outOfFive'),
                  color: AppTheme.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBox(
                  icon: Icons.military_tech_rounded,
                  value: '${summary.points}',
                  label: t('attitude.points'),
                  caption: t('attitude.running'),
                  color: AppTheme.violet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatBox(
                  icon: Icons.star_rounded,
                  value: '${summary.merits}',
                  label: t('attitude.merits'),
                  caption: t('attitude.thisTerm'),
                  color: AppTheme.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBox(
                  icon: Icons.error_outline_rounded,
                  value: '${summary.concerns}',
                  label: t('attitude.concerns'),
                  caption: t('attitude.thisTerm'),
                  color: AppTheme.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Where the records fall
 * ------------------------------------------------------------------------- */

class _AreasCard extends StatelessWidget {
  const _AreasCard({required this.notes});

  final List<AttitudeNote> notes;

  @override
  Widget build(BuildContext context) {
    // Grouped by what the school filed them under, biggest first — which is
    // the answer to "what is he actually being noticed for".
    final by = <String, List<AttitudeNote>>{};
    for (final n in notes) {
      (by[n.category] ??= []).add(n);
    }
    final areas = by.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final most = areas.isEmpty ? 1 : areas.first.value.length;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('attitude.areas')),
          if (areas.isEmpty)
            Text(
              t('attitude.nothingYet'),
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            )
          else
            for (final area in areas.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t('attitude.${area.key.toLowerCase()}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(
                          '${area.value.length}',
                          color: area.value.first.isMerit ? AppTheme.green : AppTheme.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (area.value.length / most).clamp(0, 1),
                        minHeight: 7,
                        backgroundColor: AppTheme.border,
                        valueColor: AlwaysStoppedAnimation(
                          area.value.first.isMerit ? AppTheme.green : AppTheme.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.notes});

  final List<AttitudeNote> notes;

  @override
  Widget build(BuildContext context) {
    // Points per month, oldest first. Six months is as far back as a term
    // stretches, and further back is somebody else's teacher.
    final now = DateTime.now();
    final months = <DateTime, int>{};
    for (var i = 5; i >= 0; i--) {
      months[DateTime(now.year, now.month - i)] = 0;
    }
    for (final n in notes) {
      final key = DateTime(n.occurredAt.year, n.occurredAt.month);
      if (months.containsKey(key)) months[key] = months[key]! + n.points;
    }

    final values = months.values.toList();
    final peak = values.fold<int>(1, (m, v) => v.abs() > m ? v.abs() : m);

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('attitude.trend')),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final entry in months.entries)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: entry.value < 0 ? AppTheme.rose : AppTheme.green,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            height: (entry.value.abs() / peak * 62).clamp(3, 62),
                            decoration: BoxDecoration(
                              color: entry.value < 0 ? AppTheme.rose : AppTheme.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              t('month.${entry.key.month}').characters.take(3).toString(),
                              style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * One record
 * ------------------------------------------------------------------------- */

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.seen, required this.onSeen});

  final AttitudeNote note;
  final bool seen;
  final VoidCallback onSeen;

  @override
  Widget build(BuildContext context) {
    final colour = note.isMerit ? AppTheme.green : AppTheme.amber;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  note.isMerit ? Icons.star_rounded : Icons.error_outline_rounded,
                  size: 20,
                  color: colour,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('attitude.${note.category.toLowerCase()}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      longDate(note.occurredAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                '${note.points > 0 ? '+' : ''}${note.points}',
                color: colour,
              ),
            ],
          ),
          if ((note.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              note.note!,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.text),
            ),
          ],
          if ((note.recordedByName ?? '').isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              tn('attitude.recordedBy', note.recordedByName!),
              style: TextStyle(fontSize: 10.5, color: AppTheme.textFaint),
            ),
          ],
          const SizedBox(height: 9),
          if (seen)
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 15, color: AppTheme.green),
                const SizedBox(width: 6),
                Text(
                  t('attitude.seen'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.green,
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: onSeen,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: Role.parent.tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  t('attitude.markSeen'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Role.parent.tint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
