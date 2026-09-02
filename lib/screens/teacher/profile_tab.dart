import 'package:flutter/material.dart';

import '../../api/push.dart';
import '../../api/session.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/settings_widgets.dart';
import '../../ui/sheets.dart';
import '../login_screen.dart' show LanguagePicker;

/// The teacher's own tab.
///
/// It exists because the design gives the bottom bar a Profile slot, and
/// because everything that used to live only behind the drawer — the theme, the
/// language, the password, the way out — was reachable by exactly one gesture
/// that several people never found.
class TeacherProfileTab extends StatelessWidget {
  const TeacherProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;

    return Loader<TeacherProfile>(
      tint: tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 20),
      load: () => TeacherApi.instance.me(),
      builder: (context, profile) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card16(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleInitials(label: profile.name, tint: tint, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.phone,
                            // A phone number reads left-to-right even on a
                            // Kurdish screen; mirroring it makes it unusable.
                            textDirection: TextDirection.ltr,
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.schoolName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 13),
                IconFigureStrip(
                  figures: [
                    IconFigure(
                      icon: Icons.groups_outlined,
                      label: t('teacher.classes'),
                      value: '${profile.classCount}',
                      caption: '',
                      color: tint,
                    ),
                    IconFigure(
                      icon: Icons.menu_book_rounded,
                      label: t('teacher.subjects'),
                      value: '${profile.subjectCount}',
                      caption: '',
                      color: AppTheme.blue,
                    ),
                    IconFigure(
                      icon: Icons.child_care_rounded,
                      label: t('teacher.children'),
                      value: '${profile.studentCount}',
                      caption: '',
                      color: AppTheme.amber,
                    ),
                  ],
                ),
              ],
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
      body: t('teacher.signOutBody'),
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
