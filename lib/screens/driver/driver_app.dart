import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../api/session.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import 'crew_account.dart';
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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const role = Role.driver;
    final me = Session.instance.me;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: role.wash,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me?.firstName ?? 'Driver',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          longDate(DateTime.now()),
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      humanise(me?.role),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: role.tint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  _TodayTab(),
                  _HistoryTab(),
                  CrewAccountTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _Nav(index: _tab, onChanged: (i) => setState(() => _tab = i)),
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
      empty: 'No runs assigned to you today.',
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
      empty: 'No runs recorded yet.',
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
                        '${trip.leg == 'OUT' ? 'Morning — to school' : 'Afternoon — home'}'
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
                _Fig(label: 'To carry', value: '${trip.expected}'),
                _Fig(label: 'On board', value: '${trip.boarded - trip.alighted}'),
                _Fig(label: 'Dropped', value: '${trip.alighted}'),
                _Fig(label: 'Bus', value: trip.vehicleLabel ?? '—'),
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
                        'This run has ended and the cabin sweep is not confirmed.'
                        '${trip.sweepDeadlineAt != null ? ' Due by ${hhmm(trip.sweepDeadlineAt)}.' : ''}',
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
                  'Blocked: ${trip.complianceFailReasons.map(humanise).join(', ')}',
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
                      ? 'Confirm the sweep'
                      : trip.running
                          ? 'Continue the run'
                          : trip.finished
                              ? 'See what happened'
                              : 'Open the run',
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

class _Nav extends StatelessWidget {
  const _Nav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.today_rounded, Icons.today_outlined, 'Today'),
    (Icons.history_rounded, Icons.history_outlined, 'Past runs'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_items.length, (i) {
              final on = i == index;
              final item = _items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(on ? item.$1 : item.$2, size: 23, color: on ? Role.driver.tint : AppTheme.textFaint),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                          color: on ? Role.driver.tint : AppTheme.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
