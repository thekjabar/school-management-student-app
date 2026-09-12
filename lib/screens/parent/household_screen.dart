import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/parent_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('household.title'), subtitle: t('household.subtitle')),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 10),
              child: PillTabs(
                tint: tint,
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
                tabs: [
                  TabSpec(label: t('household.tabDay'), icon: Icons.today_outlined),
                  TabSpec(label: t('household.tabFamily'), icon: Icons.family_restroom_outlined),
                ],
              ),
            ),
            Expanded(
              child: _tab == 0 ? const _DayTab() : const _FamilyTab(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab();

  @override
  Widget build(BuildContext context) {
    return Loader<HouseholdDay>(
      tint: Role.parent.tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
      load: () => ParentApi.instance.householdDay(),
      builder: (context, day) => _Day(day: day),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.day});

  final HouseholdDay day;

  @override
  Widget build(BuildContext context) {
    final closed = day.children.where((c) => c.closed).toList();
    final schools = Session.instance.me?.schoolsFor(kGuardianRoles).length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (schools > 1) ...[
          NoticeBanner(
            icon: Icons.school_outlined,
            color: AppTheme.blue,
            title: t('household.oneSchoolTitle'),
            body: tv('household.oneSchoolBody', {'name': day.school.name}),
          ),
          const SizedBox(height: kCardGap),
        ],
        if (day.overlaps.isNotEmpty) ...[
          NoticeBanner(
            icon: Icons.merge_type_rounded,
            color: AppTheme.amber,
            title: tn('household.overlapTitle', day.overlaps.length),
            body: t('household.overlapBody'),
          ),
          const SizedBox(height: kCardGap),
          for (final overlap in day.overlaps) ...[
            _OverlapCard(overlap: overlap),
            const SizedBox(height: kCardGap),
          ],
        ],
        if (closed.isNotEmpty) ...[
          for (final child in closed) ...[
            NoticeBanner(
              icon: Icons.event_busy_rounded,
              color: Role.parent.tint,
              title: tn('household.closedTitle', child.name),
              body: child.note ?? t('household.closedBody'),
            ),
            const SizedBox(height: kCardGap),
          ],
        ],
        if (day.events.isEmpty)
          Card16(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Icon(Icons.schedule_outlined, size: 30, color: AppTheme.textFaint),
                const SizedBox(height: 10),
                Text(
                  t('household.noTimes'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          )
        else
          Card16(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('household.timeline'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 10),
                for (final event in day.events) _EventRow(event: event),
              ],
            ),
          ),
        if (day.withoutTimes.isNotEmpty) ...[
          const SizedBox(height: kCardGap),
          Card16(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('household.withoutTitle'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 7),
                for (final row in day.withoutTimes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      tv('household.withoutRow', {
                        'name': row.childName,
                        'why': t('household.why.${row.reason}'),
                      }),
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OverlapCard extends StatelessWidget {
  const _OverlapCard({required this.overlap});

  final DayOverlap overlap;

  @override
  Widget build(BuildContext context) {
    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverlapSide(side: overlap.a),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(width: 22, height: 1, color: AppTheme.border),
                const SizedBox(width: 8),
                Text(
                  tn('household.minutesApart', overlap.minutesApart),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.amber,
                  ),
                ),
              ],
            ),
          ),
          _OverlapSide(side: overlap.b),
        ],
      ),
    );
  }
}

class _OverlapSide extends StatelessWidget {
  const _OverlapSide({required this.side});

  final DayOverlapSide side;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            hhmm(side.at),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppTheme.text,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${side.childName} · ${t('household.kind.${side.kind}')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text,
                ),
              ),
              if ((side.placeName ?? '').isNotEmpty)
                Text(
                  side.placeName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final DayEvent event;

  @override
  Widget build(BuildContext context) {
    final struck = event.cancelled;
    final when = event.actualAt ?? event.at;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              hhmm(when),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: struck ? AppTheme.textFaint : AppTheme.text,
                decoration: struck ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.childName} · ${t('household.kind.${event.kind}')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: struck ? AppTheme.textFaint : AppTheme.text,
                    decoration: struck ? TextDecoration.lineThrough : null,
                  ),
                ),
                if ((event.placeName ?? '').isNotEmpty)
                  Text(
                    event.placeName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                if (struck)
                  Text(
                    t('household.cancelled'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.amber,
                    ),
                  ),
              ],
            ),
          ),
          if (!struck && event.status.isNotEmpty && event.status != 'SCHEDULED') ...[
            const SizedBox(width: 8),
            StatusChip(t('household.status.${event.status}'), color: _statusColour(event.status)),
          ],
        ],
      ),
    );
  }

  Color _statusColour(String status) => switch (status) {
        'BOARDED' || 'ALIGHTED' || 'HANDED_OVER' || 'TRANSFERRED_IN' => AppTheme.green,
        'NO_SHOW' => AppTheme.amber,
        'EXCUSED' || 'NOT_EXPECTED' || 'NOT_APPLICABLE' => AppTheme.textMuted,
        _ => Role.parent.tint,
      };
}

