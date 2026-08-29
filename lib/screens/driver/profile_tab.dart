import 'package:flutter/material.dart';

import '../../api/push.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/settings_widgets.dart';
import '../login_screen.dart' show LanguagePicker;
import 'crew_account.dart';

/// The driver's own tab.
///
/// This replaced the drawer rather than sitting beside it. Two routes to one
/// set of settings is one more than anybody hunts for, and the one behind a
/// hamburger was the one nobody found.
class DriverProfile extends StatelessWidget {
  const DriverProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;
    final me = Session.instance.me;

    return ListView(
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 20),
      children: [
        Card16(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleInitials(label: me?.name ?? '', tint: tint, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me?.name ?? '',
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
                      me?.phone ?? '',
                      // A phone number reads left-to-right even on a Kurdish
                      // screen; mirroring it makes it unusable.
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 5),
                    Pill(t('driver.roleLabel'), color: tint),
                  ],
                ),
              ),
            ],
          ),
        ),

        _Section(t('driver.papers')),
        Card16(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TileRow(
            icon: Icons.badge_rounded,
            color: tint,
            title: t('driver.papers'),
            subtitle: t('driver.papersSub'),
            last: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CrewPapersScreen()),
            ),
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
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
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
