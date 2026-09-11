import 'package:flutter/material.dart';

import '../../api/offline_cache.dart';
import '../../api/parent_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/format.dart';
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

class ParentApp extends StatefulWidget {
  const ParentApp({super.key});

  @override
  State<ParentApp> createState() => _ParentAppState();
}

class _ParentAppState extends State<ParentApp> {
  List<GlobalKey<NavigatorState>> _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

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

    try {
      final notices = await ParentApi.instance.announcements();
      if (!mounted) return;
      setState(() => _unread = notices.where((n) => n.readAt == null).length);
    } catch (_) {
    }
  }

  Child? get _selected {
    final children = _children;
    if (children == null || children.isEmpty) return null;
    return children.firstWhere((c) => c.studentId == _selectedId, orElse: () => children.first);
  }

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
    if (picked != null && mounted) _switchTo(picked);
  }

  void _switchTo(String id) {
    if (id == _selectedId) return;
    setState(() {
      _selectedId = id;
      _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
      _tab = 0;
    });
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
              canSwitchChild: children != null && children.length > 1,
              onSwitchChild: () => _pickChild(children ?? const []),
            ),
            ValueListenableBuilder<DateTime?>(
              valueListenable: OfflineCache.instance.savedDataShown,
              builder: (context, savedAt, _) {
                if (savedAt == null) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  color: AppTheme.amber.withValues(alpha: AppTheme.dark ? 0.18 : 0.10),
                  padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 7),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 14, color: AppTheme.amber),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          tn('offline.savedAt', hhmm(savedAt)),
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: children == null
                  ? (_error != null
                      ? _CannotReach(message: _error!, tint: role.tint, onRetry: _load)
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
                                onOpenChild: (c) => _switchTo(c.studentId),
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
        centerIcon: Icons.add_rounded,
        centerLabel: t('nav.askLeave'),
        onCenter: () {
          if (child == null) {
            showNote(
              context,
              _error ?? t('common.noChildren'),
              bad: true,
            );
            return;
          }
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
