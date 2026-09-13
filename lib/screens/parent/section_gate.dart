import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

enum SectionFrame { screen, page, inline }

PackageEntitlements get _now => Entitlements.instance.current.value;

bool sectionLocked(String childId, String section) => _now.isLocked(childId, section);

Future<T?> openSection<T>(
  BuildContext context, {
  required String childId,
  required String section,
  required WidgetBuilder builder,
}) =>
    _open<T>(
      context,
      section: section,
      access: () => _now.access(childId, section),
      gate: (_) => SectionGate(childId: childId, section: section, builder: builder),
    );

Future<T?> openHouseholdSection<T>(
  BuildContext context, {
  required Iterable<String> childIds,
  required String section,
  required WidgetBuilder builder,
}) {
  final ids = childIds.toList();
  return _open<T>(
    context,
    section: section,
    access: () => _householdAccess(ids, section),
    gate: (_) => HouseholdSectionGate(childIds: ids, section: section, builder: builder),
  );
}

Future<T?> _open<T>(
  BuildContext context, {
  required String section,
  required SectionAccess Function() access,
  required WidgetBuilder gate,
}) async {
  if (access() == SectionAccess.unknown) {
    await Entitlements.instance.ensureLoaded();
    if (!context.mounted) return null;
  }
  if (access() == SectionAccess.locked) {
    unawaited(Entitlements.instance.refresh());
    await showSectionLocked(context, section);
    return null;
  }
  return Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: gate));
}

SectionAccess _householdAccess(List<String> childIds, String section) {
  final now = _now;
  if (!now.loaded) return SectionAccess.unknown;
  if (childIds.isEmpty) return now.paidSections.contains(section) ? SectionAccess.locked : SectionAccess.open;
  return now.lockedForAll(childIds, section) ? SectionAccess.locked : SectionAccess.open;
}

Future<void> showSectionLocked(BuildContext context, String section) {
  return showAppSheet<void>(
    context,
    builder: (sheet) => Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              LockedSectionPanel(section: section, framed: false),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: BigButton(
                  label: t('common.close'),
                  color: Role.parent.tint,
                  onPressed: () => Navigator.of(sheet).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String sectionTitle(String section) =>
    _now.nameFor(section, AppLocale.current.value.name) ?? t('section.inPackage');

class SectionGate extends StatelessWidget {
  const SectionGate({
    super.key,
    required this.childId,
    required this.section,
    required this.builder,
    this.frame = SectionFrame.screen,
  });

  final String childId;
  final String section;
  final WidgetBuilder builder;

  final SectionFrame frame;

  @override
  Widget build(BuildContext context) => _Gate(
        section: section,
        access: (now) => now.access(childId, section),
        builder: builder,
        frame: frame,
      );
}

class HouseholdSectionGate extends StatelessWidget {
  const HouseholdSectionGate({
    super.key,
    required this.childIds,
    required this.section,
    required this.builder,
  });

  final List<String> childIds;
  final String section;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => _Gate(
        section: section,
        access: (_) => _householdAccess(childIds, section),
        builder: builder,
        frame: SectionFrame.screen,
      );
}

class _Gate extends StatefulWidget {
  const _Gate({
    required this.section,
    required this.access,
    required this.builder,
    required this.frame,
  });

  final String section;
  final SectionAccess Function(PackageEntitlements now) access;
  final WidgetBuilder builder;
  final SectionFrame frame;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _checking = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    Entitlements.instance.current.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    Entitlements.instance.current.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_checking || _failed) return;
    if (widget.access(_now) != SectionAccess.unknown) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_checking) _check();
    });
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _failed = false;
    });
    await Entitlements.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _failed = !_now.loaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PackageEntitlements>(
      valueListenable: Entitlements.instance.current,
      builder: (context, now, _) => switch (widget.access(now)) {
        SectionAccess.open => widget.builder(context),
        SectionAccess.locked => _frame(LockedSectionPanel(section: widget.section)),
        SectionAccess.unknown => _frame(
            _failed && !_checking
                ? _CouldNotCheck(onRetry: _check)
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  ),
          ),
      },
    );
  }

  Widget _frame(Widget body) {
    if (widget.frame == SectionFrame.inline) return body;
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 24),
      children: [body],
    );
    if (widget.frame == SectionFrame.page) return list;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: sectionTitle(widget.section)),
            Expanded(child: list),
          ],
        ),
      ),
    );
  }
}

class _CouldNotCheck extends StatelessWidget {
  const _CouldNotCheck({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('section.couldNotCheck'),
            style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: BigButton(
              label: t('common.tryAgain'),
              color: Role.parent.tint,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class LockedSectionPanel extends StatelessWidget {
  const LockedSectionPanel({super.key, required this.section, this.framed = true});

  final String section;

  final bool framed;

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final lang = AppLocale.current.value.name;
    final name = now.nameFor(section, lang);
    final blurb = now.blurbFor(section, lang);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Chip36(icon: Icons.lock_rounded, color: AppTheme.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name ?? t('section.inPackage'),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppTheme.text,
                    ),
                  ),
                  if (name != null)
                    Text(
                      t('section.inPackage'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.amber,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (blurb.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            blurb,
            style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.text),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          t('quick.locked'),
          style: TextStyle(fontSize: 12.5, height: 1.55, color: AppTheme.textMuted),
        ),
      ],
    );

    return framed ? Card16(child: body) : body;
  }
}

class LockedSectionCard extends StatelessWidget {
  const LockedSectionCard({
    super.key,
    required this.section,
    this.icon = Icons.lock_rounded,
    this.compact = false,
  });

  final String section;
  final IconData icon;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final words = [
      Text(
        sectionTitle(section),
        maxLines: compact ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: AppTheme.text,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        t('section.inPackage'),
        maxLines: compact ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
      ),
    ];

    return Card16(
      padding: const EdgeInsets.all(13),
      onTap: () => showSectionLocked(context, section),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Chip36(icon: icon, color: AppTheme.textFaint),
                    const Spacer(),
                    Icon(Icons.lock_rounded, size: 17, color: AppTheme.textFaint),
                  ],
                ),
                const SizedBox(height: 10),
                ...words,
              ],
            )
          : Row(
              children: [
                Chip36(icon: icon, color: AppTheme.textFaint),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: words,
                  ),
                ),
                Icon(Icons.lock_rounded, size: 17, color: AppTheme.textFaint),
              ],
            ),
    );
  }
}
