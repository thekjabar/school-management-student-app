import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'home_kit.dart';
import 'kit.dart';

/// The furniture every parent screen below the home tab is built from.
///
/// Seven pieces, and the reason they live together is that the designs reuse
/// them verbatim: the same back button on Timetable and Leave, the same child
/// card under it, the same pill tabs across Attitude, Attendance and
/// Assignments. Rebuilding each one per screen is how six screens end up with
/// six slightly different tab strips.

/* ---------------------------------------------------------------------------
 * Titles
 * ------------------------------------------------------------------------- */

/// Back arrow, title, bell — the header on a pushed screen.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.notificationCount = 0,
    this.onBell,
    this.trailing,
  });

  final String title;
  final int notificationCount;
  final VoidCallback? onBell;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 10),
      child: Row(
        children: [
          SquareButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppTheme.text,
              ),
            ),
          ),
          ?trailing,
          if (trailing == null && onBell != null)
            SquareButton(
              icon: Icons.notifications_none_rounded,
              onTap: onBell!,
              badge: notificationCount,
            ),
        ],
      ),
    );
  }
}

/// A big title with something on the right — the shape the tab screens use,
/// where the header above already names the parent.
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: AppTheme.text,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Which child
 * ------------------------------------------------------------------------- */

/// The child, full width, with a caret — the card that sits under a screen
/// header and says who everything below is about.
class ChildCard extends StatelessWidget {
  const ChildCard({
    super.key,
    required this.name,
    required this.line,
    required this.tint,
    this.onTap,
  });

  final String name;
  final String line;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, kCardGap),
      child: Card16(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tint.withValues(alpha: 0.5), width: 1.5),
              ),
              child: CircleInitials(label: name, tint: tint, size: 42),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.expand_more_rounded, size: 22, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

/// The compact version, for the right of a page title.
class ChildPill extends StatelessWidget {
  const ChildPill({
    super.key,
    required this.name,
    required this.line,
    required this.tint,
    this.onTap,
  });

  final String name;
  final String line;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 178),
        padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 8, 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleInitials(label: name, tint: tint, size: 30),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: AppTheme.text,
                    ),
                  ),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.expand_more_rounded, size: 17, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Tabs
 * ------------------------------------------------------------------------- */

class TabSpec {
  const TabSpec({required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;

  /// The designs colour each tab's own icon — amber for Pending, green for
  /// Approved, rose for Rejected — which is most of what makes the strip
  /// readable at a glance rather than four identical words.
  final Color? color;
}

/// The filled-pill strip: one tab is a solid block, the rest sit on the card.
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
    required this.tint,
  });

  final List<TabSpec> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == index ? tint : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (tabs[i].icon != null) ...[
                        Icon(
                          tabs[i].icon,
                          size: 14,
                          color: i == index
                              ? Colors.white
                              : tabs[i].color ?? AppTheme.textMuted,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tabs[i].label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: i == index ? Colors.white : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The underline strip, for when the tabs sit directly on the page.
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
    required this.tint,
  });

  final List<TabSpec> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: Container(height: 1.5, color: AppTheme.border),
          ),
          Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (tabs[i].icon != null) ...[
                              Icon(
                                tabs[i].icon,
                                size: 14,
                                color: i == index
                                    ? tint
                                    : tabs[i].color ?? AppTheme.textMuted,
                              ),
                              const SizedBox(width: 5),
                            ],
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  tabs[i].label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: i == index ? tint : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Container(
                          height: 2.5,
                          color: i == index ? tint : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Banners and boxes
 * ------------------------------------------------------------------------- */

/// The tinted note at the foot of most of these screens.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    this.action,
    this.onAction,
    this.onClose,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.dark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.textMuted),
                ),
                if (action != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onAction,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        action!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Icon(Icons.close_rounded, size: 17, color: AppTheme.textFaint),
            ),
        ],
      ),
    );
  }
}

/// One of the small bordered figures the designs put in a 2×2 beside a verdict.
class StatBox extends StatelessWidget {
  const StatBox({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.caption,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.2,
                    color: AppTheme.text,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 8.5, color: AppTheme.textMuted, height: 1.25),
                ),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 8.5, color: AppTheme.textFaint, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A short status word on a tinted ground — the design's Present / Absent /
/// Due Tomorrow / Submitted chips.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
