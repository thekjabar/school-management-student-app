import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The quieter half of a pair of buttons.
///
/// The kit has BigButton for the one thing a screen is about, and nothing for
/// the action standing beside it. An OutlinedButton arrives with its own
/// radius, its own height and its own grey — none of the three are this app's,
/// and correcting all three by hand at every call site is what left these
/// screens looking like somebody else's. So this is that shape drawn from
/// AppTheme's tokens instead, the same way the parent's child card draws its
/// own pair.
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tint,
    this.height = 44,
  });

  final String label;

  /// Null disables it — the same contract as BigButton.onPressed.
  final VoidCallback? onTap;

  final IconData? icon;

  /// Set to colour it. Left off it stays quiet against the page, inside a
  /// hairline, which is what a second action beside a filled one should be.
  final Color? tint;

  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(13);
    final enabled = onTap != null;
    final base = tint ?? AppTheme.textMuted;
    final colour = enabled ? base : base.withValues(alpha: 0.45);

    return Material(
      color: tint == null
          ? AppTheme.canvas
          : base.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: tint == null ? Border.all(color: AppTheme.border) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: colour),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: colour,
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
