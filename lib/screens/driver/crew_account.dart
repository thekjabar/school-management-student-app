import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// The crew member's own record: who they are, and the papers that let them
/// drive.
///
/// The credentials list is the working part. A licence or a vetting check that
/// has lapsed does not produce a warning — the compliance gate REFUSES the run
/// at check-in — so finding out here, a week early, is the whole point.
class CrewPapersScreen extends StatelessWidget {
  const CrewPapersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // A Scaffold and a header. This screen was pushed as a bare Loader: no
    // background of its own, and no back button — the only way off it was the
    // phone's own gesture, which on a handset in a cradle is not a way off it
    // at all.
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('driver.papers')),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
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
                  // The kit's initials, tinted. The hand-rolled square took the
                  // first character of the name and nothing else, so two of the
                  // three crew on a bus showed the same letter.
                  CircleInitials(
                    label: (person['fullName'] ?? me?.name ?? '') as String,
                    tint: Role.driver.tint,
                    size: 50,
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
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
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
                child: Text(
                  t('driver.leaving'),
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.rose),
                ),
              ),
            ],
            SectionHead(t('driver.papers')),
            if (credentials.isEmpty)
              Panel(
                child: Text(
                  t('driver.noPapers'),
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
                ),
              )
            else
              ...credentials.map((c) => _CredentialRow(credential: c)),
          ],
        );
      },
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

    /*
     * The status the office set, which outranks the date on the paper.
     *
     * This row used to be coloured by the expiry date alone. A licence the
     * office had SUSPENDED or REVOKED — pulled while still in date, which is
     * exactly what happens after a safeguarding decision — drew green with a
     * comfortable day count, and the one screen a driver checks before a run
     * told him he was fine to drive. The status has been in the payload the
     * whole time; nothing read it.
     */
    final status = credential['status'] as String?;
    final stopped = status == 'SUSPENDED' ||
        status == 'REVOKED' ||
        status == 'REJECTED' ||
        status == 'EXPIRED' ||
        status == 'BLOCKING_SOON';
    final warning = status == 'EXPIRING_SOON' || status == 'PENDING_VERIFICATION';

    final (Color colour, Color wash) = stopped
        ? (AppTheme.rose, AppTheme.roseSoft)
        : warning
            ? (AppTheme.amber, AppTheme.amberSoft)
            : days == null
                ? (AppTheme.textMuted, AppTheme.neutralSoft)
                : days < 0
                    ? (AppTheme.rose, AppTheme.roseSoft)
                    : days < 30
                        ? (AppTheme.amber, AppTheme.amberSoft)
                        : (AppTheme.green, AppTheme.greenSoft);

    /// What to put in the corner: the status when it is the thing that matters,
    /// otherwise the days left, which is what it always showed.
    final String? tag = switch (status) {
      'SUSPENDED' => t('driver.credSuspended'),
      'REVOKED' => t('driver.credRevoked'),
      'REJECTED' => t('driver.credRejected'),
      'PENDING_VERIFICATION' => t('driver.credPending'),
      'BLOCKING_SOON' => t('driver.credBlocking'),
      'EXPIRED' => t('driver.expired'),
      _ => days == null
          ? null
          : days < 0
              ? t('driver.expired')
              : tn('driver.nDays', days),
    };

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
                    expires == null ? t('driver.noExpiry') : tn('driver.expires', longDate(expires)),
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                  if (stopped && status != 'EXPIRED')
                    Text(
                      t('driver.credNotValid'),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.rose),
                    ),
                ],
              ),
            ),
            if (tag != null)
              Tag(
                tag,
                color: colour,
                background: wash,
              ),
          ],
        ),
      ),
    );
  }
}
