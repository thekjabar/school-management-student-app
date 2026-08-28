import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../api/push.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import 'fees_screen.dart';
import 'leave_screen.dart';

/// The account, and everything that is not a daily question.
///
/// Changing a password lives here rather than three levels down: it ends every
/// other session, and somebody who thinks a relative has their phone needs that
/// two taps away, not five.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key, required this.children});

  final List<Child> children;

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.me;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Card16(
          child: Row(
            children: [
              CircleInitials(label: me?.name ?? '?', tint: Role.parent.tint, size: 48),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      me?.phone ?? '',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      me?.schoolName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                    ),
                  ],
                ),
              ),
              if (me != null && !me.phoneVerified) Pill(t('more.unverified'), color: AppTheme.amber),
            ],
          ),
        ),

        if (me != null && !me.phoneVerified) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppTheme.amberSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_rounded, size: 17, color: AppTheme.amber),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    // Not a nag. An unverified number loses live bus location,
                    // and a parent who does not know that assumes the app is
                    // broken rather than that their number needs checking.
                    t('more.unverifiedNote'),
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],

        Heading(t('more.yourChildren')),
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
                  trailing: humanise(children[i].relationship),
                  last: i == children.length - 1,
                ),
            ],
          ),
        ),

        Heading(t('more.notifications')),
        const Card16(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: _PushTile(),
        ),

        Heading(t('more.moneyRequests')),
        Card16(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Column(
            children: [
              TileRow(
                icon: Icons.receipt_long_rounded,
                color: AppTheme.violet,
                title: t('fees.title'),
                subtitle: t('more.feesSub'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeesScreen()),
                ),
              ),
              TileRow(
                icon: Icons.event_busy_rounded,
                color: AppTheme.amber,
                title: t('leave.title'),
                subtitle: t('more.leaveSub'),
                last: true,
                onTap: children.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => LeaveScreen(child: children.first)),
                        ),
              ),
            ],
          ),
        ),

        Heading(t('more.language')),
        Card16(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: Lang.values.map((l) {
              final on = AppLocale.current.value == l;
              return Expanded(
                child: GestureDetector(
                  onTap: () => AppLocale.set(l),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? Role.parent.tint : AppTheme.canvas,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      // Each language named IN that language. A parent looking
                      // for Kurdish is looking for "کوردی", not for "Kurdish".
                      l.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        Heading(t('more.account')),
        Card16(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Column(
            children: [
              TileRow(
                icon: Icons.lock_outline_rounded,
                color: AppTheme.blue,
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
                onTap: () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(t('more.signOutAsk')),
                      content: Text(t('more.signOutBody')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('more.stay'))),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: AppTheme.rose),
                          child: Text(t('more.signOut')),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) await Session.instance.signOut();
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Center(
          child: Text(
            'EduPulse · School Management',
            style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
          ),
        ),
      ],
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          String? error;
          bool busy = false;

          Future<void> save() async {
            if (next.text.length < 8) {
              setState(() => error = t('login.tooShort'));
              return;
            }
            if (next.text != confirm.text) {
              setState(() => error = t('login.mismatch'));
              return;
            }
            setState(() {
              busy = true;
              error = null;
            });
            try {
              await Session.instance.changePassword(current.text, next.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                showNote(context, t('more.passwordChanged'));
              }
            } on ApiException catch (e) {
              setState(() {
                error = e.message;
                busy = false;
              });
            }
          }

          return AlertDialog(
            title: Text(t('more.changePassword')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: true,
                  decoration: InputDecoration(labelText: t('more.currentPassword')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: next,
                  obscureText: true,
                  decoration: InputDecoration(labelText: t('login.newPassword')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration: InputDecoration(labelText: t('login.typeAgain')),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppTheme.rose, fontSize: 12.5)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t('common.cancel'))),
              FilledButton(
                onPressed: busy ? null : save,
                style: FilledButton.styleFrom(backgroundColor: Role.parent.tint),
                child: Text(t('common.save')),
              ),
            ],
          );
        },
      ),
    );
  }
}


/// Whether this phone will actually be told anything.
///
/// Worth a row of its own rather than leaving it to the OS settings app: when
/// a parent says "the school never told me", the first question is whether
/// this switch was ever on, and neither they nor the office can answer it from
/// inside Android's settings.
class _PushTile extends StatefulWidget {
  const _PushTile();

  @override
  State<_PushTile> createState() => _PushTileState();
}

class _PushTileState extends State<_PushTile> with WidgetsBindingObserver {
  bool _granted = Push.granted;

  @override
  void initState() {
    super.initState();
    // Permission can be revoked in Android settings while the app is in the
    // background, so the row has to re-read it on the way back rather than
    // trusting what it learned on build.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _granted = Push.granted);
    }
  }

  Future<void> _ask() async {
    final ok = await Push.askPermission();
    if (!mounted) return;
    setState(() => _granted = ok);
    if (!ok) {
      // Android only shows its dialog once. After that the only way back is
      // the system settings screen, and saying so is more use than a toast
      // that reads "permission denied".
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
