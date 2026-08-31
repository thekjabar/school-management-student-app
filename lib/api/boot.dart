import 'dart:async';

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
  /// Answers one question — who is signed in — and nothing else.
  ///
  /// It used to prefetch the whole opening screen here too, so that the home
  /// screen would already have its data by the time the splash lifted. It
  /// worked, and it was wrong: the app arrived fully formed, with no loading
  /// state to see and every entrance animation already played out behind the
  /// clip. The screens fetch for themselves, where a person can watch it
  /// happen.
  Future<BootState> start() => _future ??= _run();

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
      // Both at once, and only the prefetch is what anything waits on.
      //
      // These were serialised, to stop two requests discovering an expired
      // access token together and racing two renewals for one refresh token.
      // They cannot: _renew() memoises the attempt that is in flight, so
      // concurrent callers share one renewal and no token is spent twice. All
      // the ordering bought was a whole /auth/me round trip in front of the
      // home data, on every launch — which is the one thing a prefetch exists
      // to avoid.
      // The identity is confirmed behind the app. Not awaited: a rejected
      // session tears itself down through onSignedOut, which the gate listens
      // to, and an unreachable one leaves what the phone remembers standing.
      unawaited(_confirm());
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

  /// Only for tests, which must not inherit a previous test's boot.
  void resetForTest() {
    _future = null;
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
