import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Who is holding the phone.
///
/// Each audience gets one hue, used for the header wash, the active tab and the
/// primary action — and nowhere else. It is how somebody glancing at a phone
/// across a staff room knows whose app is open, and it is the only thing that
/// differs between the five home screens.
enum Role {
  parent('Parent', Color(0xFF7C5CFF), Color(0xFFEFEAFE)),
  student('Student', Color(0xFF22C55E), Color(0xFFE7F8EE)),
  teacher('Teacher', Color(0xFF3B82F6), Color(0xFFE6F0FE)),
  driver('Driver', Color(0xFFF97316), Color(0xFFFEEEE2)),
  admin('Admin', Color(0xFF6D4AFF), Color(0xFFECE8FE));

  const Role(this.label, this.tint, this.wash);

  final String label;
  final Color tint;
  final Color wash;
}

/// EduPulse — the visual language, shared by all five roles.
///
/// One idea holds every screen together: a soft tinted wash behind the header,
/// and everything below it a white card floating on near-white. Nothing shouts.
/// Colour is reserved for the three places it means something — a figure that
/// is good, a deadline that is close, and the one thing happening right now.
class AppTheme {
  // ---- Surfaces ------------------------------------------------------------
  static const canvas = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFEFF1F4);

  // ---- Text ----------------------------------------------------------------
  static const text = Color(0xFF15181D);
  static const textMuted = Color(0xFF7C8798);
  static const textFaint = Color(0xFFA8B0BC);

  // ---- Accents content uses ------------------------------------------------
  static const violet = Color(0xFF7C5CFF);
  static const violetSoft = Color(0xFFF0ECFF);
  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFE3F7EB);
  static const amber = Color(0xFFF59E0B);
  static const amberSoft = Color(0xFFFEF3E2);
  static const blue = Color(0xFF3B82F6);
  static const blueSoft = Color(0xFFE7F0FE);
  static const rose = Color(0xFFF43F5E);
  static const roseSoft = Color(0xFFFDE8EC);

  static const radius = 18.0;
  static const radiusSm = 14.0;
  static const gutter = 16.0;

  /// Soft enough to read as depth rather than as a border. Cards are separated
  /// by light, not by lines.
  static List<BoxShadow> get lift => [
        BoxShadow(
          color: const Color(0xFF15181D).withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 4),
        ),
      ];

  static const systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData build({Color tint = violet}) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.light(
        primary: tint,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: text,
      ),
      splashFactory: InkSparkle.splashFactory,

      /// Text fields, once, for the whole app.
      ///
      /// Without this every TextField falls back to Material's underline, its
      /// own padding and its own radius — which is why the sign-in screen used
      /// to look like a different product from the one behind it. A form is
      /// the most-touched surface in these apps and the easiest to leave
      /// looking unfinished.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        hintStyle: const TextStyle(color: textFaint, fontSize: 14, fontWeight: FontWeight.w400),
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        // A counter under every maxLength field is noise nobody reads; the
        // limit is enforced regardless.
        counterStyle: const TextStyle(height: 0, fontSize: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: tint, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: rose),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: rose, width: 1.6),
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),

      // Sheets and dialogs carry the same corner radius as the cards, so a
      // form that slides up belongs to the screen it came from.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: const TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: text,
        ),
        contentTextStyle: const TextStyle(fontSize: 13, height: 1.5, color: textMuted),
      ),
      appBarTheme: const AppBarTheme(
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
          side: const BorderSide(color: border),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tint,
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: const TextTheme(
        // The stat-strip figures. Tabular so a changing number does not nudge
        // the column beside it.
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

/// The white card everything sits in.
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
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.lift,
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

/// A section title with an optional "View All" on the right.
class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.action, this.tint, this.onAction});

  final String title;
  final String? action;
  final Color? tint;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppTheme.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

/// A small status word: Pending, High Priority, Excellent.
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

/// The rounded tinted square that fronts every list row.
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
