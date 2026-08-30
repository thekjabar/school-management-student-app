import 'package:flutter/material.dart';
import 'student_info_screen.dart';

import '../../api/parent_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../i18n/strings.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import 'leave_screen.dart';

/// Every child on this account, with the one number that matters next to each.
///
/// A family with three at the school gets three cards rather than a picker they
/// have to work through one at a time — this is the screen for "how are they
/// all doing", which the home screen deliberately cannot answer.
class ChildrenTab extends StatelessWidget {
  const ChildrenTab({super.key, required this.children, required this.selected});

  final List<Child> children;
  final Child selected;

  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, _Snapshot>>(
      tint: Role.parent.tint,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      load: () async {
        // One pass per child, all in flight together. Three children on a slow
        // cell is three round trips either way; doing them in sequence just
        // makes the parent wait three times as long.
        final entries = await Future.wait(
          children.map((c) async {
            final r = await Future.wait([
              ParentApi.instance.attendance(c.studentId),
              ParentApi.instance.transport(c.studentId),
              ParentApi.instance.homework(c.studentId),
            ]);
            return MapEntry(
              c.studentId,
              _Snapshot(
                attendance: r[0] as AttendanceSummary,
                transport: r[1] as TransportInfo,
                homework: r[2] as List<HomeworkItem>,
              ),
            );
          }),
        );
        return Map.fromEntries(entries);
      },
      builder: (context, snaps) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ChildCard(child: c, snap: snaps[c.studentId]),
            ),
        ],
      ),
    );
  }
}

class _Snapshot {
  _Snapshot({required this.attendance, required this.transport, required this.homework});

  final AttendanceSummary attendance;
  final TransportInfo transport;
  final List<HomeworkItem> homework;

  /// What is happening to this child on the bus right now, in one line.
  String get busLine {
    if (!transport.ridesTheBus) return t('children.notOnBus');
    if (transport.today.isEmpty) return t('children.noBusToday');
    final out = transport.today.where((t) => t.leg == 'OUT').firstOrNull;
    final back = transport.today.where((t) => t.leg == 'RETURN').firstOrNull;
    // The afternoon run is the live question after the morning one is done.
    if (back != null && (back.boardedAt != null || back.status == 'IN_PROGRESS')) {
      return '${t('children.homeRun')} · ${back.childLine.toLowerCase()}';
    }
    if (out != null) return '${t('children.morning')} · ${out.childLine.toLowerCase()}';
    return t('children.waitingForBus');
  }

  int get dueSoon {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return homework.where((h) => h.dueDate.difference(today).inDays <= 2).length;
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.snap});

  final Child child;
  final _Snapshot? snap;

  @override
  Widget build(BuildContext context) {
    final rate = snap?.attendance.ratePercent;
    final marked = (snap?.attendance.total ?? 0) > 0;

    return Card16(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StudentInfoScreen(child: child)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleInitials(label: child.name, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${child.className} · ${child.code}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Pill(humanise(child.relationship), color: Role.parent.tint),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 14),
          FigureStrip(
            figures: [
              Figure(
                label: t('home.attendance'),
                value: marked ? '$rate%' : '—',
                caption: marked ? tn('children.absent', snap!.attendance.absent) : t('home.notMarked'),
                captionColor: (rate ?? 100) >= 95 ? AppTheme.green : AppTheme.amber,
              ),
              Figure(
                label: t('children.homework'),
                value: '${snap?.homework.length ?? 0}',
                caption: (snap?.dueSoon ?? 0) > 0 ? tn('children.dueSoon', snap!.dueSoon) : t('children.nothingUrgent'),
                captionColor: (snap?.dueSoon ?? 0) > 0 ? AppTheme.amber : AppTheme.textFaint,
              ),
              Figure(
                label: t('children.bus'),
                value: snap?.transport.ridesTheBus == true ? t('children.yes') : t('children.no'),
                caption: snap?.transport.routeName?.split('—').last.trim() ?? '—',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_bus_rounded, size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    snap?.busLine ?? t('bus.checking'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => StudentInfoScreen(child: child)),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    foregroundColor: Role.parent.tint,
                    side: BorderSide(color: Role.parent.tint.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(t('children.open')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LeaveScreen(child: child)),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    foregroundColor: AppTheme.textMuted,
                    side: BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(t('children.askLeave')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
