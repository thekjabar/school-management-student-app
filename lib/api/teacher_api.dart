import 'package:flutter/foundation.dart' show Uint8List, ValueNotifier;

import 'attachments.dart';
import 'client.dart';
import 'parent_api.dart' show AiAnswer, Announcement;

class AiTeacherClass {
  AiTeacherClass({
    required this.classId,
    required this.name,
    required this.gradeLevel,
    required this.subjects,
  });

  final String classId;
  final String name;
  final int gradeLevel;
  final List<String> subjects;

  factory AiTeacherClass.fromJson(Map<String, dynamic> j) => AiTeacherClass(
        classId: (j['classId'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        gradeLevel: (j['gradeLevel'] as num?)?.toInt() ?? 0,
        subjects: ((j['subjects'] as List?) ?? const [])
            .map((s) => s.toString())
            .where((s) => s.isNotEmpty)
            .toList(),
      );
}

class AiTeacherOverview {
  AiTeacherOverview({
    required this.available,
    required this.limit,
    required this.remaining,
    required this.resetsOn,
    required this.classes,
  });

  final bool available;
  final int limit;
  final int remaining;
  final String? resetsOn;
  final List<AiTeacherClass> classes;

  bool get spent => remaining <= 0;

  factory AiTeacherOverview.fromJson(Map<String, dynamic> j) => AiTeacherOverview(
        available: (j['available'] ?? false) as bool,
        limit: (j['limit'] as num?)?.toInt() ?? 0,
        remaining: (j['remaining'] as num?)?.toInt() ?? 0,
        resetsOn: j['resetsOn'] as String?,
        classes: ((j['classes'] as List?) ?? const [])
            .map((c) => AiTeacherClass.fromJson((c as Map).cast<String, dynamic>()))
            .toList(),
      );
}

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
    final person = ((j['person'] as Map<String, dynamic>?) ?? const <String, dynamic>{});
    final school = ((j['school'] as Map<String, dynamic>?) ?? const <String, dynamic>{});
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
    final subject = ((j['subject'] as Map<String, dynamic>?) ?? const <String, dynamic>{});
    final cls = ((j['class'] as Map<String, dynamic>?) ?? const <String, dynamic>{});
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
    final cls = ((j['class'] as Map<String, dynamic>?) ?? const <String, dynamic>{});
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
    this.maxScore,
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
  final num? maxScore;

  factory TeacherHomework.fromJson(Map<String, dynamic> j) {
    final subject = ((j['subject'] as Map<String, dynamic>?) ?? const <String, dynamic>{});
    final cls = ((j['class'] as Map<String, dynamic>?) ?? const <String, dynamic>{});
    return TeacherHomework(
      id: j['id'] as String,
      title: (j['title'] ?? '') as String,
      dueDate: DateTime.parse(j['dueDate'] as String).toLocal(),
      assignedOn: DateTime.parse(j['assignedOn'] as String).toLocal(),
      publishedAt: j['publishedAt'] == null ? null : DateTime.parse(j['publishedAt'] as String).toLocal(),
      subjectName: (subject['name'] ?? '') as String,
      colorHex: subject['colorHex'] as String?,
      className: (cls['name'] ?? '') as String,
      submissions: (((j['_count'] as Map<String, dynamic>?) ?? const <String, dynamic>{}))['submissions'] as int? ?? 0,
      maxScore: j['maxScore'] == null ? null : num.tryParse('${j['maxScore']}'),
    );
  }
}

class HomeworkSheetRow {
  HomeworkSheetRow({
    required this.studentId,
    required this.code,
    required this.rollNumber,
    required this.name,
    required this.status,
    required this.score,
  })  : savedStatus = status,
        savedScore = score;

  final String studentId;
  final String code;
  final String? rollNumber;
  final String name;
  String status;
  num? score;
  final String savedStatus;
  final num? savedScore;

  bool get changed => status != savedStatus || score != savedScore;

  Map<String, Object?> toEntry() => {
        'studentId': studentId,
        if (score != savedScore) 'score': score,
        if (status != savedStatus) 'status': status,
      };

