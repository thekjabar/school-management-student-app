import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/session.dart';
import '../../api/teacher_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';

/// The teacher's own record, their week, and the way out.
class TeacherAccountTab extends StatelessWidget {
  const TeacherAccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.me;

    return Loader<List<TeacherSlot>>(
      tint: Role.teacher.tint,
      load: () => TeacherApi.instance.timetable(),
      builder: (context, slots) {
        final byDay = <String, List<TeacherSlot>>{};
        for (final s in slots) {
          (byDay[s.weekday] ??= []).add(s);
        }
        const order = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
        final days = order.where(byDay.containsKey).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Panel(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Role.teacher.wash,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      (me?.firstName ?? '?').characters.first.toUpperCase(),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Role.teacher.tint),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me?.name ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          me?.phone ?? '',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          me?.schoolName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SectionHead('Your week'),
            if (days.isEmpty)
              Panel(
                child: Text(
                  'No lessons are timetabled for you.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              )
            else
              ...days.map((day) {
                final lessons = [...byDay[day]!]..sort((a, b) => a.period.compareTo(b.period));
                final isToday = day == todayWeekday();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    color: isToday ? Role.teacher.wash : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              humanise(day),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            if (isToday) Tag('Today', color: Role.teacher.tint, background: AppTheme.surface),
                            const Spacer(),
                            Text(
                              '${lessons.length} lesson${lessons.length == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...lessons.map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    clock(l.startMinute),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 3,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: parseHex(l.colorHex, AppTheme.border),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${l.subjectName} · ${l.className}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (l.room != null)
                                  Text(
                                    l.room!,
                                    style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SectionHead('Account'),
            _Row(
              icon: Icons.lock_outline_rounded,
              label: 'Change password',
              onTap: () => _changePassword(context),
            ),
            _Row(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              danger: true,
              onTap: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('You will need your password to get back in.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.rose),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (yes == true) await Session.instance.signOut();
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          String? error;
          bool busy = false;

          Future<void> save() async {
            if (next.text.length < 8) {
              setState(() => error = 'Use at least eight characters.');
              return;
            }
            setState(() {
              busy = true;
              error = null;
            });
            try {
              await Session.instance.changePassword(current.text, next.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                showNote(context, 'Password changed. Every other device has been signed out.');
              }
            } on ApiException catch (e) {
              setState(() {
                error = e.message;
                busy = false;
              });
            }
          }

          return AlertDialog(
            title: const Text('Change password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: AppTheme.rose, fontSize: 12.5)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: busy ? null : save,
                style: FilledButton.styleFrom(backgroundColor: Role.teacher.tint),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 19, color: danger ? AppTheme.rose : AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: danger ? AppTheme.rose : AppTheme.text,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 19, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}
