import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/crew_api.dart';
import '../../api/session.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';

/// The crew member's own record: who they are, and the papers that let them
/// drive.
///
/// The credentials list is the working part. A licence or a vetting check that
/// has lapsed does not produce a warning — the compliance gate REFUSES the run
/// at check-in — so finding out here, a week early, is the whole point.
class CrewAccountTab extends StatelessWidget {
  const CrewAccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.me;

    return Loader<Map<String, dynamic>>(
      tint: Role.driver.tint,
      load: () => CrewApi.instance.me(),
      builder: (context, data) {
        final person = (data['person'] ?? {}) as Map<String, dynamic>;
        final roles = ((data['roles'] as List?) ?? []).cast<Map<String, dynamic>>();
        final credentials = ((data['credentials'] as List?) ?? []).cast<Map<String, dynamic>>();
        final offboarding = data['offboardingInProgress'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Panel(
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Role.driver.wash,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      ((person['fullName'] ?? me?.name ?? '?') as String).characters.first.toUpperCase(),
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Role.driver.tint),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (person['fullName'] ?? me?.name ?? '') as String,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (person['phoneE164'] ?? me?.phone ?? '') as String,
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: roles
                              .map((r) => Tag(
                                    humanise(r['role'] as String?),
                                    color: Role.driver.tint,
                                    background: Role.driver.wash,
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (offboarding != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppTheme.roseSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Text(
                  'Your leaving process has started. The office will tell you when your access ends.',
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.rose),
                ),
              ),
            ],
            const SectionHead('Your papers'),
            if (credentials.isEmpty)
              const Panel(
                child: Text(
                  'Nothing is on file. The office holds licences, medicals and vetting checks — '
                  'ask them to add yours, or the gate will stop you at check-in.',
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
                ),
              )
            else
              ...credentials.map((c) => _CredentialRow(credential: c)),
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
                    content: const Text(
                      'You will need your password to get back in. '
                      'Do not sign out mid-run — the manifest on this phone goes with it.',
                    ),
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
              if (context.mounted) showNote(context, 'Password changed');
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
                  Text(error!, style: const TextStyle(color: AppTheme.rose, fontSize: 12.5)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: busy ? null : save,
                style: FilledButton.styleFrom(backgroundColor: Role.driver.tint),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.credential});

  final Map<String, dynamic> credential;

  @override
  Widget build(BuildContext context) {
    final expiresRaw = credential['expiresAt'] as String?;
    final expires = expiresRaw == null ? null : DateTime.parse(expiresRaw).toLocal();
    final days = expires?.difference(DateTime.now()).inDays;

    final (Color colour, Color wash) = days == null
        ? (AppTheme.textMuted, const Color(0xFFF1F3F6))
        : days < 0
            ? (AppTheme.rose, AppTheme.roseSoft)
            : days < 30
                ? (AppTheme.amber, AppTheme.amberSoft)
                : (AppTheme.green, AppTheme.greenSoft);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconChip(
              icon: Icons.badge_rounded,
              color: colour,
              background: wash,
              size: 34,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    humanise(credential['kind'] as String?),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  Text(
                    expires == null ? 'No expiry recorded' : 'Expires ${longDate(expires)}',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (days != null)
              Tag(
                days < 0 ? 'expired' : '$days days',
                color: colour,
                background: wash,
              ),
          ],
        ),
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
            const Icon(Icons.chevron_right_rounded, size: 19, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}
