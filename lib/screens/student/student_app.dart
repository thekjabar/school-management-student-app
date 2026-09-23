import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/push.dart';
import '../../api/session.dart';
import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/nav_glyphs.dart';
import '../../ui/pickers.dart';
import 'announcements_screen.dart';
import 'home_tab.dart';
import 'id_card.dart';
import 'marks_tab.dart';
import 'profile_tab.dart';
import 'student_kit.dart';
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

  bool _switching = false;

  static String? _spanOf(MySchool school) {
    if (school.from == null) return null;
    return school.to == null
        ? tv('student.schoolFrom', {'from': school.from!})
        : tv('student.schoolFromTo', {'from': school.from!, 'to': school.to!});
  }

  Future<void> _switchSchool() async {
    final schools = Session.instance.mySchools.value;
    if (schools.length < 2 || _switching) return;

    final here = schools.where((s) => s.current);
    final picked = await pickOne<String>(
      context,
      title: t('student.mySchools'),
      tint: Role.student.tint,
      selected: here.isEmpty ? null : here.first.studentId,
      options: [
        for (final s in schools)
          PickOption<String>(
            value: s.studentId,
            label: s.schoolNames.inLang(AppLocale.current.value) ?? s.schoolName,
            subtitle: [
              s.stillEnrolled ? t('student.schoolNow') : t('student.schoolLeft'),
              ?_spanOf(s),
            ].join(' · '),
            icon: s.stillEnrolled ? Icons.school_rounded : Icons.history_rounded,
          ),
      ],
    );
    if (!mounted || picked == null) return;
    if (schools.any((s) => s.studentId == picked && s.current)) return;

    setState(() => _switching = true);
    try {
      await Session.instance.openSchool(picked);
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

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
            ValueListenableBuilder<List<MySchool>>(
              valueListenable: Session.instance.mySchools,
              builder: (context, schools, _) => _StudentHeader(
                greeting: greeting,
                name: me?.name ?? '',
                school: me?.schoolName ?? '',
                switching: _switching,
                onSwitchSchool: schools.length > 1 ? _switchSchool : null,
                onBell: () {
                  Push.arrived.value = 0;
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StudentAnnouncementsScreen()),
                  );
                },
              ),
            ),
            const StudentReadOnlyBanner(),
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

class StudentReadOnlyBanner extends StatelessWidget {
  const StudentReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Session.instance.readOnlyHere,
      builder: (context, readOnly, _) {
        if (!readOnly) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 12),
          child: Banner2(
            title: t('student.schoolLeft'),
            subtitle: t('student.readOnlyHere'),
            icon: Icons.history_rounded,
            tint: AppTheme.amber,
            wash: AppTheme.amberSoft,
          ),
        );
      },
    );
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({
    required this.greeting,
    required this.name,
    required this.school,
    required this.onBell,
    required this.switching,
    this.onSwitchSchool,
  });

  final String greeting;
  final String name;
  final String school;
  final VoidCallback onBell;
  final bool switching;
  final VoidCallback? onSwitchSchool;

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
                GestureDetector(
                  onTap: switching ? null : onSwitchSchool,
                  child: Container(
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
                        if (onSwitchSchool != null) ...[
                          const SizedBox(width: 4),
                          switching
                              ? SizedBox(
                                  width: 11,
                                  height: 11,
                                  child: CircularProgressIndicator(strokeWidth: 1.6, color: tint),
                                )
                              : Icon(Icons.unfold_more_rounded, size: 13, color: tint),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<int>(
            valueListenable: Push.arrived,
            builder: (context, arrived, _) => StudentBell(unread: arrived > 0, onTap: onBell),
          ),
        ],
      ),
    );
  }
}
