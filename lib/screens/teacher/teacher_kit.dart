import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

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

  final VoidCallback? onTap;

  final IconData? icon;

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
