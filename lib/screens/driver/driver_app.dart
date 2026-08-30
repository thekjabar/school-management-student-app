import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/nav_glyphs.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'route_tab.dart';
import 'students_tab.dart';
import 'trip_screen.dart';

/// The driver and attendant app.
///
/// Four destinations and one action: what today looks like, the route, the
/// children on it, and the driver's own account — with Drive in the middle,
/// which is the only thing on this app anybody presses in a hurry.
///
/// No drawer. It held the same settings the Profile tab now does, behind a
/// gesture people were not making. Everything is sized for a hand on a bus:
/// rows are tall, the primary action is full width, and nothing important is
/// behind a menu — a driver reading this is standing in an aisle counting
/// children, not sitting at a desk.
class DriverApp extends StatefulWidget {
  const DriverApp({super.key});

  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> {
  int _tab = 0;

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
              onBell: () => setState(() => _tab = 1),
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

  /// Straight into the run. Not a menu: at 06:40 there is exactly one thing a
  /// driver wants from a big button in the middle of the screen.
  Future<void> _drive() async {
    try {
      final trip = await loadDutyTrip();
      if (!mounted) return;
      if (trip == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('driver.noRunsToday'))),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripScreen(tripId: trip.id)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// The driver's header. No menu button — there is no drawer to open.
class _DriverHeader extends StatelessWidget {
  const _DriverHeader({
    required this.greeting,
    required this.name,
    required this.school,
    required this.onBell,
  });

  final String greeting;
  final String name;
  final String school;
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
                  Row(
                    children: [
                      const Text('🏫', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          school,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SquareButton(icon: Icons.notifications_none_rounded, onTap: onBell),
        ],
      ),
    );
  }
}
