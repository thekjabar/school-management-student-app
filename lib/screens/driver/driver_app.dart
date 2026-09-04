import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/nav_glyphs.dart';
import 'announcements_screen.dart';
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

  /// Guards the Drive button. Finding the run can take a few seconds on a yard
  /// connection, and a driver who gets no answer presses again — which used to
  /// stack two copies of the run on top of each other.
  bool _finding = false;

  /// The dot on the header's notices button. Loaded quietly and failing
  /// quietly, the same as the teacher shell's own bell: a number on a button
  /// is not worth an error state on the screen behind it.
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _countUnread();
  }

  Future<void> _countUnread() async {
    try {
      final rows = await CrewApi.instance.announcements();
      if (!mounted) return;
      setState(() => _unread = rows.where((a) => a.readAt == null).length);
    } catch (_) {
      // Leave it at nought.
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

  /// Straight into the run. Not a menu: at 06:40 there is exactly one thing a
  /// driver wants from a big button in the middle of the screen.
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
      // errorText, never the exception. "SocketException: Failed host lookup"
      // in front of a driver is a bug report, not a message.
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  /// The school's notices for drivers and attendants — a screen that did not
  /// exist until now (see CrewAnnouncementsController's own doc comment).
  ///
  /// A fifth tab, or a menu, would be the obvious place; this shell is
  /// deliberately four destinations and one action, and the doc comment above
  /// explains why nothing sits behind a drawer here. So this button, not a
  /// new destination, is what makes the list reachable — the same shape the
  /// teacher shell already uses for its own bell.
  Future<void> _openAnnouncements() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DriverAnnouncements()),
    );
    // The count moves by reading notices on that screen, not by anything this
    // one is told directly — it is a pushed screen, not a tab kept alive
    // underneath, so the badge is only right again once it is asked afresh.
    if (mounted) _countUnread();
  }
}

/// The driver's header.
///
/// No drawer-menu button — there is nothing behind a drawer on this shell —
/// but there is now a notices button where the doc comment below used to say
/// there could never usefully be one. That was true of the bell that jumped
/// to the Route tab and showed nothing a route needed; it stopped being true
/// the day CrewAnnouncementsController shipped a real list for this screen to
/// open.
class _DriverHeader extends StatelessWidget {
  const _DriverHeader({
    required this.greeting,
    required this.name,
    required this.school,
    required this.notificationCount,
    required this.onBell,
  });

  final String greeting;
  final String name;
  final String school;
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
