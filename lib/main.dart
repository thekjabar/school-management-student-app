import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/client.dart';
import 'api/push.dart';
import 'i18n/delegates.dart';
import 'i18n/strings.dart';
import 'api/session.dart';
import 'screens/driver/driver_app.dart';
import 'screens/login_screen.dart';
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
      'teacher' => 'EduPulse Teacher',
      'driver' => 'EduPulse Driver',
      _ => 'EduPulse Parent',
    };

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);
  // Read before the first frame. Restoring the language afterwards means the
  // app opens in English and redraws itself in Kurdish a moment later, which
  // looks like a fault.
  await AppLocale.restore();
  // Started here, but deliberately not asked for permission here — see Push.
  // Failing to start push must not stop the app, so this never throws.
  await Push.start();
  runApp(const EduPulseApp());
}

class EduPulseApp extends StatelessWidget {
  const EduPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listening here rather than at each screen: changing language rebuilds the
    // whole app, which is what has to happen — the text direction flips and
    // every row in every list is laid out the other way round.
    return ValueListenableBuilder<Lang>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) => _app(lang),
    );
  }

  Widget _app(Lang lang) {
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
      theme: AppTheme.build(tint: _role.tint),
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
      home: _Gate(),
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

  Future<void> _restore() async {
    await ApiClient.instance.restore();
    if (ApiClient.instance.hasSession) {
      final me = await Session.instance.refresh();
      if (!mounted) return;
      setState(() {
        _me = me;
        _ready = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // The same wash and the same mark as the sign-in screen, so the first
      // second of the app is not a different design from the second second.
      return Scaffold(
        backgroundColor: AppTheme.canvas,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_role.wash, AppTheme.canvas],
              stops: const [0, 0.55],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: _role.tint,
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: [
                      BoxShadow(
                        color: _role.tint.withValues(alpha: 0.34),
                        blurRadius: 22,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 18),
                const Text(
                  'EduPulse',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: _role.tint),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_me == null) {
      return LoginScreen(role: _role, onSignedIn: (me) => setState(() => _me = me));
    }

    // The signed-in person's real role decides the screens, not the build
    // flavour. A guardian who somehow installed the driver build gets the
    // parent app rather than an empty manifest and a confusing error.
    return switch (_me!.role) {
      'DRIVER' || 'ATTENDANT' => DriverApp(),
      'TEACHER' => TeacherApp(),
      'GUARDIAN' => ParentApp(),
      _ => _WrongApp(role: _me!.role, onSignOut: () async {
          await Session.instance.signOut();
          if (mounted) setState(() => _me = null);
        }),
    };
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
                const Icon(Icons.desktop_windows_rounded, size: 40, color: AppTheme.textFaint),
                const SizedBox(height: 16),
                Text(
                  'This account is for the web console',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your role — ${role.replaceAll('_', ' ').toLowerCase()} — works at '
                  'school.mrwari.com/portal rather than in this app.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.55),
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

