import 'package:flutter/material.dart';
import 'home_address_screen.dart';

import '../../api/parent_api.dart';
import '../../api/push.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import 'student_info_screen.dart';
import '../../ui/screen_kit.dart';
import '../../ui/settings_widgets.dart';
import '../../ui/sheets.dart';
import 'children_tab.dart';
import 'consents_screen.dart';
import 'dropoff_screen.dart';
import 'household_screen.dart';
import 'fees_screen.dart';
import 'help_screen.dart';
import 'personal_info_screen.dart';
import 'settings_screen.dart';

class ParentProfileTab extends StatelessWidget {
  const ParentProfileTab({
    super.key,
    required this.children,
    required this.selected,
    this.onOpenChild,
  });

  final List<Child> children;
  final Child? selected;
  final void Function(Child child)? onOpenChild;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final me = Session.instance.me;
    final child = selected ?? (children.isEmpty ? null : children.first);

    return Loader<AttitudeSummary?>(
      tint: tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
      load: () async {
        if (child == null) return null;
        return ParentApi.instance.attitude(child.studentId, tenantId: child.tenantId);
      },
      builder: (context, attitude) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Overview(me: me, tint: tint),
          const SizedBox(height: kCardGap),
          _Children(children: children, selected: child, onOpen: onOpenChild),
          const SizedBox(height: kCardGap),
          _Settings(children: children, selected: child),
          const SizedBox(height: kCardGap),
          _Figures(children: children, attitude: attitude),
          const SizedBox(height: kCardGap),
          _LogOut(onTap: () => _signOut(context)),
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
      body: t('more.signOutBody'),
      confirmLabel: t('more.signOut'),
      confirmIcon: Icons.logout_rounded,
    );
    if (!yes || !context.mounted) return;
    await Session.instance.signOut();
    await Push.forget();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.me, required this.tint});

  final Me? me;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Stack(
          children: [
            PositionedDirectional(
              end: -6,
              bottom: -6,
              child: Image.asset('assets/art/school_shield.png', width: 236),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('profile.overview'),
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                      _EditButton(tint: tint),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Fact(
                    icon: Icons.person_outline_rounded,
                    label: t('profile.fullName'),
                    value: me?.name ?? '—',
                  ),
                  _Fact(
                    icon: Icons.phone_outlined,
                    label: t('profile.phone'),
                    value: me?.phone ?? '—',
                    ltr: true,
                  ),
                  _Fact(
                    icon: Icons.account_balance_outlined,
                    label: t('profile.school'),
                    value: me?.active.tenantName ?? '—',
                  ),
                  _Fact(
                    icon: Icons.badge_outlined,
                    label: t('profile.role'),
                    value: t('profile.parent'),
                    last: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.09),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: tint.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 14, color: tint),
            const SizedBox(width: 6),
            Text(
              t('profile.edit'),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tint),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.ltr = false,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ltr;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Role.parent.tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: Role.parent.tint),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: ltr ? TextDirection.ltr : null,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Children extends StatelessWidget {
  const _Children({required this.children, required this.selected, required this.onOpen});

  final List<Child> children;
  final Child? selected;
  final void Function(Child child)? onOpen;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('more.yourChildren'),
            actionLabel: children.length > 3 ? t('home.viewAll') : null,
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: AppTheme.canvas,
                  body: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        ScreenHeader(title: t('more.yourChildren')),
                        Expanded(
                          child: ChildrenTab(
                            children: children,
                            selected: selected ?? children.first,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                t('common.noChildren'),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
            )
          else
            for (var i = 0; i < children.take(3).length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppTheme.border),
              _ChildRow(
                child: children[i],
                onTap: () {
                  final c = children[i];
                  onOpen?.call(c);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => StudentInfoScreen(child: c)),
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({required this.child, required this.onTap});

  final Child child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            CircleInitials(label: child.name, tint: Role.parent.tint, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
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
                    '${child.className}  •  ${tn('home.studentId', child.code)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(t('profile.active'), color: AppTheme.green),
            Icon(Icons.chevron_right_rounded, size: 19, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

class _Settings extends StatelessWidget {
  const _Settings({required this.children, required this.selected});

  final List<Child> children;
  final Child? selected;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _Row(
            icon: Icons.person_outline_rounded,
            title: t('profile.personal'),
            sub: t('profile.personalSub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          _Row(
            icon: Icons.home_outlined,
            title: t('more.homeAddress'),
            sub: t('more.homeAddressSub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HomeAddressScreen()),
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          _Row(
            icon: Icons.groups_outlined,
            title: t('nav.children'),
            sub: t('profile.childrenSub'),
            onTap: children.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: AppTheme.canvas,
                          body: SafeArea(
                            bottom: false,
                            child: Column(
                              children: [
                                ScreenHeader(title: t('nav.children')),
                                Expanded(
                                  child: ChildrenTab(
                                    children: children,
                                    selected: selected ?? children.first,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
          ),
          Divider(height: 1, color: AppTheme.border),
          const _ConsentsRow(),
          Divider(height: 1, color: AppTheme.border),
          _Row(
            icon: Icons.pin_drop_outlined,
            title: t('profile.dropoff'),
            sub: t('profile.dropoffSub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DropoffScreen()),
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          _Row(
            icon: Icons.family_restroom_outlined,
            title: t('profile.household'),
            sub: t('profile.householdSub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HouseholdScreen()),
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          _Row(
            icon: Icons.shield_outlined,
            title: t('profile.security'),
            sub: t('profile.securitySub'),
            onTap: () => showAppSheet<void>(
              context,
              builder: (_) => ChangePasswordSheet(tint: tint),
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          _Row(
            icon: Icons.settings_outlined,
            title: t('settings.title'),
            sub: t('profile.notificationsSub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          _Row(
            icon: Icons.receipt_long_rounded,
            title: t('fees.title'),
            sub: t('profile.paymentsSub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FeesScreen()),
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          _Row(
            icon: Icons.help_outline_rounded,
            title: t('profile.help'),
            sub: t('profile.helpSub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HelpScreen(child: children.isEmpty ? null : children.first),
              ),
            ),
            last: true,
          ),
        ],
      ),
    );
  }
}

class _ConsentsRow extends StatefulWidget {
  const _ConsentsRow();

  @override
  State<_ConsentsRow> createState() => _ConsentsRowState();
}

class _ConsentsRowState extends State<_ConsentsRow> {
  int _awaiting = 0;

  @override
  void initState() {
    super.initState();
    _count();
  }

  Future<void> _count() async {
    var awaiting = 0;
    try {
      awaiting = (await ParentApi.instance.consents()).awaitingCount;
    } catch (e) {
      debugPrint('profile: could not count the forms waiting for an answer: $e');
    }
    if (mounted && awaiting != _awaiting) setState(() => _awaiting = awaiting);
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ConsentsScreen()),
    );
    await _count();
  }

  @override
  Widget build(BuildContext context) => _Row(
        icon: Icons.fact_check_outlined,
        title: t('profile.consents'),
        sub: t('profile.consentsSub'),
        badge: _awaiting,
        onTap: _open,
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.badge = 0,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  final int badge;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (badge > 0) ...[
              Pill('$badge', color: AppTheme.amber),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right_rounded, size: 19, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.children, required this.attitude});

  final List<Child> children;
  final AttitudeSummary? attitude;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
      child: IconFigureStrip(
        figures: [
          IconFigure(
            icon: Icons.groups_outlined,
            label: t('nav.children'),
            value: '${children.length}',
            caption: t('profile.onAccount'),
            color: Role.parent.tint,
          ),
          IconFigure(
            icon: Icons.star_rounded,
            label: t('attitude.merits'),
            value: '${attitude?.merits ?? 0}',
            caption: t('att.thisTerm'),
            color: AppTheme.green,
          ),
          IconFigure(
            icon: Icons.error_outline_rounded,
            label: t('attitude.concerns'),
            value: '${attitude?.concerns ?? 0}',
            caption: t('att.thisTerm'),
            color: AppTheme.amber,
          ),
          IconFigure(
            icon: Icons.military_tech_rounded,
            label: t('attitude.points'),
            value: '${attitude?.points ?? 0}',
            caption: t('attitude.running'),
            color: AppTheme.blue,
          ),
        ],
      ),
    );
  }
}

class _LogOut extends StatelessWidget {
  const _LogOut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.rose.withValues(alpha: AppTheme.dark ? 0.14 : 0.07),
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.rose.withValues(alpha: AppTheme.dark ? 0.22 : 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.logout_rounded, size: 19, color: AppTheme.rose),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('more.signOut'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppTheme.rose,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    t('more.signOutSub'),
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 19, color: AppTheme.rose),
          ],
        ),
      ),
    );
  }
}
