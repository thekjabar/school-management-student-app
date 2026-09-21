import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/nav_glyphs.dart';
import 'announcements_screen.dart';
import 'home_tab.dart';
import 'id_card.dart';
import 'marks_tab.dart';
import 'profile_tab.dart';
import 'timetable_tab.dart';

class StudentApp extends StatefulWidget {
  const StudentApp({super.key});

  @override
  State<StudentApp> createState() => _StudentAppState();
}

class _StudentAppState extends State<StudentApp> {
  int _tab = 0;

  List<NavItem> get _nav => [
        NavItem(Icons.home_rounded, Icons.home_outlined, t('nav.home'), glyph: NavGlyph.home),
        NavItem(Icons.event_available_rounded, Icons.event_available_outlined,
            t('student.timetable'),
            glyph: NavGlyph.calendar),
        NavItem(Icons.workspace_premium_rounded, Icons.workspace_premium_outlined,
            t('student.marks')),
        NavItem(Icons.person_rounded, Icons.person_outline_rounded, t('nav.profile'),
            glyph: NavGlyph.profile),
      ];

  @override
  Widget build(BuildContext context) {
    const role = Role.student;
    final me = Session.instance.me;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? t('greet.morning')
        : hour < 17
            ? t('greet.afternoon')
            : t('greet.evening');

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _StudentHeader(
              greeting: greeting,
              name: me?.name ?? '',
              school: me?.schoolName ?? '',
              onBell: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StudentAnnouncementsScreen()),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  StudentHome(onOpenTab: (i) => setState(() => _tab = i)),
                  const StudentWeek(),
                  const StudentMarks(),
                  const StudentProfileTab(),
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
        centerIcon: Icons.qr_code_2_rounded,
        centerLabel: t('student.idCard'),
        onCenter: () => showIdCard(context),
      ),
    );
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({
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
    final tint = Role.student.tint;
    final first = name.trim().isEmpty ? '' : name.trim().split(RegExp(r'\s+')).first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 12),
      child: Row(
        children: [
          CircleInitials(label: name, tint: tint, size: 48),
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
                  t('student.greetLine'),
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
                      Flexible(
                        child: Text(
                          school.isNotEmpty ? school : t('student.roleLabel'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: tint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
