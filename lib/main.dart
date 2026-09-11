import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxOptions;

import 'api/boot.dart';
import 'api/client.dart';
import 'api/push.dart';
import 'i18n/delegates.dart';
import 'ui/async.dart';
import 'ui/map_tiles.dart';
import 'i18n/strings.dart';
import 'api/session.dart';
import 'screens/driver/driver_app.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/parent/parent_app.dart';
import 'screens/teacher/teacher_app.dart';
import 'theme/app_theme.dart';

const String kRole = String.fromEnvironment('APP_ROLE');

const List<String> kRoles = ['parent', 'teacher', 'driver'];

bool get _roleIsValid => kRoles.contains(kRole);

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
  if (MapTiles.configured) {
    MapboxOptions.setAccessToken(MapTiles.token);
  }
  await AppLocale.restore();
  AppLocale.onChanged = Session.instance.setLocale;
  await AppThemeSetting.restore();
  await Push.start();
  runApp(const KspApp());
}

class KspApp extends StatefulWidget {
  const KspApp({super.key});

  @override
  State<KspApp> createState() => _KspAppState();
}

class _KspAppState extends State<KspApp> with WidgetsBindingObserver {
  bool? _painted;

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
    return ValueListenableBuilder<Lang>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) => ValueListenableBuilder<AppThemeMode>(
        valueListenable: AppThemeSetting.current,
        builder: (context, mode, _) => _app(lang, mode),
      ),
    );
  }

  void _repaintEverything() {
    void mark(Element el) {
      el.markNeedsBuild();
      el.visitChildren(mark);
    }

    context.visitChildElements(mark);
  }

  Widget _app(Lang lang, AppThemeMode mode) {
    final platformDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    AppTheme.dark = switch (mode) {
      AppThemeMode.dark => true,
      AppThemeMode.light => false,
      AppThemeMode.system => platformDark,
    };
    SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);

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
      localizationsDelegates: appLocalizationsDelegates,
      navigatorObservers: [routeObserver],
      theme: AppTheme.build(tint: _role.tint),
      themeMode: ThemeMode.light,
      builder: (context, child) {
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
      home: SplashGate(
        tint: _role.tint,
        ready: Boot.instance.start(),
        child: _Gate(),
      ),
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  Me? _me;
  bool _ready = false;

  bool _offline = false;

  StreamSubscription<void>? _signedOut;

  @override
  void initState() {
    super.initState();
    _restore();
    _signedOut = ApiClient.instance.onSignedOut.listen((_) {
      if (mounted) setState(() => _me = null);
    });
  }

  @override
  void dispose() {
    _signedOut?.cancel();
    super.dispose();
  }

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
    if (!_roleIsValid) return const _BrokenBuild();

    if (!_ready) {
      return Scaffold(backgroundColor: _role.tint, body: const SizedBox.expand());
    }

    if (_me == null) {
      return LoginScreen(
        role: _role,
        offline: _offline,
        onSignedIn: (me) => setState(() => _me = me),
      );
    }

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

  Membership? _membershipForThisApp() {
    final wanted = switch (kRole) {
      'driver' => const ['DRIVER', 'ATTENDANT'],
      'teacher' => const ['TEACHER'],
      _ => const ['GUARDIAN'],
    };
    for (final m in _me!.memberships) {
      if (wanted.contains(m.role)) return m;
    }
    return wanted.contains(_me!.role) ? _me!.active : null;
  }
}

class _BrokenBuild extends StatelessWidget {
  const _BrokenBuild();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF7F1D1D),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.build_circle_outlined, size: 44, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'This build is broken',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'APP_ROLE was not set, so this APK does not know whether it is '
                    'the parent, teacher or driver app.\n\n'
                    'Do not hand this file to anybody. Build with '
                    'tool/build_apks.sh, which passes the define.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

