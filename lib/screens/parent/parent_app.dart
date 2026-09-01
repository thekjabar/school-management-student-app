import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/kit.dart';
import '../../ui/nav_glyphs.dart';
import '../../ui/pickers.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import 'calendar_tab.dart';
import 'home_tab.dart';
import 'leave_screen.dart';
import 'messages_tab.dart';
import 'parent_profile_tab.dart';

/// The parent app.
///
/// Four tabs, and a child picker that sits inside the header above all of them.
/// Almost every question a guardian has is about ONE child — where is she, what
/// is her homework, has she been marked absent — and a family with three at the
/// school should answer it by tapping a name once rather than by finding the
/// right list on every screen.
class ParentApp extends StatefulWidget {
  const ParentApp({super.key});

  @override
  State<ParentApp> createState() => _ParentAppState();
}

class _ParentAppState extends State<ParentApp> {
  /// One per destination, so each tab remembers where it was and the back
  /// gesture unwinds the tab rather than the app.
  final _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  int _tab = 0;
  List<Child>? _children;
  String? _selectedId;
  String? _error;
  int _unread = 0;

  List<NavItem> get _nav => [
    NavItem(Icons.home_rounded, Icons.home_outlined, t('nav.home'), glyph: NavGlyph.home),
    NavItem(Icons.sms_rounded, Icons.sms_outlined, t('nav.messages'), glyph: NavGlyph.messages),
    NavItem(Icons.event_available_rounded, Icons.event_available_outlined, t('nav.calendar'),
        glyph: NavGlyph.calendar),
    NavItem(Icons.person_rounded, Icons.person_outline_rounded, t('nav.profile'),
        glyph: NavGlyph.profile),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final children = await ParentApi.instance.children();
      if (!mounted) return;
      setState(() {
        _children = children;
        _selectedId ??= children.isNotEmpty ? children.first.studentId : null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    }

    // The bell's count. Loaded after the children because it is the least
    // important thing on the screen and must not hold the rest up.
    try {
      final notices = await ParentApi.instance.announcements();
      if (!mounted) return;
      setState(() => _unread = notices.where((n) => n.readAt == null).length);
    } catch (_) {
      // A number on a bell is not worth an error state.
    }
  }

  Child? get _selected {
    final children = _children;
    if (children == null || children.isEmpty) return null;
    return children.firstWhere((c) => c.studentId == _selectedId, orElse: () => children.first);
  }


  /// Which child this screen is about.
  ///
  /// A sheet rather than a row of chips under the header: a family with four
  /// children had four chips competing with the greeting for the top of the
  /// screen, and the switch is something they do rarely and deliberately.
  Future<void> _pickChild(List<Child> children) async {
    final picked = await pickOne<String>(
      context,
      title: t('home.whichChild'),
      tint: Role.parent.tint,
      selected: _selectedId ?? children.first.studentId,
      options: children
          .map((c) => PickOption(
                value: c.studentId,
                label: c.name,
                subtitle: '${c.className} · ${c.code}',
                icon: Icons.child_care_rounded,
              ))
          .toList(),
    );
    if (picked != null && mounted) setState(() => _selectedId = picked);
  }

  @override
  Widget build(BuildContext context) {
    const role = Role.parent;
    final me = Session.instance.me;
    final children = _children;
    final child = _selected;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? t('greet.morning')
        : hour < 17
            ? t('greet.afternoon')
            : t('greet.evening');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navKeys[_tab].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_tab != 0) {
          setState(() => _tab = 0);
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: AppTheme.canvas,
      // No drawer. Everything the old one listed is reachable without it — the
      // account rows from the Profile tab, the child's screens from the Home
      // tab's quick actions, Home and Messages from the bottom bar — so the
      // menu button it hung from was spending the best 52pt in the header on a
      // second copy of the app's navigation.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              greeting: greeting,
              parentName: me?.name ?? '',
              childName: child?.name ?? '',
              className: child?.className ?? '',
              schoolName: me?.schoolName ?? '',
              tint: role.tint,
              onBell: () => setState(() => _tab = 1),
              notificationCount: _unread,
              // Only a family with more than one child gets the switcher.
              canSwitchChild: children != null && children.length > 1,
              onSwitchChild: () => _pickChild(children ?? const []),
            ),
            Expanded(
              child: children == null
                  // Nothing yet — either still coming, or it failed and we know
                  // why. Both belong HERE, in the space the content would have
                  // filled, with the header and the bottom bar still above and
                  // below them.
                  //
                  // The failure used to replace the whole app with a centred
                  // error page. A parent who could not reach the school lost
                  // the entire interface, which reads as "the app is broken"
                  // rather than "this list did not arrive".
                  ? (_error != null
                      ? _CannotReach(message: _error!, tint: role.tint, onRetry: _load)
                      // Not a spinner. The header and the bottom bar are
                      // already drawn by this point, so a spinner in the middle
                      // of them reads as one broken panel; blocks in the shape
                      // of the content read as the rest of it arriving.
                      : const _HomeSkeleton())
                  : child == null
                      ? const _NoChildren()
                      : IndexedStack(
                          index: _tab,
                          children: [
                            TabHost(
                              navigatorKey: _navKeys[0],
                              child: HomeTab(
                                child: child,
                                onOpenTab: (i) => setState(() => _tab = i),
                              ),
                            ),
                            TabHost(
                              navigatorKey: _navKeys[1],
                              child: MessagesTab(onRead: () => setState(() => _unread = 0)),
                            ),
                            TabHost(
                              navigatorKey: _navKeys[2],
                              child: CalendarTab(child: child),
                            ),
                            TabHost(
                              navigatorKey: _navKeys[3],
                              child: ParentProfileTab(
                                children: children,
                                onOpenChild: (c) => setState(() => _selectedId = c.studentId),
                              ),
                            ),
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
        onChanged: (i) {
          if (i == _tab) {
            _navKeys[i].currentState?.popUntil((r) => r.isFirst);
          } else {
            setState(() => _tab = i);
          }
        },
        // The one thing a parent DOES on this app rather than reads. Asking for
        // leave is the only action they initiate, so it is the only thing that
        // earns the raised button.
        centerIcon: Icons.add_rounded,
        onCenter: () {
          if (child == null) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LeaveScreen(child: child)),
          );
        },
        badges: {1: _unread > 0},
      ),
      ),
    );
  }
}


