import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// The bus tracker.
///
/// The one screen in this app where being wrong is expensive, so it is built
/// around a single rule: **never render a stale position as though it were
/// live.** A frozen dot with no timestamp is the most trust-destroying thing an
/// app of this kind can do — a parent or student stands at a kerb watching a bus
/// that stopped reporting eleven minutes ago — and once someone has been caught
/// by it once they never believe the screen again.
///
/// So the freshness of the fix is stated on every render, the card visibly
/// changes state when it goes stale, and the ETA is a BAND rather than a
/// countdown, because the underlying estimate is not precise enough to justify
/// a single number and a countdown that is wrong twice is never looked at again.
class BusScreen extends StatefulWidget {
  const BusScreen({super.key});

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  BusStatus? _status;
  Object? _error;
  Timer? _poll;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _fetch();
    // Ten seconds, matching the sampling rate the vehicles actually report at.
    // Polling faster buys nothing a person can perceive and costs battery and
    // metered data on a prepaid SIM.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _fetch());
    // A separate one-second tick so the "last seen" line keeps counting up
    // between fetches. Without it the screen looks frozen precisely when the
    // data has stopped arriving — the opposite of what it should convey.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _status != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final s = await repository.bus();
      if (mounted) setState(() { _status = s; _error = null; });
    } catch (e) {
      // Keep showing the last known position — with its real age — rather than
      // replacing it with an error. Old information honestly labelled is more
      // useful than none.
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bus Tracker')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        color: AppTheme.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 4, AppTheme.gutter, 28),
          children: [
            if (_status == null && _error == null)
              const LoadingSkeleton(height: 190, count: 1)
            else if (_status == null)
              ErrorPanel(message: _error.toString(), onRetry: _fetch)
            else ...[
              _StatusCard(status: _status!),
              const SectionLabel('Your stop'),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Stop',
                value: _status!.stopName,
              ),
              _DetailRow(
                icon: Icons.directions_bus_outlined,
                label: 'Vehicle',
                // The plate, because that is what a person standing at a kerb
                // can actually check against the bus in front of them.
                value: _status!.plate,
              ),
              _DetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Driver',
                value: _status!.driverName,
              ),
              const SectionLabel('Contact'),
              // The driver's own number is deliberately never shown. An
              // unlogged direct line between an adult and a child is exactly
              // what a safeguarding lead would tell you to remove, and the
              // office can reach the bus faster anyway.
              Panel(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: const Icon(Icons.support_agent_rounded,
                          size: 19, color: AppTheme.accent),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Call the school office',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('They can reach the bus directly',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 11.5)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 17, color: AppTheme.textMuted),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});
  final BusStatus status;

  @override
  Widget build(BuildContext context) {
    final stale = status.isStale;

    return Panel(
      dark: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Green only while the data is actually live. The moment it goes
              // stale the indicator turns amber and stops pulsing, so the state
              // of the screen matches the state of the information.
              _Dot(live: !stale),
              const SizedBox(width: 8),
              Text(
                status.freshnessLabel,
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4,
                  color: stale ? AppTheme.warm : const Color(0xFF4ADE80),
                ),
              ),
              const Spacer(),
              Text(
                status.plate,
                style: const TextStyle(
                  fontSize: 11, color: Color(0xFF8A8F98), letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(status.stateLabel, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          if (status.state == BusState.approaching) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${status.etaMinutesLow}–${status.etaMinutesHigh}',
                  style: const TextStyle(
                    fontSize: 38, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: -1.4, height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('minutes away',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9AA0A8))),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'A range, not a countdown — traffic and how long each stop takes '
              'move this by a few minutes either way.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8A8F98), height: 1.4),
            ),
          ] else
            Text(
              switch (status.state) {
                BusState.boarded => 'Scanned onto the bus. You will be scanned off at your stop.',
                BusState.atSchool => 'Arrived and scanned off at school.',
                BusState.delivered => 'Handed over at your stop.',
                BusState.homeward => 'On the return run.',
                _ => "Today's run has not started yet.",
              },
              style: const TextStyle(fontSize: 13, color: Color(0xFF9AA0A8), height: 1.4),
            ),
          if (stale) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warm.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 15, color: AppTheme.warm),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'This position is ${status.staleSeconds ~/ 60} minutes old. '
                      'The bus may have moved since.',
                      style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.warm, height: 1.35,
                      ),
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

/// A pulsing dot while live; a still one when not.
class _Dot extends StatefulWidget {
  const _Dot({required this.live});
  final bool live;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.live ? const Color(0xFF4ADE80) : AppTheme.warm;
    if (!widget.live) {
      return Container(
        width: 7, height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.55 + _c.value * 0.45),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35 * _c.value),
              blurRadius: 7, spreadRadius: 2.5 * _c.value,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textMuted),
            const SizedBox(width: 13),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
