import 'dart:async';

import '../main.dart' show kRole;
import 'client.dart';
import 'parent_api.dart';
import 'session.dart';
import 'teacher_api.dart';

/// Everything the app needs before it can draw a real screen, fetched WHILE the
/// splash clip is playing.
///
/// The clip runs for about three seconds. Before this existed those three
/// seconds were spent showing a video, and then the app started doing its work
/// — restoring the session, confirming it with the server, asking who the
/// children are, then six more calls for the home screen — behind a second
/// loading screen with the wordmark on it. Two loading screens in a row, and
/// the second one is the one that feels slow, because by then the person is
/// waiting rather than watching.
///
/// So the work starts at the same instant the video does. The clip is a lid
/// over a screen that is already building itself, and by the time it lifts the
/// home screen usually has its data.
///
/// Nothing here is allowed to make the app slower than it was. Every step is
/// best-effort: a failure is swallowed and the screen that needed it falls back
/// to fetching for itself, exactly as it did before. A prefetch that can break
/// the app is not worth having.
class Boot {
  Boot._();

  static final Boot instance = Boot._();

  Future<BootState>? _future;

  /// Starts the work, once. Safe to call from anywhere; later callers get the
  /// same future rather than a second round of requests.
  ///
  /// Completes as soon as the SESSION is known. The screen data keeps loading
  /// behind it — see [warm].
  Future<BootState> start() => _future ??= _run();

  /// The screen data, still in flight when [start] completes.
  ///
  /// Kept separate because the two answer different questions. The shell needs
  /// to know who you are, which is one call; the home screen needs six more,
  /// and the header and the bottom bar have no business waiting for those —
  /// they are chrome, and they can be on screen the instant the splash lifts.
  Future<void>? _warm;

  /// Awaited by nothing that draws. Exposed so a test can settle.
  Future<void> get warm => _warm ?? Future<void>.value();

  /// The home payload. Taken ONCE — the home screen uses it for its first build
  /// and fetches for itself from then on, so a pull-to-refresh gets live data
  /// rather than this snapshot again.
  ///
  /// Waits for the prefetch to land rather than asking whether it already has.
  /// It never had: the shell mounts on the microtask after [start] completes,
  /// which is before the prefetch has sent a single byte, so this returned null
  /// every time and every screen fetched the same thing over again — ten
  /// requests where five were intended, at the one minute of the day when a
  /// whole school opens the app at once.
  ///
  /// Costs nothing to wait now. The screen is already up, with its skeleton,
  /// which is the entire point of it.
  Future<HomePayload?> takeHome() async {
    await warm;
    final h = _home;
    _home = null;
    return h;
  }

  HomePayload? _home;

  /// The children, from the same call the prefetch had to make anyway.
  ///
  /// It asks for them to work out whose home payload to fetch, and the shell
  /// then asked for exactly the same list again to draw the child switcher.
  /// Taken once, like the payloads.
  Future<List<Child>?> takeChildren() async {
    await warm;
    final c = _children;
    _children = null;
    return c;
  }

  List<Child>? _children;

  /// The teacher's opening screen. Taken once, and waited for, like [takeHome].
  Future<TeacherPayload?> takeTeacherHome() async {
    await warm;
    final t = _teacher;
    _teacher = null;
    return t;
  }

  TeacherPayload? _teacher;

  Future<BootState> _run() async {
    await ApiClient.instance.restore();
    if (!ApiClient.instance.hasSession) {
      return const BootState(me: null);
    }

    // Open from the identity on the phone, and ask the server to confirm it
    // BEHIND the app rather than in front of it.
    //
    // The confirm used to block. On a bad connection that was a white screen
    // for as long as the request took, and with no connection at all it was
    // read as "signed out" — splash, white screen, login, for a parent whose
    // session was perfectly good and who was simply in a basement.
    //
    // Nothing is given away by trusting it for a moment. A driver stood down
    // last night still cannot DO anything this morning: every call the app
    // makes comes back 401, the client clears the tokens and fires
    // onSignedOut, and the gate drops to sign-in. The check still happens. It
    // just no longer happens in the doorway.
    final cached = await Session.instance.restoreMe();
    if (cached != null) {
      // Confirm first, then prefetch — in that order deliberately. If the
      // access token has expired, letting both run at once means two requests
      // discovering it together and two concurrent renewals racing for one
      // refresh token, where the loser's is already spent.
      _warm = _confirm().then((_) => _prefetch()).catchError((_) {});
      return BootState(me: cached);
    }

    // Nothing remembered — a fresh install, or an upgrade from a build that
    // kept no identity. There is no app to draw, so this one has to be asked.
    // Capped well under the client's own 25 second timeout. That timeout is
    // sized for a person who pressed something and is watching for an answer;
    // this is the app deciding which screen to open, with nothing on screen
    // behind the splash but the role's colour. Waiting out twenty-five seconds
    // there is the white screen the customer reported.
    final Me? me;
    try {
      me = await Session.instance.refresh().timeout(const Duration(seconds: 7));
    } on TimeoutException {
      return const BootState(me: null, offline: true);
    } on ApiException {
      // Unreachable rather than rejected. With no remembered identity there is
      // still nothing to draw, so sign-in is the honest screen — and it says so
      // for itself when the attempt fails.
      return const BootState(me: null, offline: true);
    }
    if (me == null) return const BootState(me: null);

    // The screen data is started here and NOT awaited.
    //
    // Whichever opening screen this build will draw, decided by the flavour
    // rather than by the person's role: somebody can hold two, and fetching the
    // wrong one spends a school connection at the one minute of the day when
    // the whole city opens the app.
    //
    // Deliberately not awaited: the shell is chrome and needs none of it. The
    // curtain lifts on the line below, the header and the bottom bar draw
    // immediately, and the content sits under its skeleton until this lands.
    _warm = _prefetch().catchError((_) {
      // Swallowed. Every screen still fetches for itself if this never arrives.
    });

    return BootState(me: me);
  }

