import 'package:flutter/material.dart';

import '../../api/push.dart';
import '../../api/session.dart';
import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/settings_widgets.dart';
import '../../ui/sheets.dart';
import '../login_screen.dart' show LanguagePicker;
import 'id_card.dart';

class StudentProfileTab extends StatelessWidget {
  const StudentProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;
    final me = Session.instance.me;

    return Loader<StudentProfile?>(
      tint: tint,
      padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 20)),
      load: () async {
        try {
          return await StudentApi.instance.me();
        } catch (_) {
          return null;
        }
      },
      builder: (context, profile) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card16(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleInitials(
                      label: profile?.name ?? me?.name ?? '',
                      tint: tint,
                      size: 52,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? me?.name ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: 1.3,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            profile?.schoolName ?? me?.schoolName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (profile != null) Pill(profile.code, color: tint),
                              if ((profile?.schoolClass?.name ?? '').isNotEmpty)
                                Pill(profile!.schoolClass!.name, color: AppTheme.blue),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (profile != null) ...[
                  const SizedBox(height: 13),
                  Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 13),
                  IconFigureStrip(
                    figures: [
                      IconFigure(
                        icon: Icons.badge_outlined,
                        label: t('student.studentCode'),
                        value: profile.code,
                        caption: '',
                        color: tint,
                      ),
                      IconFigure(
                        icon: Icons.cake_outlined,
                        label: t('student.dateOfBirth'),
                        value: shortDate(profile.dob),
                        caption: '',
                        color: AppTheme.amber,
                      ),
                      IconFigure(
                        icon: Icons.login_rounded,
                        label: t('student.lastSignIn'),
                        value: shortDate(profile.lastLoginAt),
                        caption: '',
                        color: AppTheme.blue,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          _Section(t('student.idCard')),
          Card16(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TileRow(
              icon: Icons.qr_code_2_rounded,
              color: tint,
              title: t('student.idCard'),
              subtitle: t('student.idCardBody'),
              last: true,
              onTap: () => showIdCard(context),
            ),
          ),

          _Section(t('settings.appearance')),
          Card16(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: ThemePicker(tint: tint),
          ),

          _Section(t('settings.language')),
          Card16(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: LanguagePicker(tint: tint),
            ),
          ),

          _Section(t('settings.notifications')),
          Card16(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: PushRow(tint: tint),
          ),

          _Section(t('more.account')),
          Card16(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                TileRow(
                  icon: Icons.lock_rounded,
                  color: AppTheme.textMuted,
                  title: t('more.changePassword'),
                  subtitle: t('more.changePasswordSub'),
                  onTap: () => showAppSheet<void>(
                    context,
                    builder: (_) => ChangePasswordSheet(tint: tint),
                  ),
                ),
                TileRow(
                  icon: Icons.logout_rounded,
                  color: AppTheme.rose,
                  title: t('more.signOut'),
                  subtitle: t('more.signOutSub'),
                  last: true,
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final bool yes = await confirmDialog(
      context,
      icon: Icons.logout_rounded,
      tone: AppTheme.rose,
      title: t('more.signOutAsk'),
      body: t('student.signOutBody'),
      confirmLabel: t('more.signOut'),
      confirmIcon: Icons.logout_rounded,
    );
    if (!yes || !context.mounted) return;
    await Session.instance.signOut();
    await Push.forget();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 9),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: AppTheme.textFaint,
        ),
      ),
    );
  }
}
