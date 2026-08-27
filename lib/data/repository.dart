import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Where the screens get their data.
///
/// Two implementations behind one interface, on purpose.
///
/// `DemoRepository` runs the whole app with no backend at all. That is not a
/// toy: it is how the design gets reviewed, how the app is demonstrated to a
/// school before anything is deployed, and how the widgets get built against
/// realistic edge cases — an overdue assignment, a stale bus fix, a subject with
/// a falling grade — rather than against whatever happens to be in a database.
///
/// `ApiRepository` talks to the platform. The student-facing endpoints do not
/// exist yet — the platform's first release deliberately shipped the parent and
/// crew surfaces first — so every method here names the route it will call and
/// falls back rather than crashing. When those endpoints land, this file is the
/// only one that changes.
abstract class Repository {
  Future<Student> student();
  Future<List<Session>> today();
  Future<List<Assignment>> assignments();
  Future<List<SubjectGrade>> grades();
  Future<AttendanceSummary> attendance();
  Future<BusStatus> bus();
  Future<List<ExamEntry>> exams();
}

// ---------------------------------------------------------------------------
// Demo
// ---------------------------------------------------------------------------

class DemoRepository implements Repository {
  DemoRepository({this.latency = const Duration(milliseconds: 320)});

  /// Real latency, deliberately. A UI built against instant data has no loading
  /// states, and the first time it meets a real network every screen flashes.
  final Duration latency;

  Future<T> _delayed<T>(T value) =>
      Future.delayed(latency, () => value);

  @override
  Future<Student> student() => _delayed(const Student(
        id: 'stu_demo_1',
        code: '#8821',
        name: 'Leo Mitchell',
        className: 'Grade 11 — Section B',
        photoUrl: null,
        streakDays: 12,
      ));

  @override
  Future<List<Session>> today() => _delayed(const [
        Session(subject: 'Advanced Mathematics', teacher: 'Prof. Richard Feynman', room: 'Room 402', startMinute: 8 * 60, endMinute: 9 * 60 + 30),
        Session(subject: 'Chemistry', teacher: 'Dr. Marie Curie', room: 'Lab 2', startMinute: 9 * 60 + 40, endMinute: 11 * 60 + 10),
        Session(subject: 'Break', teacher: '', room: 'Courtyard', startMinute: 11 * 60 + 10, endMinute: 11 * 60 + 40, isBreak: true),
        Session(subject: 'Kurdish Literature', teacher: 'Mam Karwan', room: 'Room 118', startMinute: 11 * 60 + 40, endMinute: 13 * 60 + 10),
        Session(subject: 'Digital Art', teacher: 'Ms. Avan Rashid', room: 'Studio 1', startMinute: 13 * 60 + 20, endMinute: 14 * 60 + 50),
      ]);

  @override
  Future<List<Assignment>> assignments() {
    final now = DateTime.now();
    return _delayed([
      Assignment(
        id: 'a1', title: 'Chemistry Lab Report', subject: 'Chemistry',
        due: DateTime(now.year, now.month, now.day, 23, 59),
        kind: AssignmentKind.lab,
      ),
      Assignment(
        id: 'a2', title: 'Digital Art Portfolio', subject: 'Digital Art',
        due: DateTime(now.year, now.month, now.day + 3, 10, 0),
        kind: AssignmentKind.art,
      ),
      Assignment(
        id: 'a3', title: 'Integration by Parts — Problem Set 7', subject: 'Advanced Mathematics',
        due: DateTime(now.year, now.month, now.day + 5, 9, 0),
        kind: AssignmentKind.problemSet,
      ),
      // One already handed in, so the "done" state is designed rather than
      // discovered later.
      Assignment(
        id: 'a4', title: 'Essay: Sherko Bekas', subject: 'Kurdish Literature',
        due: DateTime(now.year, now.month, now.day - 2, 9, 0),
        kind: AssignmentKind.essay, submitted: true,
      ),
    ]);
  }

