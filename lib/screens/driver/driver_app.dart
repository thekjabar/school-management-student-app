import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../api/device_heartbeat.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/nav_glyphs.dart';
import '../school_picker.dart';
import 'announcements_screen.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'route_tab.dart';
import 'students_tab.dart';
import 'trip_screen.dart';

class DriverApp extends StatefulWidget {
  const DriverApp({super.key});

  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> {
  int _tab = 0;

  bool _finding = false;

  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _countUnread();
    unawaited(DeviceHeartbeat.instance.start());
  }

  @override
  void dispose() {
    DeviceHeartbeat.instance.stop();
    super.dispose();
  }

  Future<void> _countUnread() async {
    try {
      final rows = await CrewApi.instance.announcements();
      if (!mounted) return;
      setState(() => _unread = rows.where((a) => a.readAt == null).length);
    } catch (_) {
    }
  }

  List<NavItem> get _nav => [
        NavItem(Icons.home_rounded, Icons.home_outlined, t('nav.home'), glyph: NavGlyph.home),
        NavItem(Icons.map_rounded, Icons.map_outlined, t('driver.route'), glyph: NavGlyph.route),
        NavItem(Icons.groups_rounded, Icons.groups_outlined, t('driver.students'),
            glyph: NavGlyph.students),
        NavItem(Icons.person_rounded, Icons.person_outline_rounded, t('driver.profile'),
            glyph: NavGlyph.profile),
      ];

  @override
  Widget build(BuildContext context) {
    const role = Role.driver;
    final me = Session.instance.me;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? t('greet.morning')
        : hour < 17
            ? t('greet.afternoon')
            : t('greet.evening');

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DriverHeader(
              greeting: greeting,
              name: me?.name ?? '',
              school: me?.schoolName ?? '',
              canSwitchSchool: schoolsForRole(role).length > 1,
              onSwitchSchool: () => pickSchool(context, role: role),
              notificationCount: _unread,
              onBell: _openAnnouncements,
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  DriverHome(onOpenTab: (i) => setState(() => _tab = i)),
                  const DriverRoute(),
                  const DriverStudents(),
                  const DriverProfile(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CenterActionNav(
        items: _nav,
        index: _tab,
        tint: role.tint,
        onChanged: (i) => setState(() => _tab = i),
        centerIcon: Icons.drive_eta_rounded,
        centerLabel: t('driver.drive'),
        onCenter: _drive,
      ),
    );
  }

  Future<void> _drive() async {
    if (_finding) return;
    setState(() => _finding = true);
    try {
      final trip = await loadDutyTrip();
      if (!mounted) return;
      if (trip == null) {
        showNote(context, t('driver.noRunsToday'));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TripScreen(tripId: trip.id, serviceDate: trip.serviceDate),
        ),
      );
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  Future<void> _openAnnouncements() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DriverAnnouncements()),
    );
    if (mounted) _countUnread();
  }
}

class _DriverHeader extends StatelessWidget {
  const _DriverHeader({
    required this.greeting,
    required this.name,
    required this.school,
    required this.canSwitchSchool,
    required this.onSwitchSchool,
    required this.notificationCount,
    required this.onBell,
  });

  final String greeting;
  final String name;
  final String school;
  final bool canSwitchSchool;
  final VoidCallback onSwitchSchool;
  final int notificationCount;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    final tint = Role.driver.tint;
    final first = name.trim().split(RegExp(r'\s+')).first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 12),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleInitials(label: name, tint: tint, size: 48),
                PositionedDirectional(
                  bottom: 1,
                  end: 1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.canvas, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$greeting $first 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.2,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t('driver.greetLine'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
                if (school.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: canSwitchSchool ? onSwitchSchool : null,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        const Text('🏫', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            school,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: canSwitchSchool ? FontWeight.w700 : FontWeight.w400,
                              color: canSwitchSchool ? tint : AppTheme.textMuted,
                            ),
                          ),
                        ),
                        if (canSwitchSchool) ...[
                          const SizedBox(width: 2),
                          Icon(Icons.expand_more_rounded, size: 14, color: tint),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SquareButton(
            icon: Icons.campaign_outlined,
            onTap: onBell,
            badge: notificationCount,
          ),
        ],
      ),
    );
  }
}
