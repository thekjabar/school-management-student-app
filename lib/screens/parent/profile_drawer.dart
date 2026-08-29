import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../api/push.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import 'assignments_screen.dart';
import 'bus_screen.dart';
import 'attendance_screen.dart';
import 'attitude_screen.dart';
import 'fees_screen.dart';
import 'marks_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'timetable_screen.dart';

/// Everywhere the parent app goes, in one list.
///
/// The bottom bar carries the four things opened daily; this carries the rest.
/// Grouped under three headings rather than run together, because a flat list
/// of eleven rows is scanned by reading all eleven — and a parent hunting for
/// fees should be able to skip two whole groups without reading them.
class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({
    super.key,
    required this.children,
    required this.selected,
    required this.onSelectChild,
    required this.onGoTab,
    this.unread = 0,
  });

  final List<Child> children;
  final Child? selected;
  final void Function(String studentId) onSelectChild;
  final void Function(int tab) onGoTab;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.me;
    final tint = Role.parent.tint;
    final child = selected;

    return Drawer(
      backgroundColor: AppTheme.canvas,
      width: MediaQuery.of(context).size.width * 0.84,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.horizontal(end: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _Head(
              child: child,
              tint: tint,
              canSwitch: children.length > 1,
              onSwitch: () => _pickChild(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: _SchoolRow(
                name: me?.schoolName ?? '',
                tint: tint,
                onTap: children.length > 1 ? () => _pickChild(context) : null,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                children: [
                  _GroupLabel(t('drawer.school')),
                  _Row(
                    icon: Icons.home_rounded,
                    label: t('nav.home'),
                    tint: tint,
                    active: true,
                    onTap: () => _go(context, () => onGoTab(0)),
                  ),
                  _Row(
                    icon: Icons.directions_bus_rounded,
                    label: t('quick.bus'),
                    tint: tint,
                    enabled: child != null,
                    onTap: () => _push(context, BusScreen(child: child!)),
                  ),
                  _Row(
                    icon: Icons.calendar_month_rounded,
                    label: t('quick.timetable'),
                    tint: tint,
                    enabled: child != null,
                    onTap: () => _push(context, TimetableScreen(child: child!)),
                  ),

                  const _Rule(),
                  _GroupLabel(t('drawer.academic')),
                  _Row(
                    icon: Icons.description_rounded,
                    label: t('quick.assignments'),
                    tint: AppTheme.violet,
                    enabled: child != null,
                    onTap: () => _push(context, AssignmentsScreen(child: child!)),
                  ),
                  _Row(
                    icon: Icons.verified_user_rounded,
                    label: t('quick.attendance'),
                    tint: AppTheme.green,
                    enabled: child != null,
                    onTap: () => _push(context, AttendanceScreen(child: child!)),
                  ),
                  _Row(
                    icon: Icons.bar_chart_rounded,
                    label: t('quick.marks'),
                    tint: AppTheme.blue,
                    enabled: child != null,
                    onTap: () => _push(context, MarksScreen(child: child!)),
                  ),
                  _Row(
                    icon: Icons.favorite_rounded,
                    label: t('quick.attitude'),
                    tint: AppTheme.rose,
                    enabled: child != null,
                    onTap: () => _push(context, AttitudeScreen(child: child!)),
                  ),

                  const _Rule(),
                  _GroupLabel(t('drawer.more')),
                  _Row(
                    icon: Icons.forum_rounded,
                    label: t('nav.messages'),
                    tint: tint,
                    badge: unread,
                    onTap: () => _go(context, () => onGoTab(1)),
                  ),
                  _Row(
                    icon: Icons.credit_card_rounded,
                    label: t('drawer.fees'),
                    tint: AppTheme.amber,
                    onTap: () => _push(context, const FeesScreen()),
                  ),
                  _Row(
                    icon: Icons.pie_chart_rounded,
                    label: t('quick.reports'),
                    tint: AppTheme.violet,
                    enabled: child != null,
                    onTap: () => _push(context, ReportsScreen(child: child!)),
                  ),
                  _Row(
                    icon: Icons.settings_rounded,
                    label: t('drawer.settings'),
                    tint: AppTheme.textMuted,
                    onTap: () => _push(context, const SettingsScreen()),
                  ),

                  const SizedBox(height: 14),
                  const _NotificationsCard(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _LogoutButton(onTap: () => _signOut(context)),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _pickChild(BuildContext context) async {
    final picked = await pickOne<String>(
      context,
      title: t('home.whichChild'),
      tint: Role.parent.tint,
      selected: selected?.studentId,
      options: children
          .map((c) => PickOption(
                value: c.studentId,
                label: c.name,
                subtitle: '${c.className} · ${c.code}',
                icon: Icons.child_care_rounded,
              ))
          .toList(),
    );
    if (picked != null) onSelectChild(picked);
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
}

/* ---------------------------------------------------------------------------
 * The head
 * ------------------------------------------------------------------------- */

class _Head extends StatelessWidget {
  const _Head({
    required this.child,
    required this.tint,
    required this.canSwitch,
    required this.onSwitch,
  });

  final Child? child;
  final Color tint;
  final bool canSwitch;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // The ring is the one thing in the app that says "everything behind
          // me is about this child".
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tint.withValues(alpha: 0.45), width: 2),
            ),
            child: CircleInitials(label: child?.name ?? '?', tint: tint, size: 54),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: GestureDetector(
              onTap: canSwitch ? onSwitch : null,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${child?.className ?? ''} · ${child?.code ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tint,
                          ),
                        ),
                      ),
                      if (canSwitch) Icon(Icons.expand_more_rounded, size: 17, color: tint),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (canSwitch)
            GestureDetector(
              onTap: onSwitch,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: AppTheme.dark ? 0.22 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.swap_horiz_rounded, size: 20, color: tint),
              ),
            ),
        ],
      ),
    );
  }
}

