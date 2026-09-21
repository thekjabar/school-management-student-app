import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';

const _moodIcons = <String, IconData>{
  'HAPPY': Icons.sentiment_very_satisfied_rounded,
  'CALM': Icons.self_improvement_rounded,
  'PLAYFUL': Icons.toys_rounded,
  'TIRED': Icons.bedtime_rounded,
  'UPSET': Icons.sentiment_dissatisfied_rounded,
  'UNWELL': Icons.sick_rounded,
};

const _mealIcons = <String, IconData>{
  'BREAKFAST': Icons.free_breakfast_rounded,
  'SNACK': Icons.cookie_rounded,
  'LUNCH': Icons.restaurant_rounded,
};

const _mealOrder = ['BREAKFAST', 'SNACK', 'LUNCH'];

Color moodColour(String? mood) => switch (mood) {
      'HAPPY' => AppTheme.green,
      'CALM' => AppTheme.blue,
      'PLAYFUL' => AppTheme.violet,
      'TIRED' => AppTheme.amber,
      'UPSET' => AppTheme.rose,
      'UNWELL' => AppTheme.rose,
      _ => AppTheme.blue,
    };

String moodName(String? mood) => mood == null ? '' : t('dailyReport.mood.$mood');

String dayName(DateTime day) {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  final theirs = DateTime(day.year, day.month, day.day);
  final apart = midnight.difference(theirs).inDays;
  if (apart == 0) return t('dailyReport.today');
  if (apart == 1) return t('dailyReport.yesterday');
  return longDate(day);
}

class DailyReportScreen extends StatelessWidget {
  const DailyReportScreen({super.key, required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Heading(),
            Expanded(
              child: Loader<List<DailyReport>>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
                watch: child.studentId,
                load: () => ParentApi.instance.dailyReports(child.studentId),
                isEmpty: (days) => days.isEmpty,
                empty: t('dailyReport.none'),
                builder: (context, days) => _Days(days: days, tint: tint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 12),
      child: Row(
        children: [
          SquareButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('dailyReport.title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                    height: 1.1,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t('dailyReport.subtitle'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.35, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Days extends StatefulWidget {
  const _Days({required this.days, required this.tint});

  final List<DailyReport> days;
  final Color tint;

  @override
  State<_Days> createState() => _DaysState();
}

class _DaysState extends State<_Days> {
  int _at = 0;

  @override
  void didUpdateWidget(covariant _Days old) {
    super.didUpdateWidget(old);
    if (_at >= widget.days.length) _at = 0;
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.days[_at];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.days.length > 1) ...[
          _DayStrip(
            days: widget.days,
            at: _at,
            tint: widget.tint,
            onPick: (i) => setState(() => _at = i),
          ),
          const SizedBox(height: kCardGap),
        ],
        _DayBody(day: day, tint: widget.tint),
      ],
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.at,
    required this.tint,
    required this.onPick,
  });

  final List<DailyReport> days;
  final int at;
  final Color tint;
  final void Function(int index) onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = days[i].day;
          final on = i == at;
          return GestureDetector(
            onTap: () => onPick(i),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? tint : AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: on ? tint : AppTheme.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t('day.${day.weekday}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: on ? Colors.white : AppTheme.text,
                    ),
                  ),
                  Text(
                    t('monthShort.${day.month}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: on ? Colors.white70 : AppTheme.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DayBody extends StatelessWidget {
  const _DayBody({required this.day, required this.tint});

  final DailyReport day;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final activities = day.activities;
    final note = day.carerNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MoodCard(day: day),
        const SizedBox(height: kCardGap),

        if (day.meals.isNotEmpty) ...[
          _MealsCard(day: day, tint: tint),
          const SizedBox(height: kCardGap),
        ],

        if (day.naps.isNotEmpty) ...[
          _SleepCard(day: day),
          const SizedBox(height: kCardGap),
        ],

        if (day.toilet.isNotEmpty) ...[
          _ToiletCard(day: day),
          const SizedBox(height: kCardGap),
        ],

        if (activities != null && activities.trim().isNotEmpty) ...[
          _TextCard(
            title: t('dailyReport.activities'),
            icon: Icons.palette_outlined,
            colour: AppTheme.violet,
            body: activities,
          ),
          const SizedBox(height: kCardGap),
        ],

        if (day.photos.isNotEmpty) ...[
          _PhotosCard(day: day, tint: tint),
          const SizedBox(height: kCardGap),
        ],

        if (day.bringTomorrow.isNotEmpty) ...[
          _BringCard(items: day.bringTomorrow),
          const SizedBox(height: kCardGap),
        ],

        if (note != null && note.trim().isNotEmpty) ...[
          _TextCard(
            title: t('dailyReport.note'),
            icon: Icons.sticky_note_2_outlined,
            colour: AppTheme.blue,
            body: note,
          ),
          const SizedBox(height: kCardGap),
        ],
      ],
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.day});

  final DailyReport day;

  @override
  Widget build(BuildContext context) {
    final mood = day.mood;
    final colour = moodColour(mood);
    final className = day.classLabel;
    final sentAt = day.sentAt;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: AppTheme.dark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              mood == null ? Icons.child_care_rounded : (_moodIcons[mood] ?? Icons.child_care_rounded),
              size: 27,
              color: colour,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName(day.day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (mood != null) moodName(mood),
                    if (className.isNotEmpty) className,
                    if (sentAt != null) tv('dailyReport.sentAt', {'time': hhmm(sentAt)}),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.35, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealsCard extends StatelessWidget {
  const _MealsCard({required this.day, required this.tint});

  final DailyReport day;
  final Color tint;

  static Color _amountColour(String amount) => switch (amount) {
        'ALL' => AppTheme.green,
        'SOME' => AppTheme.amber,
        _ => AppTheme.rose,
      };

  @override
  Widget build(BuildContext context) {
    final meals = [...day.meals]
      ..sort((a, b) => _mealOrder.indexOf(a.meal).compareTo(_mealOrder.indexOf(b.meal)));

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('dailyReport.meals'), dense: true),
          for (final meal in meals) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip36(
                    icon: _mealIcons[meal.meal] ?? Icons.restaurant_rounded,
                    color: tint,
                    size: 30,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('dailyReport.meal.${meal.meal}'),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        if (meal.note != null && meal.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            meal.note!,
                            style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Pill(
                    t('dailyReport.amount.${meal.amount}'),
                    color: _amountColour(meal.amount),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard({required this.day});

  final DailyReport day;

  @override
  Widget build(BuildContext context) {
    final total = day.sleepMinutes;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('dailyReport.sleep'), dense: true),
          for (final nap in day.naps) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Chip36(icon: Icons.bedtime_outlined, color: AppTheme.violet, size: 30),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      nap.endedAt == null
                          ? tv('dailyReport.napOpen', {'time': hhmm(nap.startedAt)})
                          : tv('dailyReport.napSpan', {
                              'from': hhmm(nap.startedAt),
                              'to': hhmm(nap.endedAt),
                            }),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  if (nap.minutes != null) ...[
                    const SizedBox(width: 9),
                    Pill(tn('dailyReport.minutes', nap.minutes!), color: AppTheme.violet),
                  ],
                ],
              ),
            ),
          ],
          if (total > 0)
            Text(
              tn('dailyReport.sleepTotal', total),
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
        ],
      ),
    );
  }
}

class _ToiletCard extends StatelessWidget {
  const _ToiletCard({required this.day});

