import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';

String hoursClock(int minutes) {
  final whole = minutes < 0 ? 0 : minutes;
  return '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}';
}

String hoursHeadline(DrivingHours h) {
  if (h.past) return h.stopsTrips ? t('driver.hours.overBlocks') : t('driver.hours.overWarns');
  if (h.close) return t('driver.hours.close');
  return t('driver.hours.ok');
}

Color hoursColour(DrivingHours h) {
  if (h.past) return AppTheme.rose;
  if (h.close || h.breakDue) return AppTheme.amber;
  return AppTheme.green;
}

bool hoursWorthShowing(DrivingHours h) => h.past || h.close || h.breakDue || h.onDutyNow;

class HoursCard extends StatefulWidget {
  const HoursCard({super.key});

  @override
  State<HoursCard> createState() => _HoursCardState();
}

class _HoursCardState extends State<HoursCard> with FollowsReload<HoursCard> {
  DrivingHours? _hours;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void refetch() => _load();

  Future<void> _load() async {
    try {
      final hours = await CrewApi.instance.hours();
      if (mounted) setState(() => _hours = hours);
    } catch (_) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _hours;
    if (h == null || !hoursWorthShowing(h)) return const SizedBox.shrink();
    return HoursPanel(hours: h);
  }
}

class HoursPanel extends StatelessWidget {
  const HoursPanel({super.key, required this.hours});

  final DrivingHours hours;

  @override
  Widget build(BuildContext context) {
    final h = hours;
    final colour = hoursColour(h);

    return Padding(
      padding: const EdgeInsets.only(bottom: kCardGap),
      child: Card16(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        color: h.past || h.breakDue
            ? colour.withValues(alpha: AppTheme.dark ? 0.16 : 0.08)
            : null,
        border: h.past || h.breakDue ? colour.withValues(alpha: 0.45) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  h.past
                      ? Icons.report_problem_rounded
                      : h.breakDue
                          ? Icons.free_breakfast_rounded
                          : Icons.schedule_rounded,
                  size: 22,
                  color: colour,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('driver.hours.title'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colour,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hoursHeadline(h),
                        style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              h.breakDue
                  ? tn('driver.hours.breakNow', h.breakMinutes)
                  : tn('driver.hours.breakIn', hoursClock(h.minutesUntilBreakDue)),
              style: TextStyle(
                fontSize: 13,
                fontWeight: h.breakDue ? FontWeight.w800 : FontWeight.w600,
                color: h.breakDue ? colour : AppTheme.text,
              ),
            ),
            const SizedBox(height: 12),
            IconFigureStrip(
              figures: [
                IconFigure(
                  icon: Icons.directions_bus_filled_rounded,
                  label: t('driver.hours.drivingToday'),
                  value: hoursClock(h.drivingMinutesToday),
                  caption: tn('driver.hours.outOf', hoursClock(h.maxDutyMinutesPerDay)),
                  color: Role.driver.tint,
                ),
                IconFigure(
                  icon: Icons.local_cafe_rounded,
                  label: t('driver.hours.sinceBreak'),
                  value: hoursClock(h.currentDrivingStretchMinutes),
                  caption: tn('driver.hours.outOf', hoursClock(h.maxContinuousDrivingMinutes)),
                  color: AppTheme.amber,
                ),
                IconFigure(
                  icon: Icons.calendar_month_rounded,
                  label: t('driver.hours.thisWeek'),
                  value: hoursClock(h.dutyMinutesThisWeek),
                  caption: tn('driver.hours.outOf', hoursClock(h.maxDutyMinutesPerWeek)),
                  color: AppTheme.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
