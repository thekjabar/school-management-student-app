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

DateTime? _calendarDay(Object? iso) {
  if (iso is! String || iso.length < 10) return null;
  return DateTime.tryParse(iso.substring(0, 10));
}

class AttendanceSummary {
  AttendanceSummary({
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
    required this.leftEarly,
    required this.total,
    required this.ratePercent,
    required this.termId,
    required this.termName,
    required this.from,
    required this.to,
    required this.exceptions,
  });

  final int present;
  final int late;
  final int absent;
  final int excused;
  final int leftEarly;
  final int total;
  final double? ratePercent;
  final String? termId;
  final String? termName;
  final DateTime? from;
  final DateTime? to;
  final List<AttendanceException> exceptions;

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) => AttendanceSummary(
        present: (j['present'] as num?)?.toInt() ?? 0,
        late: (j['late'] as num?)?.toInt() ?? 0,
        absent: (j['absent'] as num?)?.toInt() ?? 0,
        excused: (j['excused'] as num?)?.toInt() ?? 0,
        leftEarly: (j['leftEarly'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        ratePercent: (j['ratePercent'] as num?)?.toDouble(),
        termId: j['termId'] as String?,
        termName: j['termName'] as String?,
        from: _calendarDay(j['from']),
        to: _calendarDay(j['to']),
        exceptions: ((j['exceptions'] as List?) ?? [])
            .map((e) => AttendanceException.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AttendanceTrend {
  AttendanceTrend({
    required this.termId,
    required this.termName,
    required this.from,
    required this.to,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.leftEarly,
    required this.daysMarked,
    required this.daysMissed,
    required this.missedPercent,
    required this.attendanceRate,
    required this.band,
    required this.expectedSchoolDays,
    required this.byMonth,
    required this.previous,
    required this.direction,
  });

  final String? termId;
  final String? termName;
  final DateTime? from;
  final DateTime? to;
  final int present;
  final int absent;
  final int late;
  final int excused;
  final int leftEarly;
  final int daysMarked;
  final int daysMissed;
  final double? missedPercent;
  final double? attendanceRate;
  final String band;
  final int expectedSchoolDays;
  final List<AttendanceMonthPoint> byMonth;
  final AttendanceTermFigures? previous;
  final String? direction;

  factory AttendanceTrend.fromJson(Map<String, dynamic> j) => AttendanceTrend(
        termId: j['termId'] as String?,
        termName: j['termName'] as String?,
        from: _calendarDay(j['from']),
        to: _calendarDay(j['to']),
        present: (j['present'] as num?)?.toInt() ?? 0,
        absent: (j['absent'] as num?)?.toInt() ?? 0,
        late: (j['late'] as num?)?.toInt() ?? 0,
        excused: (j['excused'] as num?)?.toInt() ?? 0,
        leftEarly: (j['leftEarly'] as num?)?.toInt() ?? 0,
        daysMarked: (j['daysMarked'] as num?)?.toInt() ?? 0,
        daysMissed: (j['daysMissed'] as num?)?.toInt() ?? 0,
        missedPercent: (j['missedPercent'] as num?)?.toDouble(),
        attendanceRate: (j['attendanceRate'] as num?)?.toDouble(),
        band: (j['band'] as String?) ?? 'UNKNOWN',
        expectedSchoolDays: (j['expectedSchoolDays'] as num?)?.toInt() ?? 0,
        byMonth: ((j['byMonth'] as List?) ?? [])
            .map((e) => AttendanceMonthPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        previous: j['previous'] == null
            ? null
            : AttendanceTermFigures.fromJson(j['previous'] as Map<String, dynamic>),
        direction: j['direction'] as String?,
      );
}

class AttendanceMonthPoint {
  AttendanceMonthPoint({
    required this.month,
    required this.daysMarked,
    required this.daysMissed,
    required this.attendanceRate,
  });

  final String month;
  final int daysMarked;
  final int daysMissed;
  final double? attendanceRate;

  int get monthNumber => int.tryParse(month.split('-').last) ?? 0;

  factory AttendanceMonthPoint.fromJson(Map<String, dynamic> j) => AttendanceMonthPoint(
        month: (j['month'] as String?) ?? '',
        daysMarked: (j['daysMarked'] as num?)?.toInt() ?? 0,
        daysMissed: (j['daysMissed'] as num?)?.toInt() ?? 0,
        attendanceRate: (j['attendanceRate'] as num?)?.toDouble(),
      );
}

class AttendanceTermFigures {
  AttendanceTermFigures({
    required this.termName,
    required this.daysMarked,
    required this.daysMissed,
    required this.missedPercent,
    required this.attendanceRate,
  });

  final String? termName;
  final int daysMarked;
  final int daysMissed;
  final double? missedPercent;
  final double? attendanceRate;

  factory AttendanceTermFigures.fromJson(Map<String, dynamic> j) => AttendanceTermFigures(
        termName: j['termName'] as String?,
        daysMarked: (j['daysMarked'] as num?)?.toInt() ?? 0,
        daysMissed: (j['daysMissed'] as num?)?.toInt() ?? 0,
        missedPercent: (j['missedPercent'] as num?)?.toDouble(),
        attendanceRate: (j['attendanceRate'] as num?)?.toDouble(),
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

int _hhInt(dynamic v) => (v as num?)?.toInt() ?? 0;
bool _hhBool(dynamic v) => (v ?? false) as bool;
Map<String, dynamic>? _hhObj(dynamic v) => v is Map<String, dynamic> ? v : null;
List<Map<String, dynamic>> _hhList(dynamic v) => (v as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList(growable: false) ??
    const <Map<String, dynamic>>[];
String? _hhName(dynamic v) => _hhObj(v)?['name'] as String?;

class SchoolContact {
  SchoolContact({required this.name, required this.phone});

  final String name;
  final String? phone;

  factory SchoolContact.fromJson(Map<String, dynamic>? j) => SchoolContact(
        name: (j?['name'] ?? '') as String,
        phone: j?['phone'] as String?,
      );
}

class SiblingRules {
  SiblingRules({
    required this.releaseRule,
    required this.mustShareRoute,
    required this.mustShareVehicle,
    required this.enforcedAtHandover,
  });

  final String releaseRule;
  final bool mustShareRoute;
  final bool mustShareVehicle;
  final bool enforcedAtHandover;

  bool get anySet =>
      releaseRule != 'NONE' || mustShareRoute || mustShareVehicle;

  factory SiblingRules.fromJson(Map<String, dynamic>? j) => SiblingRules(
        releaseRule: (j?['siblingReleaseRule'] ?? 'NONE') as String,
        mustShareRoute: _hhBool(j?['siblingsMustShareRoute']),
        mustShareVehicle: _hhBool(j?['siblingsMustShareVehicle']),
        enforcedAtHandover: _hhBool(j?['enforcedAtHandover']),
      );
}

class HouseholdRide {
  HouseholdRide({
    required this.legScope,
    required this.routeCode,
    required this.routeName,
    required this.pickupStop,
    required this.dropoffStop,
  });

  final String legScope;
  final String? routeCode;
  final String? routeName;
  final String? pickupStop;
  final String? dropoffStop;

  factory HouseholdRide.fromJson(Map<String, dynamic> j) => HouseholdRide(
        legScope: (j['legScope'] ?? '') as String,
        routeCode: _hhObj(j['route'])?['code'] as String?,
        routeName: _hhName(j['route']),
        pickupStop: _hhName(j['pickupStop']),
        dropoffStop: _hhName(j['dropoffStop']),
      );
}

class HouseholdChild {
  HouseholdChild({
    required this.studentId,
    required this.name,
    required this.className,
    required this.campusName,
    required this.shift,
    required this.ridesTheBus,
    required this.stopsHidden,
    required this.receivesRoutineAlerts,
    required this.escortName,
    required this.escortHidden,
    required this.rides,
  });

  final String studentId;
  final String name;
  final String? className;
  final String? campusName;
  final String? shift;
  final bool ridesTheBus;
  final bool stopsHidden;
  final bool receivesRoutineAlerts;
  final String? escortName;
  final bool escortHidden;
  final List<HouseholdRide> rides;

  factory HouseholdChild.fromJson(Map<String, dynamic> j) => HouseholdChild(
        studentId: (j['studentId'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        className: (j['className'] ?? j['gradeLabel']) as String?,
        campusName: _hhName(j['campus']),
        shift: j['shift'] as String?,
        ridesTheBus: _hhBool(j['ridesTheBus']),
        stopsHidden: _hhBool(j['stopsHidden']),
        receivesRoutineAlerts: _hhBool(j['receivesRoutineAlerts']),
        escortName: _hhName(j['releaseEscort']),
        escortHidden: _hhBool(j['escortNamedButNotOnYourAccount']),
        rides: _hhList(j['transport']).map(HouseholdRide.fromJson).toList(growable: false),
      );
}

class HouseholdGroup {
  HouseholdGroup({
    required this.familyId,
    required this.code,
    required this.name,
    required this.rules,
    required this.children,
  });

  final String familyId;
  final String code;
  final String name;
  final SiblingRules rules;
  final List<HouseholdChild> children;

  factory HouseholdGroup.fromJson(Map<String, dynamic> j) => HouseholdGroup(
        familyId: (j['familyId'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        rules: SiblingRules.fromJson(_hhObj(j['rules'])),
        children: _hhList(j['children']).map(HouseholdChild.fromJson).toList(growable: false),
      );
}

class HouseholdOverview {
  HouseholdOverview({
    required this.school,
    required this.childCount,
    required this.truncated,
    required this.maxChildren,
    required this.households,
  });

  final SchoolContact school;
  final int childCount;
  final bool truncated;
  final int maxChildren;
  final List<HouseholdGroup> households;

  factory HouseholdOverview.fromJson(Map<String, dynamic> j) => HouseholdOverview(
        school: SchoolContact.fromJson(_hhObj(j['school'])),
        childCount: _hhInt(j['childCount']),
        truncated: _hhBool(j['truncated']),
        maxChildren: _hhInt(j['maxChildren']),
        households: _hhList(j['households']).map(HouseholdGroup.fromJson).toList(growable: false),
      );
}

class DayChild {
  DayChild({
    required this.studentId,
    required this.name,
    required this.campusName,
    required this.ridesToday,
    required this.bellTimesKnown,
    required this.dayKind,
    required this.closed,
    required this.transportRunning,
    required this.note,
  });

  final String studentId;
  final String name;
  final String? campusName;
  final bool ridesToday;
  final bool bellTimesKnown;
  final String? dayKind;
  final bool closed;
  final bool transportRunning;
  final String? note;

  factory DayChild.fromJson(Map<String, dynamic> j) {
    final day = _hhObj(j['schoolDay']);
    return DayChild(
      studentId: (j['studentId'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      campusName: _hhName(j['campus']),
      ridesToday: _hhBool(j['ridesToday']),
      bellTimesKnown: _hhBool(j['bellTimesKnown']),
      dayKind: day?['kind'] as String?,
      closed: _hhBool(day?['closed']),
      transportRunning: day == null ? true : _hhBool(day['transportRunning']),
      note: day?['note'] as String?,
    );
  }
}

class DayEvent {
  DayEvent({
    required this.at,
    required this.kind,
    required this.childName,
    required this.placeName,
    required this.routeName,
    required this.tripId,
    required this.tripStatus,
    required this.actualAt,
    required this.status,
  });

  final DateTime? at;
  final String kind;
  final String childName;
  final String? placeName;
  final String? routeName;
  final String? tripId;
  final String? tripStatus;
  final DateTime? actualAt;
  final String status;

  bool get cancelled => tripStatus == 'CANCELLED';

  factory DayEvent.fromJson(Map<String, dynamic> j) => DayEvent(
        at: HomeArrival._at(j['atUtc']),
        kind: (j['kind'] ?? '') as String,
        childName: (j['childName'] ?? '') as String,
        placeName: (j['stopName'] ?? j['campusName']) as String?,
        routeName: j['routeName'] as String?,
        tripId: j['tripId'] as String?,
        tripStatus: j['tripStatus'] as String?,
        actualAt: HomeArrival._at(j['actualAt']),
        status: (j['status'] ?? '') as String,
      );
}

class DayOverlapSide {
  DayOverlapSide({required this.childName, required this.kind, required this.at, required this.placeName});

  final String childName;
  final String kind;
  final DateTime? at;
  final String? placeName;

  factory DayOverlapSide.fromJson(Map<String, dynamic>? j) => DayOverlapSide(
        childName: (j?['childName'] ?? '') as String,
        kind: (j?['kind'] ?? '') as String,
        at: HomeArrival._at(j?['atUtc']),
        placeName: j?['placeName'] as String?,
      );
}

class DayOverlap {
  DayOverlap({required this.minutesApart, required this.a, required this.b});

  final int minutesApart;
  final DayOverlapSide a;
  final DayOverlapSide b;

  factory DayOverlap.fromJson(Map<String, dynamic> j) => DayOverlap(
        minutesApart: _hhInt(j['minutesApart']),
        a: DayOverlapSide.fromJson(_hhObj(j['a'])),
        b: DayOverlapSide.fromJson(_hhObj(j['b'])),
      );
}

class DayWithoutTime {
  DayWithoutTime({required this.studentId, required this.childName, required this.reason});

  final String studentId;
  final String childName;
  final String reason;

  factory DayWithoutTime.fromJson(Map<String, dynamic> j) => DayWithoutTime(
        studentId: (j['studentId'] ?? '') as String,
        childName: (j['childName'] ?? '') as String,
        reason: (j['reason'] ?? '') as String,
      );
}

class HouseholdDay {
  HouseholdDay({
    required this.school,
    required this.date,
    required this.isToday,
    required this.children,
    required this.events,
    required this.overlaps,
    required this.withoutTimes,
  });

  final SchoolContact school;
  final String date;
  final bool isToday;
  final List<DayChild> children;
  final List<DayEvent> events;
  final List<DayOverlap> overlaps;
  final List<DayWithoutTime> withoutTimes;

  factory HouseholdDay.fromJson(Map<String, dynamic> j) => HouseholdDay(
        school: SchoolContact.fromJson(_hhObj(j['school'])),
        date: (j['date'] ?? '') as String,
        isToday: _hhBool(j['isToday']),
        children: _hhList(j['children']).map(DayChild.fromJson).toList(growable: false),
        events: _hhList(j['events']).map(DayEvent.fromJson).toList(growable: false),
        overlaps: _hhList(j['overlaps']).map(DayOverlap.fromJson).toList(growable: false),
        withoutTimes: _hhList(j['withoutTimes']).map(DayWithoutTime.fromJson).toList(growable: false),
      );
}

class HouseholdConflict {
  HouseholdConflict({
    required this.code,
    required this.childName,
    required this.routeCount,
    required this.vehicleCount,
    required this.message,
  });

  final String code;
  final String? childName;
  final int? routeCount;
  final int? vehicleCount;
  final String message;

  factory HouseholdConflict.fromJson(Map<String, dynamic> j) => HouseholdConflict(
        code: (j['code'] ?? '') as String,
        childName: j['childName'] as String?,
        routeCount: (j['routeCount'] as num?)?.toInt(),
        vehicleCount: (j['vehicleCount'] as num?)?.toInt(),
        message: (j['message'] ?? '') as String,
      );
}

class ConflictHousehold {
  ConflictHousehold({
    required this.familyId,
    required this.name,
    required this.ok,
    required this.childrenRiding,
    required this.distinctRoutes,
    required this.distinctVehicles,
    required this.conflicts,
    required this.notes,
  });

  final String familyId;
  final String name;
  final bool ok;
  final int childrenRiding;
  final int distinctRoutes;
  final int distinctVehicles;
  final List<HouseholdConflict> conflicts;
  final List<HouseholdConflict> notes;

  factory ConflictHousehold.fromJson(Map<String, dynamic> j) => ConflictHousehold(
        familyId: (j['familyId'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        ok: _hhBool(j['ok']),
        childrenRiding: _hhInt(j['childrenRiding']),
        distinctRoutes: _hhInt(j['distinctRoutes']),
        distinctVehicles: _hhInt(j['distinctVehicles']),
        conflicts: _hhList(j['conflicts']).map(HouseholdConflict.fromJson).toList(growable: false),
        notes: _hhList(j['notes']).map(HouseholdConflict.fromJson).toList(growable: false),
      );
}

class HouseholdConflicts {
  HouseholdConflicts({required this.school, required this.ok, required this.households});

  final SchoolContact school;
  final bool ok;
  final List<ConflictHousehold> households;

  factory HouseholdConflicts.fromJson(Map<String, dynamic> j) => HouseholdConflicts(
        school: SchoolContact.fromJson(_hhObj(j['school'])),
        ok: _hhBool(j['ok']),
        households: _hhList(j['households']).map(ConflictHousehold.fromJson).toList(growable: false),
      );
}

class RouteSafety {
  RouteSafety({
    required this.ridesTheBus,
    required this.locationHidden,
    required this.from,
    required this.to,
    required this.days,
    required this.route,
    required this.child,
    required this.alerts,
    required this.reaching,
  });

  final bool ridesTheBus;
  final bool locationHidden;
  final String from;
  final String to;
  final int days;
  final RouteSafetyRoute? route;
  final RouteSafetyChild? child;
  final RouteSafetyAlerts? alerts;
  final RouteSafetyReach? reaching;

  static Map<String, dynamic>? _obj(dynamic v) =>
      v is Map<String, dynamic> ? v : null;

  factory RouteSafety.fromJson(Map<String, dynamic> j) {
    final period = _obj(j['period']) ?? const <String, dynamic>{};
    final route = _obj(j['route']);
    final child = _obj(j['yourChild']);
    final alerts = _obj(j['answeredAboutYourChild']);
    final reaching = _obj(j['reachingYou']);
    return RouteSafety(
      ridesTheBus: (j['ridesTheBus'] ?? false) as bool,
      locationHidden: (j['locationHidden'] ?? false) as bool,
      from: (period['from'] ?? '') as String,
      to: (period['to'] ?? '') as String,
      days: (period['days'] as num?)?.toInt() ?? 0,
      route: route == null ? null : RouteSafetyRoute.fromJson(route),
      child: child == null ? null : RouteSafetyChild.fromJson(child),
      alerts: alerts == null ? null : RouteSafetyAlerts.fromJson(alerts),
      reaching: reaching == null ? null : RouteSafetyReach.fromJson(reaching),
    );
  }
}

class RouteSafetyRoute {
  RouteSafetyRoute({
    required this.name,
    required this.code,
    required this.published,
    required this.tripsMeasured,
    required this.checksDue,
    required this.closuresMeasured,
    required this.onTimeWithinSeconds,
    required this.minimumRuns,
    required this.notEnoughRuns,
    required this.checksCompletedRatePct,
    required this.everyChildAccountedForRatePct,
    required this.onTimeRatePct,
    required this.avgDelayMinutes,
  });

  final String? name;
  final String? code;
  final bool published;
  final int tripsMeasured;
  final int checksDue;
  final int closuresMeasured;
  final int onTimeWithinSeconds;
  final int minimumRuns;
  final bool notEnoughRuns;
  final double? checksCompletedRatePct;
  final double? everyChildAccountedForRatePct;
  final double? onTimeRatePct;
  final double? avgDelayMinutes;

  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
  static double? _d(dynamic v) => (v as num?)?.toDouble();

  factory RouteSafetyRoute.fromJson(Map<String, dynamic> j) => RouteSafetyRoute(
        name: j['name'] as String?,
        code: j['code'] as String?,
        published: (j['published'] ?? false) as bool,
        tripsMeasured: _i(j['tripsMeasured']),
        checksDue: _i(j['checksDue']),
        closuresMeasured: _i(j['closuresMeasured']),
        onTimeWithinSeconds: _i(j['onTimeWithinSeconds']),
        minimumRuns: _i(j['minimumRuns']),
        notEnoughRuns: (j['notEnoughRuns'] ?? false) as bool,
        checksCompletedRatePct: _d(j['checksCompletedRatePct']),
        everyChildAccountedForRatePct: _d(j['everyChildAccountedForRatePct']),
        onTimeRatePct: _d(j['onTimeRatePct']),
        avgDelayMinutes: _d(j['avgDelayMinutes']),
      );
}

class RouteSafetyChild {
  RouteSafetyChild({
    required this.tripsExpected,
    required this.tripsRidden,
    required this.noShows,
    required this.notExpected,
    required this.wrongPlace,
  });

  final int tripsExpected;
  final int tripsRidden;
  final int noShows;
  final int notExpected;
  final int wrongPlace;

  factory RouteSafetyChild.fromJson(Map<String, dynamic> j) => RouteSafetyChild(
        tripsExpected: RouteSafetyRoute._i(j['tripsExpected']),
        tripsRidden: RouteSafetyRoute._i(j['tripsRidden']),
        noShows: RouteSafetyRoute._i(j['noShows']),
        notExpected: RouteSafetyRoute._i(j['notExpected']),
        wrongPlace: RouteSafetyRoute._i(j['wrongPlace']),
      );
}

class RouteSafetyAlerts {
  RouteSafetyAlerts({
    required this.raised,
    required this.answered,
    required this.answeredRatePct,
    required this.typicalAnswerSeconds,
  });

  final int raised;
  final int answered;
  final double? answeredRatePct;
  final int? typicalAnswerSeconds;

  factory RouteSafetyAlerts.fromJson(Map<String, dynamic> j) => RouteSafetyAlerts(
        raised: RouteSafetyRoute._i(j['raised']),
        answered: RouteSafetyRoute._i(j['answered']),
        answeredRatePct: RouteSafetyRoute._d(j['answeredRatePct']),
        typicalAnswerSeconds: (j['typicalAnswerSeconds'] as num?)?.toInt(),
      );
}

class RouteSafetyReach {
  RouteSafetyReach({
    required this.sent,
    required this.delivered,
    required this.deliveredRatePct,
  });

  final int sent;
  final int delivered;
  final double? deliveredRatePct;

  factory RouteSafetyReach.fromJson(Map<String, dynamic> j) => RouteSafetyReach(
        sent: RouteSafetyRoute._i(j['sent']),
        delivered: RouteSafetyRoute._i(j['delivered']),
        deliveredRatePct: RouteSafetyRoute._d(j['deliveredRatePct']),
      );
}

class HomeArrival {
  HomeArrival({
    required this.studentId,
    required this.studentName,
    required this.tripId,
    required this.droppedOffAt,
    required this.offTheBus,
    required this.awaitingConfirmation,
    required this.confirmedAt,
    required this.confirmedByYou,
    required this.confirmedByName,
  });

  final String studentId;
  final String? studentName;
  final String tripId;
  final DateTime? droppedOffAt;
  final bool offTheBus;
  final bool awaitingConfirmation;
  final DateTime? confirmedAt;
  final bool confirmedByYou;
  final String? confirmedByName;

  static DateTime? _at(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

  factory HomeArrival.fromJson(Map<String, dynamic> j) => HomeArrival(
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String?,
        tripId: j['tripId'] as String,
        droppedOffAt: _at(j['droppedOffAt']),
        offTheBus: (j['offTheBus'] ?? false) as bool,
        awaitingConfirmation: (j['awaitingConfirmation'] ?? false) as bool,
        confirmedAt: _at(j['confirmedAt']),
        confirmedByYou: (j['confirmedByYou'] ?? false) as bool,
        confirmedByName: j['confirmedByName'] as String?,
      );
}

class HomeArrivalConfirmed {
  HomeArrivalConfirmed({
    required this.studentId,
    required this.tripId,
    required this.alreadyConfirmed,
    required this.confirmedAt,
    required this.confirmedByYou,
    required this.confirmedByName,
  });

  final String studentId;
  final String tripId;
  final bool alreadyConfirmed;
  final DateTime? confirmedAt;
  final bool confirmedByYou;
  final String? confirmedByName;

  factory HomeArrivalConfirmed.fromJson(Map<String, dynamic> j) => HomeArrivalConfirmed(
        studentId: j['studentId'] as String,
        tripId: j['tripId'] as String,
        alreadyConfirmed: (j['alreadyConfirmed'] ?? false) as bool,
        confirmedAt: HomeArrival._at(j['confirmedAt']),
        confirmedByYou: (j['confirmedByYou'] ?? false) as bool,
        confirmedByName: j['confirmedByName'] as String?,
      );
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

  Future<HouseholdOverview> household() async {
    final json = await _api.get('/parent/household') as Map<String, dynamic>;
    return HouseholdOverview.fromJson(json);
  }

  Future<HouseholdDay> householdDay({String? date}) async {
    final query = date == null ? '' : '?date=$date';
    final json = await _api.get('/parent/household/day$query') as Map<String, dynamic>;
    return HouseholdDay.fromJson(json);
  }

  Future<HouseholdConflicts> householdConflicts() async {
    final json = await _api.get('/parent/household/conflicts') as Map<String, dynamic>;
    return HouseholdConflicts.fromJson(json);
  }

  Future<RouteSafety> routeSafety(String studentId, {int days = 30}) async {
    final json = await _api.get('/parent/children/$studentId/safety?days=$days')
        as Map<String, dynamic>;
    return RouteSafety.fromJson(json);
  }

  Future<List<HomeArrival>> homeArrivals({String? studentId}) async {
    final query = studentId == null ? '' : '?studentId=$studentId';
    final json = await _api.get('/parent/home-arrivals$query') as Map<String, dynamic>;
    final rows = (json['rows'] as List?) ?? const [];
    return rows
        .map((r) => HomeArrival.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<HomeArrivalConfirmed> confirmHomeArrival({
    required String studentId,
    required String tripInstanceId,
    double? lat,
    double? lon,
    int? gpsAccuracyM,
  }) async {
    final withFix = lat != null && lon != null;
    final json = await _api.post('/parent/home-arrivals', {
      'studentId': studentId,
      'tripInstanceId': tripInstanceId,
      if (withFix) 'lat': lat,
      if (withFix) 'lon': lon,
      if (withFix && gpsAccuracyM != null) 'gpsAccuracyM': gpsAccuracyM,
    }) as Map<String, dynamic>;
    return HomeArrivalConfirmed.fromJson(json);
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

  Future<AttendanceTrend> attendanceTrend(String studentId, {String? termId}) async {
    final json = await _api.get(
      '/parent/children/$studentId/attendance/trend${termId == null ? '' : '?termId=$termId'}',
    ) as Map<String, dynamic>;
    return AttendanceTrend.fromJson(json);
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

  Future<ConsentBook> consents() async {
    final json = await _api.get('/parent/consents') as Map<String, dynamic>;
    return ConsentBook.fromJson(json);
  }

  Future<ConsentFormDetail> consentForm({
    required String policyVersionId,
    required String studentId,
  }) async {
    final json = await _api.get(
      '/parent/consents/$policyVersionId?studentId=${Uri.encodeQueryComponent(studentId)}',
    ) as Map<String, dynamic>;
    return ConsentFormDetail.fromJson(json);
  }

  Future<ConsentForm> signConsent({
    required String studentId,
    required String purpose,
    required String policyVersionId,
    required String answer,
    String? signatureMediaId,
  }) async {
    final json = await _api.post('/parent/consents/sign', {
      'studentId': studentId,
      'purpose': purpose,
      'policyVersionId': policyVersionId,
      'answer': answer,
      'signatureMediaId': ?signatureMediaId,
    });
    final form = json is Map<String, dynamic> ? json['form'] : null;
    if (form is! Map<String, dynamic>) {
      throw ApiException(t('consent.savedNoEcho'), 502);
    }
    return ConsentForm.fromJson(form);
  }

  Future<void> withdrawConsent({
    required String consentId,
    required String reason,
  }) async {
    await _api.post('/parent/consents/$consentId/withdraw', {'reason': reason.trim()});
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

const List<String> kConsentPurposes = [
  'PHOTO',
  'MEDICAL',
  'LOCATION',
  'COMMS',
  'BIOMETRIC',
  'OPERATOR_DATA_SHARING',
  'TRIP_AUDIO_RECORDING',
  'MARKETING',
];

const List<String> kConsentStatuses = [
  'GRANTED',
  'REFUSED',
  'WITHDRAWN',
  'EXPIRED',
  'SUPERSEDED',
];

const List<String> kConsentBodyLanguages = ['ckb', 'kmr', 'ar', 'en'];

String consentBodyLanguage() => switch (AppLocale.current.value) {
      Lang.ckb => 'ckb',
      Lang.ar => 'ar',
      Lang.en => 'en',
    };

class ConsentWording {
  const ConsentWording({required this.language, required this.text});

  final String language;
  final String text;

  bool get rightToLeft => language != 'en';
}

class ConsentForm {
  ConsentForm({
    required this.policyVersionId,
    required this.purpose,
    required this.key,
    required this.version,
    required this.languages,
    required this.awaitingAnswer,
    required this.canWithdraw,
    required this.signed,
    required this.sharedWith,
    this.retentionDays,
    this.status,
    this.consentId,
    this.answeredPolicyVersionId,
    this.channel,
    this.signedAt,
    this.grantedAt,
    this.withdrawnAt,
    this.withdrawalReason,
    this.scopeNote,
    this.effectiveFrom,
    this.effectiveTo,
    this.expiresAt,
    this.bodyCkb,
    this.bodyKmr,
    this.bodyAr,
    this.bodyEn,
  });

  final String policyVersionId;
  final String purpose;
  final String key;
  final int version;

  final int? retentionDays;

  final List<String> languages;

  final String? status;

  final bool awaitingAnswer;
  final bool canWithdraw;

  final String? consentId;
  final String? answeredPolicyVersionId;
  final String? channel;

  final bool signed;
  final DateTime? signedAt;
  final DateTime? grantedAt;
  final DateTime? withdrawnAt;
  final String? withdrawalReason;

  final List<String> sharedWith;
  final String? scopeNote;

  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final DateTime? expiresAt;

  final String? bodyCkb;
  final String? bodyKmr;
  final String? bodyAr;
  final String? bodyEn;

  bool get answered => status == 'GRANTED' || status == 'REFUSED';

  bool get granted => status == 'GRANTED';

  bool get recordedElsewhere =>
      status != null && channel != null && channel != 'MOBILE_APP';

  bool get onOlderWording =>
      answeredPolicyVersionId != null && answeredPolicyVersionId != policyVersionId;

  ConsentWording? get wording {
    for (final language in [consentBodyLanguage(), 'en', ...kConsentBodyLanguages]) {
      final text = bodyIn(language);
      if (text != null) return ConsentWording(language: language, text: text);
    }
    return null;
  }

  String? bodyIn(String language) {
    final raw = switch (language) {
      'ckb' => bodyCkb,
      'kmr' => bodyKmr,
      'ar' => bodyAr,
      'en' => bodyEn,
      _ => null,
    };
    if (raw == null) return null;
    final text = raw.trim();
    return text.isEmpty ? null : text;
  }

  factory ConsentForm.fromJson(Map<String, dynamic> j) => ConsentForm(
        policyVersionId: (j['policyVersionId'] ?? '') as String,
        purpose: (j['purpose'] ?? '') as String,
        key: (j['key'] ?? '') as String,
        version: (j['version'] as num?)?.toInt() ?? 0,
        retentionDays: (j['retentionDays'] as num?)?.toInt(),
        languages: ((j['languages'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        status: j['status'] as String?,
        awaitingAnswer: (j['awaitingAnswer'] ?? false) as bool,
        canWithdraw: (j['canWithdraw'] ?? false) as bool,
        consentId: j['consentId'] as String?,
        answeredPolicyVersionId: j['answeredPolicyVersionId'] as String?,
        channel: j['channel'] as String?,
        signed: (j['signed'] ?? false) as bool,
        signedAt: DateTime.tryParse((j['signedAt'] ?? '') as String)?.toLocal(),
        grantedAt: DateTime.tryParse((j['grantedAt'] ?? '') as String)?.toLocal(),
        withdrawnAt: DateTime.tryParse((j['withdrawnAt'] ?? '') as String)?.toLocal(),
        withdrawalReason: j['withdrawalReason'] as String?,
        sharedWith: ((j['sharedWith'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        scopeNote: j['scopeNote'] as String?,
        effectiveFrom: DateTime.tryParse((j['effectiveFrom'] ?? '') as String)?.toLocal(),
        effectiveTo: DateTime.tryParse((j['effectiveTo'] ?? '') as String)?.toLocal(),
        expiresAt: DateTime.tryParse((j['expiresAt'] ?? '') as String)?.toLocal(),
        bodyCkb: j['bodyCkb'] as String?,
        bodyKmr: j['bodyKmr'] as String?,
        bodyAr: j['bodyAr'] as String?,
        bodyEn: j['bodyEn'] as String?,
      );
}

class ChildConsents {
  ChildConsents({
    required this.studentId,
    required this.code,
    required this.name,
    required this.awaitingCount,
    required this.forms,
  });

  final String studentId;
  final String code;
  final String name;
  final int awaitingCount;
  final List<ConsentForm> forms;

  factory ChildConsents.fromJson(Map<String, dynamic> j) => ChildConsents(
        studentId: (j['studentId'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        awaitingCount: (j['awaitingCount'] as num?)?.toInt() ?? 0,
        forms: ((j['forms'] as List?) ?? const [])
            .map((e) => ConsentForm.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ConsentBook {
  ConsentBook({
    required this.children,
    required this.awaitingCount,
    required this.signatureRequiredToAgree,
  });

  final List<ChildConsents> children;
  final int awaitingCount;
  final bool signatureRequiredToAgree;

  factory ConsentBook.fromJson(Map<String, dynamic> j) => ConsentBook(
        children: ((j['children'] as List?) ?? const [])
            .map((e) => ChildConsents.fromJson(e as Map<String, dynamic>))
            .toList(),
        awaitingCount: (j['awaitingCount'] as num?)?.toInt() ?? 0,
        signatureRequiredToAgree: (j['signatureRequiredToAgree'] ?? true) as bool,
      );
}

class ConsentFormDetail {
  ConsentFormDetail({
    required this.studentId,
    required this.code,
    required this.name,
    required this.signatureRequiredToAgree,
    required this.form,
  });

  final String studentId;
  final String code;
  final String name;
  final bool signatureRequiredToAgree;
  final ConsentForm form;

  factory ConsentFormDetail.fromJson(Map<String, dynamic> j) {
    final child = (j['child'] as Map<String, dynamic>?) ?? const {};
    return ConsentFormDetail(
      studentId: (child['studentId'] ?? '') as String,
      code: (child['code'] ?? '') as String,
      name: (child['name'] ?? '') as String,
      signatureRequiredToAgree: (j['signatureRequiredToAgree'] ?? true) as bool,
      form: ConsentForm.fromJson((j['form'] as Map<String, dynamic>?) ?? const {}),
    );
  }
}
