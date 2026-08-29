import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/kit.dart';
import '../../ui/settings_widgets.dart';
import '../login_screen.dart' show LanguagePicker;

/// Appearance, language, notifications, password.
///
/// A screen rather than a fifth group in the drawer: these are the four things
/// a guardian changes once and then never opens again, and a navigation list
/// that ends in four toggles teaches people to scroll past the bottom of it.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final me = Session.instance.me;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(t('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
        children: [
          _Section(t('settings.signedInAs')),
          Card16(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleInitials(label: me?.name ?? '', tint: tint, size: 42),
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
                          fontSize: 14.5,
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
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
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
            child: TileRow(
              icon: Icons.lock_rounded,
              color: AppTheme.textMuted,
              title: t('more.changePassword'),
              subtitle: t('more.changePasswordSub'),
              last: true,
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ChangePasswordSheet(tint: tint),
              ),
            ),
          ),
        ],
      ),
    );
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
