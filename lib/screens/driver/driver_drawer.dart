import 'package:flutter/material.dart';

import '../../api/push.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import '../../ui/settings_widgets.dart';
import '../login_screen.dart' show LanguagePicker;
import 'crew_account.dart';

/// The driver's account, behind the menu button.
///
/// Same shape as the parent app's drawer, and for the same reason: a bottom bar
/// with three items spent a third of itself on settings a driver opens once a
/// term, while the two things they use every morning shared the rest.
class DriverDrawer extends StatelessWidget {
  const DriverDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.me;

    return Drawer(
      backgroundColor: AppTheme.canvas,
      width: MediaQuery.of(context).size.width * 0.86,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.horizontal(end: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Role.driver.wash, AppTheme.canvas],
                ),
              ),
              child: Row(
                children: [
                  CircleInitials(label: me?.name ?? '?', tint: Role.driver.tint, size: 52),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          me?.phone ?? '',
                          // A phone number reads left-to-right even on a
                          // Kurdish screen; mirroring it makes it unusable.
                          textDirection: TextDirection.ltr,
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Pill(humanise(me?.role), color: Role.driver.tint),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                children: [
                  _Section(t('driver.papers')),
                  Card16(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: TileRow(
                      icon: Icons.badge_rounded,
                      color: Role.driver.tint,
                      title: t('driver.papers'),
                      subtitle: t('driver.papersSub'),
                      last: true,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CrewPapersScreen()),
                        );
                      },
                    ),
                  ),

                  _Section(t('more.appearance')),
                  Card16(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: ThemePicker(tint: Role.driver.tint),
                  ),

                  _Section(t('more.language')),
                  Card16(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: LanguagePicker(tint: Role.driver.tint),
                    ),
                  ),

                  _Section(t('more.notifications')),
                  Card16(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: PushRow(tint: Role.driver.tint),
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
                          onTap: () {
                            Navigator.of(context).pop();
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => ChangePasswordSheet(tint: Role.driver.tint),
                            );
                          },
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('more.signOutAsk')),
        content: Text(t('driver.signOutBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.rose),
            child: Text(t('more.signOut')),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await Session.instance.signOut();
    await Push.forget();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppTheme.textFaint,
        ),
      ),
    );
  }
}
