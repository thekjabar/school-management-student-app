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
  final _loaderKey = GlobalKey<LoaderState<_Roster>>();
  _Filter _filter = _Filter.all;
  String _query = '';
  String? _busyStudent;

  /// Board, drop off, or not travelling — written to the custody ledger.
  ///
  /// This list is where a driver looks for one name out of forty. It used to be
  /// read-only, so finding the name meant remembering which stop it was under
  /// and going to look for it again on the run screen.
  Future<void> _record(String tripId, _Rider entry, String eventType, String label) async {
    setState(() => _busyStudent = entry.rider.studentId);
    try {
      await CrewApi.instance.recordCustody(
        tripId: tripId,
        studentId: entry.rider.studentId,
        eventType: eventType,
        stopId: entry.stop.stopId,
      );
      _loaderKey.currentState?.reload();
      if (mounted) {
        showNote(context, '${entry.rider.name.split(' ').first} — $label');
      }
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busyStudent = null);
    }
  }

  Future<void> _openActions(String tripId, _Rider entry, String leg) async {
    final choice = await showModalBottomSheet<_Mark>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MarkSheet(entry: entry, leg: leg),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _Mark.boarded:
        await _record(tripId, entry, 'BOARDED', t('driver.onBoard'));
      case _Mark.dropped:
        await _record(
          tripId,
          entry,
          leg == 'OUT' ? 'ALIGHTED' : 'HANDOVER',
          leg == 'OUT' ? t('driver.atSchool') : t('driver.handedOver'),
        );
      case _Mark.noShow:
        await _record(tripId, entry, 'NO_SHOW', t('driver.notRiding'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<_Roster>(
      key: _loaderKey,
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
              // 44, not 34. These four are the fastest way to answer "who is
              // still not on", and they were the smallest targets on the
              // screen.
              height: 44,
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
                      _RiderRow(
                        entry: shown[i],
                        leg: roster.trip!.leg,
                        busy: _busyStudent == shown[i].rider.studentId,
                        // A child already off the bus has nothing left to
                        // record, so that row is not a tap that does nothing —
                        // it is not a tap.
                        onTap: shown[i].isDone
                            ? null
                            : () => _openActions(
                                  roster.trip!.id,
                                  shown[i],
                                  roster.trip!.leg,
                                ),
                      ),
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
  const _RiderRow({
    required this.entry,
    required this.leg,
    required this.busy,
    required this.onTap,
  });

  final _Rider entry;
  final String leg;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (colour, word) = entry.isDone
        ? (AppTheme.blue, leg == 'RETURN' ? t('driver.handedOver') : t('driver.atSchool'))
        : entry.isOnBoard
            ? (AppTheme.green, t('driver.onBoard'))
            : (AppTheme.amber, t('driver.waiting'));

    final row = Padding(
      // 14 top and bottom puts the row at 66 — a name on a list a driver
      // scrolls with a thumb while the engine is running.
      padding: const EdgeInsets.symmetric(vertical: 14),
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
          if (busy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: colour),
            )
          else ...[
            Pill(word, color: colour),
            // The chevron only where there is something to open, so the rows
            // that do nothing do not look like the rows that do.
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textFaint),
          ],
        ],
      ),
    );

    if (onTap == null || busy) return row;
    // The Material is inside the card, so the ripple lands on the card's own
    // surface. Without it the ink paints on the Scaffold, underneath an opaque
    // white card, and the row gives no sign of having been pressed at all.
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// What a tap on a name can record.
enum _Mark { boarded, dropped, noShow }

/// The sheet behind a name.
///
/// Full-width buttons, one per thing that can be written to the ledger, and
/// only the ones that make sense for where this child currently is. Every one
/// of them is a real event on the custody ledger — there is nothing here that
/// only closes the sheet.
class _MarkSheet extends StatelessWidget {
  const _MarkSheet({required this.entry, required this.leg});

  final _Rider entry;
  final String leg;

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                CircleInitials(label: entry.rider.name, tint: tint, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.rider.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!entry.isOnBoard) ...[
              BigButton(
                label: t('driver.markBoarded'),
                color: tint,
                height: 52,
                onPressed: () => Navigator.of(context).pop(_Mark.boarded),
              ),
              const SizedBox(height: 10),
            ],
            if (entry.isOnBoard) ...[
              BigButton(
                label: leg == 'RETURN' ? t('driver.handedOver') : t('driver.markDropped'),
                color: AppTheme.green,
                height: 52,
                onPressed: () => Navigator.of(context).pop(_Mark.dropped),
              ),
              const SizedBox(height: 10),
            ],
            if (entry.isWaiting)
              BigButton(
                label: t('driver.markNoShow'),
                color: AppTheme.rose,
                height: 52,
                onPressed: () => Navigator.of(context).pop(_Mark.noShow),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  t('common.cancel'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
