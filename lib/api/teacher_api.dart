import 'package:flutter/foundation.dart' show ValueNotifier;

import 'client.dart';
import 'parent_api.dart' show Announcement;

class TeacherProfile {
  TeacherProfile({
    required this.name,
    required this.phone,
    required this.schoolName,
    required this.classCount,
    required this.subjectCount,
    required this.studentCount,
    required this.homeroomClassIds,
  });

  final String name;
  final String phone;
  final String schoolName;
  final int classCount;
  final int subjectCount;
  final int studentCount;
  final List<String> homeroomClassIds;

  factory TeacherProfile.fromJson(Map<String, dynamic> j) {
    final person = (j['person'] ?? {}) as Map<String, dynamic>;
    final school = (j['school'] ?? {}) as Map<String, dynamic>;
    return TeacherProfile(
      name: (person['name'] ?? '') as String,
      phone: (person['phone'] ?? '') as String,
      schoolName: (school['name'] ?? '') as String,
      classCount: (j['classCount'] as num?)?.toInt() ?? 0,
      subjectCount: (j['subjectCount'] as num?)?.toInt() ?? 0,
      studentCount: (j['studentCount'] as num?)?.toInt() ?? 0,
      homeroomClassIds: ((j['homeroomClassIds'] as List?) ?? []).cast<String>(),
    );
  }
}

/// A class-and-subject a teacher is assigned to.
class TeachingSlot {
  TeachingSlot({
    required this.assignmentId,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.colorHex,
    required this.room,
    required this.studentCount,
    required this.isHomeroom,
    required this.maxScore,
  });

  final String assignmentId;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final String? colorHex;
  final String? room;
  final int studentCount;
  final bool isHomeroom;
  final num maxScore;

  factory TeachingSlot.fromJson(Map<String, dynamic> j) {
    final subject = (j['subject'] ?? {}) as Map<String, dynamic>;
    final cls = (j['class'] ?? {}) as Map<String, dynamic>;
    return TeachingSlot(
      assignmentId: (j['assignmentId'] ?? '') as String,
      classId: (cls['id'] ?? '') as String,
      className: (cls['name'] ?? '') as String,
      subjectId: (subject['id'] ?? '') as String,
      subjectName: (subject['name'] ?? '') as String,
      colorHex: subject['colorHex'] as String?,
      room: cls['room'] as String?,
      studentCount: (cls['studentCount'] as num?)?.toInt() ?? 0,
      isHomeroom: (cls['isHomeroom'] ?? false) as bool,
      maxScore: (subject['defaultMaxScore'] as num?) ?? 100,
    );
  }
}

class TeacherSlot {
  TeacherSlot({
    required this.weekday,
    required this.period,
    required this.room,
    required this.startMinute,
    required this.subjectName,
    required this.colorHex,
    required this.className,
    required this.classId,
  });

  final String weekday;
  final int period;
  final String? room;
  final int? startMinute;
  final String subjectName;
  final String? colorHex;
  final String className;
  final String classId;

  factory TeacherSlot.fromJson(Map<String, dynamic> j) {
    final subject = j['subject'] as Map<String, dynamic>?;
    final cls = (j['class'] ?? {}) as Map<String, dynamic>;
    return TeacherSlot(
      weekday: (j['weekday'] ?? '') as String,
      period: (j['period'] as num?)?.toInt() ?? 0,
      room: (j['room'] ?? cls['roomDefault']) as String?,
      startMinute: (j['startMinute'] as num?)?.toInt(),
      subjectName: (subject?['name'] ?? j['kind'] ?? '') as String,
      colorHex: subject?['colorHex'] as String?,
      className: (cls['name'] ?? '') as String,
      classId: (cls['id'] ?? '') as String,
    );
  }
}

class ClassStudent {
  ClassStudent({
    required this.studentId,
    required this.code,
    required this.name,
    required this.rollNumber,
    required this.status,
  });

  final String studentId;
  final String code;
  final String name;
  final String? rollNumber;
  final String? status;

