import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../api/push.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/kit.dart';
import '../../ui/settings_widgets.dart';
import '../login_screen.dart' show LanguagePicker;
import 'fees_screen.dart';
import 'leave_screen.dart';

/// The account, behind the avatar.
///
/// This used to be a fourth bottom-bar tab labelled "⋯ More", which spent a
/// quarter of the bar on a drawer's worth of settings and pushed the three
/// things a parent actually opens the app for into three-quarters of it. A
/// drawer costs one tap on the face they already press to find "my account",
/// and gives the whole bar back to attendance, children and messages.
class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key, required this.children});

  final List<Child> children;

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
            _Head(me: me),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                children: [
                  if (me != null && !me.phoneVerified) ...[
                    const SizedBox(height: 10),
                    _Note(text: t('more.unverifiedNote')),
                  ],

                  _Section(t('more.yourChildren')),
                  Card16(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: Column(
                      children: [
                        for (var i = 0; i < children.length; i++)
                          TileRow(
                            icon: Icons.child_care_rounded,
                            color: Role.parent.tint,
                            title: children[i].name,
                            subtitle: '${children[i].className} · ${children[i].code}',
                            last: i == children.length - 1,
                          ),
                      ],
                    ),
                  ),

                  _Section(t('more.moneyRequests')),
                  Card16(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: Column(
                      children: [
                        TileRow(
                          icon: Icons.receipt_long_rounded,
                          color: AppTheme.violet,
                          title: t('fees.title'),
                          subtitle: t('more.feesSub'),
                          onTap: () => _go(context, const FeesScreen()),
                        ),
                        TileRow(
                          icon: Icons.event_busy_rounded,
                          color: AppTheme.amber,
                          title: t('leave.title'),
                          subtitle: t('more.leaveSub'),
                          last: true,
                          onTap: children.isEmpty
                              ? null
                              : () => _go(context, LeaveScreen(child: children.first)),
                        ),
                      ],
                    ),
                  ),

                  _Section(t('more.notifications')),
                  Card16(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: PushRow(tint: Role.parent.tint),
                  ),

                  _Section(t('more.appearance')),
                  Card16(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: ThemePicker(tint: Role.parent.tint),
                  ),

                  _Section(t('more.language')),
                  Card16(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: LanguagePicker(tint: Role.parent.tint),
                    ),
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
                          onTap: () => _changePassword(context),
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

  /// Close the drawer first, then navigate — otherwise it is still open
  /// underneath when the parent presses back.
  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _signOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('more.signOutAsk')),
        content: Text(t('more.signOutBody')),
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

  void _changePassword(BuildContext context) {
    Navigator.of(context).pop();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangePasswordSheet(tint: Role.parent.tint),
    );
  }
}

/// Name, number and school, over the role's wash — the same top band the home
/// screen uses, so the drawer reads as part of the app rather than a settings
/// screen borrowed from somewhere else.
class _Head extends StatelessWidget {
  const _Head({required this.me});

  final Me? me;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Role.parent.wash, AppTheme.canvas],
        ),
      ),
      child: Row(
        children: [
          CircleInitials(label: me?.name ?? '?', tint: Role.parent.tint, size: 52),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  me?.phone ?? '',
                  // A phone number is read left-to-right even on a Kurdish
                  // screen; letting it mirror makes it unreadable.
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                ),
                if ((me?.schoolName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    me!.schoolName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                  ),
                ],
              ],
            ),
          ),
          if (me != null && !me!.phoneVerified)
            Pill(t('more.unverified'), color: AppTheme.amber),
        ],
      ),
    );
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

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.amberSoft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.info_rounded, size: 17, color: AppTheme.amber),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, height: 1.5)),
          ),
        ],
      ),
    );
  }
}