class _FamilyTab extends StatelessWidget {
  const _FamilyTab();

  @override
  Widget build(BuildContext context) {
    return Loader<(HouseholdOverview, HouseholdConflicts)>(
      tint: Role.parent.tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
      load: () async {
        final r = await Future.wait<Object?>([
          ParentApi.instance.household(),
          ParentApi.instance.householdConflicts(),
        ]);
        return (r[0] as HouseholdOverview, r[1] as HouseholdConflicts);
      },
      builder: (context, both) => _Family(overview: both.$1, conflicts: both.$2),
    );
  }
}

class _Family extends StatelessWidget {
  const _Family({required this.overview, required this.conflicts});

  final HouseholdOverview overview;
  final HouseholdConflicts conflicts;

  ConflictHousehold? _conflictFor(String familyId) {
    for (final row in conflicts.households) {
      if (row.familyId == familyId) return row;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (overview.households.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Center(
          child: Text(
            t('common.noChildren'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overview.truncated) ...[
          NoticeBanner(
            icon: Icons.more_horiz_rounded,
            color: AppTheme.textMuted,
            title: tn('household.truncated', overview.maxChildren),
            body: t('household.truncatedBody'),
          ),
          const SizedBox(height: kCardGap),
        ],
        for (final group in overview.households) ...[
          _GroupCard(
            group: group,
            conflict: _conflictFor(group.familyId),
            phone: conflicts.school.phone ?? overview.school.phone,
          ),
          const SizedBox(height: kCardGap),
        ],
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.conflict, required this.phone});

  final HouseholdGroup group;
  final ConflictHousehold? conflict;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final problems = <HouseholdConflict>[
      ...?conflict?.conflicts,
      ...?conflict?.notes,
    ];

    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleInitials(label: group.name, tint: tint, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.text,
                      ),
                    ),
                    Text(
                      tn('household.childCount', group.children.length),
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          for (final child in group.children) _ChildRow(child: child),
          if (group.rules.anySet) ...[
            const SizedBox(height: 9),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 9),
            Text(
              t('household.rulesTitle'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 4),
            if (group.rules.releaseRule != 'NONE')
              _Bullet(t('household.rule.${group.rules.releaseRule}')),
            if (group.rules.mustShareRoute) _Bullet(t('household.rule.sameRoute')),
            if (group.rules.mustShareVehicle) _Bullet(t('household.rule.sameVehicle')),
            const SizedBox(height: 5),
            Text(
              t('household.rulesOnFile'),
              style: TextStyle(fontSize: 11, height: 1.5, color: AppTheme.textFaint),
            ),
          ],
          if (problems.isNotEmpty) ...[
            const SizedBox(height: 11),
            for (final problem in problems) ...[
              _ProblemRow(problem: problem),
              const SizedBox(height: 7),
            ],
            if ((phone ?? '').isNotEmpty)
              BigButton(
                label: t('household.callOffice'),
                color: AppTheme.amber,
                height: 42,
                onPressed: () => launchUrl(Uri.parse('tel:$phone')),
              ),
          ],
        ],
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({required this.child});

  final HouseholdChild child;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    if ((child.className ?? '').isNotEmpty) lines.add(child.className!);
    if ((child.campusName ?? '').isNotEmpty) lines.add(child.campusName!);

    final ride = child.rides.isEmpty ? null : child.rides.first;
    final stops = child.stopsHidden
        ? t('household.stopsHidden')
        : (ride == null
            ? null
            : [
                if ((ride.routeName ?? '').isNotEmpty) ride.routeName!,
                if ((ride.pickupStop ?? '').isNotEmpty) ride.pickupStop!,
              ].join(' · '));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: child.ridesTheBus ? AppTheme.green : AppTheme.border,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppTheme.text,
                  ),
                ),
                if (lines.isNotEmpty)
                  Text(
                    lines.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                if (child.ridesTheBus && stops != null && stops.isNotEmpty)
                  Text(
                    stops,
                    maxLines: 2,
                    style: TextStyle(fontSize: 11, height: 1.4, color: AppTheme.textFaint),
                  ),
                if (!child.ridesTheBus)
                  Text(
                    t('household.noBus'),
                    style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                  ),
                if (child.escortHidden)
                  Text(
                    t('household.escortHidden'),
                    style: TextStyle(fontSize: 11, height: 1.4, color: AppTheme.textFaint),
                  )
                else if ((child.escortName ?? '').isNotEmpty)
                  Text(
                    tn('household.escort', child.escortName!),
                    style: TextStyle(fontSize: 11, height: 1.4, color: AppTheme.textFaint),
                  ),
                if (!child.receivesRoutineAlerts)
                  Text(
                    t('household.noRoutineAlerts'),
                    style: TextStyle(fontSize: 11, height: 1.4, color: AppTheme.amber),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({required this.problem});

  final HouseholdConflict problem;

  @override
  Widget build(BuildContext context) {
    final text = tOr('household.problem.${problem.code}', problem.message);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: AppTheme.dark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.55, color: AppTheme.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: AppTheme.textFaint, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, height: 1.55, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
