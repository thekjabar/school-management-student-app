import 'dart:typed_data';

import '../i18n/strings.dart';
import 'attachments.dart';
import 'client.dart';

class Child {
  Child({
    required this.studentId,
    required this.code,
    required this.name,
    required this.gradeLevel,
    required this.className,
    required this.classId,
    required this.relationship,
    required this.isPrimary,
  });

  final String studentId;
  final String code;
  final String name;
  final int gradeLevel;
  final String className;
  final String? classId;
  final String relationship;
  final bool isPrimary;

  factory Child.fromJson(Map<String, dynamic> j) => Child(
        studentId: j['studentId'] as String,
        code: (j['code'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        gradeLevel: (j['gradeLevel'] as num?)?.toInt() ?? 0,
        className: (j['className'] ?? '') as String,
        classId: j['classId'] as String?,
        relationship: (j['relationship'] ?? '') as String,
        isPrimary: (j['isPrimary'] ?? false) as bool,
      );
}

class ChildProfile {
  ChildProfile({
    required this.studentId,
    required this.code,
    required this.name,
    required this.fullName,
    required this.nickname,
    required this.gender,
    required this.dob,
    required this.ageYears,
    required this.nationality,
    required this.photoUrl,
    required this.className,
    required this.gradeLevel,
    required this.gradeLabel,
    required this.section,
    required this.room,
    required this.shift,
    required this.homeroomTeacher,
    required this.campusName,
    required this.campusAddress,
    required this.academicYear,
    required this.rollNo,
    required this.enrolledAt,
    required this.guardians,
    required this.medical,
    required this.support,
  });

  final String studentId;
  final String code;
  final String name;
  final String fullName;
  final String? nickname;
  final String? gender;
  final DateTime? dob;
  final int? ageYears;
  final String? nationality;
  final String? photoUrl;

  final String? className;
  final int? gradeLevel;
  final String? gradeLabel;
  final String? section;
  final String? room;
  final String? shift;
  final String? homeroomTeacher;

  final String? campusName;
  final String? campusAddress;
  final String? academicYear;
  final String? rollNo;
  final DateTime? enrolledAt;

  final List<GuardianOnAccount> guardians;
  final MedicalSummary? medical;
  final SupportSummary? support;

  factory ChildProfile.fromJson(Map<String, dynamic> j) => ChildProfile(
        studentId: j['studentId'] as String,
        code: (j['code'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        fullName: (j['fullName'] ?? j['name'] ?? '') as String,
        nickname: j['nickname'] as String?,
        gender: j['gender'] as String?,
        dob: _date(j['dob']),
        ageYears: (j['ageYears'] as num?)?.toInt(),
        nationality: j['nationality'] as String?,
        photoUrl: j['photoUrl'] as String?,
        className: j['className'] as String?,
        gradeLevel: (j['gradeLevel'] as num?)?.toInt(),
        gradeLabel: j['gradeLabel'] as String?,
        section: j['section'] as String?,
        room: j['room'] as String?,
        shift: j['shift'] as String?,
        homeroomTeacher: j['homeroomTeacher'] as String?,
        campusName: j['campusName'] as String?,
        campusAddress: j['campusAddress'] as String?,
        academicYear: j['academicYear'] as String?,
        rollNo: j['rollNo'] as String?,
        enrolledAt: _date(j['enrolledAt']),
        guardians: ((j['guardians'] as List?) ?? const [])
            .map((e) => GuardianOnAccount.fromJson(e as Map<String, dynamic>))
            .toList(),
        medical: j['medical'] == null
            ? null
            : MedicalSummary.fromJson(j['medical'] as Map<String, dynamic>),
        support: j['support'] == null
            ? null
            : SupportSummary.fromJson(j['support'] as Map<String, dynamic>),
      );

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;
}

class GuardianOnAccount {
  GuardianOnAccount({
    required this.name,
    required this.relationship,
    required this.isPrimary,
    required this.isYou,
  });

  final String name;
  final String relationship;
  final bool isPrimary;

  final bool isYou;

  factory GuardianOnAccount.fromJson(Map<String, dynamic> j) => GuardianOnAccount(
        name: (j['name'] ?? '') as String,
        relationship: (j['relationship'] ?? '') as String,
        isPrimary: (j['isPrimary'] ?? false) as bool,
        isYou: (j['isYou'] ?? false) as bool,
      );
}

class MedicalSummary {
  MedicalSummary({
    required this.flags,
    required this.actionText,
    required this.carriesMedication,
    required this.medicationLocation,
    required this.emergencyContacts,
    required this.reviewDueAt,
  });

  final List<String> flags;
  final String? actionText;
  final bool carriesMedication;
  final String? medicationLocation;
  final List<String> emergencyContacts;
  final DateTime? reviewDueAt;

  bool get needsReview =>
      reviewDueAt != null && reviewDueAt!.isBefore(DateTime.now());

  bool get isEmpty =>
      flags.isEmpty &&
      (actionText == null || actionText!.trim().isEmpty) &&
      !carriesMedication &&
      emergencyContacts.isEmpty;

  factory MedicalSummary.fromJson(Map<String, dynamic> j) => MedicalSummary(
        flags: ((j['flags'] as List?) ?? const []).map((e) => '$e').toList(),
        actionText: j['actionText'] as String?,
        carriesMedication: (j['carriesMedication'] ?? false) as bool,
        medicationLocation: j['medicationLocation'] as String?,
        emergencyContacts:
            ((j['emergencyContacts'] as List?) ?? const []).map((e) => '$e').toList(),
        reviewDueAt: ChildProfile._date(j['reviewDueAt']),
      );
}

class SupportSummary {
  SupportSummary({
    required this.escortRequired,
    required this.wheelchairVehicleRequired,
    required this.fixedSeat,
    required this.doNotReleaseAlone,
  });

  final bool escortRequired;
  final bool wheelchairVehicleRequired;

  final Object? fixedSeat;
  final bool doNotReleaseAlone;

  bool get isEmpty =>
      !escortRequired &&
      !wheelchairVehicleRequired &&
      fixedSeat == null &&
      !doNotReleaseAlone;

  factory SupportSummary.fromJson(Map<String, dynamic> j) => SupportSummary(
        escortRequired: (j['escortRequired'] ?? false) as bool,
        wheelchairVehicleRequired: (j['wheelchairVehicleRequired'] ?? false) as bool,
        fixedSeat: j['fixedSeat'],
        doNotReleaseAlone: (j['doNotReleaseAlone'] ?? false) as bool,
      );
}

class RecentCrew {
  RecentCrew({
    required this.personId,
    required this.name,
    required this.role,
    required this.lastRodeOn,
  });

  final String personId;
  final String name;

  final String role;

  final DateTime? lastRodeOn;

  factory RecentCrew.fromJson(Map<String, dynamic> j) => RecentCrew(
        personId: j['personId'] as String,
        name: (j['name'] ?? '') as String,
        role: (j['role'] ?? '') as String,
        lastRodeOn: DateTime.tryParse((j['lastRodeOn'] ?? '') as String),
      );
}

class CrewFeedbackItem {
  CrewFeedbackItem({
    required this.id,
    required this.sentiment,
    required this.topics,
    required this.comment,
    required this.occurredOn,
    required this.direction,
    required this.status,
    required this.submittedAt,
    required this.crewName,
  });

  final String id;

  final String sentiment;
  final List<String> topics;
  final String? comment;
  final DateTime? occurredOn;

  final String direction;

  final String status;
  final DateTime? submittedAt;
  final String? crewName;

  bool get isPraise => sentiment == 'PRAISE';

  bool get isClosed =>
      status == 'RESOLVED' || status == 'CLOSED_NO_ACTION' || status == 'ESCALATED';

  factory CrewFeedbackItem.fromJson(Map<String, dynamic> j) => CrewFeedbackItem(
        id: j['id'] as String,
        sentiment: (j['sentiment'] ?? 'CONCERN') as String,
        topics: ((j['topics'] as List?) ?? const []).map((e) => '$e').toList(),
        comment: j['comment'] as String?,
        occurredOn: DateTime.tryParse((j['occurredOn'] ?? '') as String),
        direction: (j['direction'] ?? 'UNSPECIFIED') as String,
        status: (j['status'] ?? 'NEW') as String,
        submittedAt: DateTime.tryParse((j['submittedAt'] ?? '') as String)?.toLocal(),
        crewName: j['crewName'] as String?,
      );
}

class MemoryAlbum {
  MemoryAlbum({
    required this.id,
    required this.title,
    required this.description,
    required this.happenedOn,
    required this.campusName,
    required this.items,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime? happenedOn;
  final String? campusName;
  final List<MemoryItem> items;

  factory MemoryAlbum.fromJson(Map<String, dynamic> j) => MemoryAlbum(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        description: j['description'] as String?,
        happenedOn: DateTime.tryParse((j['happenedOn'] ?? '') as String),
        campusName: j['campusName'] as String?,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => MemoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MemoryItem {
  MemoryItem({
    required this.id,
    required this.caption,
    required this.isVideo,
    required this.url,
    required this.thumbnailUrl,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.takenAt,
  });

  final String id;
  final String? caption;
  final bool isVideo;
  final String? url;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int? durationMs;
  final DateTime? takenAt;

  double get aspect =>
      (width != null && height != null && height! > 0) ? width! / height! : 1;

  factory MemoryItem.fromJson(Map<String, dynamic> j) => MemoryItem(
        id: j['id'] as String,
        caption: j['caption'] as String?,
        isVideo: (j['isVideo'] ?? false) as bool,
        url: j['url'] as String?,
        thumbnailUrl: (j['thumbnailUrl'] ?? j['url']) as String?,
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
        durationMs: (j['durationMs'] as num?)?.toInt(),
        takenAt: DateTime.tryParse((j['takenAt'] ?? '') as String)?.toLocal(),
      );
}

class HomeLocation {
  HomeLocation({
    required this.address,
    required this.note,
    required this.lat,
    required this.lon,
    required this.children,
  });

  final String? address;
  final String? note;
  final double? lat;
  final double? lon;

  final List<AssignedStops> children;

  bool get hasPin => lat != null && lon != null;

  factory HomeLocation.fromJson(Map<String, dynamic> j) => HomeLocation(
        address: j['address'] as String?,
        note: j['note'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        children: ((j['children'] as List?) ?? const [])
            .map((e) => AssignedStops.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AssignedStops {
  AssignedStops({
    required this.studentId,
    required this.name,
    required this.pickup,
    required this.dropoff,
  });

  final String studentId;
  final String name;
  final StopPoint? pickup;
  final StopPoint? dropoff;

  factory AssignedStops.fromJson(Map<String, dynamic> j) => AssignedStops(
        studentId: (j['studentId'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        pickup: j['pickup'] == null
            ? null
            : StopPoint.fromJson(j['pickup'] as Map<String, dynamic>),
        dropoff: j['dropoff'] == null
            ? null
            : StopPoint.fromJson(j['dropoff'] as Map<String, dynamic>),
      );
}

class StopPoint {
  StopPoint({required this.name, required this.lat, required this.lon, required this.landmark});

  final String name;
  final double? lat;
  final double? lon;
  final String? landmark;

  factory StopPoint.fromJson(Map<String, dynamic> j) => StopPoint(
        name: (j['name'] ?? '') as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        landmark: j['landmark'] as String?,
      );
}

class Lesson {
  Lesson({
    required this.period,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.startMinute,
    required this.endMinute,
    required this.colorHex,
    required this.kind,
  });

  final int period;
  final String subject;
  final String? teacher;
  final String? room;
  final int? startMinute;
  final int? endMinute;
  final String? colorHex;
  final String kind;

  factory Lesson.fromJson(Map<String, dynamic> j) {
    return Lesson(
      period: (j['period'] as num?)?.toInt() ?? 0,
      subject: _subjectOf(j, fallback: j['kind'] as String?),
      colorHex: _colorOf(j),
      teacher: j['teacherName'] as String?,
      room: j['room'] as String?,
      startMinute: (j['startMinute'] as num?)?.toInt(),
      endMinute: (j['endMinute'] as num?)?.toInt(),
      kind: (j['kind'] ?? 'LESSON') as String,
    );
  }
}

class DayOfLessons {
  DayOfLessons({required this.weekday, required this.lessons});

  final String weekday;
  final List<Lesson> lessons;

  factory DayOfLessons.fromJson(Map<String, dynamic> j) => DayOfLessons(
        weekday: j['weekday'] as String,
        lessons: ((j['slots'] as List?) ?? [])
            .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AttitudeNote {
  AttitudeNote({
    required this.id,
    required this.kind,
    required this.category,
    required this.points,
    required this.note,
    required this.occurredAt,
    required this.acknowledgedAt,
    required this.className,
    required this.recordedByName,
  });

  final String id;

  final String kind;
  final String category;
  final int points;
  final String? note;
  final DateTime occurredAt;
  final DateTime? acknowledgedAt;
  final String? className;
  final String? recordedByName;

  bool get isMerit => kind == 'MERIT';
  bool get isConcern => kind == 'CONCERN' || kind == 'INCIDENT';
  bool get seen => acknowledgedAt != null;

  factory AttitudeNote.fromJson(Map<String, dynamic> j) => AttitudeNote(
        id: j['id'] as String,
        kind: (j['kind'] ?? 'MERIT') as String,
        category: (j['category'] ?? 'OTHER') as String,
        points: (j['points'] as num?)?.toInt() ?? 0,
        note: j['note'] as String?,
        occurredAt: DateTime.parse(j['occurredAt'] as String).toLocal(),
        acknowledgedAt: j['acknowledgedAt'] == null
            ? null
            : DateTime.parse(j['acknowledgedAt'] as String).toLocal(),
        className: j['className'] as String?,
        recordedByName: j['recordedByName'] as String?,
      );
}

class AttitudeSummary {
  AttitudeSummary({
    required this.merits,
    required this.concerns,
    required this.incidents,
    required this.points,
    required this.notes,
  });

  final int merits;
  final int concerns;
  final int incidents;
  final int points;
  final List<AttitudeNote> notes;

  String get verdict {
    if (concerns + incidents == 0 && merits > 0) return 'excellent';
    if (concerns + incidents == 0) return 'settled';
    if (merits >= (concerns + incidents) * 2) return 'good';
    if (concerns + incidents > merits) return 'needsWork';
    return 'mixed';
  }

  factory AttitudeSummary.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] ?? const {}) as Map<String, dynamic>;
    return AttitudeSummary(
      merits: (s['merits'] as num?)?.toInt() ?? 0,
      concerns: (s['concerns'] as num?)?.toInt() ?? 0,
      incidents: (s['incidents'] as num?)?.toInt() ?? 0,
      points: (s['points'] as num?)?.toInt() ?? 0,
      notes: ((j['rows'] as List?) ?? const [])
          .map((e) => AttitudeNote.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HomeworkItem {
  HomeworkItem({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedOn,
    required this.dueDate,
    required this.subject,
    required this.colorHex,
    required this.teacher,
    required this.estimatedMinutes,
    this.submittedAt,
    this.score,
    this.maxScore,
    this.feedback,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime assignedOn;
  final DateTime dueDate;
  final String subject;
  final String? colorHex;
  final String? teacher;
  final int? estimatedMinutes;

  final DateTime? submittedAt;
  final num? score;
  final num? maxScore;
  final String? feedback;

  bool get handedIn => submittedAt != null;

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dueDate.difference(today).inDays;
  }

  factory HomeworkItem.fromJson(Map<String, dynamic> j) {
    return HomeworkItem(
      id: j['id'] as String,
      title: (j['title'] ?? '') as String,
      description: j['description'] as String?,
      assignedOn: DateTime.parse(j['assignedOn'] as String).toLocal(),
      dueDate: DateTime.parse(j['dueDate'] as String).toLocal(),
      subject: _subjectOf(j),
      colorHex: _colorOf(j),
      teacher: j['teacherName'] as String?,
      estimatedMinutes: (j['estimatedMinutes'] as num?)?.toInt(),
      submittedAt: j['submitted'] == null ? null : DateTime.parse(j['submitted'] as String).toLocal(),
      score: j['score'] as num?,
      maxScore: j['maxScore'] as num?,
      feedback: j['feedback'] as String?,
    );
  }
}

class ExamResultItem {
  ExamResultItem({
    required this.id,
    required this.score,
    required this.maxScore,
    required this.percent,
    required this.gradeLetter,
    required this.isPass,
    required this.wasAbsent,
    required this.examTitle,
    required this.subject,
    required this.colorHex,
    required this.date,
    this.classAverage,
    this.classAveragePercent,
    this.classAverageOf,
  });

  final String id;
  final num? score;
  final num maxScore;
  final num? percent;

  final num? classAverage;
  final num? classAveragePercent;

  final int? classAverageOf;
  final String? gradeLetter;
  final bool? isPass;
  final bool wasAbsent;
  final String examTitle;
  final String subject;
  final String? colorHex;
  final DateTime date;

  factory ExamResultItem.fromJson(Map<String, dynamic> j) {
    final exam = (j['exam'] ?? {}) as Map<String, dynamic>;
    return ExamResultItem(
      id: j['id'] as String,
      score: j['score'] as num?,
      maxScore: (j['maxScore'] as num?) ?? 100,
      percent: j['percent'] as num?,
      classAverage: j['classAverage'] as num?,
      classAveragePercent: j['classAveragePercent'] as num?,
      classAverageOf: (j['classAverageOf'] as num?)?.toInt(),
      gradeLetter: j['gradeLetter'] as String?,
      isPass: j['isPass'] as bool?,
      wasAbsent: (j['wasAbsent'] ?? false) as bool,
      examTitle: (exam['title'] ?? 'Test') as String,
      subject: _subjectOf(exam),
      colorHex: _colorOf(exam),
      date: DateTime.parse((exam['date'] ?? DateTime.now().toIso8601String()) as String).toLocal(),
    );
  }
}

class ReportCardSummary {
  ReportCardSummary({
    required this.id,
    required this.version,
    required this.termId,
    required this.termName,
    required this.wholeYear,
    required this.academicYearName,
    required this.className,
    required this.subjectCount,
    required this.overallScore,
    required this.overallGrade,
    required this.gpa,
    required this.classRank,
    required this.classSize,
    required this.daysPresent,
    required this.daysAbsent,
    required this.daysLate,
    required this.daysExcused,
    required this.promoted,
    required this.publishedAt,
    required this.openedAt,
    required this.hasPdf,
  });

  final String id;
  final int version;

  final String? termId;
  final String? termName;
  final bool wholeYear;

  final String academicYearName;

  final String? className;
  final int subjectCount;

  final num? overallScore;

  final String? overallGrade;
  final num? gpa;
  final int? classRank;
  final int? classSize;
  final int? daysPresent;
  final int? daysAbsent;
  final int? daysLate;
  final int? daysExcused;

  final bool? promoted;

  final DateTime publishedAt;

  final DateTime? openedAt;

  final bool hasPdf;

  factory ReportCardSummary.fromJson(Map<String, dynamic> j) {
    final term = j['term'] as Map<String, dynamic>?;
    final year = (j['academicYear'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    final klass = j['class'] as Map<String, dynamic>?;
    return ReportCardSummary(
      id: j['id'] as String,
      version: (j['version'] as num?)?.toInt() ?? 1,
      termId: term?['id'] as String?,
      termName: term?['name'] as String?,
      wholeYear: (j['wholeYear'] as bool?) ?? (term == null),
      academicYearName: (year['name'] ?? '') as String,
      className: klass?['name'] as String?,
      subjectCount: (j['subjectCount'] as num?)?.toInt() ?? 0,
      overallScore: j['overallScore'] as num?,
      overallGrade: j['overallGrade'] as String?,
      gpa: j['gpa'] as num?,
      classRank: (j['classRank'] as num?)?.toInt(),
      classSize: (j['classSize'] as num?)?.toInt(),
      daysPresent: (j['daysPresent'] as num?)?.toInt(),
      daysAbsent: (j['daysAbsent'] as num?)?.toInt(),
      daysLate: (j['daysLate'] as num?)?.toInt(),
      daysExcused: (j['daysExcused'] as num?)?.toInt(),
      promoted: j['promoted'] as bool?,
      publishedAt: DateTime.parse(j['publishedAt'] as String).toLocal(),
      openedAt: j['openedAt'] == null
          ? null
          : DateTime.parse(j['openedAt'] as String).toLocal(),
      hasPdf: (j['hasPdf'] ?? false) as bool,
    );
  }
}

class ReportCardLine {
  ReportCardLine({
    required this.id,
    required this.subject,
    required this.subjectId,
    required this.colorHex,
    required this.score,
    required this.maxScore,
    required this.percent,
    required this.gradeLetter,
    required this.gradePoint,
    required this.isPass,
    required this.classRank,
    required this.teacherComment,
  });

  final String id;

  final String subject;
  final String subjectId;
  final String? colorHex;

  final num? score;
  final num maxScore;
  final num? percent;
  final String? gradeLetter;
  final num? gradePoint;

  final bool? isPass;
  final int? classRank;
  final String? teacherComment;

  factory ReportCardLine.fromJson(Map<String, dynamic> j) => ReportCardLine(
        id: j['id'] as String,
        subject: _subjectOf(j),
        subjectId: (j['subjectId'] ?? '') as String,
        colorHex: _colorOf(j),
        score: j['score'] as num?,
        maxScore: (j['maxScore'] as num?) ?? 100,
        percent: j['percent'] as num?,
        gradeLetter: j['gradeLetter'] as String?,
        gradePoint: j['gradePoint'] as num?,
        isPass: j['isPass'] as bool?,
        classRank: (j['classRank'] as num?)?.toInt(),
        teacherComment: j['teacherComment'] as String?,
      );
}

class ReportCardDetail {
  ReportCardDetail({
    required this.id,
    required this.version,
    required this.termId,
    required this.termName,
    required this.wholeYear,
    required this.academicYearName,
    required this.className,
    required this.overallScore,
    required this.overallGrade,
    required this.gpa,
    required this.classRank,
    required this.classSize,
    required this.daysPresent,
    required this.daysAbsent,
    required this.daysLate,
    required this.daysExcused,
    required this.promoted,
    required this.homeroomComment,
    required this.principalComment,
    required this.publishedAt,
    required this.openedAt,
    required this.pdfUrl,
    required this.lines,
  });

  final String id;
  final int version;
  final String? termId;
  final String? termName;
  final bool wholeYear;
  final String academicYearName;
  final String? className;
  final num? overallScore;
  final String? overallGrade;
  final num? gpa;
  final int? classRank;
  final int? classSize;
  final int? daysPresent;
  final int? daysAbsent;
  final int? daysLate;
  final int? daysExcused;
  final bool? promoted;

  final String? homeroomComment;
  final String? principalComment;

  final DateTime publishedAt;

  final DateTime openedAt;

  final String? pdfUrl;

  final List<ReportCardLine> lines;

  factory ReportCardDetail.fromJson(Map<String, dynamic> j) {
    final term = j['term'] as Map<String, dynamic>?;
    final year = (j['academicYear'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    final klass = j['class'] as Map<String, dynamic>?;
    return ReportCardDetail(
      id: j['id'] as String,
      version: (j['version'] as num?)?.toInt() ?? 1,
      termId: term?['id'] as String?,
      termName: term?['name'] as String?,
      wholeYear: (j['wholeYear'] as bool?) ?? (term == null),
      academicYearName: (year['name'] ?? '') as String,
      className: klass?['name'] as String?,
      overallScore: j['overallScore'] as num?,
      overallGrade: j['overallGrade'] as String?,
      gpa: j['gpa'] as num?,
      classRank: (j['classRank'] as num?)?.toInt(),
      classSize: (j['classSize'] as num?)?.toInt(),
      daysPresent: (j['daysPresent'] as num?)?.toInt(),
      daysAbsent: (j['daysAbsent'] as num?)?.toInt(),
      daysLate: (j['daysLate'] as num?)?.toInt(),
      daysExcused: (j['daysExcused'] as num?)?.toInt(),
      promoted: j['promoted'] as bool?,
      homeroomComment: j['homeroomComment'] as String?,
      principalComment: j['principalComment'] as String?,
      publishedAt: DateTime.parse(j['publishedAt'] as String).toLocal(),
      openedAt: DateTime.parse(j['openedAt'] as String).toLocal(),
      pdfUrl: j['pdfUrl'] as String?,
      lines: ((j['lines'] as List?) ?? [])
          .map((e) => ReportCardLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TermSubjectGrade {
  TermSubjectGrade({
    required this.id,
    required this.subject,
    required this.subjectId,
    required this.colorHex,
    required this.score,
    required this.maxScore,
    required this.percent,
    required this.gradeLetter,
    required this.gradePoint,
    required this.isPass,
    required this.classRank,
    required this.teacherComment,
    required this.publishedAt,
  });

  final String id;

  final String subject;
  final String subjectId;
  final String? colorHex;
  final num? score;
  final num maxScore;
  final num? percent;
  final String? gradeLetter;
  final num? gradePoint;
  final bool? isPass;
  final int? classRank;
  final String? teacherComment;
  final DateTime publishedAt;

  factory TermSubjectGrade.fromJson(Map<String, dynamic> j) => TermSubjectGrade(
        id: j['id'] as String,
        subject: _subjectOf(j),
        subjectId: (j['subjectId'] ?? '') as String,
        colorHex: _colorOf(j),
        score: j['score'] as num?,
        maxScore: (j['maxScore'] as num?) ?? 100,
        percent: j['percent'] as num?,
        gradeLetter: j['gradeLetter'] as String?,
        gradePoint: j['gradePoint'] as num?,
        isPass: j['isPass'] as bool?,
        classRank: (j['classRank'] as num?)?.toInt(),
        teacherComment: j['teacherComment'] as String?,
        publishedAt: DateTime.parse(j['publishedAt'] as String).toLocal(),
      );
}

class TermGradeGroup {
  TermGradeGroup({
    required this.termId,
    required this.termName,
    required this.sequence,
    required this.startsOn,
    required this.endsOn,
    required this.academicYearName,
    required this.className,
    required this.subjectCount,
    required this.subjectsPassed,
    required this.subjectsFailed,
    required this.averagePercent,
    required this.subjects,
  });

  final String termId;
  final String termName;
  final int sequence;

  final DateTime startsOn;
  final DateTime endsOn;

  final String academicYearName;
  final String className;
  final int subjectCount;

  final int subjectsPassed;
  final int subjectsFailed;

  final num? averagePercent;

  final List<TermSubjectGrade> subjects;

  factory TermGradeGroup.fromJson(Map<String, dynamic> j) {
    final term = (j['term'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    final year = (j['academicYear'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    final klass = (j['class'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    return TermGradeGroup(
      termId: (term['id'] ?? '') as String,
      termName: (term['name'] ?? '') as String,
      sequence: (term['sequence'] as num?)?.toInt() ?? 0,
      startsOn: DateTime.parse(term['startsOn'] as String),
      endsOn: DateTime.parse(term['endsOn'] as String),
      academicYearName: (year['name'] ?? '') as String,
      className: (klass['name'] ?? '') as String,
      subjectCount: (j['subjectCount'] as num?)?.toInt() ?? 0,
      subjectsPassed: (j['subjectsPassed'] as num?)?.toInt() ?? 0,
      subjectsFailed: (j['subjectsFailed'] as num?)?.toInt() ?? 0,
      averagePercent: j['averagePercent'] as num?,
      subjects: ((j['subjects'] as List?) ?? [])
          .map((e) => TermSubjectGrade.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class UpcomingExam {
  UpcomingExam({
    required this.id,
    required this.kind,
    required this.title,
    required this.subject,
    required this.colorHex,
    required this.date,
    required this.startMinute,
    required this.durationMin,
    required this.room,
    required this.maxScore,
  });

  final String id;

  final String kind;

  final String? title;

  final String subject;
  final String? colorHex;

  final DateTime date;

  final int? startMinute;
  final int? durationMin;
  final String? room;
  final num maxScore;

  String? get kindKey => _kinds.contains(kind) ? 'exam.kind.$kind' : null;

  static const _kinds = {
    'QUIZ',
    'MONTHLY',
    'MIDTERM',
    'FINAL',
    'NATIONAL',
    'PRACTICAL',
    'ORAL',
    'MAKEUP',
  };

  factory UpcomingExam.fromJson(Map<String, dynamic> j) {
    return UpcomingExam(
      id: j['id'] as String,
      kind: (j['kind'] ?? '') as String,
      title: j['title'] as String?,
      subject: _subjectOf(j),
      colorHex: _colorOf(j),
      date: DateTime.parse(j['date'] as String).toLocal(),
      startMinute: (j['startMinute'] as num?)?.toInt(),
      durationMin: (j['durationMin'] as num?)?.toInt(),
      room: j['room'] as String?,
      maxScore: (j['maxScore'] as num?) ?? 100,
    );
  }
}

class AttendanceSummary {
  AttendanceSummary({
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
    required this.total,
    required this.ratePercent,
    required this.exceptions,
  });

  final int present;
  final int late;
  final int absent;
  final int excused;
  final int total;
  final int ratePercent;
  final List<AttendanceException> exceptions;

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) => AttendanceSummary(
        present: (j['present'] as num?)?.toInt() ?? 0,
        late: (j['late'] as num?)?.toInt() ?? 0,
        absent: (j['absent'] as num?)?.toInt() ?? 0,
        excused: (j['excused'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        ratePercent: (j['ratePercent'] as num?)?.toInt() ?? 0,
        exceptions: ((j['exceptions'] as List?) ?? [])
            .map((e) => AttendanceException.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AttendanceException {
  AttendanceException({
    required this.date,
    required this.status,
    required this.reason,
    required this.minutesLate,
  });

  final DateTime date;
  final String status;
  final String? reason;
  final int? minutesLate;

  factory AttendanceException.fromJson(Map<String, dynamic> j) => AttendanceException(
        date: DateTime.parse(j['date'] as String).toLocal(),
        status: j['status'] as String,
        reason: j['reason'] as String?,
        minutesLate: (j['minutesLate'] as num?)?.toInt(),
      );
}

class LeaveRequestItem {
  LeaveRequestItem({
    required this.id,
    required this.kind,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    required this.decisionNote,
    required this.studentId,
  });

  final String id;
  final String kind;
  final DateTime fromDate;
  final DateTime toDate;
  final String? reason;
  final String status;
  final String? decisionNote;
  final String? studentId;

  factory LeaveRequestItem.fromJson(Map<String, dynamic> j) => LeaveRequestItem(
        id: j['id'] as String,
        kind: (j['kind'] ?? 'OTHER') as String,
        fromDate: DateTime.parse(j['fromDate'] as String).toLocal(),
        toDate: DateTime.parse(j['toDate'] as String).toLocal(),
        reason: j['reason'] as String?,
        status: (j['status'] ?? 'PENDING') as String,
        decisionNote: j['decisionNote'] as String?,
        studentId: j['studentId'] as String?,
      );
}

class TripToday {
  TripToday({
    required this.tripId,
    required this.leg,
    required this.heading,
    required this.status,
    required this.scheduledDepartureAt,
    required this.startedAt,
    required this.endedAt,
    required this.driverName,
    required this.driverPhone,
    required this.vehicleLabel,
    required this.plate,
    required this.stopName,
    required this.resolution,
    required this.boardedAt,
    required this.alightedAt,
    required this.collectorName,
    required this.collectorRelationship,
    required this.collectorPhotoUrl,
  });

  final String tripId;
  final String leg;
  final String heading;
  final String status;
  final DateTime? scheduledDepartureAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? driverName;
  final String? driverPhone;
  final String? vehicleLabel;
  final String? plate;
  final String? stopName;
  final String? resolution;
  final DateTime? boardedAt;
  final DateTime? alightedAt;

  final String? collectorName;

  final String? collectorRelationship;

  final String? collectorPhotoUrl;

  static DateTime? _at(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

  factory TripToday.fromJson(Map<String, dynamic> j) => TripToday(
        tripId: j['tripId'] as String,
        leg: j['leg'] as String,
        heading: (j['heading'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        scheduledDepartureAt: _at(j['scheduledDepartureAt']),
        startedAt: _at(j['startedAt']),
        endedAt: _at(j['endedAt']),
        driverName: j['driverName'] as String?,
        driverPhone: j['driverPhone'] as String?,
        vehicleLabel: j['vehicleLabel'] as String?,
        plate: j['plate'] as String?,
        stopName: j['stopName'] as String?,
        resolution: j['resolution'] as String?,
        boardedAt: _at(j['boardedAt']),
        alightedAt: _at(j['alightedAt']),
        collectorName: j['collectorName'] as String?,
        collectorRelationship: j['collectorRelationship'] as String?,
        collectorPhotoUrl: j['collectorPhotoUrl'] as String?,
      );

  String get childLineKey {
    if (boardedAt != null && alightedAt != null) {
      return leg == 'OUT' ? 'bus.child.arrivedSchool' : 'bus.child.droppedOff';
    }
    if (boardedAt != null) return 'bus.child.onBus';
    if (resolution == 'NO_SHOW') return 'bus.child.noShow';
    if (resolution == 'EXCUSED') return 'bus.child.excused';
    if (status == 'PLANNED' || status == 'ROSTERED') return 'bus.child.notStarted';
    return 'bus.child.waiting';
  }
}

class TransportInfo {
  TransportInfo({
    required this.ridesTheBus,
    required this.routeName,
    required this.routeColorHex,
    required this.seatNumber,
    required this.pickupStopId,
    required this.pickupStopName,
    required this.pickupLandmark,
    required this.dropoffStopId,
    required this.dropoffStopName,
    required this.dropoffLandmark,
    required this.today,
    this.locationHidden = false,
  });

  final bool ridesTheBus;
  final String? routeName;
  final String? routeColorHex;
  final String? seatNumber;

  final String? pickupStopId;
  final String? pickupStopName;
  final String? pickupLandmark;
  final String? dropoffStopId;
  final String? dropoffStopName;
  final String? dropoffLandmark;
  final List<TripToday> today;

  final bool locationHidden;

  factory TransportInfo.fromJson(Map<String, dynamic> j) {
    final route = j['route'] as Map<String, dynamic>?;
    final pickup = j['pickupStop'] as Map<String, dynamic>?;
    final dropoff = j['dropoffStop'] as Map<String, dynamic>?;
    return TransportInfo(
      ridesTheBus: (j['ridesTheBus'] ?? false) as bool,
      routeName: route?['name'] as String?,
      routeColorHex: route?['colorHex'] as String?,
      seatNumber: j['seatNumber'] as String?,
      pickupStopId: pickup?['id'] as String?,
      pickupStopName: pickup?['name'] as String?,
      pickupLandmark: pickup?['landmarkDescription'] as String?,
      dropoffStopId: dropoff?['id'] as String?,
      dropoffStopName: dropoff?['name'] as String?,
      dropoffLandmark: dropoff?['landmarkDescription'] as String?,
      today: ((j['today'] as List?) ?? [])
          .map((e) => TripToday.fromJson(e as Map<String, dynamic>))
          .toList(),
      locationHidden: (j['locationHidden'] ?? false) as bool,
    );
  }
}

class LiveBus {
  LiveBus({
    required this.studentId,
    required this.studentName,
    required this.visible,
    required this.reason,
    required this.lat,
    required this.lon,
    required this.ageSeconds,
    required this.stale,
    required this.stopName,
    required this.etaMinutes,
    required this.stopLat,
    required this.stopLon,
    required this.childState,
    required this.boardedAt,
    required this.alightedAt,
    required this.headingDeg,
    required this.speedKph,
    required this.busLabel,
    required this.plate,
    required this.driverName,
    required this.simulated,
  });

  final String studentId;
  final String studentName;
  final bool visible;
  final String? reason;
  final double? lat;
  final double? lon;
  final int? ageSeconds;
  final bool stale;
  final String? stopName;
  final int? etaMinutes;

  final double? stopLat;
  final double? stopLon;

  final String? childState;
  final DateTime? boardedAt;
  final DateTime? alightedAt;

  final double? headingDeg;
  final double? speedKph;

  final String? busLabel;
  final String? plate;
  final String? driverName;

  final bool simulated;

  bool get onBoard => childState == 'ON_BOARD';

  bool get hasFix => visible && lat != null && lon != null;

  String get reasonText {
    switch (reason) {
      case 'no_trip_today':
        return t('reason.noTripToday');
      case 'trip_ended':
        return t('reason.tripEnded');
      case 'trip_cancelled':
        return t('reason.tripCancelled');
      case 'window_not_open_yet':
        return t('reason.windowNotOpen');
      case 'already_alighted':
        return t('reason.alreadyAlighted');
      case 'no_bus_assigned':
        return t('reason.noBusAssigned');
      case 'no_schedule':
        return t('reason.noSchedule');
      case 'no_fix_yet':
        return t('reason.noFixYet');
      case 'phone_not_verified':
        return t('reason.phoneNotVerified');
      case 'location_not_permitted':
        return t('reason.locationNotPermitted');
      case 'simulated_feed_withheld':
        return t('reason.simulatedWithheld');
      default:
        return t('reason.closed');
    }
  }

  factory LiveBus.fromJson(Map<String, dynamic> j) {
    final student = (j['student'] ?? {}) as Map<String, dynamic>;
    final position = j['position'] as Map<String, dynamic>?;
    final stop = j['stop'] as Map<String, dynamic>?;
    final child = j['child'] as Map<String, dynamic>?;
    final trip = j['trip'] as Map<String, dynamic>?;
    return LiveBus(
      studentId: (student['id'] ?? '') as String,
      studentName: (student['name'] ?? '') as String,
      visible: (j['visible'] ?? false) as bool,
      reason: j['reason'] as String?,
      lat: (position?['lat'] as num?)?.toDouble(),
      lon: (position?['lon'] as num?)?.toDouble(),
      ageSeconds: (j['ageSeconds'] as num?)?.toInt(),
      stale: (j['stale'] ?? true) as bool,
      stopName: stop?['name'] as String?,
      etaMinutes: (j['etaMinutes'] as num?)?.toInt(),
      stopLat: (stop?['lat'] as num?)?.toDouble(),
      stopLon: (stop?['lon'] as num?)?.toDouble(),
      childState: child?['state'] as String?,
      boardedAt: DateTime.tryParse((child?['boardedAt'] ?? '') as String)?.toLocal(),
      alightedAt: DateTime.tryParse((child?['alightedAt'] ?? '') as String)?.toLocal(),
      headingDeg: (position?['headingDeg'] as num?)?.toDouble(),
      speedKph: (position?['speedKph'] as num?)?.toDouble(),
      busLabel: trip?['busLabel'] as String?,
      plate: trip?['plate'] as String?,
      driverName: trip?['driverName'] as String?,
      simulated: (j['simulated'] ?? false) as bool,
    );
  }
}

class ConcernStatus {
  ConcernStatus({
    required this.id,
    required this.title,
    required this.topic,
    required this.urgent,
    required this.state,
    required this.raisedAt,
    required this.timesRaised,
  });

  final String id;
  final String title;

  final String? topic;
  final bool urgent;

  final String state;
  final DateTime? raisedAt;
  final int timesRaised;

  factory ConcernStatus.fromJson(Map<String, dynamic> j) => ConcernStatus(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        topic: j['topic'] as String?,
        urgent: (j['urgent'] ?? false) as bool,
        state: (j['state'] ?? 'SENT') as String,
        raisedAt: DateTime.tryParse((j['raisedAt'] ?? '') as String)?.toLocal(),
        timesRaised: (j['timesRaised'] as num?)?.toInt() ?? 1,
      );
}

class SkipLegEligibility {
  SkipLegEligibility({
    required this.leg,
    required this.open,
    required this.scheduledDepartureAt,
    required this.cutoffAt,
  });

  final String leg;
  final bool open;
  final DateTime? scheduledDepartureAt;
  final DateTime? cutoffAt;

  factory SkipLegEligibility.fromJson(Map<String, dynamic> j) => SkipLegEligibility(
        leg: (j['leg'] ?? '') as String,
        open: (j['open'] ?? false) as bool,
        scheduledDepartureAt:
            DateTime.tryParse((j['scheduledDepartureAt'] ?? '') as String)?.toLocal(),
        cutoffAt: DateTime.tryParse((j['cutoffAt'] ?? '') as String)?.toLocal(),
      );
}

class SkipEligibility {
  SkipEligibility({required this.serviceDate, required this.legs});

  final String serviceDate;
  final List<SkipLegEligibility> legs;

  bool get anyOpen => legs.any((l) => l.open);

  SkipLegEligibility? leg(String leg) {
    for (final l in legs) {
      if (l.leg == leg) return l;
    }
    return null;
  }

  factory SkipEligibility.fromJson(Map<String, dynamic> j) => SkipEligibility(
        serviceDate: (j['serviceDate'] ?? '') as String,
        legs: ((j['legs'] as List?) ?? [])
            .map((e) => SkipLegEligibility.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DropoffOption {
  DropoffOption({required this.id, required this.label, required this.stopName, required this.landmark});

  final String id;
  final String label;
  final String stopName;
  final String? landmark;

  factory DropoffOption.fromJson(Map<String, dynamic> j) {
    final stop = (j['stop'] ?? {}) as Map<String, dynamic>;
    return DropoffOption(
      id: j['id'] as String,
      label: (j['label'] ?? '') as String,
      stopName: (stop['name'] ?? '') as String,
      landmark: stop['landmarkDescription'] as String?,
    );
  }
}

class ParentApi {
  ParentApi._();

  static final ParentApi instance = ParentApi._();
  final ApiClient _api = ApiClient.instance;

  Future<List<Child>> children() async {
    final json = await _api.get('/parent/children');
    return (json as List).map((e) => Child.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RecentCrew>> recentCrew(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/recent-crew');
    return (json as List)
        .map((e) => RecentCrew.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CrewFeedbackItem>> crewFeedback(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/crew-feedback?pageSize=50');
    return Paged.from<CrewFeedbackItem>(json, CrewFeedbackItem.fromJson).rows;
  }

  Future<void> sendCrewFeedback({
    required String studentId,
    required String sentiment,
    required DateTime occurredOn,
    required List<String> topics,
    String? comment,
    String? direction,
    String? crewPersonId,
  }) async {
    await _api.post('/parent/children/$studentId/crew-feedback', {
      'sentiment': sentiment,
      'occurredOn': _dateOnly(occurredOn),
      'topics': topics,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      'direction': ?direction,
      'crewPersonId': ?crewPersonId,
    });
  }

  Future<List<MemoryAlbum>> memories(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/memories?pageSize=24');
    return Paged.from<MemoryAlbum>(json, MemoryAlbum.fromJson).rows;
  }

  Future<HomeLocation> homeLocation() async {
    final json = await _api.get('/parent/home') as Map<String, dynamic>;
    return HomeLocation.fromJson(json);
  }

  Future<void> saveHomeLocation({
    double? lat,
    double? lon,
    String? address,
    String? note,
  }) async {
    await _api.put('/parent/home', {
      'lat': ?lat,
      'lon': ?lon,
      if (address != null) 'address': address.trim(),
      if (note != null) 'note': note.trim(),
    });
  }

  Future<String> submitStopCorrection({
    required String stopId,
    required String reason,
    double? proposedLat,
    double? proposedLon,
  }) async {
    final json = await _api.post('/parent/stops/$stopId/correction', {
      'reason': reason.trim(),
      'proposedLat': ?proposedLat,
      'proposedLon': ?proposedLon,
    });
    return (json is Map<String, dynamic> ? json['status'] as String? : null) ??
        'AWAITING_REVIEW';
  }

  Future<ChildProfile> profile(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/profile') as Map<String, dynamic>;
    return ChildProfile.fromJson(json);
  }

  Future<List<DayOfLessons>> timetable(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/timetable') as Map<String, dynamic>;
    return ((json['days'] as List?) ?? [])
        .map((e) => DayOfLessons.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<HomeworkItem>> homework(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/homework?pageSize=50');
    return Paged.from<HomeworkItem>(json, HomeworkItem.fromJson).rows;
  }

  Future<List<UpcomingExam>> upcomingExams(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/exams');
    if (json is List) {
      return json.map((e) => UpcomingExam.fromJson(e as Map<String, dynamic>)).toList();
    }
    return Paged.from<UpcomingExam>(json, UpcomingExam.fromJson).rows;
  }

  Future<List<ExamResultItem>> results(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/results');
    if (json is List) {
      return json.map((e) => ExamResultItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return Paged.from<ExamResultItem>(json, ExamResultItem.fromJson).rows;
  }

  Future<List<ReportCardSummary>> reportCards(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/report-cards');
    return (json as List)
        .map((e) => ReportCardSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReportCardDetail> reportCard(String studentId, String id) async {
    final json = await _api.get('/parent/children/$studentId/report-cards/$id')
        as Map<String, dynamic>;
    return ReportCardDetail.fromJson(json);
  }

  Future<List<TermGradeGroup>> termGrades(String studentId, {String? termId}) async {
    final filter = (termId == null || termId.isEmpty) ? '' : '?termId=$termId';
    final json = await _api.get('/parent/children/$studentId/term-grades$filter');
    return (json as List)
        .map((e) => TermGradeGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AttitudeSummary> attitude(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/attitude') as Map<String, dynamic>;
    return AttitudeSummary.fromJson(json);
  }

  Future<void> markAttitudeSeen(String id) async {
    await _api.post('/parent/attitude/$id/seen');
  }

  Future<AttendanceSummary> attendance(String studentId, {DateTime? from, DateTime? to}) async {
    final q = <String>[
      if (from != null) 'from=${_day(from)}',
      if (to != null) 'to=${_day(to)}',
    ];
    final json = await _api.get(
      '/parent/children/$studentId/attendance${q.isEmpty ? '' : '?${q.join('&')}'}',
    ) as Map<String, dynamic>;
    return AttendanceSummary.fromJson(json);
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<TransportInfo> transport(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/transport') as Map<String, dynamic>;
    return TransportInfo.fromJson(json);
  }

  Future<List<LiveBus>> live() async {
    final json = await _api.get('/parent/live/children');
    return Paged.from<LiveBus>(json, LiveBus.fromJson).rows;
  }

  Future<List<LeaveRequestItem>> leaveRequests() async {
    final json = await _api.get('/parent/leave-requests?pageSize=50');
    return Paged.from<LeaveRequestItem>(json, LeaveRequestItem.fromJson).rows;
  }

  Future<void> requestLeave({
    required String studentId,
    required String kind,
    required DateTime from,
    required DateTime to,
    required String reason,
    String? doctorNoteAssetId,
  }) async {
    final why = reason.trim();
    await _api.post('/parent/leave-requests', {
      'studentId': studentId,
      'kind': kind,
      'fromDate': _dateOnly(from),
      'toDate': _dateOnly(to),
      'doctorNoteAssetId': ?doctorNoteAssetId,
      'reason': ?(why.isEmpty ? null : why),
    });
  }

  Future<void> cancelLeave(String id) => _api.post('/parent/leave-requests/$id/cancel');

  Future<void> acknowledgeAnnouncement(String id) =>
      _api.post('/parent/announcements/$id/acknowledge', const <String, dynamic>{});

  Future<List<ProfileChange>> profileChanges() async {
    final json = await _api.get('/auth/profile/change-requests');
    final rows = json is Map ? (json['rows'] as List?) ?? const [] : (json as List?) ?? const [];
    return rows.map((e) => ProfileChange.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> askProfileChange({
    String? nameGiven,
    String? nameFather,
    String? nameGrandfather,
    String? nameFamily,
    String? email,
    String? reason,
  }) =>
      _api.post('/auth/profile/change-requests', {
        'nameGiven': ?nameGiven,
        'nameFather': ?nameFather,
        'nameGrandfather': ?nameGrandfather,
        'nameFamily': ?nameFamily,
        'email': ?email,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  Future<void> cancelProfileChange(String id) =>
      _api.post('/auth/profile/change-requests/$id/cancel');

  Future<({String? usualStop, List<DropoffOption> options, String note})> dropoffOptions(
    String studentId,
  ) async {
    final json = await _api.get('/parent/children/$studentId/dropoff-options') as Map<String, dynamic>;
    final usual = json['usualStop'] as Map<String, dynamic>?;
    return (
      usualStop: usual?['name'] as String?,
      options: ((json['alternates'] as List?) ?? [])
          .map((e) => DropoffOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      note: (json['note'] ?? '') as String,
    );
  }

  Future<void> requestDropoffChange({
    required String studentId,
    required String alternateStopId,
    String? reason,
  }) async {
    await _api.post('/parent/dropoff-changes', {
      'studentId': studentId,
      'alternateStopId': alternateStopId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> skipRides() async {
    final json = await _api.get('/parent/skip-rides?pageSize=50');
    return Paged.from<Map<String, dynamic>>(json, (m) => m).rows;
  }

  Future<String> uploadFile({
    required Uint8List bytes,
    required String filename,
    required String mime,
    required String kind,
    String? studentId,
    String? note,
    DateTime? capturedAt,
  }) async {
    final json = await _api.upload(
      '/parent/uploads',
      field: 'file',
      bytes: bytes,
      filename: filename,
      mime: mime,
      fields: {
        'kind': kind,
        'subjectStudentId': ?studentId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'capturedAt': ?capturedAt?.toUtc().toIso8601String(),
      },
    );
    final id = json is Map ? json['id'] : null;
    if (id is! String || id.isEmpty) {
      throw ApiException('The school could not store that file.', 500);
    }
    return id;
  }

  Future<Map<String, dynamic>> raiseConcern({
    required String studentId,
    required String urgency,
    required String topic,
    String? message,
  }) async {
    final json = await _api.post('/parent/concerns', {
      'studentId': studentId,
      'urgency': urgency,
      'topic': topic,
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
    });
    return (json as Map).cast<String, dynamic>();
  }

  Future<List<ConcernStatus>> concerns({String? studentId, String? topic}) async {
    final params = <String>[
      if (studentId != null) 'studentId=$studentId',
      if (topic != null) 'topic=$topic',
    ];
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final json = await _api.get('/parent/concerns$q') as Map<String, dynamic>;
    return ((json['rows'] as List?) ?? [])
        .map((e) => ConcernStatus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SkipEligibility> skipRideEligibility(String studentId, {DateTime? on}) async {
    final date = on == null ? '' : '&date=${_day(on)}';
    final json = await _api.get('/parent/skip-rides/eligibility?studentId=$studentId$date')
        as Map<String, dynamic>;
    return SkipEligibility.fromJson(json);
  }

  Future<Map<String, dynamic>> createSkipRide({
    required String studentId,
    required DateTime from,
    required DateTime to,
    required String legScope,
    required String reason,
    String? note,
    required String idempotencyKey,
  }) async {
    final json = await _api.post('/parent/skip-rides', {
      'studentId': studentId,
      'dateFrom': _day(from),
      'dateTo': _day(to),
      'legScope': legScope,
      'reason': reason,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'idempotencyKey': idempotencyKey,
    });
    return (json as Map).cast<String, dynamic>();
  }

  Future<void> cancelSkipRide(String id, {String? note}) async {
    await _api.post('/parent/skip-rides/$id/cancel', {
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<List<Announcement>> announcements() async {
    final json = await _api.get('/parent/announcements?pageSize=50');
    return Paged.from<Announcement>(json, Announcement.fromJson).rows;
  }

  Future<void> markAnnouncementRead(String id) async {
    await _api.post('/parent/announcements/$id/read');
  }

  Future<List<AttachedFile>> announcementAttachments(String id) async {
    final json = await _api.get('/parent/announcements/$id/attachments?pageSize=50');
    return Paged.from<AttachedFile>(json, AttachedFile.fromJson).rows;
  }

  Future<int> markAllAnnouncementsRead() async {
    final json = await _api.post('/parent/announcements/read-all');
    return json is Map ? ((json['marked'] as num?)?.toInt() ?? 0) : 0;
  }

  Future<FeeSummary> fees() async {
    final json = await _api.get('/parent/fees') as Map<String, dynamic>;
    return FeeSummary.fromJson(json);
  }

  Future<PaymentOptions?> paymentOptions() async {
    try {
      final json = await _api.get('/parent/payments/options') as Map<String, dynamic>;
      return PaymentOptions.fromJson(json);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<Paged<DeclaredPayment>> payments({int pageSize = 50}) async {
    final json = await _api.get('/parent/payments?pageSize=$pageSize');
    return Paged.from<DeclaredPayment>(json, DeclaredPayment.fromJson);
  }

  Future<Paged<PaymentReceipt>> receipts({int pageSize = 50}) async {
    final json = await _api.get('/parent/receipts?pageSize=$pageSize');
    return Paged.from<PaymentReceipt>(json, PaymentReceipt.fromJson);
  }

  Future<StoredDocument> receiptPdf(String receiptId) async {
    final json = await _api.get('/parent/receipts/$receiptId/pdf') as Map<String, dynamic>;
    return StoredDocument.fromJson(json);
  }

  Future<StoredDocument> invoicePdf(String invoiceId) async {
    final json = await _api.get('/parent/invoices/$invoiceId/pdf') as Map<String, dynamic>;
    return StoredDocument.fromJson(json);
  }

  Future<void> declarePayment({
    required int amountIqd,
    required String method,
    required String idempotencyKey,
    String? invoiceId,
    String? studentId,
    DateTime? paidAt,
    String? reference,
    String? notes,
    String? proofAssetId,
  }) async {
    final ref = reference?.trim() ?? '';
    final note = notes?.trim() ?? '';
    try {
      await _api.post('/parent/payments', {
        'amountIqd': amountIqd,
        'method': method,
        'idempotencyKey': idempotencyKey,
        if (invoiceId != null && invoiceId.isNotEmpty) 'invoiceId': invoiceId,
        if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
        if (paidAt != null) 'paidAt': paidAt.toUtc().toIso8601String(),
        if (ref.isNotEmpty) 'reference': ref,
        if (note.length >= 2) 'notes': note,
        if (proofAssetId != null && proofAssetId.isNotEmpty) 'proofAssetId': proofAssetId,
      });
    } on ApiException catch (e) {
      if (e.status == 409) return;
      rethrow;
    }
  }

  Future<void> withdrawPayment(String paymentId) async {
    await _api.post('/parent/payments/$paymentId/withdraw');
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class Announcement {
  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.priority,
    required this.sentAt,
    required this.pinned,
    required this.requiresAcknowledgement,
    this.acknowledgedAt,
    required this.authorName,
    required this.readAt,
    this.attachmentCount = 0,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final String priority;
  final DateTime? sentAt;
  final bool pinned;
  final bool requiresAcknowledgement;

  final DateTime? acknowledgedAt;
  final String authorName;
  final DateTime? readAt;

  final int attachmentCount;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        category: (j['category'] ?? 'ANNOUNCEMENT') as String,
        priority: (j['priority'] ?? 'NORMAL') as String,
        sentAt: j['sentAt'] == null ? null : DateTime.parse(j['sentAt'] as String).toLocal(),
        pinned: (j['pinned'] ?? false) as bool,
        requiresAcknowledgement: (j['requiresAcknowledgement'] ?? false) as bool,
        acknowledgedAt: j['acknowledgedAt'] == null
            ? null
            : DateTime.parse(j['acknowledgedAt'] as String).toLocal(),
        authorName: (j['authorName'] ?? '') as String,
        readAt: j['readAt'] == null ? null : DateTime.parse(j['readAt'] as String).toLocal(),
        attachmentCount: (j['attachmentCount'] as num?)?.toInt() ?? 0,
      );
}

class InvoiceLine2 {
  InvoiceLine2({required this.description, required this.amountIqd, required this.studentName});

  final String description;
  final int amountIqd;
  final String? studentName;

  factory InvoiceLine2.fromJson(Map<String, dynamic> j) => InvoiceLine2(
        description: (j['description'] ?? '') as String,
        amountIqd: (j['amountIqd'] as num?)?.toInt() ?? 0,
        studentName: j['studentName'] as String?,
      );
}

class Invoice2 {
  Invoice2({
    required this.id,
    required this.serial,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
    required this.dueAt,
    required this.totalIqd,
    required this.paidIqd,
    required this.balanceIqd,
    required this.overdue,
    required this.lines,
  });

  final String id;
  final String serial;
  final String status;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime dueAt;
  final int totalIqd;
  final int paidIqd;
  final int balanceIqd;
  final bool overdue;
  final List<InvoiceLine2> lines;

  factory Invoice2.fromJson(Map<String, dynamic> j) => Invoice2(
        id: j['id'] as String,
        serial: (j['serial'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        periodStart: DateTime.parse(j['periodStart'] as String).toLocal(),
        periodEnd: DateTime.parse(j['periodEnd'] as String).toLocal(),
        dueAt: DateTime.parse(j['dueAt'] as String).toLocal(),
        totalIqd: (j['totalIqd'] as num?)?.toInt() ?? 0,
        paidIqd: (j['paidIqd'] as num?)?.toInt() ?? 0,
        balanceIqd: (j['balanceIqd'] as num?)?.toInt() ?? 0,
        overdue: (j['overdue'] ?? false) as bool,
        lines: ((j['lines'] as List?) ?? [])
            .map((e) => InvoiceLine2.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class FeeSummary {
  FeeSummary({
    required this.outstandingIqd,
    required this.overdueIqd,
    required this.dueAt,
    required this.daysUntilDue,
    required this.invoices,
  });

  final int outstandingIqd;
  final int overdueIqd;
  final DateTime? dueAt;
  final int? daysUntilDue;
  final List<Invoice2> invoices;

  factory FeeSummary.fromJson(Map<String, dynamic> j) => FeeSummary(
        outstandingIqd: (j['outstandingIqd'] as num?)?.toInt() ?? 0,
        overdueIqd: (j['overdueIqd'] as num?)?.toInt() ?? 0,
        dueAt: j['dueAt'] == null ? null : DateTime.parse(j['dueAt'] as String).toLocal(),
        daysUntilDue: (j['daysUntilDue'] as num?)?.toInt(),
        invoices: ((j['invoices'] as List?) ?? [])
            .map((e) => Invoice2.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

String? _twoPartName(Map<String, dynamic>? j) {
  if (j == null) return null;
  final name = '${j['nameGiven'] ?? ''} ${j['nameFamily'] ?? ''}'.trim();
  return name.isEmpty ? null : name;
}

class PaymentOptions {
  PaymentOptions({
    required this.allowSelfDeclare,
    required this.requireProofForTransfer,
    required this.methods,
    required this.currencyCode,
    required this.instructions,
  });

  final bool allowSelfDeclare;

  final bool requireProofForTransfer;

  final List<String> methods;

  final String currencyCode;

  final String? instructions;

  List<String> get usableMethods => methods;

  factory PaymentOptions.fromJson(Map<String, dynamic> j) {
    final written = (j['paymentInstructions'] as String?)?.trim() ?? '';
    return PaymentOptions(
      allowSelfDeclare: (j['allowParentSelfDeclare'] ?? false) as bool,
      requireProofForTransfer: (j['requireProofForTransfer'] ?? true) as bool,
      methods: ((j['methods'] as List?) ?? const []).map((e) => '$e').toList(),
      currencyCode: (j['currencyCode'] ?? 'IQD') as String,
      instructions: written.isEmpty ? null : written,
    );
  }
}

class PaymentReceipt {
  PaymentReceipt({
    required this.id,
    required this.serial,
    required this.amountIqd,
    required this.currencyCode,
    required this.method,
    required this.issuedAt,
    required this.voidedAt,
    required this.invoiceSerial,
    required this.studentName,
  });

  final String id;
  final String serial;
  final int amountIqd;
  final String currencyCode;
  final String method;
  final DateTime? issuedAt;
  final DateTime? voidedAt;
  final String? invoiceSerial;
  final String? studentName;

  bool get open => voidedAt == null;

  factory PaymentReceipt.fromJson(Map<String, dynamic> j) => PaymentReceipt(
        id: j['id'] as String,
        serial: (j['serial'] ?? '') as String,
        amountIqd: (j['amountIqd'] as num?)?.toInt() ?? 0,
        currencyCode: (j['currencyCode'] ?? 'IQD') as String,
        method: (j['method'] ?? '') as String,
        issuedAt: DateTime.tryParse((j['issuedAt'] ?? '') as String)?.toLocal(),
        voidedAt: DateTime.tryParse((j['voidedAt'] ?? '') as String)?.toLocal(),
        invoiceSerial: (j['invoice'] as Map<String, dynamic>?)?['serial'] as String?,
        studentName: _twoPartName(j['student'] as Map<String, dynamic>?),
      );
}

class DeclaredPayment {
  DeclaredPayment({
    required this.id,
    required this.amountIqd,
    required this.currencyCode,
    required this.method,
    required this.status,
    required this.paidAt,
    required this.receivedAt,
    required this.createdAt,
    required this.reference,
    required this.rejectedReason,
    required this.invoiceId,
    required this.invoiceSerial,
    required this.studentName,
    required this.receipts,
  });

  final String id;
  final int amountIqd;
  final String currencyCode;
  final String method;

  final String status;

  final DateTime? paidAt;
  final DateTime? receivedAt;
  final DateTime createdAt;
  final String? reference;
  final String? rejectedReason;
  final String? invoiceId;
  final String? invoiceSerial;
  final String? studentName;
  final List<PaymentReceipt> receipts;

  bool get awaiting => status == 'PENDING_CONFIRMATION';
  bool get confirmed => status == 'CONFIRMED';

  static const _withdrawnMark = 'Withdrawn by the family';

  bool get withdrawnByFamily =>
      status == 'REJECTED' && (rejectedReason ?? '').startsWith(_withdrawnMark);

  String? get refusal {
    final reason = rejectedReason?.trim() ?? '';
    if (reason.isEmpty) return null;
    if (!withdrawnByFamily) return reason;
    var rest = reason.substring(_withdrawnMark.length).trim();
    if (rest.startsWith(':')) rest = rest.substring(1).trim();
    return rest.isEmpty ? null : rest;
  }

  DateTime get when => paidAt ?? receivedAt ?? createdAt;

  PaymentReceipt? get receipt {
    for (final r in receipts) {
      if (r.open) return r;
    }
    return null;
  }

  factory DeclaredPayment.fromJson(Map<String, dynamic> j) {
    final invoice = j['invoice'] as Map<String, dynamic>?;
    return DeclaredPayment(
      id: j['id'] as String,
      amountIqd: (j['amountIqd'] as num?)?.toInt() ?? 0,
      currencyCode: (j['currencyCode'] ?? 'IQD') as String,
      method: (j['method'] ?? '') as String,
      status: (j['status'] ?? '') as String,
      paidAt: DateTime.tryParse((j['paidAt'] ?? '') as String)?.toLocal(),
      receivedAt: DateTime.tryParse((j['receivedAt'] ?? '') as String)?.toLocal(),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String)?.toLocal() ?? DateTime.now(),
      reference: j['reference'] as String?,
      rejectedReason: j['rejectedReason'] as String?,
      invoiceId: invoice?['id'] as String?,
      invoiceSerial: invoice?['serial'] as String?,
      studentName: _twoPartName(j['student'] as Map<String, dynamic>?),
      receipts: ((j['receipts'] as List?) ?? const [])
          .map((e) => PaymentReceipt.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StoredDocument {
  StoredDocument({required this.url, required this.filename, required this.latinOnly});

  final String url;
  final String filename;

  final bool latinOnly;

  factory StoredDocument.fromJson(Map<String, dynamic> j) => StoredDocument(
        url: (j['url'] ?? '') as String,
        filename: (j['filename'] ?? '') as String,
        latinOnly: (j['latinOnly'] ?? false) as bool,
      );
}

String _subjectOf(Map<String, dynamic> j, {String? fallback}) {
  final raw = j['subject'];
  if (raw is String) return raw;
  if (raw is Map<String, dynamic>) return (raw['name'] ?? fallback ?? '') as String;
  return fallback ?? '';
}

String? _colorOf(Map<String, dynamic> j) {
  final flat = j['subjectColorHex'];
  if (flat is String) return flat;
  final raw = j['subject'];
  if (raw is Map<String, dynamic>) return raw['colorHex'] as String?;
  return null;
}

class ProfileChange {
  ProfileChange({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.fields,
    this.reason,
    this.decisionNote,
    this.decidedAt,
  });

  final String id;

  final String status;
  final DateTime requestedAt;

  final List<({String field, String value})> fields;

  final String? reason;

  final String? decisionNote;
  final DateTime? decidedAt;

  bool get pending => status == 'PENDING';

  factory ProfileChange.fromJson(Map<String, dynamic> j) {
    final asked = <({String field, String value})>[];
    void take(String key) {
      final v = j[key];
      if (v is String) asked.add((field: key, value: v));
    }

    final flat = (j['proposed'] as Map<String, dynamic>?) ?? j;
    for (final key in const ['nameGiven', 'nameFather', 'nameGrandfather', 'nameFamily', 'email']) {
      final v = flat[key];
      if (v is String) asked.add((field: key, value: v));
    }
    if (asked.isEmpty) {
      for (final key in const ['nameGiven', 'nameFather', 'nameGrandfather', 'nameFamily', 'email']) {
        take(key);
      }
    }

    return ProfileChange(
      id: j['id'] as String,
      status: (j['status'] ?? 'PENDING') as String,
      requestedAt: DateTime.tryParse((j['requestedAt'] ?? '') as String)?.toLocal() ?? DateTime.now(),
      fields: asked,
      reason: j['reason'] as String?,
      decisionNote: j['decisionNote'] as String?,
      decidedAt: DateTime.tryParse((j['decidedAt'] ?? '') as String)?.toLocal(),
    );
  }
}
