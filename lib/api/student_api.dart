import 'client.dart';
import 'family_payments.dart' show LocalText;

DateTime? _at(Object? value) => value == null ? null : DateTime.tryParse('$value')?.toLocal();

double? _num(Object? value) => (value as num?)?.toDouble();

class OpenSchool {
  OpenSchool({required this.id, required String name, required this.names}) : _name = name;

  final String id;
  final String _name;
  final LocalText names;

  String get displayName => names.pick(_name);

  factory OpenSchool.fromJson(Map<String, dynamic> j) => OpenSchool(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        names: LocalText.fromJson(j['names']),
      );
}

class StudentClass {
  StudentClass({
    required this.id,
    required String name,
    required this.names,
    required this.gradeLevel,
    required this.section,
  }) : _name = name;

  final String id;
  final String _name;
  final LocalText names;
  final int? gradeLevel;
  final String? section;

  String get name => names.pick(_name);

  factory StudentClass.fromJson(Map<String, dynamic> j) => StudentClass(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        names: LocalText.fromJson(j['names']),
        gradeLevel: (j['gradeLevel'] as num?)?.toInt(),
        section: j['section'] as String?,
      );
}

class StudentProfile {
  StudentProfile({
    required this.id,
    required this.code,
    required String name,
    required this.names,
    required this.gender,
    required this.dob,
    required this.photoUrl,
    required this.lastLoginAt,
    required String schoolName,
    required this.schoolNames,
    required this.schoolClass,
  })  : _name = name,
        _schoolName = schoolName;

  final String id;
  final String code;
  final String _name;
  final LocalText names;
  final String? gender;
  final DateTime? dob;
  final String? photoUrl;
  final DateTime? lastLoginAt;
  final String _schoolName;
  final LocalText schoolNames;
  final StudentClass? schoolClass;

  String get name => names.pick(_name);
  String get schoolName => schoolNames.pick(_schoolName);

