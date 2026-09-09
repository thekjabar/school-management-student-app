import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import 'credentials_screen.dart';

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
            // Fetched separately from /crew/me/credentials rather than read out
            // of the payload above, because only that route computes the two
            // things a driver actually needs: `derivedStatus`, which applies
            // the dates to the office's status so a VERIFIED licence that
            // expired last week stops reading as verified, and
            // `daysUntilRosterBlock` — the countdown to the day he stops being
            // given runs, which is EARLIER than the expiry on the paper by the
            // lead days the office set, and is the number that matters.
            //
            // The old section read `credential['expiresAt']` while the server
            // has always sent `expiresOn`, so the date was null on every row
            // and the day count under it never appeared at all.
            const CredentialsPanel(),
          ],
        );
      },
    );
  }

}
