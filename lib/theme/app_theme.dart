import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Who is holding the phone.
///
/// Each audience gets one hue, used for the header wash, the active tab and the
/// primary action — and nowhere else. It is how somebody glancing at a phone
/// across a staff room knows whose app is open, and it is the only thing that
/// differs between the five home screens.
enum Role {
  parent('Parent', Color(0xFF6D3FF7), Color(0xFFF2EEFD)),
  student('Student', Color(0xFF22C55E), Color(0xFFE7F8EE)),
  teacher('Teacher', Color(0xFF4D994B), Color(0xFFE7F1E6)),
  driver('Driver', Color(0xFFFB6A00), Color(0xFFFFEFE2)),
  admin('Admin', Color(0xFF6D4AFF), Color(0xFFECE8FE));

  const Role(this.label, this.tint, this._lightWash);

  final String label;
  final Color tint;

  /// The pale tint used behind headers in the light theme.
  final Color _lightWash;

  /// The wash behind a header, in whichever theme is drawing.
  ///
  /// The light value is a pale tint that reads as "almost white, with a hint of
  /// who you are". Reused unchanged on a dark canvas it becomes a bright band
  /// across the top of every screen — the app's darkest surface directly under
  /// its lightest. So in the dark it is the same hue mixed INTO the canvas
  /// instead: dark enough to belong, tinted enough to still say parent or
  /// driver at a glance.
  Color get wash => AppTheme.dark
      ? Color.lerp(AppTheme.canvas, tint, 0.14)!
      : _lightWash;
}

/// KSP — the visual language, shared by all five roles.
///
/// One idea holds every screen together: a soft tinted wash behind the header,
/// and everything below it a white card floating on near-white. Nothing shouts.
/// Colour is reserved for the three places it means something — a figure that
/// is good, a deadline that is close, and the one thing happening right now.
class AppTheme {
  /// Whether the app is currently drawing dark.
  ///
  /// Set by the widget that owns ThemeMode, before the frame is built. Every
  /// colour below reads it, so one assignment repaints the entire app.
  static bool dark = false;

  static Color _pick(Color light, Color night) => dark ? night : light;

  // ---- Surfaces ------------------------------------------------------------
  //
  // Dark is not the light palette inverted. Cards sit ABOVE the canvas in both
  // themes, so in the dark the canvas is the darkest surface and cards are
  // lifted off it — inverting would put the card behind its own page.
  //
  // Both palettes are sampled from the design rather than chosen: the page, the
  // card and the border are three values apart in the light theme and the
  // separation comes from the shadow, and the dark theme is navy rather than
  // the near-black the app used to draw — which is the single change that made
  // the dark screens stop looking like a different product from the mockup.
  static Color get canvas => _pick(const Color(0xFFFCFCFE), const Color(0xFF0A1324));
  static Color get surface => _pick(const Color(0xFFFFFFFF), const Color(0xFF121A29));
  static Color get border => _pick(const Color(0xFFEEEFF4), const Color(0xFF212A3D));

  // ---- Text ----------------------------------------------------------------
  //
  // Not pure white on dark: #F2F1F6 against #12111A is about 15:1, well past
  // AA, without the halo pure white produces on an OLED at night — which is
  // most of the phones this runs on.
  static Color get text => _pick(const Color(0xFF111827), const Color(0xFFF2F4F8));
  static Color get textMuted => _pick(const Color(0xFF6B7280), const Color(0xFF97A1B4));
  static Color get textFaint => _pick(const Color(0xFF9CA3AF), const Color(0xFF6B7688));

