import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';

/// One run, from the driver's seat.
///
/// The whole screen is one question repeated: WHO IS STILL NOT ACCOUNTED FOR.
/// The headcount line at the top answers it in words, every stop shows how many
/// of its children are outstanding, and the sweep at the bottom is the last
/// check before the bus is left.
class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final _loaderKey = GlobalKey<LoaderState<_TripData>>();
  bool _nearestFirst = false;
  String? _busy;

  Future<_TripData> _load() async {
    final api = CrewApi.instance;
    final results = await Future.wait([
      api.today(),
      api.plan(widget.tripId, nearest: _nearestFirst),
      api.sweepState(widget.tripId),
    ]);
    final trips = results[0] as List<CrewTrip>;
    return _TripData(
      trip: trips.where((t) => t.id == widget.tripId).firstOrNull,
      plan: results[1] as TripPlan,
      sweep: results[2] as SweepState,
    );
  }

  Future<void> _act(String label, Future<void> Function() action) async {
    setState(() => _busy = label);
    try {
      await action();
      _loaderKey.currentState?.reload();
      if (mounted) showNote(context, label);
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(t('driver.theRun')),
        backgroundColor: Role.driver.wash,
        surfaceTintColor: Colors.transparent,
      ),
      body: Loader<_TripData>(
        key: _loaderKey,
        tint: Role.driver.tint,
        load: _load,
        builder: (context, data) {
          final counts = data.plan.counts;
          final trip = data.trip;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _HeadcountCard(counts: counts),
              if (trip != null) ...[
                const SizedBox(height: 12),
                _RunControls(
                  trip: trip,
                  busy: _busy,
                  onStart: () => _act(t('driver.shiftStarted'), () => CrewApi.instance.startShift(trip.id)),
                  onDepart: () => _act(t('driver.departed'), () => CrewApi.instance.depart(trip.id)),
                  onEnd: () => _act(t('driver.runEnded'), () => CrewApi.instance.endTrip(trip.id)),
                ),
              ],
              SectionHead(t('driver.stops')),
              _OrderToggle(
                nearestFirst: _nearestFirst,
                note: data.plan.orderingNote,
                onChanged: (v) {
                  setState(() => _nearestFirst = v);
                  _loaderKey.currentState?.reload();
                },
              ),
              const SizedBox(height: 12),
              ...data.plan.stops.map(
                (s) => _StopCard(
                  stop: s,
                  tripId: widget.tripId,
                  leg: trip?.leg ?? 'OUT',
                  onChanged: () => _loaderKey.currentState?.reload(),
                ),
              ),
              SectionHead(t('driver.beforeYouLeave')),
              _SweepCard(
                sweep: data.sweep,
                busy: _busy != null,
                onConfirm: () => _act(
                  t('driver.sweepConfirmed'),
                  () => CrewApi.instance.confirmSweep(widget.tripId),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

class _TripData {
  _TripData({required this.trip, required this.plan, required this.sweep});

  final CrewTrip? trip;
  final TripPlan plan;
  final SweepState sweep;
}

/// The count, in words.
///
/// "40 on the register, 3 away, 37 to carry" is the sentence a driver says out
/// loud at the gate. Giving them the sentence rather than three numbers to
/// subtract is the difference between a check that happens and one that does
/// not.
class _HeadcountCard extends StatelessWidget {
  const _HeadcountCard({required this.counts});

  final Headcount counts;

  @override
  Widget build(BuildContext context) {
    final outstanding = counts.expected - counts.alighted;
    final allDone = outstanding <= 0 && counts.expected > 0;

    return Panel(
      color: allDone ? AppTheme.greenSoft : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            counts.summary.isEmpty
                ? '${counts.onRegister} on the register, ${counts.notComingToday} away, ${counts.expected} to carry.'
                : counts.summary,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Fig(label: t('driver.onBoard'), value: '${counts.stillOnBoard}', colour: AppTheme.blue),
              _Fig(label: t('driver.dropped'), value: '${counts.alighted}', colour: AppTheme.green),
              _Fig(
                label: t('driver.stillToDrop'),
                value: '$outstanding',
                colour: outstanding > 0 ? AppTheme.amber : AppTheme.textMuted,
              ),
              _Fig(label: t('driver.stops'), value: '${counts.stopsDone}/${counts.stopsTotal}', colour: AppTheme.text),
            ],
          ),
          if (counts.excluded.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 10),
            Text(
              t('driver.notRiding'),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 5),
            Text(
              counts.excluded.join(', '),
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _RunControls extends StatelessWidget {
  const _RunControls({
    required this.trip,
    required this.busy,
    required this.onStart,
    required this.onDepart,
    required this.onEnd,
  });

  final CrewTrip trip;
  final String? busy;
  final VoidCallback onStart;
  final VoidCallback onDepart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    // One button at a time, and it is always the next thing to do. Presenting
    // start, depart and end together invites the wrong one to be pressed on a
    // moving bus.
    final (String label, VoidCallback? action) = switch (trip.status) {
      'PLANNED' || 'ROSTERED' => (t('driver.startShift'), onStart),
      'BOARDING' => (t('driver.setOff'), onDepart),
      'IN_PROGRESS' => (t('driver.endRun'), onEnd),
      _ => (t('driver.runFinished'), null),
    };

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.directions_bus_filled_rounded,
                color: AppTheme.textMuted,
                background: Color(0xFFF1F3F6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip.vehicleLabel ?? t('driver.bus')}${trip.plate != null ? ' · ${trip.plate}' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    Text(
                      '${tn('driver.dueOut', hhmm(trip.scheduledDepartureAt))}'
                      '${trip.startedAt != null ? ' · ${tn('driver.departedAt', hhmm(trip.startedAt))}' : ''}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: busy != null ? null : action,
              style: FilledButton.styleFrom(
                backgroundColor: action == null ? AppTheme.border : Role.driver.tint,
                foregroundColor: action == null ? AppTheme.textMuted : AppTheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              ),
              child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderToggle extends StatelessWidget {
  const _OrderToggle({required this.nearestFirst, required this.note, required this.onChanged});

  final bool nearestFirst;
  final String note;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('driver.nearestFirst'),
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
              Switch(
                value: nearestFirst,
                activeTrackColor: Role.driver.tint,
                onChanged: onChanged,
              ),
            ],
          ),
          if (note.isNotEmpty)
            Text(
              note,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.45),
            ),
        ],
      ),
    );
  }
}

class _StopCard extends StatefulWidget {
  const _StopCard({
    required this.stop,
    required this.tripId,
    required this.leg,
    required this.onChanged,
  });

  final PlannedStop stop;
  final String tripId;
  final String leg;
  final VoidCallback onChanged;

  @override
  State<_StopCard> createState() => _StopCardState();
}

class _StopCardState extends State<_StopCard> {
  bool _open = false;
  String? _busyStudent;

  Future<void> _mark(RiderOnStop rider, String eventType) async {
    setState(() => _busyStudent = rider.studentId);
    try {
      await CrewApi.instance.recordCustody(
        tripId: widget.tripId,
        studentId: rider.studentId,
        eventType: eventType,
        stopId: widget.stop.stopId,
      );
      widget.onChanged();
      if (mounted) {
        showNote(context, '${rider.name.split(' ').first} — ${humanise(eventType).toLowerCase()}');
      }
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _busyStudent = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stop;
    final remaining = s.remaining;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.done
                            ? AppTheme.greenSoft
                            : remaining == 0
                                ? AppTheme.greenSoft
                                : Role.driver.wash,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: s.done || remaining == 0
                          ? Icon(Icons.check_rounded, size: 18, color: AppTheme.green)
                          : Text(
                              '${s.plannedSequence}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Role.driver.tint,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // The landmark, not the coordinates. In much of the
                            // Region a street address is not something a driver
                            // can navigate by; "opposite the mosque" is.
                            [
                              if (s.landmark != null) s.landmark!,
                              if (s.metresAway != null) '${s.metresAway} m away',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Tag(
                      remaining == 0 ? 'Done' : '$remaining left',
                      color: remaining == 0 ? AppTheme.green : AppTheme.amber,
                      background: remaining == 0 ? AppTheme.greenSoft : AppTheme.amberSoft,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppTheme.textFaint,
                    ),
                  ],
                ),
              ),
            ),
            if (_open) ...[
              Divider(height: 1, color: AppTheme.border),
              ...s.students.map((r) => _RiderRow(
                    rider: r,
                    leg: widget.leg,
                    busy: _busyStudent == r.studentId,
                    onBoard: () => _mark(r, 'BOARDED'),
                    onOff: () => _mark(r, widget.leg == 'OUT' ? 'ALIGHTED' : 'HANDOVER'),
                    onNoShow: () => _mark(r, 'NO_SHOW'),
                  )),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            await CrewApi.instance
                                .arriveAtStop(widget.tripId, s.plannedSequence);
                            widget.onChanged();
                          } on ApiException catch (e) {
                            if (context.mounted) showNote(context, e.message, bad: true);
                          }
                        },
                        child: Text(t('driver.arrived')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            await CrewApi.instance
                                .leaveStop(widget.tripId, s.plannedSequence);
                            widget.onChanged();
                          } on ApiException catch (e) {
                            if (context.mounted) showNote(context, e.message, bad: true);
                          }
                        },
                        child: Text(t('driver.movingOn')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RiderRow extends StatelessWidget {
  const _RiderRow({
    required this.rider,
    required this.leg,
    required this.busy,
    required this.onBoard,
    required this.onOff,
    required this.onNoShow,
  });

  final RiderOnStop rider;
  final String leg;
  final bool busy;
  final VoidCallback onBoard;
  final VoidCallback onOff;
  final VoidCallback onNoShow;

  @override
  Widget build(BuildContext context) {
    final onBus = rider.boardedAt != null && rider.alightedAt == null;
    final off = rider.alightedAt != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: off
                  ? AppTheme.greenSoft
                  : onBus
                      ? AppTheme.blueSoft
                      : const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              rider.seatNumber ?? '·',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: off
                    ? AppTheme.green
                    : onBus
                        ? AppTheme.blue
                        : AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rider.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                    ),
                    if (rider.requiresAssistance) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.accessible_rounded, size: 14, color: AppTheme.amber),
                    ],
                  ],
                ),
                if (off)
                  Text(
                    '${leg == 'OUT' ? t('driver.atSchool') : t('driver.handedOver')} ${hhmm(rider.alightedAt)}',
                    style: TextStyle(fontSize: 11, color: AppTheme.green),
                  )
                else if (onBus)
                  Text(
                    tn('driver.onBoardSince', hhmm(rider.boardedAt)),
                    style: TextStyle(fontSize: 11, color: AppTheme.blue),
                  ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else if (!off)
            Row(
              children: [
                _Mini(
                  icon: onBus ? Icons.logout_rounded : Icons.login_rounded,
                  colour: onBus ? AppTheme.green : Role.driver.tint,
                  onTap: onBus ? onOff : onBoard,
                ),
                const SizedBox(width: 6),
                _Mini(icon: Icons.close_rounded, colour: AppTheme.rose, onTap: onNoShow),
              ],
            ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.colour, required this.onTap});

  final IconData icon;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: colour),
      ),
    );
  }
}

