import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import 'async.dart';
import 'motion.dart';
import 'nav_glyphs.dart';

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

  final String? avatarLabel;

  final int notificationCount;
  final VoidCallback? onBell;

  final VoidCallback? onAvatar;
  final Widget? trailing;

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

class Figure {
  const Figure({required this.label, required this.value, this.caption, this.captionColor});

  final String label;
  final String value;
  final String? caption;
  final Color? captionColor;
}

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

class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.glyph,
    this.enabled = true,
    this.locked = false,
    this.note,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  final bool enabled;

  final bool locked;

  final String? note;

  final Widget Function(Color color, double size)? glyph;
}

class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.actions});

  final List<QuickAction> actions;

  static const _tile = 62.0;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      child: LayoutBuilder(
        builder: (context, box) {
          final fits = actions.length * _tile <= box.maxWidth;
          final row = Row(
            mainAxisSize: fits ? MainAxisSize.max : MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++)
                SizedBox(
                  width: fits ? box.maxWidth / actions.length : _tile,
                  child: _Tile(action: actions[i], index: i),
                ),
            ],
          );

          if (fits) {
            return Column(
              children: [row, const SizedBox(height: 11), const _Rule(progress: 0, visible: 1)],
            );
          }
          return _ScrollingActions(
            row: row,
            width: box.maxWidth,
            span: actions.length * _tile,
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.action, this.index = 0});

  final QuickAction action;

  final int index;

  @override
  Widget build(BuildContext context) {
    final on = action.enabled && !action.locked;
    final tint = on ? action.color : AppTheme.textFaint;

    return GestureDetector(
      onTap: on
          ? action.onTap
          : action.note == null
              ? null
              : () => showNote(context, action.note!),
      behavior: HitTestBehavior.opaque,
      child: Rise(
        index: index,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pop(
              index: index,
              extraDelay: const Duration(milliseconds: 60),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: action.glyph == null
                        ? Icon(action.icon, size: 22, color: tint)
                        : Center(child: action.glyph!(tint, 22)),
                  ),
                  if (action.locked)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Icon(Icons.lock_rounded, size: 10, color: AppTheme.textFaint),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: on ? AppTheme.text : AppTheme.textFaint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollingActions extends StatefulWidget {
  const _ScrollingActions({required this.row, required this.width, required this.span});

  final Widget row;
  final double width;
  final double span;

  @override
  State<_ScrollingActions> createState() => _ScrollingActionsState();
}

class _ScrollingActionsState extends State<_ScrollingActions> {
  final _controller = ScrollController();
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final max = _controller.position.maxScrollExtent;
      final next = max <= 0 ? 0.0 : (_controller.offset / max).clamp(0.0, 1.0);
      if ((next - _progress).abs() > 0.01) setState(() => _progress = next);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: widget.row,
        ),
        const SizedBox(height: 11),
        _Rule(
          progress: _progress,
          visible: (widget.width / widget.span).clamp(0.2, 1.0),
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.progress, required this.visible});

  final double progress;

  final double visible;

  @override
  Widget build(BuildContext context) {
    const rail = 40.0;
    final thumb = rail * visible;

    return SizedBox(
      width: rail,
      height: 3,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          AnimatedPositionedDirectional(
            duration: motionOff(context) ? Duration.zero : const Duration(milliseconds: 90),
            start: (rail - thumb) * progress,
            child: Container(
              width: thumb,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.violet,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

class NavItem {
  const NavItem(this.filled, this.outline, this.label, {this.glyph});

  final NavGlyph? glyph;

  final IconData filled;
  final IconData outline;
  final String label;
}

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
                    duration: motionOff(context) ? Duration.zero : const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: on ? tint.withValues(alpha: AppTheme.dark ? 0.22 : 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          duration: motionOff(context) ? Duration.zero : const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          scale: on ? 1.0 : 0.92,
                          child: Icon(
                            on ? item.filled : item.outline,
                            size: 21,
                            color: on ? tint : AppTheme.textFaint,
                          ),
                        ),
                        ClipRect(
                          child: AnimatedAlign(
                            duration: motionOff(context) ? Duration.zero : const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: on ? 1.0 : 0.0,
                            child: AnimatedOpacity(
                              duration: motionOff(context) ? Duration.zero : const Duration(milliseconds: 140),
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

  final String? centerLabel;

  final Map<int, bool> badges;

  static const _bar = 64.0;

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
                      color: tint,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.canvas, width: 3.5),
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

  static Color get _idle =>
      AppTheme.dark ? const Color(0xFFA8B0C0) : const Color(0xFF5B6478);

  Widget _slot(int i) {
    final on = i == index;
    final item = items[i];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(i),
      child: SizedBox(
        height: _bar,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (on && !AppTheme.dark)
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

Future<bool> confirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String body,
  required String confirmLabel,
  IconData confirmIcon = Icons.check_rounded,
  Color? tone,
  String? cancelLabel,
}) async {
  final colour = tone ?? AppTheme.rose;

  final answer = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: AppTheme.dark ? 0.62 : 0.34),
    builder: (context) => Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ConfirmMark(icon: icon, colour: colour),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ConfirmButton(
                    label: cancelLabel ?? t('common.cancel'),
                    icon: Icons.close_rounded,
                    filled: false,
                    colour: AppTheme.violet,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ConfirmButton(
                    label: confirmLabel,
                    icon: confirmIcon,
                    filled: true,
                    colour: colour,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  return answer ?? false;
}

class _ConfirmMark extends StatelessWidget {
  const _ConfirmMark({required this.icon, required this.colour});

  final IconData icon;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    Widget speck(double size, bool cross, double opacity) => Icon(
          cross ? Icons.close_rounded : Icons.circle_outlined,
          size: size,
          color: colour.withValues(alpha: opacity),
        );

    return SizedBox(
      width: 168,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 122,
            height: 122,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: AppTheme.dark ? 0.18 : 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 50, color: colour),
          ),
          PositionedDirectional(start: 16, top: 30, child: speck(11, true, 0.45)),
          PositionedDirectional(end: 20, top: 18, child: speck(10, true, 0.35)),
          PositionedDirectional(start: 4, bottom: 26, child: speck(9, false, 0.40)),
          PositionedDirectional(end: 10, bottom: 34, child: speck(8, false, 0.30)),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.colour,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : colour;

    return Material(
      color: filled ? colour : Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: filled ? null : Border.all(color: colour, width: 1.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
