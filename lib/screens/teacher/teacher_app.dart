import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/nav_glyphs.dart';
import '../../ui/pickers.dart';
import 'classes_tab.dart';
import 'exams_tab.dart';
import 'home_tab.dart';
import 'homework_tab.dart';
import 'messages_tab.dart';
import 'profile_tab.dart';
import 'teacher_account.dart';
import 'teacher_drawer.dart';

/// The teacher app.
///
/// Five slots, four of them destinations: what today looks like, what the
/// school has said, the week, and the teacher's own account — with the one
/// thing they DO in the middle. Classes, homework and exams moved off the bar
/// and onto the home screen's action row: they are things a teacher opens two
/// or three times a day, not places they live.
class TeacherApp extends StatefulWidget {
  const TeacherApp({super.key});

  @override
  State<TeacherApp> createState() => _TeacherAppState();
}

class _TeacherAppState extends State<TeacherApp> {
  // Held so the header's menu button can open the drawer: the Scaffold that
  // owns it is built by this method, so there is no context above it to ask.
  final _scaffold = GlobalKey<ScaffoldState>();
  int _tab = 0;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _countUnread();
  }

  /// The dot on Messages. Loaded quietly and failing quietly: a number on a
  /// bell is not worth an error state on the screen behind it.
  Future<void> _countUnread() async {
    try {
      final rows = await TeacherApi.instance.announcements();
      if (!mounted) return;
      setState(() => _unread = rows.where((a) => a.readAt == null).length);
    } catch (_) {
      // Leave it at nought.
    }
  }

  List<NavItem> get _nav => [
        NavItem(Icons.home_rounded, Icons.home_outlined, t('nav.home'), glyph: NavGlyph.home),
        NavItem(Icons.sms_rounded, Icons.sms_outlined, t('nav.messages'), glyph: NavGlyph.messages),
        NavItem(Icons.event_available_rounded, Icons.event_available_outlined, t('nav.calendar'),
            glyph: NavGlyph.calendar),
        NavItem(Icons.person_rounded, Icons.person_outline_rounded, t('nav.profile'),
            glyph: NavGlyph.profile),
      ];

  @override
  Widget build(BuildContext context) {
    const role = Role.teacher;
    final me = Session.instance.me;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? t('greet.morning')
        : hour < 17
            ? t('greet.afternoon')
            : t('greet.evening');

    return Scaffold(
      key: _scaffold,
      backgroundColor: AppTheme.canvas,
      drawer: const TeacherDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TeacherHeader(
              greeting: greeting,
              name: me?.name ?? '',
              notificationCount: _unread,
              onMenu: () => _scaffold.currentState?.openDrawer(),
              onBell: () => setState(() => _tab = 1),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  TeacherHome(onOpenTab: (i) => setState(() => _tab = i)),
                  const TeacherMessages(),
                  const TeacherWeekScreen(),
                  const TeacherProfileTab(),
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
        centerIcon: Icons.add_rounded,
        onCenter: _newThing,
        badges: {1: _unread > 0},
      ),
    );
  }

  /// The three things a teacher creates, behind the one button that means
  /// "make something". Set out as a sheet rather than three more tiles because
  /// each of them opens a form, and a form is not a destination.
  Future<void> _newThing() async {
    final picked = await pickOne<String>(
      context,
      title: t('teacher.newWork'),
      tint: Role.teacher.tint,
      options: [
        PickOption(
          value: 'homework',
          label: t('teacher.setHomework'),
          icon: Icons.assignment_add,
        ),
        PickOption(
          value: 'register',
          label: t('teacher.takeRegister'),
          icon: Icons.how_to_reg_rounded,
        ),
        PickOption(
          value: 'exam',
          label: t('teacher.exams'),
          icon: Icons.school_rounded,
        ),
      ],
    );
    if (picked == null || !mounted) return;
    final screen = switch (picked) {
      'homework' => const HomeworkTab(),
      'register' => const ClassesScreen(),
      _ => const ExamsTab(),
    };
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// Menu, face, greeting, role, bell.
///
/// Unlike the parent's header this names ONE person, so the space the child
/// switcher took goes to the line under the greeting and the role badge — which
/// is what tells a teacher at a glance that they are in the staff app and not
/// the one they use for their own children.
class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({
    required this.greeting,
    required this.name,
    required this.onMenu,
    required this.onBell,
    this.notificationCount = 0,
  });

  final String greeting;
  final String name;
  final VoidCallback onMenu;
  final VoidCallback onBell;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    final first = name.trim().split(RegExp(r'\s+')).first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 12),
      child: Row(
        children: [
          SquareButton(icon: Icons.menu_rounded, onTap: onMenu),
          const SizedBox(width: 10),
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
                      color: tint,
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
                  // greet.morning is "Good morning," — comma included, because
                  // in Kurdish and Arabic the punctuation does not sit where an
                  // English template would put it.
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
                  t('teacher.greetLine'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded, size: 13, color: tint),
                      const SizedBox(width: 5),
                      Text(
                        t('teacher.roleLabel'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SquareButton(
            icon: Icons.notifications_none_rounded,
            onTap: onBell,
            badge: notificationCount,
          ),
        ],
      ),
    );
  }
}
