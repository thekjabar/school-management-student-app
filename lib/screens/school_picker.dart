import 'package:flutter/material.dart';

import '../api/session.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import '../ui/async.dart';
import '../ui/home_kit.dart';
import '../ui/kit.dart';
import '../ui/pickers.dart';

List<String> rolesForApp(Role role) => switch (role) {
      Role.teacher => kTeacherRoles,
      Role.driver => kCrewRoles,
      _ => kGuardianRoles,
    };

List<Membership> schoolsForRole(Role role) =>
    Session.instance.me?.schoolsFor(rolesForApp(role)) ?? const <Membership>[];

String? schoolRoleLabel(String role) => switch (role) {
      'ATTENDANT' => t('school.attendant'),
      'DRIVER' => t('role.driver'),
      'TEACHER' => t('role.teacher'),
      _ => null,
    };

Future<bool> openSchool(
  BuildContext context,
  String tenantId, {
  required Color tint,
}) async {
  final entry = OverlayEntry(builder: (_) => _Opening(tint: tint));
  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    await Session.instance.switchTenant(tenantId);
    await Session.instance.markSchoolChosen();
    return true;
  } catch (e) {
    final message = errorText(e);
    if (context.mounted) showNote(context, message, bad: true);
    return false;
  } finally {
    entry.remove();
  }
}

Future<bool> pickSchool(BuildContext context, {required Role role}) async {
  final schools = schoolsForRole(role);
  if (schools.length < 2) return false;

  final active = Session.instance.me?.active.tenantId;
  final picked = await pickOne<String>(
    context,
    title: t('school.whichSchool'),
    tint: role.tint,
    selected: active,
    options: schools
        .map((m) => PickOption(
              value: m.tenantId,
              label: m.tenantName,
              subtitle: schoolRoleLabel(m.role),
              icon: Icons.school_rounded,
            ))
        .toList(),
  );
  if (picked == null || picked == active || !context.mounted) return false;
  return openSchool(context, picked, tint: role.tint);
}

class SchoolChoiceScreen extends StatelessWidget {
  const SchoolChoiceScreen({super.key, required this.role, required this.onChosen});

  final Role role;
  final VoidCallback onChosen;

  @override
  Widget build(BuildContext context) {
    final schools = schoolsForRole(role);
    final active = Session.instance.me?.active.tenantId;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(kGutter, 34, kGutter, 24),
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: role.wash,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.school_rounded, size: 26, color: role.tint),
            ),
            const SizedBox(height: 18),
            Text(
              t('school.chooseTitle'),
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              t('school.chooseBody'),
              style: TextStyle(fontSize: 13, height: 1.55, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 22),
            for (final m in schools) ...[
              _SchoolRow(
                name: m.tenantName,
                roleLabel: schoolRoleLabel(m.role),
                tint: role.tint,
                on: m.tenantId == active,
                onTap: () async {
                  final ok = await openSchool(context, m.tenantId, tint: role.tint);
                  if (ok) onChosen();
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SchoolRow extends StatelessWidget {
  const _SchoolRow({
    required this.name,
    required this.roleLabel,
    required this.tint,
    required this.on,
    required this.onTap,
  });

  final String name;
  final String? roleLabel;
  final Color tint;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? tint : AppTheme.border, width: on ? 1.4 : 1),
        ),
        child: Row(
          children: [
            Chip36(icon: Icons.location_city_rounded, color: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                  if (roleLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      roleLabel!,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

class _Opening extends StatelessWidget {
  const _Opening({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModalBarrier(
          dismissible: false,
          color: Colors.black.withValues(alpha: 0.35),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6, color: tint),
                ),
                const SizedBox(height: 14),
                Text(
                  t('school.opening'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
