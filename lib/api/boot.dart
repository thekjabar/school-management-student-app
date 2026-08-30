import 'dart:async';

import 'parent_api.dart';
import 'client.dart';
import 'session.dart';

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
  Future<BootState> start() => _future ??= _run();

  /// The home payload, if it arrived in time. Taken ONCE — the home screen uses
  /// it for its first build and fetches for itself from then on, so a
  /// pull-to-refresh gets live data rather than this snapshot again.
  HomePayload? takeHome() {
    final h = _home;
    _home = null;
    return h;
  }

  HomePayload? _home;

  Future<BootState> _run() async {
    await ApiClient.instance.restore();
    if (!ApiClient.instance.hasSession) {
      return const BootState(me: null);
    }

    // Confirmed against the server rather than trusted. A driver stood down
    // last night must not open a manifest this morning, and the only thing
    // that knows is the server.
    final Me? me;
    try {
      me = await Session.instance.refresh();
    } catch (_) {
      return const BootState(me: null);
    }
    if (me == null) return const BootState(me: null);

    // The children, and then the first child's home screen. Only worth doing
    // for the parent build — a teacher's and a driver's first screens are
    // different work, and guessing wrong just wastes a school connection.
    List<Child> children = const [];
    try {
      children = await ParentApi.instance.children();
      if (children.isNotEmpty) {
        _home = await HomePayload.fetch(children.first.studentId);
      }
    } catch (_) {
      // Left null. The home screen fetches for itself.
    }

    return BootState(me: me, children: children);
  }

  /// Only for tests, which must not inherit a previous test's boot.
  void resetForTest() {
    _future = null;
    _home = null;
  }
}

/// What the app knew by the time the splash lifted.
class BootState {
  const BootState({required this.me, this.children = const []});

  final Me? me;
  final List<Child> children;
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
