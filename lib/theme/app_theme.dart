import 'package:flutter/material.dart';

import '../ui/home_kit.dart';
import '../ui/kit.dart';
import 'package:flutter/services.dart';

enum Role {
  parent('Parent', Color(0xFF6D3FF7), Color(0xFFF2EEFD)),
  student('Student', Color(0xFF22C55E), Color(0xFFE7F8EE)),
  teacher('Teacher', Color(0xFF4D994B), Color(0xFFE7F1E6)),
  driver('Driver', Color(0xFFFB6A00), Color(0xFFFFEFE2)),
  admin('Admin', Color(0xFF6D4AFF), Color(0xFFECE8FE));

  const Role(this.label, this.tint, this._lightWash);

  final String label;
  final Color tint;

  final Color _lightWash;

  Color get wash => AppTheme.dark
      ? Color.lerp(AppTheme.canvas, tint, 0.14)!
      : _lightWash;
}

class AppTheme {
  static bool dark = false;

  static Color _pick(Color light, Color night) => dark ? night : light;

  static Color get canvas => _pick(const Color(0xFFFCFCFE), const Color(0xFF0A1324));
  static Color get surface => _pick(const Color(0xFFFFFFFF), const Color(0xFF121A29));
  static Color get border => _pick(const Color(0xFFEEEFF4), const Color(0xFF212A3D));

  static Color get text => _pick(const Color(0xFF111827), const Color(0xFFF2F4F8));
  static Color get textMuted => _pick(const Color(0xFF6B7280), const Color(0xFF97A1B4));
  static Color get textFaint => _pick(const Color(0xFF9CA3AF), const Color(0xFF6B7688));

  static Color get violet => _pick(const Color(0xFF6D3FF7), const Color(0xFF8B6BFF));
  static Color get violetSoft => _pick(const Color(0xFFF2EEFD), const Color(0xFF20213C));
  static Color get green => _pick(const Color(0xFF149447), const Color(0xFF22C55E));
  static Color get greenSoft => _pick(const Color(0xFFEAF6EC), const Color(0xFF172629));
  static Color get amber => _pick(const Color(0xFFDF5F09), const Color(0xFFFB8C3A));
  static Color get amberSoft => _pick(const Color(0xFFFEF0E6), const Color(0xFF252225));
  static Color get blue => _pick(const Color(0xFF2E7DF6), const Color(0xFF4D97FF));
  static Color get blueSoft => _pick(const Color(0xFFE9F0FE), const Color(0xFF15233A));
  static Color get rose => _pick(const Color(0xFFF43F5E), const Color(0xFFFF6B84));
  static Color get roseSoft => _pick(const Color(0xFFFDECF0), const Color(0xFF251D2E));

  static Color get neutralSoft => _pick(const Color(0xFFF1F3F6), const Color(0xFF1B2434));

  static const teacherDeep = Color(0xFF0B503C);

  static const brand = Color(0xFF6D3FF7);

  static const radius = 18.0;
  static const radiusSm = 14.0;
  static const gutter = 16.0;

  static List<BoxShadow> get lift => [
        BoxShadow(
          color: dark
              ? Color(0xFF000000).withValues(alpha: 0.35)
              : Color(0xFF15181D).withValues(alpha: 0.05),
          blurRadius: dark ? 14 : 18,
          offset: Offset(0, 4),
        ),
      ];

  static SystemUiOverlayStyle get systemOverlay => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: surface,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      );

  static ThemeData build({Color? tint}) {
    final accent = tint ?? violet;
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Roboto',
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: accent,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: text,
      ),
      splashFactory: InkSparkle.splashFactory,

      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: accent,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        dayStyle: const TextStyle(fontWeight: FontWeight.w600),
        todayBorder: BorderSide(color: accent, width: 1.4),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : accent,
        ),
        todayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : Colors.transparent,
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) return textFaint;
            return states.contains(WidgetState.selected) ? Colors.white : text;
          },
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : Colors.transparent,
        ),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : text,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : Colors.transparent,
        ),
        weekdayStyle: TextStyle(color: textMuted, fontWeight: FontWeight.w600, fontSize: 12),
        dividerColor: border,
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: textMuted),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: accent),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        dialHandColor: accent,
        hourMinuteTextColor: text,
        dayPeriodTextColor: text,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        hintStyle: TextStyle(color: textFaint, fontSize: 14, fontWeight: FontWeight.w400),
        labelStyle: TextStyle(color: textMuted, fontSize: 13),
        counterStyle: const TextStyle(height: 0, fontSize: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: rose),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: rose, width: 1.6),
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: text,
        ),
        contentTextStyle: TextStyle(fontSize: 13, height: 1.5, color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: text,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: text,
          height: 1.05,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        titleLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: text,
        ),
        titleMedium: TextStyle(
          fontSize: 14.5, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: text,
        ),
        bodyMedium: TextStyle(fontSize: 13, color: textMuted, height: 1.35),
        bodySmall: TextStyle(fontSize: 11.5, color: textMuted, height: 1.3),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textFaint),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Card16(padding: padding, onTap: onTap, color: color, child: child);
}

class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.action, this.tint, this.onAction});

  final String title;
  final String? action;
  final Color? tint;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) =>
      SectionRow(title: title, actionLabel: action, onAction: onAction);
}

class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 38,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}