  @override
  Future<List<SubjectGrade>> grades() => _delayed(const [
        SubjectGrade(subject: 'Advanced Mathematics', score: 94, maxScore: 100, letter: 'A', teacher: 'Prof. Richard Feynman', trend: 2.5),
        SubjectGrade(subject: 'Chemistry', score: 88, maxScore: 100, letter: 'B+', teacher: 'Dr. Marie Curie', trend: -1.5),
        SubjectGrade(subject: 'Kurdish Literature', score: 91, maxScore: 100, letter: 'A-', teacher: 'Mam Karwan', trend: 4.0),
        SubjectGrade(subject: 'Digital Art', score: 97, maxScore: 100, letter: 'A+', teacher: 'Ms. Avan Rashid', trend: 1.0),
        SubjectGrade(subject: 'Physics', score: 79, maxScore: 100, letter: 'C+', teacher: 'Dr. Hemin Salih', trend: -3.5),
      ]);

  @override
  Future<AttendanceSummary> attendance() => _delayed(const AttendanceSummary(
        present: 78, absent: 4, late: 6, excused: 2, trend: 1.2,
      ));

  @override
  Future<BusStatus> bus() => _delayed(BusStatus(
        state: BusState.approaching,
        plate: 'ERB 21-4471',
        driverName: 'Karwan Ahmad',
        stopName: 'Shar Park — north gate',
        etaMinutesLow: 6,
        etaMinutesHigh: 10,
        asOf: DateTime.now().subtract(const Duration(seconds: 8)),
      ));

