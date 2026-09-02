import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/boot.dart';
import 'api/client.dart';
import 'api/push.dart';
import 'i18n/delegates.dart';
import 'ui/async.dart';
import 'i18n/strings.dart';
import 'api/session.dart';
import 'screens/driver/driver_app.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/parent/parent_app.dart';
import 'screens/teacher/teacher_app.dart';
import 'theme/app_theme.dart';

/// Which audience this build is for.
///
/// Set at build time —
///
///     flutter build apk --flavor parent --dart-define=APP_ROLE=parent
///
/// — so one codebase produces three apps. Each Android flavour also carries its
/// own applicationId, so a teacher whose own child rides the bus can have both
/// the teacher app and the parent app on one phone.
const String kRole = String.fromEnvironment('APP_ROLE', defaultValue: 'parent');

Role get _role => switch (kRole) {
      'teacher' => Role.teacher,
      'driver' => Role.driver,
      _ => Role.parent,
    };

String get _title => switch (kRole) {
      'teacher' => 'KSP Teacher',
      'driver' => 'KSP Driver',
      _ => 'KSP Parent',
    };

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);
  // Read before the first frame. Restoring the language afterwards means the
  // app opens in English and redraws itself in Kurdish a moment later, which
  // looks like a fault.
  await AppLocale.restore();
  // Every later change of language now also reaches the account, because that
  // is what decides the language of the notifications. Registered here rather
  // than inside the setting so that i18n stays at the bottom of the stack.
  AppLocale.onChanged = Session.instance.setLocale;
  await AppThemeSetting.restore();
  // Started here, but deliberately not asked for permission here — see Push.
  // Failing to start push must not stop the app, so this never throws.
  await Push.start();
  runApp(const KspApp());
}

class KspApp extends StatefulWidget {
  const KspApp({super.key});

  @override
  State<KspApp> createState() => _KspAppState();
}

/// Stateful only so it can hear the phone change brightness.
///
/// On "follow the system" the app has to repaint when the handset flips, which
/// on most phones happens on a schedule nobody thinks about — an app that only
/// read the setting at launch stays light all evening.
class _KspAppState extends State<KspApp> with WidgetsBindingObserver {
  /// The brightness the tree was last actually PAINTED with.
  ///
  /// Compared against the newly resolved one to notice a change, because the
  /// widgets that need telling cannot notice it themselves — see
  /// [_repaintEverything].
  bool? _painted;

