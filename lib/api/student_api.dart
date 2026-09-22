import 'dart:typed_data';

import 'attachments.dart';
import 'awards.dart';
import 'client.dart';
import 'family_payments.dart' show LocalText;
import 'hand_in_file.dart';

export 'awards.dart' show AwardsWall, Certificate;
export 'hand_in_file.dart' show HandInFile;

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

class StudentFeatures {
  const StudentFeatures({
    required this.housePoints,
    required this.homeworkHandIn,
    required this.idCard,
    required this.nextClass,
    required this.awards,
    required this.examPlanner,
  });

  static const all = StudentFeatures(
    housePoints: true,
    homeworkHandIn: true,
    idCard: true,
    nextClass: true,
    awards: true,
    examPlanner: true,
  );

  final bool housePoints;
  final bool homeworkHandIn;
  final bool idCard;
  final bool nextClass;
  final bool awards;
  final bool examPlanner;

  factory StudentFeatures.fromJson(Object? raw) {
    if (raw is! Map) return all;
    bool on(String key) => raw[key] != false;
    return StudentFeatures(
      housePoints: on('housePoints'),
      homeworkHandIn: on('homeworkHandIn'),
      idCard: on('idCard'),
      nextClass: on('nextClass'),
      awards: on('awards'),
      examPlanner: on('examPlanner'),
    );
  }
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
    required this.features,
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
  final StudentFeatures features;

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
      features: StudentFeatures.fromJson(j['features']),
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
    required this.inProgress,
    required this.minutesUntilStart,
    required this.minutesLeft,
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
  final bool inProgress;
  final int? minutesUntilStart;
  final int? minutesLeft;

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
        inProgress: (j['inProgress'] ?? false) as bool,
        minutesUntilStart: (j['minutesUntilStart'] as num?)?.toInt(),
        minutesLeft: (j['minutesLeft'] as num?)?.toInt(),
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
    required this.handInOpen,
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
  final bool handInOpen;

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
        handInOpen: (j['allowSubmission'] ?? false) as bool,
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

class HouseStanding {
  HouseStanding({
    required this.id,
    required String name,
    required this.names,
    required String? motto,
    required this.mottoNames,
    required this.colorHex,
    required this.termPoints,
  })  : _name = name,
        _motto = motto;

  final String id;
  final String _name;
  final LocalText names;
  final String? _motto;
  final LocalText mottoNames;
  final String? colorHex;
  final double termPoints;

  String get name => names.pick(_name);
  String? get motto {
    final picked = mottoNames.pick(_motto ?? '');
    return picked.isEmpty ? null : picked;
  }

  factory HouseStanding.fromJson(Map<String, dynamic> j) => HouseStanding(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        names: LocalText.fromJson(j['names']),
        motto: j['motto'] as String?,
        mottoNames: LocalText.fromJson(j['mottoNames']),
        colorHex: j['colorHex'] as String?,
        termPoints: _num(j['termPoints']) ?? 0,
      );
}

class PointsWindow {
  PointsWindow({
    required this.from,
    required this.to,
    required String? termName,
    required this.termNames,
    required this.meritPoints,
    required this.bankedPoints,
    required this.total,
  }) : _termName = termName;

  final DateTime? from;
  final DateTime? to;
  final String? _termName;
  final LocalText termNames;
  final double meritPoints;
  final double bankedPoints;
  final double total;

  String? get termName {
    final picked = termNames.pick(_termName ?? '');
    return picked.isEmpty ? null : picked;
  }

  factory PointsWindow.fromJson(Map<String, dynamic> j) => PointsWindow(
        from: _at(j['from']),
        to: _at(j['to']),
        termName: j['termName'] as String?,
        termNames: LocalText.fromJson(j['termNames']),
        meritPoints: _num(j['meritPoints']) ?? 0,
        bankedPoints: _num(j['bankedPoints']) ?? 0,
        total: _num(j['total']) ?? 0,
      );
}

class MyPoints {
  MyPoints({
    required this.house,
    required this.week,
    required this.term,
    required this.attendanceStreak,
    required this.attendanceSince,
    required this.homeworkStreak,
    required this.homeworkSince,
  });

