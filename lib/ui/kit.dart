import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import 'nav_glyphs.dart';

/// The pieces the mockup is made of.
///
/// Every screen in the three apps is built from these seven, and nothing else:
/// a gradient header, a card, a strip of figures, a section heading, a list
/// row, a row of quick actions, and a bottom bar. Keeping the vocabulary that
/// small is what makes the parent app and the driver app feel like one product
/// rather than two that happen to share a logo.

/// The tinted header at the top of every home screen.
///
/// A soft vertical gradient from the role's colour into the page, rather than a
/// flat block: the flat version reads as a coloured bar stuck on top, and the
/// fade is what makes the card below it look like it is floating.
class RoleHeader extends StatelessWidget {
  const RoleHeader({
    super.key,
    required this.role,
    required this.greeting,
    required this.name,
    this.avatarLabel,
    this.notificationCount = 0,
    this.onBell,
    this.onAvatar,
    this.trailing,
    this.bottom,
  });

  final Role role;
  final String greeting;
  final String name;

  /// Initials, when there is no photograph — and there usually is not. Families
  /// here are frequently not comfortable with a child's photograph in an app,
  /// so a tinted circle of initials is the default rather than the fallback.
  final String? avatarLabel;

  final int notificationCount;
  final VoidCallback? onBell;

  /// Tapping the avatar opens the account drawer. The face is where people
  /// already press to find "my account" — a separate menu button beside it
  /// would be a second thing to learn for the same destination.
  final VoidCallback? onAvatar;
  final Widget? trailing;

  /// Anything that sits under the greeting inside the wash — the child picker,
  /// for instance.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [role.wash, AppTheme.canvas],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onAvatar,
                behavior: HitTestBehavior.opaque,
                child: CircleInitials(label: avatarLabel ?? name, tint: role.tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              // These three are independent. The menu used to live inside the
              // `else`, so any screen passing a `trailing` widget — the driver
              // and teacher apps both pass a date pill — silently lost the only
              // way into the account drawer.
              ?trailing,
              if (trailing == null && onBell != null)
                BellButton(count: notificationCount, onTap: onBell),
              if (onAvatar != null) ...[
                const SizedBox(width: 6),
                _MenuButton(onTap: onAvatar!),
              ],
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 14), bottom!],
        ],
      ),
    );
  }
}

/// A circle of initials, coloured from the name so the same person keeps the
/// same colour everywhere in the app.
class CircleInitials extends StatelessWidget {
  const CircleInitials({super.key, required this.label, this.tint, this.size = 42});

  final String label;
  final Color? tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = label.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first.characters.first.toUpperCase()
            : (parts.first.characters.first + parts.last.characters.first).toUpperCase();

    var hash = 0;
    for (final code in label.codeUnits) {
      hash = (hash * 31 + code) % 360;
    }
    final hue = hash.toDouble();
    final background = tint != null
        ? tint!.withValues(alpha: 0.16)
        : HSLColor.fromAHSL(1, hue, 0.55, 0.90).toColor();
    final foreground = tint ?? HSLColor.fromAHSL(1, hue, 0.55, 0.38).toColor();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// The bell, with the little red count on it.
class BellButton extends StatelessWidget {
  const BellButton({super.key, required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppTheme.surface, shape: BoxShape.circle),
            child: Icon(Icons.notifications_none_rounded, size: 21, color: AppTheme.text),
          ),
          if (count > 0)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 17),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.rose,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.surface, width: 1.6),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.surface,
                    height: 1.25,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One figure in a strip: a small grey label, a large value, and a caption
/// underneath that says whether the value is good.
class Figure {
  const Figure({required this.label, required this.value, this.caption, this.captionColor});

  final String label;
  final String value;
  final String? caption;
  final Color? captionColor;
}

/// Three figures side by side with hairline dividers between them.
///
/// Three, almost always. Four fits on a wide phone and wraps on a narrow one,
/// and a strip that reflows is a strip nobody can compare at a glance.
class FigureStrip extends StatelessWidget {
  const FigureStrip({super.key, required this.figures});