  /// And the language it was last painted in, for exactly the same reason.
  ///
  /// `t()` is a plain function call, not an InheritedWidget lookup, so a widget
  /// that does not rebuild keeps whatever words it was built with. Rebuilding
  /// from the root reaches most of the app, but not a subtree Flutter is
  /// entitled to skip — which is why the settings page, the page the language
  /// is changed ON, was the one page that stayed in the old language until it
  /// was navigated away from and back.
  Lang? _paintedLang;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (mounted && AppThemeSetting.current.value == AppThemeMode.system) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Listening here rather than at each screen: changing language rebuilds the
    // whole app, which is what has to happen — the text direction flips and
    // every row in every list is laid out the other way round.
    // Both listened to here rather than at each screen: either one rebuilds
    // the whole app, which is what has to happen. A language change flips the
    // text direction and re-lays every row; a theme change repaints every
    // surface.
    return ValueListenableBuilder<Lang>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) => ValueListenableBuilder<AppThemeMode>(
        valueListenable: AppThemeSetting.current,
        builder: (context, mode, _) => _app(lang, mode),
      ),
    );
  }

  /// Mark every mounted element dirty, so all of them rebuild next frame.
  ///
  /// Unusual, and deliberate. The ordinary way to make a value reactive is an
  /// InheritedWidget, and every reader calls `of(context)` so Flutter knows to
  /// rebuild it. This app reads its palette through 1,112 static getters across
  /// 49 files; converting them all is a large change with a lot of places to
  /// get one wrong, and a single missed call site is an invisible bug that only
  /// shows up in the theme somebody uses less.
  ///
  /// Marking the tree dirty gets the same result — every widget rebuilds and
  /// re-reads the palette — while unmounting nothing, so all State survives.
  /// It costs one traversal on a gesture that happens rarely.
  void _repaintEverything() {
    void mark(Element el) {
      el.markNeedsBuild();
      el.visitChildren(mark);
    }

    // From the root down, so pushed routes and hidden tabs are included: they
    // are mounted elements too, and they are exactly the pages that used to
    // come back in the wrong colours.
    context.visitChildElements(mark);
  }

  Widget _app(Lang lang, AppThemeMode mode) {
    // The palette reads one global flag, so it has to be set BEFORE the
    // ThemeData and the widgets below are built — not from inside a builder
    // that runs after them.
    final platformDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    AppTheme.dark = switch (mode) {
      AppThemeMode.dark => true,
      AppThemeMode.light => false,
      AppThemeMode.system => platformDark,
    };
    SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);

    // The palette is static getters over the flag set just above, read during
    // build — so a widget picks up a new colour only when it rebuilds, and
    // Flutter SKIPS rebuilding a child whose widget is identical to the mounted
    // one. Every `const Something()` is canonicalised to a single instance and
    // is therefore always identical, so those widgets kept the old colours
    // until something unrelated forced them to rebuild. That is why a page used
    // to look right only after navigating away and coming back.
    //
    // Marked dirty in place, once, after this frame — rather than by replacing
    // the tree, which unmounts the running app, replays the splash clip and
    // drops the person somewhere they were not.
    //
    // The language is carried through the same door. It is not a colour, but it
    // reaches the widgets the same way — a bare function call rather than a
    // lookup Flutter tracks — so a subtree that does not rebuild keeps the old
    // words just as it kept the old palette.
    if ((_painted != null && _painted != AppTheme.dark) ||
        (_paintedLang != null && _paintedLang != lang)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _repaintEverything());
    }
    _painted = AppTheme.dark;
    _paintedLang = lang;

    return MaterialApp(
      title: _title,
      debugShowCheckedModeBanner: false,
      locale: Locale(lang.code),
      supportedLocales: Lang.values.map((l) => Locale(l.code)),
      // Kurdish is not one of Flutter's 78 locales, so this list carries three
      // delegates that claim 'ku' and hand back Arabic's framework strings.
      // Without them a date picker or a text field throws on build. See
      // i18n/delegates.dart — the widget tests mount this same list.
      localizationsDelegates: appLocalizationsDelegates,
      // Lets every Loader refetch when the screen it sits on is uncovered —
      // press back from a leave request and the list already includes it.
      navigatorObservers: [routeObserver],
      // One ThemeData, built from the flag above. Handing MaterialApp separate
      // light/dark themes would let IT choose, and the palette getters would
      // then disagree with whatever it picked.
      theme: AppTheme.build(tint: _role.tint),
      themeMode: ThemeMode.light,
      builder: (context, child) {
        // The phone's font scale is honoured but capped. A driver's manifest at
        // 200% text becomes one name per screen, which is worse for them than
        // slightly smaller type.
        final media = MediaQuery.of(context);
        return Directionality(
          textDirection: lang.direction,
          child: MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      // NOT const, and that matters. A const widget is canonicalised to a
      // single instance, and Flutter's updateChild skips a subtree whose widget
      // is identical to the one already mounted — so the language changed and
      // nothing below this line redrew until a new route was pushed. The same
      // applies to the three role apps below.
      // The clip plays OVER the app rather than before it, so the sign-in
      // check happens underneath instead of after — and `ready` holds the
      // curtain until the work started at boot has finished, so the clip is
      // never followed by a second loading screen.
      home: SplashGate(
        tint: _role.tint,
        ready: Boot.instance.start(),
        child: _Gate(),
      ),
    );
  }
}