  factory ClassStudent.fromJson(Map<String, dynamic> j) => ClassStudent(
        studentId: (j['studentId'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        name: (j['name'] ?? 'Student') as String,
        rollNumber: j['rollNumber'] as String?,
        status: j['status'] as String?,
      );
}

/// One child's mark on the register for a day.
class RegisterMark {
  RegisterMark({
    required this.studentId,
    required this.name,
    required this.code,
    required this.rollNumber,
    required this.status,
    required this.minutesLate,
  });

  final String studentId;
  final String name;
  final String code;
  final String? rollNumber;
  String status;
  int? minutesLate;

  factory RegisterMark.fromJson(Map<String, dynamic> j) => RegisterMark(
        studentId: (j['studentId'] ?? '') as String,
        name: (j['name'] ?? 'Student') as String,
        code: (j['code'] ?? '') as String,
        rollNumber: j['rollNumber'] as String?,
        // Null means nobody has marked this child today. Defaulting to PRESENT
        // here would silently mark a full register the moment the screen opens,
        // which is precisely the mistake the register exists to prevent.
        status: (j['status'] ?? 'PRESENT') as String,
        minutesLate: (j['minutesLate'] as num?)?.toInt(),
      );
}

class TeacherHomework {
  TeacherHomework({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.assignedOn,
    required this.publishedAt,
    required this.subjectName,
    required this.colorHex,
    required this.className,
    required this.submissions,
  });

  final String id;
  final String title;
  final DateTime dueDate;
  final DateTime assignedOn;
  final DateTime? publishedAt;
  final String subjectName;
  final String? colorHex;
  final String className;
  final int submissions;

  factory TeacherHomework.fromJson(Map<String, dynamic> j) {
    final subject = (j['subject'] ?? {}) as Map<String, dynamic>;
    final cls = (j['class'] ?? {}) as Map<String, dynamic>;
    return TeacherHomework(
      id: j['id'] as String,
      title: (j['title'] ?? '') as String,
      dueDate: DateTime.parse(j['dueDate'] as String).toLocal(),
      assignedOn: DateTime.parse(j['assignedOn'] as String).toLocal(),
      publishedAt: j['publishedAt'] == null ? null : DateTime.parse(j['publishedAt'] as String).toLocal(),
      subjectName: (subject['name'] ?? '') as String,
      colorHex: subject['colorHex'] as String?,
      className: (cls['name'] ?? '') as String,
      submissions: ((j['_count'] ?? {}) as Map<String, dynamic>)['submissions'] as int? ?? 0,
    );
  }
}

class TeacherExam {
  TeacherExam({
    required this.id,
    required this.title,
    required this.kind,
    required this.state,
    required this.date,
    required this.startMinute,
    required this.room,
    required this.maxScore,
    required this.subjectName,
    required this.colorHex,
    required this.className,
    required this.resultCount,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final String kind;
  final String state;
  final DateTime date;
  final int? startMinute;
  final String? room;
  final num maxScore;
  final String subjectName;
  final String? colorHex;
  final String className;
  final int resultCount;
  final DateTime? publishedAt;

  factory TeacherExam.fromJson(Map<String, dynamic> j) {
    final subject = (j['subject'] ?? {}) as Map<String, dynamic>;
    final cls = (j['class'] ?? {}) as Map<String, dynamic>;
    return TeacherExam(
      id: j['id'] as String,
      title: (j['title'] ?? 'Test') as String,
      kind: (j['kind'] ?? '') as String,
      state: (j['state'] ?? 'DRAFT') as String,
      date: DateTime.parse(j['date'] as String).toLocal(),
      startMinute: (j['startMinute'] as num?)?.toInt(),
      room: j['room'] as String?,
      maxScore: (j['maxScore'] as num?) ?? 100,
      subjectName: (subject['name'] ?? '') as String,
      colorHex: subject['colorHex'] as String?,
      className: (cls['name'] ?? '') as String,
      resultCount: ((j['_count'] ?? {}) as Map<String, dynamic>)['results'] as int? ?? 0,
      publishedAt:
          j['resultsPublishedAt'] == null ? null : DateTime.parse(j['resultsPublishedAt'] as String).toLocal(),
    );
  }
}

/// A mark sheet row: one child, with whatever score has been entered.
class MarkRow {
  MarkRow({
    required this.studentId,
    required this.name,
    required this.code,
    required this.rollNumber,
    required this.score,
    required this.wasAbsent,
    required this.publishedAt,
  }) : _openedWith = (score, wasAbsent);

  final String studentId;
  final String name;
  final String code;
  final String? rollNumber;
  num? score;
  bool wasAbsent;
  final DateTime? publishedAt;

  /// What this row said when the screen opened it.
  ///
  /// score and wasAbsent are edited in place, so without this there is no way
  /// to tell a mark the teacher CLEARED from one they never touched — and that
  /// distinction is the whole difference between "leave this student alone" and
  /// "take the old mark off".
  final (num?, bool) _openedWith;

  /// Whether the teacher changed this row.
  bool get changed => score != _openedWith.$1 || wasAbsent != _openedWith.$2;

  factory MarkRow.fromJson(Map<String, dynamic> j) => MarkRow(
        studentId: (j['studentId'] ?? '') as String,
        name: (j['name'] ?? 'Student') as String,
        code: (j['code'] ?? '') as String,
        rollNumber: j['rollNumber'] as String?,
        score: j['score'] as num?,
        wasAbsent: (j['wasAbsent'] ?? false) as bool,
        publishedAt: null,
      );
}

/// Everything the teacher app asks the platform for.
class TeacherApi {
  TeacherApi._();

  static final TeacherApi instance = TeacherApi._();
  final ApiClient _api = ApiClient.instance;

  /// How many notices this teacher has not opened yet.
  ///
  /// The dot on Messages is drawn from a count the shell takes once, at
  /// start-up, from [announcements] — so nothing a teacher does afterwards can
  /// move it. This is that same number kept live: seeded by every fetch, and
  /// moved by the messages tab as notices are read. Anything drawing the dot
  /// should listen to this rather than count rows itself.
  final ValueNotifier<int> unreadAnnouncements = ValueNotifier<int>(0);

  Future<TeacherProfile> me() async =>
      TeacherProfile.fromJson(await _api.get('/teacher/me') as Map<String, dynamic>);

  /// What the office has sent that this teacher should see.
  ///
  /// Resolved server-side against their classes, their campus and anything
  /// aimed at staff — the client cannot work that out and should not try.
  Future<List<Announcement>> announcements() async {
    final json = await _api.get('/teacher/announcements?pageSize=50');
    final rows = Paged.from<Announcement>(json, Announcement.fromJson).rows;
    unreadAnnouncements.value = rows.where((a) => a.readAt == null).length;
    return rows;
  }

  /// This teacher has read one notice.
  ///
  /// Scoped to the caller by the server — a teacher marks their own reading,
  /// never a colleague's — and idempotent, so a notice opened twice is not an
  /// error and the app need not remember what it has already sent.
  Future<void> markAnnouncementRead(String id) =>
      _api.post('/teacher/announcements/$id/read');

  /// This teacher has read everything they can see. Returns how many rows the
  /// server actually stamped, which is not always what was on screen: the list
  /// is one page long, and the sweep covers the lot.
  Future<int> markAllAnnouncementsRead() async {
    final json = await _api.post('/teacher/announcements/read-all');
    return ((json as Map<String, dynamic>?)?['marked'] as num?)?.toInt() ?? 0;
  }

  Future<List<TeachingSlot>> classes() async {
    final json = await _api.get('/teacher/classes');
    return Paged.from<TeachingSlot>(json, TeachingSlot.fromJson).rows;
  }

  Future<List<TeacherSlot>> timetable() async {
    final json = await _api.get('/teacher/timetable');
    return Paged.from<TeacherSlot>(json, TeacherSlot.fromJson).rows;
  }

  Future<List<ClassStudent>> students(String classId) async {
    final json = await _api.get('/teacher/classes/$classId/students') as Map<String, dynamic>;
    return ((json['students'] as List?) ?? [])
        .map((e) => ClassStudent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The register for a day, with whatever has already been marked on it.
  ///
  /// [q] asks the server for only the children whose name or code contains
  /// it; the matching is done there, on the folded form the search columns
  /// use, so case and letter variants do not matter. It does not transliterate:
  /// a name stored in Latin is found by typing it in Latin.
  Future<({bool alreadyTaken, List<RegisterMark> marks})> register(
    String classId, {
    String? date,
    String? q,
  }) async {
    final query = <String, String>{
      'date': ?date,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };
    final json = await _api.get(
      '/teacher/classes/$classId/attendance${query.isEmpty ? '' : '?${Uri(queryParameters: query).query}'}',
    ) as Map<String, dynamic>;
    return (
      alreadyTaken: (json['alreadyTaken'] ?? false) as bool,
      marks: ((json['students'] as List?) ?? [])
          .map((e) => RegisterMark.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Save the whole register in one call.
  ///
  /// Batched deliberately. A register is thirty decisions taken in ninety
  /// seconds; thirty requests over a school's connection is thirty chances for
  /// one to fail and leave a child unmarked with nobody the wiser.
  Future<void> saveRegister({
    required String classId,
    required String date,
    required List<RegisterMark> marks,
  }) async {
    await _api.post('/teacher/attendance', {
      'classId': classId,
      'date': date,
      'marks': marks
          .map((m) => {
                'studentId': m.studentId,
                'status': m.status,
                if (m.status == 'LATE' && m.minutesLate != null) 'minutesLate': m.minutesLate,
              })
          .toList(),
    });
  }

  Future<List<TeacherHomework>> homework() async {
    final json = await _api.get('/teacher/homework');
    return Paged.from<TeacherHomework>(json, TeacherHomework.fromJson).rows;
  }

  Future<void> setHomework({
    required String classId,
    required String subjectId,
    required String title,
    required String description,
    required DateTime dueDate,
    int? estimatedMinutes,
  }) async {
    await _api.post('/teacher/homework', {
      'classId': classId,
      'subjectId': subjectId,
      'title': title,
      'description': description,
      'dueDate': _dateOnly(dueDate),
      'estimatedMinutes': ?estimatedMinutes,
    });
  }

  Future<void> publishHomework(String id) => _api.post('/teacher/homework/$id/publish');

  Future<List<TeacherExam>> exams() async {
    final json = await _api.get('/teacher/exams');
    return Paged.from<TeacherExam>(json, TeacherExam.fromJson).rows;
  }

  Future<void> createExam({
    required String classId,
    required String subjectId,
    required String termId,
    required String title,
    required String kind,
    required DateTime date,
    required num maxScore,
  }) async {
    await _api.post('/teacher/exams', {
      'classId': classId,
      'subjectId': subjectId,
      'termId': termId,
      'title': title,
      'kind': kind,
      'date': _dateOnly(date),
      'maxScore': maxScore,
    });
  }

  Future<({bool published, num maxScore, List<MarkRow> rows})> marks(String examId) async {
    final json = await _api.get('/teacher/exams/$examId/marks') as Map<String, dynamic>;
    final exam = (json['exam'] ?? {}) as Map<String, dynamic>;
    return (
      published: (json['published'] ?? false) as bool,
      maxScore: (exam['maxScore'] as num?) ?? 100,
      rows: ((json['students'] as List?) ?? [])
          .map((e) => MarkRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// The term marks are entered against. Every exam belongs to one, and the
  /// app must not invent it — a mark filed under the wrong term lands in the
  /// wrong report card.
  Future<String?> currentTermId() async {
    final json = await _api.get('/school/terms?pageSize=10');
    final rows = Paged.from<Map<String, dynamic>>(json, (m) => m).rows;
    for (final row in rows) {
      if (row['isCurrent'] == true) return row['id'] as String?;
    }
    return rows.isEmpty ? null : rows.first['id'] as String?;
  }

  /// Save the marks the teacher actually changed.
  ///
  /// The filter used to be `score != null || wasAbsent`, which silently dropped
  /// the one case that matters most: a mark the teacher had just CLEARED, or a
  /// student they had just un-flagged as absent. Neither reached the server, so
  /// it kept the old value while the screen said "Marks saved" — a correction
  /// that looked made and was not, on the numbers a family is sent.
  ///
  /// Only changed rows go, so a save cannot quietly wipe the marks of students
  /// nobody touched. `score` is OMITTED rather than sent null when a mark is
  /// cleared, because that is how the server clears one: an absent `score`
  /// writes null, which is exactly what "no mark" means.
  Future<void> saveMarks(String examId, List<MarkRow> rows) async {
    final changed = rows.where((r) => r.changed).toList();
    if (changed.isEmpty) return;
    await _api.post('/teacher/exams/$examId/marks', {
      'marks': changed
          .map((r) => {
                'studentId': r.studentId,
                if (!r.wasAbsent && r.score != null) 'score': r.score,
                'wasAbsent': r.wasAbsent,
              })
          .toList(),
    });
  }

  /// Release marks to families.
  ///
  /// A separate permission from entering them, and a separate button here, for
  /// the same reason: a mark typed wrong is fixed in a minute, a mark released
  /// wrong is on three hundred phones.
  Future<void> publishMarks(String examId) => _api.post('/teacher/exams/$examId/publish');

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