  final List<Figure> figures;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < figures.length; i++) {
      if (i > 0) {
        children.add(Container(width: 1, height: 40, color: AppTheme.border));
      }
      final f = figures[i];
      children.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  f.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 3),
                Text(
                  f.value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                if (f.caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    f.caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: f.captionColor ?? AppTheme.textFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

/// A section title with an optional "View All" on the right.
class Heading extends StatelessWidget {
  const Heading(this.title, {super.key, this.action, this.onAction, this.tint});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: tint ?? AppTheme.violet,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The rounded tinted square that fronts every list row.
class Chip36 extends StatelessWidget {
  const Chip36({
    super.key,
    required this.icon,
    required this.color,
    this.background,
    this.size = 36,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// A row inside a white card: chip, two lines of text, something on the right.
class TileRow extends StatelessWidget {
  const TileRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingSub,
    this.trailingColor,
    this.onTap,
    this.last = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? trailing;
  final String? trailingSub;
  final Color? trailingColor;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Chip36(icon: icon, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: trailingColor ?? AppTheme.textMuted,
                  ),
                ),
                if (trailingSub != null)
                  Text(
                    trailingSub!,
                    style: TextStyle(fontSize: 10.5, color: AppTheme.textFaint),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return Column(
      children: [
        if (onTap == null)
          content
        else
          InkWell(onTap: onTap, child: content),
        if (!last) Divider(height: 1, color: AppTheme.border),
      ],
    );
  }
}

/// One of the four squares in a Quick Actions row.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.glyph,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  /// Set when the design's mark is not in the Material set — see
  /// nav_glyphs.dart. [icon] stays required as the fallback.
  final Widget Function(Color color, double size)? glyph;
}

/// Six tinted squares across one card.
///
/// All six fit — they are not a scrolling strip. The design puts every route
/// out of the home screen on one line, and a row that scrolls hides two of them
/// behind a gesture nobody makes on a card. What gives instead is the label:
/// it scales down to fit its column rather than truncating, so "Assignments"
/// stays "Assignments" beside the shorter words.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      child: Column(
        children: [
          Row(
            children: [
          for (final a in actions)
            Expanded(
              child: GestureDetector(
                onTap: a.onTap,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: a.glyph == null
                          ? Icon(a.icon, size: 22, color: a.color)
                          : Center(child: a.glyph!(a.color, 22)),
                    ),
                    const SizedBox(height: 9),
                    // The padding is what keeps "Bus tracking" off
                    // "Assignments": a scale-down box shrinks to its
                    // CONSTRAINT, and six equal columns with no inset put two
                    // full-width words hard against each other.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          a.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                    ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          // A short rule beneath the row. Not a page indicator — the six fit —
          // but the design carries it, and it reads as "this is one set".
          Container(
            width: 34,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.violet.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

/// The white card everything sits on.
class Card16 extends StatelessWidget {
  const Card16({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.border,
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? border;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.surface,
        borderRadius: BorderRadius.circular(radius),
        // No outline on the light theme. A grey hairline round every card is
        // what turned a white page into a grey one: eight cards on a screen is
        // eight grey rectangles, and the design separates them with light.
        // The dark theme is the opposite — nothing casts a shadow on navy, so
        // there the border IS the edge.
        border: AppTheme.dark
            ? Border.all(color: border ?? AppTheme.border)
            : (border == null ? null : Border.all(color: border!)),
        boxShadow: AppTheme.dark
            ? null
            : const [
                BoxShadow(color: Color(0x0A101828), blurRadius: 14, offset: Offset(0, 4)),
                BoxShadow(color: Color(0x08101828), blurRadius: 3, offset: Offset(0, 1)),
              ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

/// A short status word: Excellent, Pending, High Priority.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color, this.background});

  final String label;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// One destination in the bottom bar.
class NavItem {
  const NavItem(this.filled, this.outline, this.label, {this.glyph});

  /// Set on the parent bar, whose four marks are drawn rather than taken from
  /// the Material set — see nav_glyphs.dart. The two IconData stay required so
  /// the driver and teacher bars are unaffected.
  final NavGlyph? glyph;

  final IconData filled;
  final IconData outline;
  final String label;
}

/// The bottom bar. Icon above a small label, the active one in the role colour.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.tint,
    required this.onChanged,
  });

  final List<NavItem> items;
  final int index;
  final Color tint;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final on = i == index;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    // Short enough to feel like a response to the tap rather
                    // than an animation being played at you.
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      // The selected tab is a soft pill in the role's colour
                      // rather than a bare tinted icon over a hairline rule.
                      // It reads as a control, and it is the same shape as
                      // every other selected thing in the app.
                      color: on ? tint.withValues(alpha: AppTheme.dark ? 0.22 : 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          scale: on ? 1.0 : 0.92,
                          child: Icon(
                            on ? item.filled : item.outline,
                            size: 21,
                            color: on ? tint : AppTheme.textFaint,
                          ),
                        ),
                        // The label appears only on the selected tab. Four
                        // permanent 10px captions is what made this bar look
                        // like a toolbar from another decade; the icons carry
                        // the rest, and the one that matters says its name.
                        ClipRect(
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: on ? 1.0 : 0.0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 140),
                              opacity: on ? 1 : 0,
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(start: 7),
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.1,
                                    color: tint,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// A bottom bar with a raised action in the middle.
///
/// The centre button is not a sixth destination — it is the one thing a parent
/// DOES rather than reads, and it sits apart because mixing an action into a
/// row of destinations is how people tap it expecting a page. Two slots either
/// side, which is as many as a thumb can reach without the bar becoming a
/// menu.
class CenterActionNav extends StatelessWidget {
  const CenterActionNav({
    super.key,
    required this.items,
    required this.index,
    required this.tint,
    required this.onChanged,
    required this.centerIcon,
    required this.onCenter,
    this.centerLabel,
    this.badges = const {},
  });

  final List<NavItem> items;
  final int index;
  final Color tint;
  final ValueChanged<int> onChanged;
  final IconData centerIcon;
  final VoidCallback onCenter;

  /// A word inside the button. The driver's raised action is not "add
  /// something" — it is the one thing the whole app exists to start, and a
  /// naked icon does not say which.
  final String? centerLabel;

  /// Index -> a dot on that item. A count is not shown: "you have something"
  /// is the whole message, and a number invites arithmetic nobody wanted.
  final Map<int, bool> badges;

  static const _bar = 64.0;

  /// How far the raised button rises above the bar.
  static const _lift = 10.0;
  static const _fab = 54.0;

  @override
  Widget build(BuildContext context) {
    final half = (items.length / 2).ceil();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: SizedBox(
          // Room above the bar for the part of the button that stands proud
          // of it. Without it the raised action is clipped by the bar's box.
          height: _bar + _lift,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: _bar,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: AppTheme.dark ? Border.all(color: AppTheme.border) : null,
                  boxShadow: AppTheme.dark
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x14101828),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    children: [
                      for (var i = 0; i < half; i++) Expanded(child: _slot(i)),
                      // The gap the raised button sits in.
                      SizedBox(width: _fab + 18),
                      for (var i = half; i < items.length; i++) Expanded(child: _slot(i)),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: GestureDetector(
                  onTap: onCenter,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: _fab,
                    height: _fab,
                    decoration: BoxDecoration(
                      // The role hue, not one fixed brand colour: the teacher
                      // bar is green in the design and a violet button in it
                      // would be the only violet on the screen.
                      color: tint,
                      shape: BoxShape.circle,
                      // The ring is the page showing through, which is what
                      // gives the bar its notch without cutting a hole in it.
                      border: Border.all(color: AppTheme.canvas, width: 3.5),
                      // A neutral halo, as the design draws it. Tinting the
                      // shadow with the button's own violet painted a coloured
                      // crescent on the ring, which read as a second circle
                      // rather than as depth.
                      boxShadow: AppTheme.dark
                          ? null
                          : const [
                              BoxShadow(
                                color: Color(0x1A101828),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                    ),
                    child: centerLabel == null
                        ? Icon(centerIcon, size: 25, color: Colors.white)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(centerIcon, size: 22, color: Colors.white),
                              Text(
                                centerLabel!,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The slate the design draws an unselected mark in.
  static Color get _idle =>
      AppTheme.dark ? const Color(0xFFA8B0C0) : const Color(0xFF5B6478);

  Widget _slot(int i) {
    final on = i == index;
    final item = items[i];

    // Where you are is a filled block on the dark canvas and a rule under the
    // word on the light one — exactly as the design draws it. A tint that works
    // on white is invisible on navy, and a rule on navy is invisible full stop.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(i),
      child: Container(
        height: _bar,
        color: on && AppTheme.dark
            ? tint.withValues(alpha: 0.18)
            : Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (on && !AppTheme.dark)
              // Clear of the bar's edge, and rounded on all four corners. Sat
              // flush against the bottom it was sliced in half by the bar's
              // own clip and read as a rendering fault rather than as a rule.
              PositionedDirectional(
                bottom: 7,
                child: Container(
                  width: 26,
                  height: 3,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (item.glyph != null)
                        NavGlyphIcon(
                          glyph: item.glyph!,
                          filled: on,
                          size: 21,
                          color: on ? tint : _idle,
                        )
                      else
                        Icon(
                          on ? item.filled : item.outline,
                          size: 21,
                          color: on ? tint : _idle,
                        ),
                      if (badges[i] == true)
                        PositionedDirectional(
                          top: -2,
                          end: -3,
                          child: Container(
                            width: 8.5,
                            height: 8.5,
                            decoration: BoxDecoration(
                              color: tint,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.surface, width: 1.4),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: on ? tint : _idle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.color,
    this.onPressed,
    this.busy = false,
    this.height = 48,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

/// A tinted banner with a circular icon on the right — the teacher's
/// "Today's Overview".
class Banner2 extends StatelessWidget {
  const Banner2({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.wash,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
      decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tint),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ],
      ),
    );
  }
}


/// Opens the account drawer.
///
/// Sits beside the bell rather than replacing the avatar, and looks exactly
/// like the bell, because the two do the same kind of thing: open something
/// from the header. The account used to be a labelled tab in the bottom bar;
/// moving it behind an icon means the icon has to be one people already read
/// as "menu", not a chevron tucked onto a circle of initials.
class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: t('nav.account'),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(Icons.menu_rounded, size: 19, color: AppTheme.textMuted),
        ),
      ),
    );
  }
}


/// A tab that can be navigated INSIDE.
///
/// Wraps one bottom-bar destination in its own Navigator so pushes from that
/// tab sit under the bar instead of over it. [key] must be stable per tab —
/// it is what lets the shell ask "can this tab go back?" before the app does.
class TabHost extends StatelessWidget {
  const TabHost({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => child,
      ),
    );
  }
}
