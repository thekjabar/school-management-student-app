import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import 'home_tab.dart' show loadDutyTrip;
import 'route_strip.dart';
import 'trip_screen.dart';

/// The run, stop by stop.
///
/// The home screen answers "what next"; this answers "what is the shape of the
/// morning" — which stops are behind, which is live, and how many children are
/// waiting at each of the ones ahead.
class DriverRoute extends StatelessWidget {
  const DriverRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<_Run>(
      tint: Role.driver.tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 18),
      load: () async {
        final trip = await loadDutyTrip();
        if (trip == null) return _Run(trip: null, plan: null);
        return _Run(trip: trip, plan: await CrewApi.instance.plan(trip.id));
      },
      builder: (context, run) {
        final trip = run.trip;
        if (trip == null) {
          return Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                t('driver.noRunsToday'),
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ),
          );
        }

        final stops = run.plan?.stops ?? const <PlannedStop>[];
        final liveIndex = stops.indexWhere((s) => s.departedAt == null);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card16(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kCardRadius),
                child: SizedBox(
                  height: 150,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RouteStrip(stops: stops, tint: Role.driver.tint),
                      ),
                      PositionedDirectional(
                        start: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                trip.routeName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: Role.driver.tint,
                                ),
                              ),
                              Text(
                                '${run.plan?.counts.stopsDone ?? 0} / '
                                '${run.plan?.counts.stopsTotal ?? stops.length}  '
                                '${t('driver.stops')}',
                                style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: kCardGap),

            Card16(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionRow(
                    title: t('driver.theRun'),
                    actionLabel: t('driver.openRun'),
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TripScreen(tripId: trip.id)),
                    ),
                  ),
                  if (stops.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        t('driver.noStopsLeft'),
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                      ),
                    )
                  else
                    for (var i = 0; i < stops.length; i++)
                      _StopRow(
                        stop: stops[i],
                        leg: trip.leg,
                        first: i == 0,
                        last: i == stops.length - 1,
                        live: i == liveIndex,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => TripScreen(tripId: trip.id)),
                        ),
                      ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Run {
  _Run({required this.trip, required this.plan});

  final CrewTrip? trip;
  final TripPlan? plan;
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.leg,
    required this.first,
    required this.last,
    required this.live,
    required this.onTap,
  });

  final PlannedStop stop;
  final String leg;
  final bool first;
  final bool last;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;
    final done = stop.departedAt != null;
    final colour = done ? AppTheme.green : live ? tint : AppTheme.textFaint;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: first ? Colors.transparent : AppTheme.border,
                    ),
                  ),
                ),
                Container(
                  width: live ? 22 : 16,
                  height: live ? 22 : 16,
                  decoration: BoxDecoration(
                    color: done || live ? colour : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: done || live ? colour : AppTheme.border, width: 2),
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded, size: 10, color: Colors.white)
                      : live
                          ? const Icon(Icons.directions_bus_rounded, size: 12, color: Colors.white)
                          : null,
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: last ? Colors.transparent : AppTheme.border,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: BoxDecoration(
                  color: live
                      ? tint.withValues(alpha: AppTheme.dark ? 0.14 : 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        hhmm(stop.arrivedAt ?? stop.departedAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            leg == 'RETURN'
                                ? tn('driver.nToDropOff', stop.students.length)
                                : tn('driver.nToPickUp', stop.students.length),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pill(
                      done
                          ? t('driver.done')
                          : live
                              ? t('driver.ongoing')
                              : t('driver.waiting'),
                      color: colour,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