  factory HomeworkSheetRow.fromJson(Map<String, dynamic> j) => HomeworkSheetRow(
        studentId: (j['studentId'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        rollNumber: j['rollNumber'] as String?,
        name: (j['name'] ?? '') as String,
        status: (j['status'] ?? 'NOT_SUBMITTED') as String,
        score: j['score'] as num?,
      );
}

class HomeworkSheet {
  HomeworkSheet({
    required this.id,
    required this.title,
    required this.maxScore,
    required this.className,
    required this.subjectName,
    required this.rows,
  });

  final String id;
  final String title;
  final num? maxScore;
  final String className;
  final String subjectName;
  final List<HomeworkSheetRow> rows;

  List<Map<String, Object?>> changedEntries() => rows.where((r) => r.changed).map((r) => r.toEntry()).toList();

  factory HomeworkSheet.fromJson(Map<String, dynamic> j) {
    final hw = ((j['homework'] as Map<String, dynamic>?) ?? const <String, dynamic>{});
    return HomeworkSheet(
      id: (hw['id'] ?? '') as String,
      title: (hw['title'] ?? '') as String,
      maxScore: hw['maxScore'] as num?,
      className: (hw['className'] ?? '') as String,
      subjectName: (hw['subjectName'] ?? '') as String,
      rows: ((j['students'] as List?) ?? const [])
          .map((e) => HomeworkSheetRow.fromJson(e as Map<String, dynamic>))
          .toList(),
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
    final subject = ((j['subject'] as Map<String, dynamic>?) ?? const <String, dynamic>{});
    final cls = ((j['class'] as Map<String, dynamic>?) ?? const <String, dynamic>{});
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
      resultCount: (((j['_count'] as Map<String, dynamic>?) ?? const <String, dynamic>{}))['results'] as int? ?? 0,
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

  Future<AiTeacherOverview> aiOverview() async {
    final json = await _api.get('/teacher/ai') as Map<String, dynamic>;
    return AiTeacherOverview.fromJson(json);
  }

  Future<AiAnswer> aiQuestion({
    required String question,
    String? classId,
    String? subjectId,
  }) async {
    final json = await _api.post('/teacher/ai/question', {
      'question': question.trim(),
      'classId': ?(classId == null || classId.isEmpty ? null : classId),
      'subjectId': ?(subjectId == null || subjectId.isEmpty ? null : subjectId),
    });
    return AiAnswer.fromJson((json as Map).cast<String, dynamic>());
  }

  Future<AiAnswer> aiClassReport({
    required String classId,
    required String question,
  }) async {
    final json = await _api.post('/teacher/ai/class-report', {
      'classId': classId,
      'question': question.trim(),
    });
    return AiAnswer.fromJson((json as Map).cast<String, dynamic>());
  }

  Future<AiAnswer> aiStudentReport({
    required String classId,
    required String studentId,
    required String question,
  }) async {
    final json = await _api.post('/teacher/ai/student-report', {
      'classId': classId,
      'studentId': studentId,
      'question': question.trim(),
    });
    return AiAnswer.fromJson((json as Map).cast<String, dynamic>());
  }

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

  Future<void> publishHomework(String id) => _api.post('/teacher/homework/$id/publish');

  Future<int> setHomeworkForClasses({
    required List<String> classIds,
    required String subjectId,
    required String title,
    required String description,
    required DateTime dueDate,
    int? estimatedMinutes,
    num? maxScore,
  }) async {
    final json = await _api.post('/teacher/homework/batch', {
      'classIds': classIds,
      'subjectId': subjectId,
      'title': title,
      'description': description,
      'dueDate': _dateOnly(dueDate),
      'estimatedMinutes': ?estimatedMinutes,
      'maxScore': ?maxScore,
    });
    return (((json as Map<String, dynamic>)['created'] as List?) ?? const []).length;
  }

  Future<HomeworkSheet> homeworkSheet(String id) async {
    final json = await _api.get('/teacher/homework/$id/submissions');
    return HomeworkSheet.fromJson(json as Map<String, dynamic>);
  }

  Future<int> saveHomeworkMarks(HomeworkSheet sheet) async {
    final entries = sheet.changedEntries();
    if (entries.isEmpty) return 0;
    final json = await _api.put('/teacher/homework/${sheet.id}/grades', {'entries': entries});
    return (((json as Map<String, dynamic>)['saved'] as num?) ?? 0).toInt();
  }

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
    final exam = ((json['exam'] as Map<String, dynamic>?) ?? const <String, dynamic>{});
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

  Future<MarkBankRules> markBankRules() async {
    final json = await _api.get('$_bankBase/policy');
    return MarkBankRules.fromJson((json as Map).cast<String, dynamic>());
  }

  Future<void> reviseMark(
    String id, {
    num? points,
    String? reason,
    String? subjectId,
    String? termId,
  }) =>
      _api.patch('$_bankBase/$id', {
        'points': ?points,
        if (reason != null) 'reason': reason.trim(),
        'subjectId': ?subjectId,
        'termId': ?termId,
      });

  Future<void> voidMark(String id, String reason) =>
      _api.post('$_bankBase/$id/void', {'reason': reason.trim()});

  Future<AwardPreview> previewAward({
    required List<String> entryIds,
    required String kind,
    String? subjectId,
    String? termId,
  }) async {
    final json = await _api.post('$_bankBase/awards/preview', {
      'entryIds': entryIds,
      'kind': kind,
      'subjectId': ?subjectId,
      'termId': ?termId,
    });
    return AwardPreview.fromJson((json as Map).cast<String, dynamic>());
  }

  Future<MarkBankAward> awardBanked({
    required List<String> entryIds,
    required String kind,
    required String reason,
    bool acceptCap = false,
    String? subjectId,
    String? termId,
  }) async {
    final json = await _api.post('$_bankBase/awards', {
      'entryIds': entryIds,
      'kind': kind,
      'reason': reason.trim(),
      'acceptCap': acceptCap,
      'subjectId': ?subjectId,
      'termId': ?termId,
    });
    return MarkBankAward.fromJson((json as Map).cast<String, dynamic>());
  }

  Future<List<MarkBankAward>> markBankAwards({String? status, String? studentId}) async {
    final query = <String>[
      'pageSize=100',
      if (status != null) 'status=$status',
      if (studentId != null) 'studentId=$studentId',
    ].join('&');
    final json = await _api.get('$_bankBase/awards?$query');
    return Paged.from<MarkBankAward>(json, MarkBankAward.fromJson).rows;
  }

  Future<void> reverseAward(String id, String reason) =>
      _api.post('$_bankBase/awards/$id/reverse', {'reason': reason.trim()});

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

num _points(Object? value) =>
    value is num ? value : num.tryParse('${value ?? ''}') ?? 0;

class MarkBankEntry {
  MarkBankEntry({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.points,
    required this.reason,
    required this.occurredAt,
    required this.state,
    this.classId,
    this.className,
    this.subjectId,
    this.subjectName,
    this.termId,
    this.termName,
    this.evidenceMediaId,
    this.awaitingApproval = false,
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

  final String? classId;
  final String? className;
  final String? subjectId;
  final String? subjectName;
  final String? termId;
  final String? termName;
  final String? evidenceMediaId;

  final bool awaitingApproval;
  final DateTime? redeemedAt;

  final String? redeemedAs;

  bool get isBanked => state == 'BANKED';

  bool get canSpend => isBanked && !awaitingApproval;

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
        points: _points(j['points']),
        reason: (j['reason'] ?? '') as String,
        occurredAt: DateTime.tryParse((j['occurredAt'] ?? '') as String)?.toLocal(),
        state: (j['state'] ?? 'BANKED') as String,
        classId: j['classId'] as String?,
        className: _name(j, 'className', 'class'),
        subjectId: j['subjectId'] as String?,
        subjectName: _name(j, 'subjectName', 'subject'),
        termId: j['termId'] as String?,
        termName: _name(j, 'termName', 'term'),
        evidenceMediaId: j['evidenceMediaId'] as String?,
        awaitingApproval: j['awaitingApproval'] == true,
        redeemedAt: DateTime.tryParse((j['redeemedAt'] ?? '') as String)?.toLocal(),
        redeemedAs: j['redeemedAs'] as String?,
      );
}

class MarkBankRules {
  const MarkBankRules({
    required this.enabled,
    required this.maxPointsPerEntry,
    required this.maxBankedPerStudentPerTerm,
    required this.maxAddedToMark,
    required this.approvalMode,
    required this.allSubjects,
    required this.subjectIds,
    required this.pointSteps,
  });

  final bool enabled;
  final num maxPointsPerEntry;
  final num maxBankedPerStudentPerTerm;
  final num maxAddedToMark;

  final String approvalMode;

  final bool allSubjects;
  final List<String> subjectIds;
  final List<num> pointSteps;

  bool get principalApproves => approvalMode == 'PRINCIPAL';

  bool covers(String? subjectId) =>
      allSubjects || (subjectId != null && subjectIds.contains(subjectId));

  factory MarkBankRules.fromJson(Map<String, dynamic> j) => MarkBankRules(
        enabled: j['enabled'] == true,
        maxPointsPerEntry: _points(j['maxPointsPerEntry']),
        maxBankedPerStudentPerTerm: _points(j['maxBankedPerStudentPerTerm']),
        maxAddedToMark: _points(j['maxAddedToMark']),
        approvalMode: (j['approvalMode'] ?? 'TEACHER') as String,
        allSubjects: j['allSubjects'] != false,
        subjectIds: [
          for (final id in (j['subjectIds'] as List? ?? const []))
            if (id is String) id,
        ],
        pointSteps: [
          for (final step in (j['pointSteps'] as List? ?? const []))
            if (step != null) _points(step),
        ],
      );
}

class AwardPreview {
  const AwardPreview({
    required this.kind,
    required this.bankedPoints,
    required this.pointsToAward,
    required this.cappedByMarkLimit,
    required this.cappedByMaxScore,
    required this.needsApproval,
    required this.entryCount,
    this.scoreBefore,
    this.scoreAfter,
    this.refusal,
    this.refusalMessage,
    this.capMessage,
  });

  final String kind;
  final num bankedPoints;
  final num pointsToAward;

  final bool cappedByMarkLimit;
  final bool cappedByMaxScore;
  final bool needsApproval;
  final int entryCount;

  final num? scoreBefore;
  final num? scoreAfter;

  final String? refusal;
  final String? refusalMessage;
  final String? capMessage;

  bool get capped => cappedByMarkLimit || cappedByMaxScore;

  bool get canGo => refusal == null && pointsToAward > 0;

  num get pointsLost => bankedPoints - pointsToAward;

  factory AwardPreview.fromJson(Map<String, dynamic> j) => AwardPreview(
        kind: (j['kind'] ?? 'TERM_MARK') as String,
        bankedPoints: _points(j['bankedPoints']),
        pointsToAward: _points(j['pointsToAward']),
        cappedByMarkLimit: j['cappedByMarkLimit'] == true,
        cappedByMaxScore: j['cappedByMaxScore'] == true,
        needsApproval: j['needsApproval'] == true,
        entryCount: (j['entryCount'] as num?)?.toInt() ?? 0,
        scoreBefore: j['scoreBefore'] == null ? null : _points(j['scoreBefore']),
        scoreAfter: j['scoreAfter'] == null ? null : _points(j['scoreAfter']),
        refusal: j['refusal'] as String?,
        refusalMessage: j['refusalMessage'] as String?,
        capMessage: j['capMessage'] as String?,
      );
}

class MarkBankAward {
  const MarkBankAward({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.kind,
    required this.status,
    required this.points,
    required this.reason,
    required this.entryCount,
    this.subjectName,
    this.termName,
    this.scoreBefore,
    this.scoreAfter,
    this.appliedAt,
    this.decidedAt,
    this.decisionReason,
    this.reversedAt,
    this.reversedReason,
    this.createdAt,
  });

  final String id;
  final String studentId;
  final String studentName;

  final String kind;
  final String status;

  final num points;
  final String reason;
  final int entryCount;

  final String? subjectName;
  final String? termName;

  final num? scoreBefore;
  final num? scoreAfter;

  final DateTime? appliedAt;
  final DateTime? decidedAt;
  final String? decisionReason;
  final DateTime? reversedAt;
  final String? reversedReason;
  final DateTime? createdAt;

  bool get isApplied => status == 'APPLIED';

  bool get isWaiting => status == 'PROPOSED';

  bool get canUndo => status == 'APPLIED' || status == 'PROPOSED';

  factory MarkBankAward.fromJson(Map<String, dynamic> j) => MarkBankAward(
        id: (j['id'] ?? '') as String,
        studentId: (j['studentId'] ?? '') as String,
        studentName: MarkBankEntry._name(j, 'studentName', 'student') ?? '—',
        kind: (j['kind'] ?? 'TERM_MARK') as String,
        status: (j['status'] ?? 'APPLIED') as String,
        points: _points(j['points']),
        reason: (j['reason'] ?? '') as String,
        entryCount: (j['entryCount'] as num?)?.toInt() ?? 0,
        subjectName: MarkBankEntry._name(j, 'subjectName', 'subject'),
        termName: MarkBankEntry._name(j, 'termName', 'term'),
        scoreBefore: j['scoreBefore'] == null ? null : _points(j['scoreBefore']),
        scoreAfter: j['scoreAfter'] == null ? null : _points(j['scoreAfter']),
        appliedAt: DateTime.tryParse((j['appliedAt'] ?? '') as String)?.toLocal(),
        decidedAt: DateTime.tryParse((j['decidedAt'] ?? '') as String)?.toLocal(),
        decisionReason: j['decisionReason'] as String?,
        reversedAt: DateTime.tryParse((j['reversedAt'] ?? '') as String)?.toLocal(),
        reversedReason: j['reversedReason'] as String?,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String)?.toLocal(),
      );
}
