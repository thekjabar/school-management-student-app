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

class CrewPapersScreen extends StatelessWidget {
  const CrewPapersScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            const CredentialsPanel(),
          ],
        );
      },
    );
  }

}
