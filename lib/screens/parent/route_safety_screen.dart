import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

class RouteSafetyScreen extends StatelessWidget {
  const RouteSafetyScreen({super.key, required this.child});

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
            ScreenHeader(
              title: t('safety.title'),
              trailing: ChildPill(name: child.name, line: child.className, tint: tint),
            ),
            Expanded(
              child: Loader<RouteSafety>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
                load: () => ParentApi.instance.routeSafety(child.studentId),
                builder: (context, safety) => _Body(safety: safety),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.safety});

  final RouteSafety safety;

  @override
  Widget build(BuildContext context) {
    if (!safety.ridesTheBus) {
      return Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Center(
          child: Text(
            t('safety.notOnBus'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    if (safety.locationHidden) {
      return Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Center(
          child: Text(
            t('safety.locationHidden'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    final route = safety.route;
    final child = safety.child;
    final alerts = safety.alerts;
    final reaching = safety.reaching;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Period(safety: safety),
        const SizedBox(height: kCardGap),
        if (route != null) ...[
          _RouteCard(route: route),
          const SizedBox(height: kCardGap),
        ],
        if (child != null) ...[
          _ChildCard(child: child),
          const SizedBox(height: kCardGap),
        ],
        if (alerts != null) ...[
          _AlertsCard(alerts: alerts),
          const SizedBox(height: kCardGap),
        ],
        if (reaching != null) ...[
          _ReachCard(reaching: reaching),
          const SizedBox(height: kCardGap),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            t('safety.explain'),
            style: TextStyle(fontSize: 11.5, height: 1.65, color: AppTheme.textFaint),
          ),
        ),
      ],
    );
  }
}

class _Period extends StatelessWidget {
  const _Period({required this.safety});

  final RouteSafety safety;

  @override
  Widget build(BuildContext context) {
    final from = DateTime.tryParse(safety.from);
    final to = DateTime.tryParse(safety.to);
    final name = safety.route?.name;

    return Card16(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.green.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.health_and_safety_outlined, size: 19, color: AppTheme.green),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (name != null && name.isNotEmpty) ? name : t('safety.subtitle'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.25,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayRange(from, to),
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route});

  final RouteSafetyRoute route;

  @override
  Widget build(BuildContext context) {
    if (!route.published) {
      return Card16(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(t('safety.routeTitle')),
            const SizedBox(height: 7),
            Text(
              t('safety.notPublished'),
              style: TextStyle(fontSize: 12.5, height: 1.6, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    final withheld = route.notEnoughRuns ? tn('safety.notEnough', route.minimumRuns) : null;

    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _CardTitle(t('safety.routeTitle'))),
              StatusChip(tn('safety.runsMeasured', route.tripsMeasured), color: AppTheme.textMuted),
            ],
          ),
          const SizedBox(height: 12),
          _Rate(
            label: t('safety.checksTitle'),
            body: tn('safety.checksBody', route.checksDue),
            value: route.checksCompletedRatePct,
            withheld: withheld,
            color: AppTheme.green,
          ),
          const SizedBox(height: 13),
          _Rate(
            label: t('safety.accountedTitle'),
            body: tn('safety.accountedBody', route.closuresMeasured),
            value: route.everyChildAccountedForRatePct,
            withheld: withheld,
            color: Role.parent.tint,
          ),
          const SizedBox(height: 13),
          _Rate(
            label: t('safety.onTimeTitle'),
            body: tn('safety.onTimeBody', (route.onTimeWithinSeconds / 60).round()),
            value: route.onTimeRatePct,
            withheld: withheld,
            color: AppTheme.amber,
          ),
          if (route.avgDelayMinutes != null && withheld == null) ...[
            const SizedBox(height: 11),
            Text(
              _delayLine(route.avgDelayMinutes!),
              style: TextStyle(fontSize: 11.5, height: 1.5, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  String _delayLine(double minutes) {
    final rounded = minutes.abs().round();
    if (rounded == 0) return t('safety.delayNone');
    return minutes > 0 ? tn('safety.delayLate', rounded) : tn('safety.delayEarly', rounded);
  }
}

class _Rate extends StatelessWidget {
  const _Rate({
    required this.label,
    required this.body,
    required this.value,
    required this.withheld,
    required this.color,
  });

  final String label;
  final String body;
  final double? value;
  final String? withheld;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shown = withheld == null ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppTheme.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (shown != null)
              Text(
                percent(shown),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.1,
                  color: color,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        if (shown != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (shown / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        const SizedBox(height: 5),
        Text(
          shown == null ? (withheld ?? t('safety.noRate')) : body,
          style: TextStyle(fontSize: 11.5, height: 1.5, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child});

  final RouteSafetyChild child;

  @override
  Widget build(BuildContext context) {
    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(t('safety.childTitle')),
          const SizedBox(height: 4),
          Text(
            t('safety.childBody'),
            style: TextStyle(fontSize: 11.5, height: 1.55, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 11),
          _Count(label: t('safety.childRidden'), value: '${child.tripsRidden} / ${child.tripsExpected}'),
          _Count(label: t('safety.childNoShows'), value: '${child.noShows}'),
          _Count(label: t('safety.childNotExpected'), value: '${child.notExpected}'),
          _Count(
            label: t('safety.childWrongPlace'),
            value: '${child.wrongPlace}',
            alarming: child.wrongPlace > 0,
          ),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.alerts});

  final RouteSafetyAlerts alerts;

  @override
  Widget build(BuildContext context) {
    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(t('safety.alertsTitle')),
          const SizedBox(height: 4),
          if (alerts.raised == 0)
            Text(
              t('safety.alertsNone'),
              style: TextStyle(fontSize: 12.5, height: 1.6, color: AppTheme.textMuted),
            )
          else ...[
            Text(
              t('safety.alertsBody'),
              style: TextStyle(fontSize: 11.5, height: 1.55, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 11),
            _Count(label: t('safety.alertsRaised'), value: '${alerts.raised}'),
            _Count(
              label: t('safety.alertsAnswered'),
              value: '${alerts.answered}',
              alarming: alerts.answered < alerts.raised,
            ),
            if (alerts.typicalAnswerSeconds != null)
              _Count(
                label: t('safety.alertsTypical'),
                value: tn('safety.minutes', (alerts.typicalAnswerSeconds! / 60).round()),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReachCard extends StatelessWidget {
  const _ReachCard({required this.reaching});

  final RouteSafetyReach reaching;

  @override
  Widget build(BuildContext context) {
    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(t('safety.reachTitle')),
          const SizedBox(height: 4),
          if (reaching.sent == 0)
            Text(
              t('safety.reachNone'),
              style: TextStyle(fontSize: 12.5, height: 1.6, color: AppTheme.textMuted),
            )
          else ...[
            Text(
              t('safety.reachBody'),
              style: TextStyle(fontSize: 11.5, height: 1.55, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 11),
            _Count(label: t('safety.reachSent'), value: '${reaching.sent}'),
            _Count(
              label: t('safety.reachDelivered'),
              value: '${reaching.delivered}',
              alarming: reaching.delivered < reaching.sent,
            ),
            if (reaching.delivered < reaching.sent) ...[
              const SizedBox(height: 7),
              Text(
                t('safety.reachFix'),
                style: TextStyle(fontSize: 11.5, height: 1.55, color: AppTheme.amber),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: AppTheme.text,
        ),
      );
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, this.alarming = false});

  final String label;
  final String value;
  final bool alarming;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: alarming ? AppTheme.amber : AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}