  factory StudentProfile.fromJson(Map<String, dynamic> j) {
    final school = (j['school'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final klass = (j['schoolClass'] as Map?)?.cast<String, dynamic>();
    return StudentProfile(
      id: (j['id'] ?? '') as String,
      code: (j['code'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      names: LocalText.fromJson(j['names']),
      gender: j['gender'] as String?,
      dob: _at(j['dob']),
      photoUrl: j['photoUrl'] as String?,
      lastLoginAt: _at(j['lastLoginAt']),
      schoolName: (school['name'] ?? '') as String,
      schoolNames: LocalText.fromJson(school['names']),
      schoolClass: klass == null ? null : StudentClass.fromJson(klass),
    );
  }
}

class IdCardToken {
  IdCardToken({required this.token, required this.expiresAt, required this.expiresIn});

  final String token;
  final DateTime? expiresAt;
  final int expiresIn;

  Duration get remaining {
    final at = expiresAt;
    if (at == null) return Duration(seconds: expiresIn);
    final left = at.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  factory IdCardToken.fromJson(Map<String, dynamic> j) => IdCardToken(
        token: (j['token'] ?? '') as String,
        expiresAt: _at(j['expiresAt']),
        expiresIn: (j['expiresIn'] as num?)?.toInt() ?? 120,
      );
}

class Lesson {
  Lesson({
    required this.id,
    required this.weekday,
    required this.period,
    required this.kind,
    required this.room,
    required this.startMinute,
    required this.endMinute,
    required String subject,
    required this.subjectNames,
    required this.subjectColorHex,
    required String? teacherName,
    required this.teacherNames,
  })  : _subject = subject,
        _teacherName = teacherName;

  final String id;
  final String weekday;
  final int period;
  final String? kind;
  final String? room;
  final int? startMinute;
  final int? endMinute;
  final String _subject;
  final LocalText subjectNames;
  final String? subjectColorHex;
  final String? _teacherName;
  final LocalText teacherNames;

  String get subject => subjectNames.pick(_subject);
  String? get teacherName {
    final picked = teacherNames.pick(_teacherName ?? '');
    return picked.isEmpty ? null : picked;
  }

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: (j['id'] ?? '') as String,
        weekday: (j['weekday'] ?? '') as String,
        period: (j['period'] as num?)?.toInt() ?? 0,
        kind: j['kind'] as String?,
        room: j['room'] as String?,
        startMinute: (j['startMinute'] as num?)?.toInt(),
        endMinute: (j['endMinute'] as num?)?.toInt(),
        subject: (j['subject'] ?? '') as String,
        subjectNames: LocalText.fromJson(j['subjectNames']),
        subjectColorHex: j['subjectColorHex'] as String?,
        teacherName: j['teacherName'] as String?,
        teacherNames: LocalText.fromJson(j['teacherNames']),
      );
}

class TodayTimetable {
  TodayTimetable({required this.weekday, required this.slots, required this.nextSlot});

  final String weekday;
  final List<Lesson> slots;
  final Lesson? nextSlot;

  factory TodayTimetable.fromJson(Map<String, dynamic> j) {
    final next = (j['nextSlot'] as Map?)?.cast<String, dynamic>();
    return TodayTimetable(
      weekday: (j['weekday'] ?? '') as String,
      slots: ((j['slots'] as List?) ?? const [])
          .map((s) => Lesson.fromJson((s as Map).cast<String, dynamic>()))
          .toList(),
      nextSlot: next == null ? null : Lesson.fromJson(next),
    );
  }
}

class TimetableDay {
  TimetableDay({required this.weekday, required this.slots});

  final String weekday;
  final List<Lesson> slots;

  factory TimetableDay.fromJson(Map<String, dynamic> j) => TimetableDay(
        weekday: (j['weekday'] ?? '') as String,
        slots: ((j['slots'] as List?) ?? const [])
            .map((s) => Lesson.fromJson((s as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class Homework {
  Homework({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedOn,
    required this.dueDate,
    required this.estimatedMinutes,
    required this.maxScore,
    required String subject,
    required this.subjectNames,
    required this.subjectColorHex,
    required String? teacherName,
    required this.teacherNames,
    required this.submitted,
    required this.score,
    required this.feedback,
  })  : _subject = subject,
        _teacherName = teacherName;

  final String id;
  final String title;
  final String? description;
  final DateTime? assignedOn;
  final DateTime? dueDate;
  final int? estimatedMinutes;
  final double? maxScore;
  final String _subject;
  final LocalText subjectNames;
  final String? subjectColorHex;
  final String? _teacherName;
  final LocalText teacherNames;
  final DateTime? submitted;
  final double? score;
  final String? feedback;

  String get subject => subjectNames.pick(_subject);
  String? get teacherName {
    final picked = teacherNames.pick(_teacherName ?? '');
    return picked.isEmpty ? null : picked;
  }

  int get daysLeft {
    final due = dueDate;
    if (due == null) return 0;
    final today = DateTime.now();
    return DateTime(due.year, due.month, due.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  factory Homework.fromJson(Map<String, dynamic> j) => Homework(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        description: j['description'] as String?,
        assignedOn: _at(j['assignedOn']),
        dueDate: _at(j['dueDate']),
        estimatedMinutes: (j['estimatedMinutes'] as num?)?.toInt(),
        maxScore: _num(j['maxScore']),
        subject: (j['subject'] ?? '') as String,
        subjectNames: LocalText.fromJson(j['subjectNames']),
        subjectColorHex: j['subjectColorHex'] as String?,
        teacherName: j['teacherName'] as String?,
        teacherNames: LocalText.fromJson(j['teacherNames']),
        submitted: _at(j['submitted']),
        score: _num(j['score']),
        feedback: j['feedback'] as String?,
      );
}

class AttendanceDay {
  AttendanceDay({required this.date, required this.status, required this.minutesLate});

  final DateTime? date;
  final String status;
  final int? minutesLate;

  factory AttendanceDay.fromJson(Map<String, dynamic> j) => AttendanceDay(
        date: _at(j['date']),
        status: (j['status'] ?? '') as String,
        minutesLate: (j['minutesLate'] as num?)?.toInt(),
      );
}

class AttendanceSummary {
  AttendanceSummary({
    required String? termName,
    required this.termNames,
    required this.from,
    required this.to,
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
    required this.leftEarly,
    required this.total,
    required this.ratePercent,
    required this.exceptions,
  }) : _termName = termName;

  final String? _termName;
  final LocalText termNames;
  final DateTime? from;
  final DateTime? to;
  final int present;
  final int late;
  final int absent;
  final int excused;
  final int leftEarly;
  final int total;
  final double ratePercent;
  final List<AttendanceDay> exceptions;

  String? get termName {
    final picked = termNames.pick(_termName ?? '');
    return picked.isEmpty ? null : picked;
  }

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) => AttendanceSummary(
        termName: j['termName'] as String?,
        termNames: LocalText.fromJson(j['termNames']),
        from: _at(j['from']),
        to: _at(j['to']),
        present: (j['present'] as num?)?.toInt() ?? 0,
        late: (j['late'] as num?)?.toInt() ?? 0,
        absent: (j['absent'] as num?)?.toInt() ?? 0,
        excused: (j['excused'] as num?)?.toInt() ?? 0,
        leftEarly: (j['leftEarly'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        ratePercent: _num(j['ratePercent']) ?? 0,
        exceptions: ((j['exceptions'] as List?) ?? const [])
            .map((e) => AttendanceDay.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class Mark {
  Mark({
    required this.id,
    required this.score,
    required this.maxScore,
    required this.percent,
    required this.gradeLetter,
    required this.isPass,
    required this.wasAbsent,
    required this.wasExempt,
    required this.remark,
    required this.examKind,
    required this.examTitle,
    required this.examDate,
    required String subject,
    required this.subjectNames,
    required this.subjectColorHex,
  }) : _subject = subject;

  final String id;
  final double? score;
  final double maxScore;
  final double? percent;
  final String? gradeLetter;
  final bool? isPass;
  final bool wasAbsent;
  final bool wasExempt;
  final String? remark;
  final String? examKind;
  final String examTitle;
  final DateTime? examDate;
  final String _subject;
  final LocalText subjectNames;
  final String? subjectColorHex;

  String get subject => subjectNames.pick(_subject);

  factory Mark.fromJson(Map<String, dynamic> j) {
    final exam = (j['exam'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return Mark(
      id: (j['id'] ?? '') as String,
      score: _num(j['score']),
      maxScore: _num(j['maxScore']) ?? 0,
      percent: _num(j['percent']),
      gradeLetter: j['gradeLetter'] as String?,
      isPass: j['isPass'] as bool?,
      wasAbsent: (j['wasAbsent'] ?? false) as bool,
      wasExempt: (j['wasExempt'] ?? false) as bool,
      remark: j['remark'] as String?,
      examKind: exam['kind'] as String?,
      examTitle: (exam['title'] ?? '') as String,
      examDate: _at(exam['date']),
      subject: (exam['subject'] ?? '') as String,
      subjectNames: LocalText.fromJson(exam['subjectNames']),
      subjectColorHex: exam['subjectColorHex'] as String?,
    );
  }
}

class StudentNotice {
  StudentNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.priority,
    required this.sentAt,
    required this.pinned,
    required String authorName,
    required this.authorNames,
    required this.attachmentCount,
  }) : _authorName = authorName;

  final String id;
  final String title;
  final String body;
  final String? category;
  final String? priority;
  final DateTime? sentAt;
  final bool pinned;
  final String _authorName;
  final LocalText authorNames;
  final int attachmentCount;

  String get authorName => authorNames.pick(_authorName);

  factory StudentNotice.fromJson(Map<String, dynamic> j) => StudentNotice(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        category: j['category'] as String?,
        priority: j['priority'] as String?,
        sentAt: _at(j['sentAt']),
        pinned: (j['pinned'] ?? false) as bool,
        authorName: (j['authorName'] ?? '') as String,
        authorNames: LocalText.fromJson(j['authorNames']),
        attachmentCount: (j['attachmentCount'] as num?)?.toInt() ?? 0,
      );
}

class StudentApi {
  StudentApi._();

  static final StudentApi instance = StudentApi._();

  final ApiClient _api = ApiClient.instance;

  Future<List<OpenSchool>> openSchools() async {
    final body = await _api.get('/auth/schools') as List;
    return body
        .map((s) => OpenSchool.fromJson((s as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<StudentProfile> me() async =>
      StudentProfile.fromJson(await _api.get('/student/me') as Map<String, dynamic>);

  Future<IdCardToken> idCard() async =>
      IdCardToken.fromJson(await _api.get('/student/id-card') as Map<String, dynamic>);

  Future<TodayTimetable> today() async =>
      TodayTimetable.fromJson(await _api.get('/student/timetable/today') as Map<String, dynamic>);

  Future<List<TimetableDay>> week() async {
    final body = await _api.get('/student/timetable/week') as Map<String, dynamic>;
    return ((body['days'] as List?) ?? const [])
        .map((d) => TimetableDay.fromJson((d as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<Paged<Homework>> homework({bool includeDone = false, int pageSize = 20}) async {
    final body = await _api.get(
      '/student/homework?includeDone=$includeDone&pageSize=$pageSize',
    );
    return Paged.from(body, Homework.fromJson);
  }

  Future<AttendanceSummary> attendance() async =>
      AttendanceSummary.fromJson(await _api.get('/student/attendance') as Map<String, dynamic>);

  Future<List<Mark>> marks() async {
    final body = await _api.get('/student/marks') as List;
    return body
        .map((m) => Mark.fromJson((m as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<Paged<StudentNotice>> announcements({int pageSize = 20}) async {
    final body = await _api.get('/student/announcements?pageSize=$pageSize');
    return Paged.from(body, StudentNotice.fromJson);
  }
}
