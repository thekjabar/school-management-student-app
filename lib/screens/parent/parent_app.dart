import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/kit.dart';
import 'children_tab.dart';
import 'home_tab.dart';
import 'messages_tab.dart';
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
  int _tab = 0;
  List<Child>? _children;
  String? _selectedId;
  String? _error;
  int _unread = 0;

  List<NavItem> get _nav => [
    NavItem(Icons.home_rounded, Icons.home_outlined, t('nav.home')),
    NavItem(Icons.child_care_rounded, Icons.child_care_outlined, t('nav.children')),
    NavItem(Icons.forum_rounded, Icons.forum_outlined, t('nav.messages')),
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

    return Scaffold(
      key: _scaffold,
      backgroundColor: AppTheme.canvas,
      // The account lives behind the avatar rather than in a fourth tab. A
      // "⋯ More" tab spends a quarter of the bottom bar on a drawer's worth of
      // settings, and hides the three things a parent opens the app for.
      drawer: children == null ? null : ProfileDrawer(children: children),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RoleHeader(
              role: role,
              greeting: greeting,
              name: me?.name ?? '',
              notificationCount: _unread,
              onBell: () => setState(() => _tab = 2),
              onAvatar: () => _scaffold.currentState?.openDrawer(),
              // The picker only appears for a family with more than one child.
              // A single chip that never changes anything is furniture.
              bottom: (children != null && children.length > 1)
                  ? _ChildPicker(
                      children: children,
                      selectedId: child?.studentId,
                      tint: role.tint,
                      onSelect: (id) => setState(() => _selectedId = id),
                    )
                  : null,
            ),
            Expanded(
              child: children == null
                  ? const Center(child: CircularProgressIndicator())
                  : child == null
                      ? const _NoChildren()
                      : IndexedStack(
                          index: _tab,
                          children: [
                            HomeTab(child: child, onOpenTab: (i) => setState(() => _tab = i)),
                            ChildrenTab(children: children, selected: child),
                            MessagesTab(onRead: () => setState(() => _unread = 0)),
                          ],
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        items: _nav,
        index: _tab,
        tint: role.tint,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

/// The row of children in the header.
class _ChildPicker extends StatelessWidget {
  const _ChildPicker({
    required this.children,
    required this.selectedId,
    required this.tint,
    required this.onSelect,
  });

  final List<Child> children;
  final String? selectedId;
  final Color tint;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = children[i];
          final on = c.studentId == selectedId;
          return GestureDetector(
            onTap: () => onSelect(c.studentId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? tint : AppTheme.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                // First name plus class: two children in one family often share
                // a given name in this region.
                '${c.name.split(' ').first} · ${c.className}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : AppTheme.textMuted,
                ),
              ),
            ),
          );
        },
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