  // ---- Accents content uses ------------------------------------------------
  //
  // The hues hold across both themes; only the SOFT backings change. A soft
  // tint that works on white is nearly white itself, and on a dark canvas it
  // becomes a glowing block — so in the dark they are deep, desaturated
  // versions of the same hue instead.
  static Color get violet => _pick(const Color(0xFF6D3FF7), const Color(0xFF8B6BFF));
  static Color get violetSoft => _pick(const Color(0xFFF2EEFD), const Color(0xFF20213C));
  // A shade under the design's #16A34A, which came out at 2.96:1 on its own
  // soft backing — under the 3:1 floor the theme test enforces, and visibly so
  // for the 8pt captions in the figure strip.
  static Color get green => _pick(const Color(0xFF149447), const Color(0xFF22C55E));
  static Color get greenSoft => _pick(const Color(0xFFEAF6EC), const Color(0xFF172629));
  // Two shades under the design's #F97316, for the same reason as green: the
  // bright orange is 2.5:1 on its own backing, and this colour carries text —
  // an overdue date, a late tally — not just icons.
  static Color get amber => _pick(const Color(0xFFDF5F09), const Color(0xFFFB8C3A));
  static Color get amberSoft => _pick(const Color(0xFFFEF0E6), const Color(0xFF252225));
  static Color get blue => _pick(const Color(0xFF2E7DF6), const Color(0xFF4D97FF));
  static Color get blueSoft => _pick(const Color(0xFFE9F0FE), const Color(0xFF15233A));
  static Color get rose => _pick(const Color(0xFFF43F5E), const Color(0xFFFF6B84));
  static Color get roseSoft => _pick(const Color(0xFFFDECF0), const Color(0xFF251D2E));

  /// The deep green the teacher design uses for the one thing it wants read
  /// first — the lesson count and the button under it. Not [Role.teacher.tint]:
  /// that is the hue of the app, and a headline in it disappears into the six
  /// other green things on the screen.
  static const teacherDeep = Color(0xFF0B503C);

  /// The brand violet, at full strength in both themes.
  ///
  /// [violet] lightens in the dark so text drawn in it stays legible; the raised
  /// action in the bottom bar is a FILLED shape, so it wants the one value the
  /// design uses for it on both canvases.
  static const brand = Color(0xFF6D3FF7);

  static const radius = 18.0;
  static const radiusSm = 14.0;
  static const gutter = 16.0;

  /// Soft enough to read as depth rather than as a border. Cards are separated
  /// by light, not by lines.
  /// Cards are separated by light, not by lines.
  ///
  /// In the dark a drop shadow is invisible — there is nothing darker to cast
  /// onto — so the separation comes from the card being lighter than the
  /// canvas, and the shadow only deepens the edge.
  static List<BoxShadow> get lift => [
        BoxShadow(
          color: dark
              ? Color(0xFF000000).withValues(alpha: 0.35)
              : Color(0xFF15181D).withValues(alpha: 0.05),
          blurRadius: dark ? 14 : 18,
          offset: Offset(0, 4),
        ),
      ];

  /// The status and navigation bars. Icon brightness is the OPPOSITE of the
  /// theme: dark icons on a light bar, light icons on a dark one.
  static SystemUiOverlayStyle get systemOverlay => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: surface,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      );

  static ThemeData build({Color? tint}) {
    // Nullable now that the palette is a set of getters: a getter cannot be a
    // default parameter value.
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

      /// Text fields, once, for the whole app.
      ///
      /// Without this every TextField falls back to Material's underline, its
      /// own padding and its own radius — which is why the sign-in screen used
      /// to look like a different product from the one behind it. A form is
      /// the most-touched surface in these apps and the easiest to leave
      /// looking unfinished.
      /// The date picker, once, for the whole app.
      ///
      /// Left alone it arrives as stock Material: square-ish corners, its own
      /// blue, its own type — which is why the leave form looked like it had
      /// been lifted out of a different product the moment a parent tapped a
      /// date. It is also the one surface in these apps that Flutter builds
      /// rather than us, so it is the easiest to forget.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: accent,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        dayStyle: const TextStyle(fontWeight: FontWeight.w600),
        // The selected day is the accent; today is outlined in it. Two
        // different jobs, so they must not look the same.
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

      /// The same for time, so the two never disagree.
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
        // A counter under every maxLength field is noise nobody reads; the
        // limit is enforced regardless.
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
              style: TextStyle(
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
