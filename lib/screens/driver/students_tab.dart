import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import 'home_tab.dart' show loadDutyTrip;

/// Every child on today's run, and where each one is.
///
/// Grouped by state rather than by stop, because the question this screen
/// answers is "who is still not on" — a driver about to pull away wants the
/// four names, not the twelve stops those names are spread across.
class DriverStudents extends StatefulWidget {
  const DriverStudents({super.key});

  @override
  State<DriverStudents> createState() => _DriverStudentsState();
}

class _DriverStudentsState extends State<DriverStudents> {
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Loader<_Roster>(
      tint: Role.driver.tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 18),
      load: () async {
        final trip = await loadDutyTrip();
        if (trip == null) return _Roster(trip: null, riders: const []);
        final plan = await CrewApi.instance.plan(trip.id);
        return _Roster(
          trip: trip,
          riders: [
            for (final stop in plan.stops)
              for (final r in stop.students) _Rider(stop: stop, rider: r),
          ],
        );
      },
      builder: (context, roster) {
        if (roster.trip == null) {
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

        final all = roster.riders;
        final onBoard = all.where((r) => r.isOnBoard).length;
        final waiting = all.where((r) => r.isWaiting).length;
        final done = all.where((r) => r.isDone).length;

        final shown = all.where((r) {
          if (_query.isNotEmpty && !r.rider.name.toLowerCase().contains(_query)) return false;
          return switch (_filter) {
            _Filter.all => true,
            _Filter.waiting => r.isWaiting,
            _Filter.onBoard => r.isOnBoard,
            _Filter.done => r.isDone,
          };
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card16(
              padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
              child: IconFigureStrip(
                figures: [
                  IconFigure(
                    icon: Icons.groups_rounded,
                    label: t('driver.studentsOnRoute'),
                    value: '${all.length}',
                    caption: t('driver.onRoute'),
                    color: Role.driver.tint,
                  ),
                  IconFigure(
                    icon: Icons.person_add_alt_rounded,
                    label: t('driver.toPickUp'),
                    value: '$waiting',
                    caption: t('driver.waiting'),
                    color: AppTheme.amber,
                  ),
                  IconFigure(
                    icon: Icons.directions_bus_rounded,
                    label: t('driver.onBoard'),
                    value: '$onBoard',
                    caption: t('driver.onRoute'),
                    color: AppTheme.green,
                  ),
                  IconFigure(
                    icon: Icons.check_circle_outline_rounded,
                    label: t('driver.done'),
                    value: '$done',
                    caption: t('driver.school'),
                    color: AppTheme.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),

            _SearchBar(onChanged: (v) => setState(() => _query = v.trim().toLowerCase())),
            const SizedBox(height: 10),

            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in _Filter.values) ...[
                    _Chip(
                      label: switch (f) {
                        _Filter.all => t('driver.students'),
                        _Filter.waiting => t('driver.toPickUp'),
                        _Filter.onBoard => t('driver.onBoard'),
                        _Filter.done => t('driver.done'),
                      },
                      count: switch (f) {
                        _Filter.all => all.length,
                        _Filter.waiting => waiting,
                        _Filter.onBoard => onBoard,
                        _Filter.done => done,
                      },
                      on: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: kCardGap),

            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Center(
                  child: Text(
                    t('driver.noRoster'),
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              Card16(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: AppTheme.border),
                      _RiderRow(entry: shown[i], leg: roster.trip!.leg),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _Filter { all, waiting, onBoard, done }

class _Roster {
  _Roster({required this.trip, required this.riders});

  final CrewTrip? trip;
  final List<_Rider> riders;
}

class _Rider {
  _Rider({required this.stop, required this.rider});

  final PlannedStop stop;
  final RiderOnStop rider;

  bool get isOnBoard => rider.boardedAt != null && rider.alightedAt == null;
  bool get isDone => rider.alightedAt != null;
  bool get isWaiting => rider.boardedAt == null;
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: t('common.search'),
        prefixIcon: Icon(Icons.search_rounded, size: 19, color: AppTheme.textFaint),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.on,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? tint : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? tint : AppTheme.border),
        ),
        child: Text(
          '$label  $count',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: on ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _RiderRow extends StatelessWidget {
  const _RiderRow({required this.entry, required this.leg});

  final _Rider entry;
  final String leg;

  @override
  Widget build(BuildContext context) {
    final (colour, word) = entry.isDone
        ? (AppTheme.blue, leg == 'RETURN' ? t('driver.handedOver') : t('driver.atSchool'))
        : entry.isOnBoard
            ? (AppTheme.green, t('driver.onBoard'))
            : (AppTheme.amber, t('driver.waiting'));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          CircleInitials(label: entry.rider.name, tint: colour, size: 38),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.rider.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                    if (entry.rider.requiresAssistance) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.accessible_rounded, size: 14, color: AppTheme.violet),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.rider.boardedAt != null
                      ? tn('driver.onBoardSince', hhmm(entry.rider.boardedAt))
                      : entry.stop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pill(word, color: colour),
        ],
      ),
    );
  }
}