/// Decides between the sign-in screen and the app.
///
/// A saved token is CONFIRMED against the server before the app is drawn around
/// it, rather than trusted. A driver whose account was stood down last night
/// must not open a manifest this morning, and the only thing that knows is the
/// server.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  Me? _me;
  bool _ready = false;

  /// Start-up could not reach the platform. Carried through to the sign-in
  /// screen so it can say so instead of waiting for a password to fail.
  bool _offline = false;

  StreamSubscription<void>? _signedOut;

  @override
  void initState() {
    super.initState();
    _restore();
    // Fired when a refresh fails for good. Handled here, once, rather than by
    // every screen checking after every call.
    _signedOut = ApiClient.instance.onSignedOut.listen((_) {
      if (mounted) setState(() => _me = null);
    });
  }

  @override
  void dispose() {
    _signedOut?.cancel();
    super.dispose();
  }

  /// Reads the work started when the app booted, rather than starting its own.
  ///
  /// Boot.start() is called from build(), the instant the splash is created, so
  /// by the time this runs the request is usually already in flight. Awaiting
  /// the same future joins it instead of firing a second one.
  Future<void> _restore() async {
    final boot = await Boot.instance.start();
    if (!mounted) return;
    setState(() {
      _me = boot.me;
      _offline = boot.offline;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Deliberately bare of CONTENT — the wordmark and spinner that used to
      // live here read as a second splash screen the moment the clip lifted,
      // which is the part that felt slow, because by then a person is waiting
      // rather than watching.
      //
      // But in the ROLE'S OWN COLOUR, not the page white. Almost always this is
      // covered by the splash and nobody sees it. When it is not — a fresh
      // install on a network that connects and never answers, where start-up
      // waits out its timeout — white was a screen that looked broken. The
      // tint just looks like the clip has not finished.
      return Scaffold(backgroundColor: _role.tint, body: const SizedBox.expand());
    }

    if (_me == null) {
      return LoginScreen(
        role: _role,
        offline: _offline,
        onSignedIn: (me) => setState(() => _me = me),
      );
    }

    // The BUILD decides which app this is, not the account.
    //
    // It used to be the other way round: whatever role the signed-in person
    // held chose the screens. That reads sensibly until three separately named
    // and separately installed apps exist — then signing into KSP Teacher
    // with a parent account silently showed the parent app in teacher blue,
    // and the three APKs became one app wearing three colours.
    //
    // A person can hold more than one role — a teacher whose own child attends
    // the school is common — so the check is whether they hold the role THIS
    // app serves, not whether their first membership happens to match.
    final membership = _membershipForThisApp();
    if (membership == null) {
      return _WrongApp(
        role: _me!.role,
        onSignOut: () async {
          await Session.instance.signOut();
          if (mounted) setState(() => _me = null);
        },
      );
    }

    return switch (kRole) {
      'driver' => DriverApp(),
      'teacher' => TeacherApp(),
      _ => ParentApp(),
    };
  }

  /// The membership that entitles this person to use this build, or null.
  ///
  /// Returning the membership rather than a bool because a person with two
  /// roles at two schools needs the right one made active before any screen
  /// asks the server for anything.
  Membership? _membershipForThisApp() {
    final wanted = switch (kRole) {
      'driver' => const ['DRIVER', 'ATTENDANT'],
      'teacher' => const ['TEACHER'],
      _ => const ['GUARDIAN'],
    };
    for (final m in _me!.memberships) {
      if (wanted.contains(m.role)) return m;
    }
    // The active membership may not be listed separately on some accounts.
    return wanted.contains(_me!.role) ? _me!.active : null;
  }
}

/// Signed in, but with a role none of these three apps serves.
///
/// Office staff, principals and platform administrators use the web console.
/// Saying so is kinder than showing them an empty app and letting them conclude
/// the account is broken.
class _WrongApp extends StatelessWidget {
  const _WrongApp({required this.role, required this.onSignOut});

  final String role;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.desktop_windows_rounded, size: 40, color: AppTheme.textFaint),
                const SizedBox(height: 16),
                Text(
                  'This account is for the web console',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your role — ${role.replaceAll('_', ' ').toLowerCase()} — works at '
                  'admin.krsprotection.com rather than in this app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.55),
                ),
                const SizedBox(height: 24),
                OutlinedButton(onPressed: onSignOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

