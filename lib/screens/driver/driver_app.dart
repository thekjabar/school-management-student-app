import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import 'driver_drawer.dart';
import 'trip_screen.dart';

/// The driver and attendant app.
///
/// Two runs a day, and one of them is the only screen that matters. So the home
/// screen is not a dashboard: it is today's runs, largest first, with whatever
/// needs doing right now written on the button.
///
/// Everything is sized for a hand on a bus. Rows are tall, the primary action
/// is full width, and nothing important is behind a menu — a driver reading
/// this is standing in an aisle counting children, not sitting at a desk.
class DriverApp extends StatefulWidget {
  const DriverApp({super.key});

  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> {
  // Held so the header's menu button can open the drawer: the Scaffold that
  // owns it is built by this method, so there is no context above it to ask.
  final _scaffold = GlobalKey<ScaffoldState>();
  int _tab = 0;

  List<NavItem> get _nav => [
        NavItem(Icons.today_rounded, Icons.today_outlined, t('driver.today')),
        NavItem(Icons.history_rounded, Icons.history_outlined, t('driver.past')),
      ];

  @override
  Widget build(BuildContext context) {
    const role = Role.driver;
    final me = Session.instance.me;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? t('greet.morning')
        : hour < 17
            ? t('greet.afternoon')
            : t('greet.evening');

    return Scaffold(
      key: _scaffold,
      backgroundColor: AppTheme.canvas,
      // The account moved out of the bottom bar. A driver opens it once a term;
      // the two runs are what they open every morning.
      drawer: const DriverDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RoleHeader(
              role: role,
              greeting: greeting,
              name: me?.name ?? '',
              onAvatar: () => _scaffold.currentState?.openDrawer(),
              // The date, not a notification count: a driver's day is defined
              // by which day it is, and there is no inbox in this app.
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  shortDate(DateTime.now()),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: role.tint,
                  ),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  _TodayTab(),
                  _HistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        items: _nav,
        index: _tab,
        tint: role.tint,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _TodayTab extends StatefulWidget {
  const _TodayTab();

  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab> {
  final _loaderKey = GlobalKey<LoaderState<List<CrewTrip>>>();

  @override
  Widget build(BuildContext context) {
    return Loader<List<CrewTrip>>(
      key: _loaderKey,
      tint: Role.driver.tint,
      load: () => CrewApi.instance.today(),
      isEmpty: (rows) => rows.isEmpty,
      empty: t('driver.noRunsToday'),
      builder: (context, trips) {
        // Anything still owing a sweep goes to the top regardless of time. A
        // completed run with an unconfirmed cabin sweep is the one state in
        // this whole product that can end with a child left on a bus.
        final owing = trips.where((t) => t.sweepOwed).toList();
        final rest = trips.where((t) => !t.sweepOwed).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            if (owing.isNotEmpty) ...[
              for (final t in owing) _TripCard(trip: t, urgent: true, onChanged: _reload),
              const SizedBox(height: 6),
            ],
            for (final t in rest) _TripCard(trip: t, urgent: false, onChanged: _reload),
          ],
        );
      },
    );
  }

  void _reload() => _loaderKey.currentState?.reload();
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return Loader<List<CrewTrip>>(
      tint: Role.driver.tint,
      load: () => CrewApi.instance.trips(),
      isEmpty: (rows) => rows.isEmpty,
      empty: t('driver.noRunsYet'),
      builder: (context, trips) {
        final sorted = [...trips]..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
        return Column(
          children: [
            const SizedBox(height: 12),
            ...sorted.map((t) => _HistoryRow(trip: t)),
          ],
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.urgent, required this.onChanged});

  final CrewTrip trip;
  final bool urgent;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final blocked = trip.complianceGate == 'FAIL';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Panel(
        color: urgent ? AppTheme.roseSoft : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 40,
                  decoration: BoxDecoration(
                    color: parseHex(trip.routeColorHex, Role.driver.tint),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.routeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${trip.leg == 'OUT' ? t('driver.morningRun') : t('driver.afternoonRun')}'
                        ' · ${hhmm(trip.scheduledDepartureAt)}',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Tag(
                  humanise(trip.status),
                  color: trip.running
                      ? AppTheme.blue
                      : trip.finished
                          ? AppTheme.green
                          : AppTheme.textMuted,
                  background: trip.running
                      ? AppTheme.blueSoft
                      : trip.finished
                          ? AppTheme.greenSoft
                          : const Color(0xFFF1F3F6),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Fig(label: t('driver.toCarry'), value: '${trip.expected}'),
                _Fig(label: t('driver.onBoard'), value: '${trip.boarded - trip.alighted}'),
                _Fig(label: t('driver.dropped'), value: '${trip.alighted}'),
                _Fig(label: t('driver.bus'), value: trip.vehicleLabel ?? '—'),
              ],
            ),
            if (urgent) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded, color: AppTheme.rose, size: 19),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${t('driver.sweepOutstanding')}'
                        '${trip.sweepDeadlineAt != null ? ' ${tn('driver.sweepDueBy', hhmm(trip.sweepDeadlineAt))}.' : ''}',
                        style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.rose),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (blocked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.roseSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  // The gate refuses the run rather than warning about it, so
                  // the reasons have to be readable here or the driver is stuck
                  // at the depot with no idea why.
                  tn('driver.blocked', trip.complianceFailReasons.map(humanise).join(', ')),
                  style: TextStyle(fontSize: 12.5, color: AppTheme.rose, height: 1.45),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TripScreen(tripId: trip.id)),
                  );
                  onChanged();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: urgent ? AppTheme.rose : Role.driver.tint,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                ),
                child: Text(
                  urgent
                      ? t('driver.confirmSweep')
                      : trip.running
                          ? t('driver.continueRun')
                          : trip.finished
                              ? t('driver.seeWhatHappened')
                              : t('driver.openRun'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.trip});

  final CrewTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripScreen(tripId: trip.id)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                color: parseHex(trip.routeColorHex, Role.driver.tint),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.routeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  Text(
                    '${shortDate(trip.serviceDate)} · ${trip.leg == 'OUT' ? 'to school' : 'home'}',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              '${trip.alighted}/${trip.expected}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 10),
            Icon(
              trip.sweepOwed ? Icons.warning_rounded : Icons.check_circle_rounded,
              size: 18,
              color: trip.sweepOwed ? AppTheme.rose : AppTheme.green,
            ),
          ],
        ),
      ),
    );
  }
}

class _Fig extends StatelessWidget {
  const _Fig({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

