import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../api/push.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/kit.dart';
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
                  const Card16(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: _PushRow(),
                  ),

                  _Section(t('more.appearance')),
                  Card16(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: const _ThemePicker(),
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
      builder: (_) => const _ChangePasswordSheet(),
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

/// Whether this phone will actually be told anything.
///
/// Worth a row of its own: when a parent says "the school never told me", the
/// first question is whether this was ever on, and neither they nor the office
/// can answer that from inside Android's settings.
class _PushRow extends StatefulWidget {
  const _PushRow();

  @override
  State<_PushRow> createState() => _PushRowState();
}

class _PushRowState extends State<_PushRow> with WidgetsBindingObserver {
  bool _granted = Push.granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission can be revoked in Android settings while the app is in the
    // background, so this re-reads on the way back rather than trusting what
    // it learned on build.
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _granted = Push.granted);
    }
  }

  Future<void> _ask() async {
    final ok = await Push.askPermission();
    if (!mounted) return;
    setState(() => _granted = ok);
    if (!ok) {
      // Android shows its dialog once. After that the only way back is the
      // system settings screen, and saying so is more use than a toast that
      // reads "permission denied".
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('more.pushBlocked'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TileRow(
      icon: _granted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
      color: _granted ? AppTheme.green : AppTheme.amber,
      title: t('more.push'),
      subtitle: _granted ? t('more.pushOn') : t('more.pushOff'),
      trailing: _granted ? null : t('more.turnOn'),
      last: true,
      onTap: _granted ? null : _ask,
    );
  }
}

/// Changing a password ends every other session, which is the point: somebody
/// who thinks a relative has their phone needs this two taps away, not five.
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text.length < 8) {
      setState(() => _error = t('login.tooShort'));
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = t('login.mismatch'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.instance.changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('more.passwordChanged'))),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              t('more.changePassword'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
            const SizedBox(height: 4),
            Text(
              t('more.changePasswordSub'),
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            _Field(controller: _current, label: t('more.currentPassword')),
            const SizedBox(height: 10),
            _Field(controller: _next, label: t('login.newPassword')),
            const SizedBox(height: 10),
            _Field(controller: _confirm, label: t('login.confirmPassword')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: AppTheme.rose, fontSize: 12.5)),
            ],
            const SizedBox(height: 18),
            BigButton(
              label: _busy ? t('common.saving') : t('common.save'),
              color: Role.parent.tint,
              height: 50,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.canvas,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }
}


/// Light, dark, or follow the phone.
///
/// "System" first and selected by default: somebody who has set their handset
/// to dark has already answered this question, and asking it again in every
/// app is how a settings screen fills up with questions nobody wanted.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  IconData _icon(AppThemeMode m) => switch (m) {
        AppThemeMode.system => Icons.brightness_auto_rounded,
        AppThemeMode.light => Icons.light_mode_rounded,
        AppThemeMode.dark => Icons.dark_mode_rounded,
      };

  String _label(AppThemeMode m) => switch (m) {
        AppThemeMode.system => t('theme.system'),
        AppThemeMode.light => t('theme.light'),
        AppThemeMode.dark => t('theme.dark'),
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: AppThemeSetting.current,
      builder: (context, current, _) => Row(
        children: [
          for (final mode in AppThemeMode.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: current == mode ? null : () => AppThemeSetting.set(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: current == mode ? Role.parent.wash : AppTheme.canvas,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: current == mode ? Role.parent.tint : AppTheme.border,
                      width: current == mode ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _icon(mode),
                        size: 19,
                        color: current == mode ? Role.parent.tint : AppTheme.textMuted,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _label(mode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: current == mode ? FontWeight.w700 : FontWeight.w600,
                          color: current == mode ? AppTheme.text : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