class _SchoolRow extends StatelessWidget {
  const _SchoolRow({required this.name, required this.tint, required this.onTap});

  final String name;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_rounded, size: 26, color: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppTheme.text,
                    ),
                  ),
                  if (onTap != null)
                    Text(
                      t('drawer.switchSchool'),
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Rows and groups
 * ------------------------------------------------------------------------- */

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 5),
      child: Text(
        text.toUpperCase(),
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

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Divider(height: 14, color: AppTheme.border),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
    this.active = false,
    this.badge = 0,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;
  final bool active;
  final int badge;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          // The current destination is a filled pill, not merely a coloured
          // label — a list where "you are here" is only a text colour is one
          // people re-read to find themselves in.
          color: active ? tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: active && AppTheme.dark
              ? Border.all(color: tint.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: enabled ? tint : AppTheme.textFaint.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: -0.2,
                  color: !enabled
                      ? AppTheme.textFaint.withValues(alpha: 0.6)
                      : active
                          ? tint
                          : AppTheme.text,
                ),
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                constraints: const BoxConstraints(minWidth: 24),
                decoration: BoxDecoration(
                  color: AppTheme.violet,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Notifications prompt
 * ------------------------------------------------------------------------- */

/// Shown only while notifications are off.
///
/// A card asking somebody to switch on a thing they already switched on is the
/// fastest way to teach them to ignore every card in the app.
class _NotificationsCard extends StatefulWidget {
  const _NotificationsCard();

  @override
  State<_NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends State<_NotificationsCard> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _granted = Push.granted);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_granted) return const SizedBox.shrink();
    final tint = Role.parent.tint;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: AppTheme.dark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The rendered bell rather than the outline one: this card is the
          // only place in the app asking for something, and the illustration is
          // what stops it reading as another row in the list above it.
          Image.asset('assets/art/bell.png', width: 40, height: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('drawer.stayUpdated'),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('drawer.stayUpdatedBody'),
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _ask,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t('drawer.enableNotifications'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 17, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ask() async {
    final ok = await Push.askPermission();
    if (!mounted) return;
    setState(() => _granted = ok);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('more.pushBlocked'))),
      );
    }
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.rose.withValues(alpha: AppTheme.dark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, size: 19, color: AppTheme.rose),
            const SizedBox(width: 9),
            Text(
              t('more.signOut'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.rose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