  /// Confirms the remembered identity against the server, behind the app.
  ///
  /// Failure here is not the app's problem to solve. Rejected, and the client
  /// has already cleared the tokens and fired onSignedOut, which the gate
  /// listens to. Unreachable, and the remembered identity stands — each screen
  /// says so when its own call fails, which is where a person can see it.
  Future<void> _confirm() async {
    final Me? me;
    try {
      me = await Session.instance.refresh();
    } on ApiException {
      return; // Unreachable. Carry on with what the phone remembers.
    }

    // Answered, and the answer was no. Normally the client has already torn the
    // session down by this point; this covers the case where a renewal
    // succeeded and the account was still refused, which leaves the tokens in
    // place and every later call failing silently.
    if (me == null) await Session.instance.signOut();
  }

  /// The opening screen's data, running behind the shell.
  Future<void> _prefetch() async {
    switch (kRole) {
      case 'teacher':
        _teacher = await TeacherPayload.fetch();

      case 'driver':
        // Nothing worth prefetching. The driver's home resolves today's duty
        // trip and then asks for that trip's plan — two dependent calls where
        // the second is large, better spent when the screen is on top and can
        // show its own progress.
        break;

      default:
        final children = await ParentApi.instance.children();
        // Kept, not just used. The shell needs this same list.
        _children = children;
        if (children.isNotEmpty) {
          _home = await HomePayload.fetch(children.first.studentId);
        }
    }
  }

  /// Only for tests, which must not inherit a previous test's boot.
  void resetForTest() {
    _future = null;
    _warm = null;
    _home = null;
    _children = null;
    _teacher = null;
  }
}

/// What the app knew by the time the splash lifted: who you are, and nothing
/// else. The screens ask for their own data.
class BootState {
  const BootState({required this.me, this.offline = false});

  final Me? me;

  /// The platform could not be reached at all during start-up.
  ///
  /// Only meaningful alongside a null [me]: it separates "we asked and you are
  /// not signed in" from "we could not ask", so the sign-in screen can lead
  /// with the connection rather than with a password that was never wrong.
  final bool offline;
}

/// The six calls the parent home screen opens with.
///
/// Gathered here as well as on the screen so that the splash can do them early.
/// The screen owns the shape; this owns only the timing.
class HomePayload {
  HomePayload({
    required this.studentId,
    required this.transport,
    required this.week,
    required this.attendance,
    required this.homework,
    required this.attitude,
    required this.announcements,
  });

  final String studentId;
  final TransportInfo transport;
  final List<DayOfLessons> week;
  final AttendanceSummary attendance;
  final List<HomeworkItem> homework;
  final AttitudeSummary attitude;
  final List<Announcement> announcements;

  /// One pass, all at once. Six sequential round trips on a school connection
  /// is the difference between a screen and a wait.
  static Future<HomePayload> fetch(String studentId) async {
    final api = ParentApi.instance;
    final r = await Future.wait([
      api.transport(studentId),
      api.timetable(studentId),
      api.attendance(studentId),
      api.homework(studentId),
      api.attitude(studentId),
      api.announcements(),
    ]);
    return HomePayload(
      studentId: studentId,
      transport: r[0] as TransportInfo,
      week: r[1] as List<DayOfLessons>,
      attendance: r[2] as AttendanceSummary,
      homework: r[3] as List<HomeworkItem>,
      attitude: r[4] as AttitudeSummary,
      announcements: r[5] as List<Announcement>,
    );
  }
}

/// The five calls the teacher home screen opens with.
///
/// Same arrangement as [HomePayload]: the screen owns the shape, this owns only
/// the timing.
class TeacherPayload {
  TeacherPayload({
    required this.profile,
    required this.slots,
    required this.classes,
    required this.homework,
    required this.exams,
  });

  final TeacherProfile profile;
  final List<TeacherSlot> slots;
  final List<TeachingSlot> classes;
  final List<TeacherHomework> homework;
  final List<TeacherExam> exams;

  static Future<TeacherPayload> fetch() async {
    final api = TeacherApi.instance;
    final r = await Future.wait([
      api.me(),
      api.timetable(),
      api.classes(),
      api.homework(),
      api.exams(),
    ]);
    return TeacherPayload(
      profile: r[0] as TeacherProfile,
      slots: r[1] as List<TeacherSlot>,
      classes: r[2] as List<TeachingSlot>,
      homework: r[3] as List<TeacherHomework>,
      exams: r[4] as List<TeacherExam>,
    );
  }
}
