import 'package:flutter/material.dart';
import 'student_info_screen.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../i18n/strings.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/motion.dart';
import 'attendance_screen.dart';
import 'leave_screen.dart';
import 'section_gate.dart';

class ChildrenTab extends StatelessWidget {
  const ChildrenTab({super.key, required this.children, required this.selected});

  final List<Child> children;
  final Child selected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PackageEntitlements>(
      valueListenable: Entitlements.instance.current,
      builder: (context, ent, _) => Loader<Map<String, _Snapshot>>(
        tint: Role.parent.tint,
        watch: [for (final c in children) '${c.studentId}|${ent.lockSignature(c.studentId)}'].join(';'),
        padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
        load: () async {
          await Entitlements.instance.ensureLoaded();
          final now = Entitlements.instance.current.value;
          final entries = await Future.wait(
            children.map((c) async {
              Future<T?> when<T>(String section, Future<T> Function() load) async {
                if (now.access(c.studentId, section) != SectionAccess.open) return null;
                try {
                  return await load();
                } on SectionLockedException {
                  return null;
                }
              }

              final attendance = when(
                ParentSection.attendance,
                () => ParentApi.instance.attendanceTrend(c.studentId, tenantId: c.tenantId),
              );
              final transport = when(
                ParentSection.bus,
                () => ParentApi.instance.transport(c.studentId, tenantId: c.tenantId),
              );
              final homework = when(
                ParentSection.assignments,
                () => ParentApi.instance.homework(c.studentId, tenantId: c.tenantId),
              );
              return MapEntry(
                c.studentId,
                _Snapshot(
                  trend: await attendance,
                  transport: await transport,
                  homework: await homework,
                ),
              );
            }),
          );
          return Map.fromEntries(entries);
        },
        builder: (context, snaps) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: kCardGap),
              Rise(
                index: i,
                child: _ChildCard(
                  child: children[i],
                  snap: snaps[children[i].studentId],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Snapshot {
  _Snapshot({
    required this.transport,
    required this.homework,
    required this.trend,
  });

  final TransportInfo? transport;
  final List<HomeworkItem>? homework;
  final AttendanceTrend? trend;

  String get busLine {
    final transport = this.transport;
    if (transport == null) return t('section.inPackage');
    if (!transport.ridesTheBus) return t('children.notOnBus');
    if (transport.today.isEmpty) return t('children.noBusToday');
    final out = transport.today.where((t) => t.leg == 'OUT').firstOrNull;
    final back = transport.today.where((t) => t.leg == 'RETURN').firstOrNull;
    if (back != null && (back.boardedAt != null || back.status == 'IN_PROGRESS')) {
      return '${t('children.homeRun')} · ${t(back.childLineKey).toLowerCase()}';
    }
    if (out != null) return '${t('children.morning')} · ${t(out.childLineKey).toLowerCase()}';
    return t('children.waitingForBus');
  }

  int get dueSoon {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return (homework ?? const <HomeworkItem>[])
        .where((h) => h.dueDate.difference(today).inDays <= 2)
        .length;
  }
}

IconFigure _lockedFigure(String label) => IconFigure(
      icon: Icons.lock_rounded,
      label: label,
      value: '—',
      caption: t('section.lockedShort'),
      color: AppTheme.textFaint,
    );

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.snap});

  final Child child;
  final _Snapshot? snap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final trend = snap?.trend;
    final marked = (trend?.daysMarked ?? 0) > 0;
    final dueSoon = snap?.dueSoon ?? 0;
    final look = attendanceBand(trend?.band);

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StudentInfoScreen(child: child)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.5),
                ),
                child: CircleInitials(label: child.name, tint: tint, size: 44),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${child.className} · ${child.code}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pill(humanise(child.relationship), color: tint),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
          IconFigureStrip(
            figures: [
              if (snap != null && trend == null)
                _lockedFigure(t('home.attendance'))
              else
                IconFigure(
                  icon: Icons.verified_user_outlined,
                  label: t('home.attendance'),
                  value: percent(trend?.attendanceRate),
                  caption: marked
                      ? tv('att.missedShort', {'n': percent(trend!.missedPercent)})
                      : t('home.notMarked'),
                  color: marked ? look.colour : AppTheme.textMuted,
                ),
              if (snap != null && snap!.homework == null)
                _lockedFigure(t('children.homework'))
              else
                IconFigure(
                  icon: Icons.assignment_outlined,
                  label: t('children.homework'),
                  value: '${snap?.homework?.length ?? 0}',
                  caption: dueSoon > 0
                      ? tn('children.dueSoon', dueSoon)
                      : t('children.nothingUrgent'),
                  color: dueSoon > 0 ? AppTheme.amber : AppTheme.blue,
                ),
              if (snap != null && snap!.transport == null)
                _lockedFigure(t('children.bus'))
              else
                IconFigure(
                  icon: Icons.directions_bus_rounded,
                  label: t('children.bus'),
                  value: snap?.transport?.ridesTheBus == true
                      ? t('children.yes')
                      : t('children.no'),
                  caption: snap?.transport?.routeName?.split('—').last.trim() ?? '—',
                  color: tint,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_bus_rounded, size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    snap?.busLine ?? t('bus.checking'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  label: t('children.open'),
                  tint: tint,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => StudentInfoScreen(child: child)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CardAction(
                  label: t('children.askLeave'),
                  onTap: () => openSection<void>(
                    context,
                    childId: child.studentId,
                    section: ParentSection.leave,
                    builder: (_) => LeaveScreen(child: child),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, required this.onTap, this.tint});

  final String label;
  final VoidCallback onTap;

  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusSm);
    final colour = tint;

    return Material(
      color: colour == null
          ? AppTheme.canvas
          : colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: colour == null ? Border.all(color: AppTheme.border) : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: colour ?? AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
