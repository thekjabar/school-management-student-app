import 'package:flutter/material.dart';
import '../../ui/tab_memory.dart';

import '../../api/parent_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/kit.dart';
import '../../ui/nav_glyphs.dart';
import '../../ui/pickers.dart';
import '../../ui/home_kit.dart';
import 'calendar_tab.dart';
import 'home_tab.dart';
import 'leave_screen.dart';
import 'messages_tab.dart';
import 'parent_profile_tab.dart';
import 'profile_drawer.dart';

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
  // Held so the avatar can open the drawer: the Scaffold that owns it is
  // built by this very method, so there is no context above it to ask.
  final _scaffold = GlobalKey<ScaffoldState>();

  /// One per destination, so each tab remembers where it was and the back
  /// gesture unwinds the tab rather than the app.
  final _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  // A getter and setter over TabMemory rather than a field, so that every

  // `_tab = i` below keeps working untouched while the value itself survives

  // the remount a theme change causes.

  int get _tab => TabMemory.parent;

  set _tab(int v) => TabMemory.parent = v;
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
      setState(() => _error = e.toString());
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

    if (_error != null && children == null) {
      return Scaffold(
        backgroundColor: AppTheme.canvas,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 36, color: AppTheme.textFaint),
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, height: 1.5, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 180,
                    child: BigButton(label: t('common.tryAgain'), color: role.tint, onPressed: _load),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
      key: _scaffold,
      backgroundColor: AppTheme.canvas,
      // The account lives behind the avatar rather than in a fourth tab. A
      // "⋯ More" tab spends a quarter of the bottom bar on a drawer's worth of
      // settings, and hides the three things a parent opens the app for.
      drawer: children == null
          ? null
          : ProfileDrawer(
              children: children,
              selected: child,
              onSelectChild: (id) => setState(() => _selectedId = id),
              onGoTab: (i) => setState(() => _tab = i),
              unread: _unread,
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ParentHeader(
              greeting: greeting,
              parentName: me?.name ?? '',
              child: child == null
                  ? null
                  : ChildBrief(name: child.name, className: child.className),
              schoolName: me?.schoolName ?? '',
              tint: role.tint,
              onMenu: () => _scaffold.currentState?.openDrawer(),
              onBell: () => setState(() => _tab = 1),
              notificationCount: _unread,
              // Only a family with more than one child gets the switcher.
              canSwitchChild: children != null && children.length > 1,
              onSwitchChild: () => _pickChild(children ?? const []),
            ),
            Expanded(
              child: children == null
                  ? const Center(child: CircularProgressIndicator())
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