  final DailyReport day;

  static Color _kindColour(String kind) => switch (kind) {
        'NAPPY_DRY' => AppTheme.green,
        'ACCIDENT' => AppTheme.rose,
        _ => AppTheme.amber,
      };

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('dailyReport.toilet'), dense: true),
          for (final entry in day.toilet) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      hhmm(entry.at),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('dailyReport.toiletKind.${entry.kind}'),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _kindColour(entry.kind),
                          ),
                        ),
                        if (entry.note != null && entry.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            entry.note!,
                            style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BringCard extends StatelessWidget {
  const _BringCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      color: AppTheme.amber.withValues(alpha: AppTheme.dark ? 0.16 : 0.09),
      border: AppTheme.amber.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('dailyReport.bring'), dense: true),
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.amber),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.title,
    required this.icon,
    required this.colour,
    required this.body,
  });

  final String title;
  final IconData icon;
  final Color colour;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(icon: icon, color: colour, size: 30),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            body,
            style: TextStyle(fontSize: 13, height: 1.55, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.day, required this.tint});

  final DailyReport day;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('dailyReport.photos'), dense: true),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: day.photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
            ),
            itemBuilder: (context, i) {
              final photo = day.photos[i];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => _Viewer(photos: day.photos, at: i),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: photo.thumbnailUrl == null
                      ? Container(color: tint.withValues(alpha: 0.12))
                      : Image.network(
                          photo.thumbnailUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, widget, progress) => progress == null
                              ? widget
                              : Container(color: tint.withValues(alpha: 0.12)),
                          errorBuilder: (_, _, _) => Container(color: tint.withValues(alpha: 0.12)),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Viewer extends StatefulWidget {
  const _Viewer({required this.photos, required this.at});

  final List<DailyPhoto> photos;
  final int at;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final PageController _pages = PageController(initialPage: widget.at);
  late int _at = widget.at;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.photos[_at].caption;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.photos.length,
                onPageChanged: (i) => setState(() => _at = i),
                itemBuilder: (context, i) {
                  final url = widget.photos[i].url;
                  if (url == null) {
                    return const Center(
                      child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.white38),
                    );
                  }
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, widget, progress) => progress == null
                            ? widget
                            : const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white54,
                                ),
                              ),
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.white38),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (caption != null && caption.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
