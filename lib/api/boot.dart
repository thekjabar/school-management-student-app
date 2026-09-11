import 'dart:async';

import 'client.dart';
import 'parent_api.dart';
import 'session.dart';
import 'teacher_api.dart';

class Boot {
  Boot._();

  static final Boot instance = Boot._();

  Future<BootState>? _future;

  Future<BootState> start() => _future ??= _run();

  Future<BootState> _run() async {
    await ApiClient.instance.restore();
    if (!ApiClient.instance.hasSession) {
      return const BootState(me: null);
    }

    final cached = await Session.instance.restoreMe();
    if (cached != null) {
      unawaited(_confirm());
      return BootState(me: cached);
    }

    final Me? me;
    try {
      me = await Session.instance.refresh().timeout(const Duration(seconds: 7));
    } on TimeoutException {
      return const BootState(me: null, offline: true);
    } on ApiException {
      return const BootState(me: null, offline: true);
    }
    if (me == null) return const BootState(me: null);
    if (me.passwordMustChange) {
      Session.passwordChangeRequired = true;
      await Session.instance.signOut();
      return const BootState(me: null);
    }

    return BootState(me: me);
  }

  Future<void> _confirm() async {
    final Me? me;
    try {
      me = await Session.instance.refresh();
    } on ApiException {
      return;
    }

    if (me == null) {
      await Session.instance.signOut();
      return;
    }

    if (me.passwordMustChange) {
      Session.passwordChangeRequired = true;
      await Session.instance.signOut();
    }
  }

  void resetForTest() {
    _future = null;
  }
}

class BootState {
  const BootState({required this.me, this.offline = false});

  final Me? me;

  final bool offline;
}

class HomePayload {
  HomePayload({
    required this.studentId,
    required this.transport,
    required this.week,
    required this.attendance,
    required this.homework,
    required this.attitude,
    required this.announcements,
    required this.exams,
  });

  final String studentId;
  final TransportInfo transport;
  final List<DayOfLessons> week;
  final AttendanceSummary attendance;
  final List<HomeworkItem> homework;
  final AttitudeSummary attitude;
  final List<Announcement> announcements;

  final List<UpcomingExam> exams;

  static Future<HomePayload> fetch(String studentId) async {
    final api = ParentApi.instance;
    final r = await Future.wait([
      api.transport(studentId),
      api.timetable(studentId),
      api.attendance(studentId),
      api.homework(studentId),
      api.attitude(studentId),
      api.announcements(),
      api.upcomingExams(studentId),
    ]);
    return HomePayload(
      studentId: studentId,
      transport: r[0] as TransportInfo,
      week: r[1] as List<DayOfLessons>,
      attendance: r[2] as AttendanceSummary,
      homework: r[3] as List<HomeworkItem>,
      attitude: r[4] as AttitudeSummary,
      announcements: r[5] as List<Announcement>,
      exams: r[6] as List<UpcomingExam>,
    );
  }
}

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