/// The last thing before the bus is locked.
class _SweepCard extends StatelessWidget {
  const _SweepCard({required this.sweep, required this.busy, required this.onConfirm});

  final SweepState sweep;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    if (!sweep.required_) {
      return Panel(
        child: Text(
          t('driver.sweepNotRequired'),
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
      );
    }

    if (sweep.confirmedAt != null) {
      return Panel(
        color: AppTheme.greenSoft,
        child: Row(
          children: [
            IconChip(
              icon: Icons.verified_rounded,
              color: AppTheme.green,
              background: AppTheme.surface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('driver.cabinSwept'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  Text(
                    tn('driver.confirmedAt', hhmm(sweep.confirmedAt)),
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final seconds = sweep.secondsRemaining ?? 0;
    final late = seconds <= 0;

    return Panel(
      color: late ? AppTheme.roseSoft : AppTheme.amberSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.event_seat_rounded,
                color: late ? AppTheme.rose : AppTheme.amber,
                background: AppTheme.surface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('driver.walkToBack'),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      late
                          ? t('driver.sweepDeadlinePassed')
                          : '${tn('driver.sweepDueBy', hhmm(sweep.deadlineAt))} — ${tn('driver.aboutMinutes', (seconds / 60).ceil())}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: late ? AppTheme.rose : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            // Said every time. In an Iraqi June a sealed cabin becomes lethal in
            // minutes, not hours, and this sentence is the reason the deadline
            // is short rather than convenient.
            '${t('driver.sweepHow')}${t('driver.sweepWhy')}',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: busy ? null : onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: late ? AppTheme.rose : AppTheme.amber,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              ),
              child: Text(
                t('driver.walkedTheBus'),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fig extends StatelessWidget {
  const _Fig({required this.label, required this.value, required this.colour});

  final String label;
  final String value;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: colour),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