  @override
  Future<List<ExamEntry>> exams() {
    final now = DateTime.now();
    return _delayed([
      ExamEntry(subject: 'Advanced Mathematics', date: now.add(const Duration(days: 4)), startMinute: 9 * 60, room: 'Hall A', kind: 'Midterm'),
      ExamEntry(subject: 'Chemistry', date: now.add(const Duration(days: 6)), startMinute: 9 * 60, room: 'Hall A', kind: 'Midterm'),
      ExamEntry(subject: 'Physics', date: now.add(const Duration(days: 9)), startMinute: 11 * 60, room: 'Hall B', kind: 'Midterm'),
      ExamEntry(subject: 'Kurdish Literature', date: now.add(const Duration(days: 12)), startMinute: 9 * 60, room: 'Room 118', kind: 'Midterm'),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Live
// ---------------------------------------------------------------------------

/// Talks to the platform gateway.
///
/// Every service sits behind one host and is routed by path prefix, so the app
/// only ever knows one base URL. That matters more on a phone than it looks: a
/// client that has to discover five hostnames is a client that breaks the first
/// time one of them moves.
class ApiRepository implements Repository {
  ApiRepository({
    required this.baseUrl,
    required this.accessToken,
    required this.tenantId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String accessToken;
  final String tenantId;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $accessToken',
        // The tenant a request acts against comes from a header, never a body.
        'X-Tenant-Id': tenantId,
        'Content-Type': 'application/json',
      };

  Future<dynamic> _get(String path) async {
    final res = await _client
        .get(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, _messageFrom(res.body));
    }
    return jsonDecode(res.body);
  }

  /// The API writes its errors for the person who will read them on screen, so
  /// they are surfaced rather than replaced with something generic.
  static String _messageFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        final m = decoded['message'];
        return m is List ? m.join(', ') : m.toString();
      }
    } catch (_) {}
    return 'Something went wrong.';
  }

  @override
  Future<Student> student() async {
    final j = await _get('/api/student/me');
    return Student(
      id: j['id'],
      code: j['code'] ?? '',
      name: j['name'] ?? '',
      className: j['className'] ?? '',
      photoUrl: j['photoUrl'],
      streakDays: j['streakDays'] ?? 0,
    );
  }

  @override
  Future<List<Session>> today() async {
    final j = await _get('/api/student/timetable/today') as List;
    return j
        .map((s) => Session(
              subject: s['subject'] ?? '',
              teacher: s['teacher'] ?? '',
              room: s['room'] ?? '',
              startMinute: s['startMinute'] ?? 0,
              endMinute: s['endMinute'] ?? 0,
              isBreak: s['isBreak'] ?? false,
            ))
        .toList();
  }

  @override
  Future<List<Assignment>> assignments() async {
    final j = await _get('/api/student/homework') as List;
    return j
        .map((a) => Assignment(
              id: a['id'],
              title: a['title'] ?? '',
              subject: a['subject'] ?? '',
              due: DateTime.parse(a['dueAt']),
              kind: _kind(a['kind']),
              submitted: a['submitted'] ?? false,
            ))
        .toList();
  }

  static AssignmentKind _kind(String? raw) => switch (raw) {
        'LAB' => AssignmentKind.lab,
        'ART' => AssignmentKind.art,
        'ESSAY' => AssignmentKind.essay,
        'PROBLEM_SET' => AssignmentKind.problemSet,
        'READING' => AssignmentKind.reading,
        _ => AssignmentKind.project,
      };

  @override
  Future<List<SubjectGrade>> grades() async {
    // Only marks the school has actually PUBLISHED come back here. A teacher
    // entering results over three days must not appear on a student's phone
    // one subject at a time.
    final j = await _get('/api/student/grades') as List;
    return j
        .map((g) => SubjectGrade(
              subject: g['subject'] ?? '',
              score: (g['score'] ?? 0).toDouble(),
              maxScore: (g['maxScore'] ?? 100).toDouble(),
              letter: g['gradeLetter'] ?? '',
              teacher: g['teacher'] ?? '',
              trend: (g['trend'] ?? 0).toDouble(),
            ))
        .toList();
  }

  @override
  Future<AttendanceSummary> attendance() async {
    final j = await _get('/api/student/attendance/summary');
    return AttendanceSummary(
      present: j['present'] ?? 0,
      absent: j['absent'] ?? 0,
      late: j['late'] ?? 0,
      excused: j['excused'] ?? 0,
      trend: (j['trend'] ?? 0).toDouble(),
    );
  }

  @override
  Future<BusStatus> bus() async {
    final j = await _get('/api/student/bus');
    return BusStatus(
      state: switch (j['state']) {
        'APPROACHING' => BusState.approaching,
        'BOARDED' => BusState.boarded,
        'AT_SCHOOL' => BusState.atSchool,
        'HOMEWARD' => BusState.homeward,
        'DELIVERED' => BusState.delivered,
        _ => BusState.notStarted,
      },
      plate: j['plate'] ?? '',
      driverName: j['driverName'] ?? '',
      stopName: j['stopName'] ?? '',
      etaMinutesLow: j['etaMinutesLow'] ?? 0,
      etaMinutesHigh: j['etaMinutesHigh'] ?? 0,
      // The server's own timestamp, never the phone's clock. A device an hour
      // out would otherwise render a live fix as stale, or worse, the reverse.
      asOf: DateTime.parse(j['asOf']),
    );
  }

  @override
  Future<List<ExamEntry>> exams() async {
    final j = await _get('/api/student/exams') as List;
    return j
        .map((e) => ExamEntry(
              subject: e['subject'] ?? '',
              date: DateTime.parse(e['date']),
              startMinute: e['startMinute'] ?? 0,
              room: e['room'] ?? '',
              kind: e['kind'] ?? '',
            ))
        .toList();
  }
}

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

/// Which repository the app is running against.
///
/// Demo by default so `flutter run` works with nothing else in place. Point it
/// at a real deployment with:
///
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
final Repository repository = () {
  const base = String.fromEnvironment('API_BASE_URL');
  if (base.isEmpty) {
    if (kDebugMode) {
      debugPrint('student_app: no API_BASE_URL — running on demo data');
    }
    return DemoRepository();
  }
  return ApiRepository(
    baseUrl: base,
    accessToken: const String.fromEnvironment('ACCESS_TOKEN'),
    tenantId: const String.fromEnvironment('TENANT_ID'),
  );
}();