/* ---------------------------------------------------------------------------
 * The header
 * ------------------------------------------------------------------------- */

/// Who this screen is about, and the bell.
///
/// The leading menu button is gone with the drawer it opened, and the 52pt it
/// held has gone to the child: a bigger ring on the face, and a text column
/// wide enough that a real school name and a real class stop ellipsing on a
/// small handset. The face is the child switcher — the chevron on it is the
/// only affordance in the header now, so it is the only one that has to read.
class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.parentName,
    required this.childName,
    required this.className,
    required this.schoolName,
    required this.tint,
    required this.onBell,
    this.notificationCount = 0,
    this.canSwitchChild = false,
    this.onSwitchChild,
  });

  final String greeting;
  final String parentName;
  final String childName;
  final String className;
  final String schoolName;
  final Color tint;
  final VoidCallback onBell;
  final int notificationCount;
  final bool canSwitchChild;
  final VoidCallback? onSwitchChild;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 12),
      child: Row(
        children: [
          _Face(
            label: childName.isEmpty ? parentName : childName,
            tint: tint,
            canSwitch: canSwitchChild,
            onTap: canSwitchChild ? onSwitchChild : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$parentName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                // School, then the child's name and class — an emoji rather
                // than an icon because the design's glyph is a rendered
                // building, and a flat Material outline beside it reads as a
                // different app.
                // One paragraph rather than a row of competing boxes.
                //
                // As a Row the school and the class each took half the width
                // and both were cut, so "Rebaz Basic School — Erbil" showed as
                // "Rebaz Basic Sch…". A school's name is not decoration: it is
                // the one line that says which school this account belongs to,
                // and a parent with children at two of them reads it. Wrapping
                // to a second line costs nothing here and abbreviating it
                // costs the only thing the line is for.
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '🏫 ', style: TextStyle(fontSize: 11.5)),
                      TextSpan(
                        text: schoolName,
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                      if (className.isNotEmpty) ...[
                        TextSpan(
                          text: '  •  ',
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                        ),
                        TextSpan(
                          text: className,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: tint,
                          ),
                        ),
                      ],
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

/// The child's face, ringed, with the switcher on it.
class _Face extends StatelessWidget {
  const _Face({required this.label, required this.tint, required this.canSwitch, this.onTap});

  final String label;
  final Color tint;
  final bool canSwitch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tint, width: 1.6),
              ),
              child: CircleInitials(label: label, tint: tint, size: 45),
            ),
            PositionedDirectional(
              bottom: -1,
              end: -1,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.canvas, width: 1.8),
                ),
                child: Icon(
                  canSwitch ? Icons.expand_more_rounded : Icons.check_rounded,
                  size: 11,
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

class _NoChildren extends StatelessWidget {
  const _NoChildren();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.family_restroom_rounded, size: 38, color: AppTheme.textFaint),
          const SizedBox(height: 14),
          Text(
            t('common.noChildren'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            t('common.noChildrenBody'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}


/// The home screen's shape, before it has anything to put in it.
///
/// Deliberately the same geometry as the real thing — a wide bus card, a row of
/// tiles, two columns — so nothing moves sideways when the data lands. A
/// skeleton whose blocks are in different places from the content it becomes is
/// worse than a spinner, because the screen jumps at the exact moment somebody
/// starts reading it.
/// Shown in the content area when the first load failed and there is still
/// nothing to show. Sits inside the shell, so the header and the bottom bar
/// stay where they are.
class _CannotReach extends StatelessWidget {
  const _CannotReach({required this.message, required this.tint, required this.onRetry});

  final String message;
  final Color tint;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 36, color: AppTheme.textFaint),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: BigButton(label: t('common.tryAgain'), color: tint, onPressed: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const _Block(height: 92),
        const SizedBox(height: kCardGap),
        SizedBox(
          height: 86,
          child: Row(
            children: List.generate(
              4,
              (i) => Padding(
                padding: EdgeInsetsDirectional.only(end: i == 3 ? 0 : 10),
                child: const _Block(width: 74, height: 86),
              ),
            ),
          ),
        ),
        const SizedBox(height: kCardGap),
        const _Block(height: 168),
        const SizedBox(height: kCardGap),
        const _Block(height: 132),
      ],
    );
  }
}

/// One grey block. No shimmer: a sweep across five blocks on a cheap handset
/// costs a repaint of the whole column every frame, for a screen that is on
/// its way out.
class _Block extends StatelessWidget {
  const _Block({this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.neutralSoft,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
    );
  }
}
