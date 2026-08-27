import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The visual language of the student app.
///
/// Two ideas run through it, and both come from who is holding the phone.
///
/// The first is that ONE thing on each screen is dark and everything else is
/// quiet. A student opening this between lessons is looking for a single
/// answer — which room, what is due, where is the bus — and a screen where six
/// cards compete equally is a screen they have to read. The dark card is the
/// answer; the rest is reference.
///
/// The second is that the numbers are the interface. Attendance and GPA are set
/// large, tight and tabular, because a figure that has to be hunted for is a
/// figure nobody checks.
class AppTheme {
  // ---- Palette -------------------------------------------------------------
  // Defined once here. Nothing in the widget tree may invent a colour: a
  // hardcoded hex in a screen is how an app ends up with nine greys.

  static const ink = Color(0xFF14161A);
  static const inkSoft = Color(0xFF1D2026);
  static const canvas = Color(0xFFF4F4F6);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6E6EA);

  static const textPrimary = Color(0xFF14161A);
  static const textSecondary = Color(0xFF6B6F76);
  /// Section labels. Deliberately light — they are signposts, not content.
  static const textMuted = Color(0xFF9A9EA6);

  static const accent = Color(0xFF7C5CFF);
  static const accentSoft = Color(0xFFEFEBFF);
  static const positive = Color(0xFF16A34A);
  static const positiveSoft = Color(0xFFDCFCE7);
  static const warm = Color(0xFFF97316);
  static const warmSoft = Color(0xFFFFF1E6);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFEE2E2);

  static const radius = 16.0;
  static const radiusSmall = 12.0;
  static const gutter = 20.0;

  /// A hairline that survives a 3x screen. `BorderSide.width: 1` renders as a
  /// three-pixel slab on a modern phone and makes every card look heavy.
  static Border hairline([Color? c]) =>
      Border.all(color: c ?? border, width: 0.8);

  static const systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData build() {
    const family = 'Roboto';

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      fontFamily: family,
      colorScheme: const ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: danger,
      ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: TextStyle(
          fontFamily: family,
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: const TextTheme(
        // The figures. Tabular so a changing number does not shift the layout,
        // and tightened because large type set at default tracking reads loose.
        displayLarge: TextStyle(
          fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.2,
          color: textPrimary, height: 1.05,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        titleLarge: TextStyle(
          fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.5,
          color: Colors.white, height: 1.2,
        ),
        titleMedium: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
        bodySmall: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35),
        // Section headers: small, wide-tracked, upper-case at the call site.
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.9,
          color: textMuted,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border, thickness: 0.8, space: 0.8,
      ),
    );
  }
}

/// A card. One shape, used everywhere, so the app reads as one surface.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.dark = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool dark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? AppTheme.ink : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: dark ? null : AppTheme.hairline(),
        boxShadow: dark
            // Only the dark card lifts. If everything has a shadow, nothing is
            // raised, and the hierarchy the screen depends on disappears.
            ? [BoxShadow(
                color: AppTheme.ink.withValues(alpha: 0.22),
                blurRadius: 28, offset: const Offset(0, 12),
              )]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: content,
      ),
    );
  }
}

/// A section header: `ACADEMIC PERFORMANCE`, with an optional right-hand note.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
      // Both sides are Flexible. A long label beside a long note — "ASSIGNMENTS
      // REGISTRY" and "3 PENDING" — overruns a narrow phone by a few pixels
      // once the letter-spacing is counted, and a rigid Row clips it.
      child: Row(
        children: [
          Flexible(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                trailing!.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppTheme.accent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

/// A small status word: ACTIVE, 12 DAY STREAK, 3 PENDING.
class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.color = AppTheme.positive,
    this.background = AppTheme.positiveSoft,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 9 : 7, 5, 9, 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 0.6, color: color,
            ),
          ),
        ],
      ),
    );
  }
}
