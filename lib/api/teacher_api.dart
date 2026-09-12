import 'package:flutter/foundation.dart' show Uint8List, ValueNotifier;

import 'attachments.dart';
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

String? _photoAddress(dynamic raw) {
  final v = (raw as String?)?.trim() ?? '';
  if (v.isEmpty) return null;
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  return '$kApiBase${v.startsWith('/') ? '' : '/'}$v';
}

class RegisterMark {
  RegisterMark({
    required this.studentId,
    required this.name,
    required this.code,
    required this.rollNumber,
    required this.status,
    required this.minutesLate,
    this.photoUrl,
  });

  final String studentId;
  final String name;
  final String code;
  final String? rollNumber;
  String status;
  int? minutesLate;

  final String? photoUrl;

  factory RegisterMark.fromJson(Map<String, dynamic> j) => RegisterMark(
        studentId: (j['studentId'] ?? '') as String,
        name: (j['name'] ?? 'Student') as String,
        code: (j['code'] ?? '') as String,
        rollNumber: j['rollNumber'] as String?,
        photoUrl: _photoAddress(j['photoUrl']),
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

  final (num?, bool) _openedWith;

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

class TeacherApi {
  TeacherApi._();

  static final TeacherApi instance = TeacherApi._();
  final ApiClient _api = ApiClient.instance;

  Future<void> recordBehaviour({
    required String studentId,
    required String kind,
    String? classId,
    String? category,
    int? points,
    String? note,
    bool visibleToGuardian = false,
  }) async {
    await _api.post('/teacher/behaviour', {
      'studentId': studentId,
      'kind': kind,
      'classId': ?classId,
      'category': ?category,
      'points': ?points,
      'note': ?(note == null || note.trim().isEmpty ? null : note.trim()),
      'visibleToGuardian': visibleToGuardian,
    });
  }

  final ValueNotifier<int> unreadAnnouncements = ValueNotifier<int>(0);

  Future<TeacherProfile> me() async =>
      TeacherProfile.fromJson(await _api.get('/teacher/me') as Map<String, dynamic>);

  Future<List<Announcement>> announcements() async {
    final json = await _api.get('/teacher/announcements?pageSize=50');
    final rows = Paged.from<Announcement>(json, Announcement.fromJson).rows;
    unreadAnnouncements.value = rows.where((a) => a.readAt == null).length;
    return rows;
  }

  Future<void> markAnnouncementRead(String id) =>
      _api.post('/teacher/announcements/$id/read');

  Future<int> markAllAnnouncementsRead() async {
    final json = await _api.post('/teacher/announcements/read-all');
    return ((json as Map<String, dynamic>?)?['marked'] as num?)?.toInt() ?? 0;
  }
  Future<void> acknowledgeAnnouncement(String id) =>
      _api.post('/teacher/announcements/$id/acknowledge', const <String, dynamic>{});

  Future<List<AttachedFile>> announcementAttachments(String id) async {
    final json = await _api.get('/teacher/announcements/$id/attachments?pageSize=50');
    return Paged.from<AttachedFile>(json, AttachedFile.fromJson).rows;
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

  Future<String?> currentTermId() async {
    final json = await _api.get('/teacher/terms?pageSize=10');
    final rows = Paged.from<Map<String, dynamic>>(json, (m) => m).rows;
    for (final row in rows) {
      if (row['isCurrent'] == true) return row['id'] as String?;
    }
    return rows.isEmpty ? null : rows.first['id'] as String?;
  }

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

  Future<void> publishMarks(String examId) => _api.post('/teacher/exams/$examId/publish');

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const String _bankBase = '/teacher/mark-bank';

  Future<void> bankMark({
    required String studentId,
    required num points,
    required String reason,
    String? classId,
    String? subjectId,
    String? termId,
    String? evidenceMediaId,
  }) async {
    await _api.post(_bankBase, {
      'studentId': studentId,
      'points': points,
      'reason': reason.trim(),
      'classId': ?classId,
      'subjectId': ?subjectId,
      'termId': ?termId,
      'evidenceMediaId': ?evidenceMediaId,
    });
  }

  Future<List<MarkBankEntry>> markBank({String? state}) async {
    final query = state == null ? '?pageSize=200' : '?state=$state&pageSize=200';
    final json = await _api.get('$_bankBase$query');
    return Paged.from<MarkBankEntry>(json, MarkBankEntry.fromJson).rows;
  }

  Future<void> redeemMarks({
    required List<String> entryIds,
    required String redeemedAs,
  }) async {
    await _api.post('$_bankBase/redeem', {
      'entryIds': entryIds,
      'redeemedAs': redeemedAs,
    });
  }

  Future<void> voidMark(String id, String reason) =>
      _api.post('$_bankBase/$id/void', {'reason': reason.trim()});

  Future<String> uploadMarkEvidence({
    required Uint8List bytes,
    required String filename,
    required String mime,
    String? studentId,
  }) async {
    final json = await _api.upload(
      '/teacher/uploads/direct',
      field: 'file',
      bytes: bytes,
      filename: filename,
      mime: mime,
      fields: {
        'kind': 'HOMEWORK_ATTACHMENT',
        'subjectStudentId': ?studentId,
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    final id = json is Map ? json['id'] : null;
    if (id is! String || id.isEmpty) {
      throw ApiException('The school could not store that photo.', 500);
    }
    return id;
  }
}

class MarkBankEntry {
  MarkBankEntry({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.points,
    required this.reason,
    required this.occurredAt,
    required this.state,
    this.className,
    this.subjectName,
    this.termId,
    this.termName,
    this.evidenceMediaId,
    this.redeemedAt,
    this.redeemedAs,
  });

  final String id;
  final String studentId;
  final String studentName;

  final num points;
  final String reason;
  final DateTime? occurredAt;

  final String state;

  final String? className;
  final String? subjectName;
  final String? termId;
  final String? termName;
  final String? evidenceMediaId;
  final DateTime? redeemedAt;

  final String? redeemedAs;

  bool get isBanked => state == 'BANKED';

  static String? _name(Map<String, dynamic> j, String flat, String nested) {
    final direct = j[flat];
    if (direct is String && direct.isNotEmpty) return direct;
    final child = j[nested];
    if (child is Map && child['name'] is String) return child['name'] as String;
    return null;
  }

  factory MarkBankEntry.fromJson(Map<String, dynamic> j) => MarkBankEntry(
        id: (j['id'] ?? '') as String,
        studentId: (j['studentId'] ?? '') as String,
        studentName: _name(j, 'studentName', 'student') ?? '—',
        points: (j['points'] as num?) ??
            num.tryParse('${j['points'] ?? ''}') ??
            0,
        reason: (j['reason'] ?? '') as String,
        occurredAt: DateTime.tryParse((j['occurredAt'] ?? '') as String)?.toLocal(),
        state: (j['state'] ?? 'BANKED') as String,
        className: _name(j, 'className', 'class'),
        subjectName: _name(j, 'subjectName', 'subject'),
        termId: j['termId'] as String?,
        termName: _name(j, 'termName', 'term'),
        evidenceMediaId: j['evidenceMediaId'] as String?,
        redeemedAt: DateTime.tryParse((j['redeemedAt'] ?? '') as String)?.toLocal(),
        redeemedAs: j['redeemedAs'] as String?,
      );
}