  final HouseStanding? house;
  final PointsWindow week;
  final PointsWindow term;
  final int attendanceStreak;
  final DateTime? attendanceSince;
  final int homeworkStreak;
  final DateTime? homeworkSince;

  factory MyPoints.fromJson(Map<String, dynamic> j) {
    final house = (j['house'] as Map?)?.cast<String, dynamic>();
    final attendance = (j['attendanceStreak'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final homework = (j['homeworkStreak'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return MyPoints(
      house: house == null ? null : HouseStanding.fromJson(house),
      week: PointsWindow.fromJson((j['week'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      term: PointsWindow.fromJson((j['term'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      attendanceStreak: (attendance['days'] as num?)?.toInt() ?? 0,
      attendanceSince: _at(attendance['since']),
      homeworkStreak: (homework['count'] as num?)?.toInt() ?? 0,
      homeworkSince: _at(homework['since']),
    );
  }
}

class DueToday {
  DueToday({
    required this.id,
    required this.title,
    required String subject,
    required this.subjectNames,
    required this.subjectColorHex,
    required this.handInOpen,
    required this.handedIn,
  }) : _subject = subject;

  final String id;
  final String title;
  final String _subject;
  final LocalText subjectNames;
  final String? subjectColorHex;
  final bool handInOpen;
  final DateTime? handedIn;

  String get subject => subjectNames.pick(_subject);

  factory DueToday.fromJson(Map<String, dynamic> j) => DueToday(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        subject: (j['subject'] ?? '') as String,
        subjectNames: LocalText.fromJson(j['subjectNames']),
        subjectColorHex: j['subjectColorHex'] as String?,
        handInOpen: (j['handInOpen'] ?? false) as bool,
        handedIn: _at(j['handedIn']),
      );
}

class ComingExam {
  ComingExam({
    required this.id,
    required this.kind,
    required this.title,
    required this.date,
    required this.startMinute,
    required this.durationMin,
    required this.room,
    required this.maxScore,
    required this.daysLeft,
    required this.subjectId,
    required String subject,
    required this.subjectNames,
    required this.subjectColorHex,
    required this.sessionsPlanned,
    required this.sessionsDone,
  }) : _subject = subject;

  final String id;
  final String? kind;
  final String title;
  final DateTime? date;
  final int? startMinute;
  final int? durationMin;
  final String? room;
  final double? maxScore;
  final int daysLeft;
  final String? subjectId;
  final String _subject;
  final LocalText subjectNames;
  final String? subjectColorHex;
  final int sessionsPlanned;
  final int sessionsDone;

  String get subject => subjectNames.pick(_subject);

  factory ComingExam.fromJson(Map<String, dynamic> j) => ComingExam(
        id: (j['id'] ?? '') as String,
        kind: j['kind'] as String?,
        title: (j['title'] ?? '') as String,
        date: _at(j['date']),
        startMinute: (j['startMinute'] as num?)?.toInt(),
        durationMin: (j['durationMin'] as num?)?.toInt(),
        room: j['room'] as String?,
        maxScore: _num(j['maxScore']),
        daysLeft: (j['daysLeft'] as num?)?.toInt() ?? 0,
        subjectId: j['subjectId'] as String?,
        subject: (j['subject'] ?? '') as String,
        subjectNames: LocalText.fromJson(j['subjectNames']),
        subjectColorHex: j['subjectColorHex'] as String?,
        sessionsPlanned: (j['sessionsPlanned'] as num?)?.toInt() ?? 0,
        sessionsDone: (j['sessionsDone'] as num?)?.toInt() ?? 0,
      );
}

class TodayGlance {
  TodayGlance({
    required this.weekday,
    required this.minuteOfDay,
    required this.nextClass,
    required this.classesLeft,
    required this.classesToday,
    required this.dueToday,
    required this.nextExam,
    required this.attendanceStatus,
    required this.minutesLate,
  });

  final String weekday;
  final int minuteOfDay;
  final Lesson? nextClass;
  final int classesLeft;
  final int classesToday;
  final List<DueToday> dueToday;
  final ComingExam? nextExam;
  final String? attendanceStatus;
  final int? minutesLate;

  factory TodayGlance.fromJson(Map<String, dynamic> j) {
    final next = (j['nextClass'] as Map?)?.cast<String, dynamic>();
    final exam = (j['nextExam'] as Map?)?.cast<String, dynamic>();
    final marked = (j['attendanceToday'] as Map?)?.cast<String, dynamic>();
    return TodayGlance(
      weekday: (j['weekday'] ?? '') as String,
      minuteOfDay: (j['minuteOfDay'] as num?)?.toInt() ?? 0,
      nextClass: next == null ? null : Lesson.fromJson(next),
      classesLeft: (j['classesLeft'] as num?)?.toInt() ?? 0,
      classesToday: (j['classesToday'] as num?)?.toInt() ?? 0,
      dueToday: ((j['homeworkDueToday'] as List?) ?? const [])
          .map((h) => DueToday.fromJson((h as Map).cast<String, dynamic>()))
          .toList(growable: false),
      nextExam: exam == null ? null : ComingExam.fromJson(exam),
      attendanceStatus: marked?['status'] as String?,
      minutesLate: (marked?['minutesLate'] as num?)?.toInt(),
    );
  }
}

class RevisionSession {
  RevisionSession({
    required this.id,
    required this.plannedFor,
    required this.minutes,
    required this.note,
    required this.done,
    required this.subjectId,
    required String? subject,
    required this.subjectNames,
    required this.subjectColorHex,
    required this.examId,
    required this.examDate,
  }) : _subject = subject;

  final String id;
  final DateTime? plannedFor;
  final int? minutes;
  final String? note;
  final bool done;
  final String? subjectId;
  final String? _subject;
  final LocalText subjectNames;
  final String? subjectColorHex;
  final String? examId;
  final DateTime? examDate;

  String? get subject {
    final picked = subjectNames.pick(_subject ?? '');
    return picked.isEmpty ? null : picked;
  }

  factory RevisionSession.fromJson(Map<String, dynamic> j) => RevisionSession(
        id: (j['id'] ?? '') as String,
        plannedFor: _at(j['plannedFor']),
        minutes: (j['minutes'] as num?)?.toInt(),
        note: j['note'] as String?,
        done: (j['done'] ?? false) as bool,
        subjectId: j['subjectId'] as String?,
        subject: j['subject'] as String?,
        subjectNames: LocalText.fromJson(j['subjectNames']),
        subjectColorHex: j['subjectColorHex'] as String?,
        examId: j['examId'] as String?,
        examDate: _at(j['examDate']),
      );
}

class RevisionPlan {
  RevisionPlan({required this.rows, required this.done, required this.minutesDone});

  final List<RevisionSession> rows;
  final int done;
  final int minutesDone;

  factory RevisionPlan.fromJson(Map<String, dynamic> j) => RevisionPlan(
        rows: ((j['rows'] as List?) ?? const [])
            .map((s) => RevisionSession.fromJson((s as Map).cast<String, dynamic>()))
            .toList(growable: false),
        done: (j['done'] as num?)?.toInt() ?? 0,
        minutesDone: (j['minutesDone'] as num?)?.toInt() ?? 0,
      );
}

class ExamPlanner {
  ExamPlanner({required this.exams, required this.plan});

  final List<ComingExam> exams;
  final RevisionPlan plan;
}

class HandInSubmission {
  HandInSubmission({
    required this.id,
    required this.status,
    required this.submittedAt,
    required this.text,
    required this.score,
    required this.feedback,
    required this.gradedAt,
    required this.files,
  });

  final String id;
  final String status;
  final DateTime? submittedAt;
  final String? text;
  final double? score;
  final String? feedback;
  final DateTime? gradedAt;
  final List<HandInFile> files;

  bool get marked => gradedAt != null;

  factory HandInSubmission.fromJson(Map<String, dynamic> j) => HandInSubmission(
        id: (j['id'] ?? '') as String,
        status: (j['status'] ?? 'NOT_SUBMITTED') as String,
        submittedAt: _at(j['submittedAt']),
        text: j['text'] as String?,
        score: _num(j['score']),
        feedback: j['feedback'] as String?,
        gradedAt: _at(j['gradedAt']),
        files: ((j['files'] as List?) ?? const [])
            .map((f) => HandInFile.fromJson((f as Map).cast<String, dynamic>()))
            .toList(growable: false),
      );
}

class HandInWork {
  HandInWork({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.maxScore,
    required this.handInOpen,
    required this.maxFiles,
    required String subject,
    required this.subjectNames,
    required this.subjectColorHex,
  }) : _subject = subject;

  final String id;
  final String title;
  final DateTime? dueDate;
  final double? maxScore;
  final bool handInOpen;
  final int maxFiles;
  final String _subject;
  final LocalText subjectNames;
  final String? subjectColorHex;

  String get subject => subjectNames.pick(_subject);

  factory HandInWork.fromJson(Map<String, dynamic> j) => HandInWork(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        dueDate: _at(j['dueDate']),
        maxScore: _num(j['maxScore']),
        handInOpen: (j['handInOpen'] ?? false) as bool,
        maxFiles: (j['maxFiles'] as num?)?.toInt() ?? 5,
        subject: (j['subject'] ?? '') as String,
        subjectNames: LocalText.fromJson(j['subjectNames']),
        subjectColorHex: j['subjectColorHex'] as String?,
      );
}

class HandIn {
  HandIn({required this.homework, required this.submission});

  final HandInWork homework;
  final HandInSubmission? submission;

  factory HandIn.fromJson(Map<String, dynamic> j) {
    final submission = (j['submission'] as Map?)?.cast<String, dynamic>();
    return HandIn(
      homework: HandInWork.fromJson(
        (j['homework'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
      submission: submission == null ? null : HandInSubmission.fromJson(submission),
    );
  }
}

class MySchool {
  MySchool({
    required this.studentId,
    required this.tenantId,
    required this.schoolName,
    required this.schoolNames,
    required this.from,
    required this.to,
    required this.stillEnrolled,
    required this.current,
  });

  final String studentId;
  final String tenantId;
  final String schoolName;
  final LocalText schoolNames;
  final String? from;
  final String? to;
  final bool stillEnrolled;
  final bool current;

  factory MySchool.fromJson(Map<String, dynamic> j) => MySchool(
        studentId: (j['studentId'] ?? '') as String,
        tenantId: (j['tenantId'] ?? '') as String,
        schoolName: (j['schoolName'] ?? '') as String,
        schoolNames: LocalText.fromJson(j['schoolNames']),
        from: j['from'] as String?,
        to: j['to'] as String?,
        stillEnrolled: (j['stillEnrolled'] ?? false) as bool,
        current: (j['current'] ?? false) as bool,
      );
}

class OpenedSchool {
  OpenedSchool({
    required this.accessToken,
    required this.refreshToken,
    required this.studentId,
    required this.tenantId,
    required this.readOnly,
  });

  final String accessToken;
  final String? refreshToken;
  final String studentId;
  final String tenantId;
  final bool readOnly;

  factory OpenedSchool.fromJson(Map<String, dynamic> j) => OpenedSchool(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String?,
        studentId: (j['studentId'] ?? '') as String,
        tenantId: (j['tenantId'] ?? '') as String,
        readOnly: (j['readOnly'] ?? false) as bool,
      );
}

class StudentApi {
  StudentApi._();

  static final StudentApi instance = StudentApi._();

  final ApiClient _api = ApiClient.instance;

  Future<List<MySchool>> mySchools() async {
    final body = await _api.get('/me/schools') as Map<String, dynamic>;
    return ((body['schools'] as List?) ?? const [])
        .map((s) => MySchool.fromJson((s as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<OpenedSchool> openSchool(String studentId) async =>
      OpenedSchool.fromJson(
        await _api.post('/me/schools/$studentId/open') as Map<String, dynamic>,
      );

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

  Future<MyPoints> points() async =>
      MyPoints.fromJson(await _api.get('/student/points') as Map<String, dynamic>);

  Future<TodayGlance> glance() async =>
      TodayGlance.fromJson(await _api.get('/student/today') as Map<String, dynamic>);

  Future<AwardsWall> awards() async =>
      AwardsWall.fromJson(await _api.get('/student/awards') as Map<String, dynamic>);

  Future<List<ComingExam>> examsAhead() async {
    final body = await _api.get('/student/exams/ahead') as Map<String, dynamic>;
    return ((body['rows'] as List?) ?? const [])
        .map((e) => ComingExam.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<RevisionPlan> revision({DateTime? from, DateTime? to}) async {
    final query = <String>[
      if (from != null) 'from=${_dayKey(from)}',
      if (to != null) 'to=${_dayKey(to)}',
    ];
    final path = '/student/revision${query.isEmpty ? '' : '?${query.join('&')}'}';
    return RevisionPlan.fromJson(await _api.get(path) as Map<String, dynamic>);
  }

  Future<ExamPlanner> planner({DateTime? from}) async {
    final both = await Future.wait([examsAhead(), revision(from: from)]);
    return ExamPlanner(exams: both[0] as List<ComingExam>, plan: both[1] as RevisionPlan);
  }

  Future<RevisionSession> planRevision({
    required DateTime plannedFor,
    String? subjectId,
    String? examId,
    int? minutes,
    String? note,
  }) async {
    final body = await _api.post('/student/revision', {
      'plannedFor': _dayKey(plannedFor),
      'subjectId': ?subjectId,
      'examId': ?examId,
      'minutes': ?minutes,
      'note': ?note,
    });
    return RevisionSession.fromJson(body as Map<String, dynamic>);
  }

  Future<RevisionSession> changeRevision(
    String sessionId, {
    DateTime? plannedFor,
    int? minutes,
    String? note,
    bool? done,
  }) async {
    final changes = <String, Object>{'minutes': ?minutes, 'note': ?note, 'done': ?done};
    if (plannedFor != null) changes['plannedFor'] = _dayKey(plannedFor);
    final body = await _api.patch('/student/revision/$sessionId', changes);
    return RevisionSession.fromJson(body as Map<String, dynamic>);
  }

  Future<void> removeRevision(String sessionId) async {
    await _api.delete('/student/revision/$sessionId');
  }

  Future<HandIn> handIn(String homeworkId) async => HandIn.fromJson(
        await _api.get('/student/homework/$homeworkId/hand-in') as Map<String, dynamic>,
      );

  Future<HandInSubmission> sendHandIn(String homeworkId, String text) async {
    final body = await _api.post('/student/homework/$homeworkId/hand-in', {'text': text});
    return HandInSubmission.fromJson(body as Map<String, dynamic>);
  }

  Future<HandInSubmission> addHandInFile(
    String homeworkId, {
    required Uint8List bytes,
    required String filename,
    required String mime,
  }) async {
    final body = await _api.upload(
      '/student/homework/$homeworkId/hand-in/files',
      field: 'file',
      bytes: bytes,
      filename: filename,
      mime: mime,
    );
    return HandInSubmission.fromJson(body as Map<String, dynamic>);
  }

  Future<HandInSubmission> removeHandInFile(String homeworkId, String attachmentId) async {
    final body = await _api.delete('/student/homework/$homeworkId/hand-in/files/$attachmentId');
    return HandInSubmission.fromJson(body as Map<String, dynamic>);
  }

  Future<AttachedFile> openHandInFile(String homeworkId, String assetId) async {
    final j = await _api.get('/student/homework/$homeworkId/hand-in/files/$assetId')
        as Map<String, dynamic>;
    return AttachedFile(
      id: (j['id'] ?? assetId) as String,
      caption: null,
      url: j['url'] as String?,
      thumbnailUrl: null,
      kind: 'OTHER',
      mime: j['mime'] as String?,
      bytes: (j['bytes'] as num?)?.toInt(),
      filename: j['originalFilename'] as String?,
    );
  }
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
