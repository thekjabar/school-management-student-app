import 'client.dart';

/// One child on this guardian's account.
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

/// Everything the school has written down about one child.
///
/// The office answers this on the telephone a dozen times a term. This is that
/// answer, in the app: her names as enrolled, her class, who teaches her, who
/// else is on the account, and what the medical card says.
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

/// One of the adults the school will ring.
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

  /// So the list reads as "you and her mother", not two strangers.
  final bool isYou;

  factory GuardianOnAccount.fromJson(Map<String, dynamic> j) => GuardianOnAccount(
        name: (j['name'] ?? '') as String,
        relationship: (j['relationship'] ?? '') as String,
        isPrimary: (j['isPrimary'] ?? false) as bool,
        isYou: (j['isYou'] ?? false) as bool,
      );
}

/// The medical card, shown back to the family who supplied it.
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

  /// Medical information ages badly, and a card nobody has looked at since
  /// year one is worse than no card, because everyone assumes it is current.
  bool get needsReview =>
      reviewDueAt != null && reviewDueAt!.isBefore(DateTime.now());

  bool get isEmpty =>
      flags.isEmpty &&
      (actionText == null || actionText!.isEmpty) &&
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

/// What the school has arranged for this child on the bus and at the door.
class SupportSummary {
  SupportSummary({
    required this.escortRequired,
    required this.wheelchairVehicleRequired,
    required this.fixedSeat,
    required this.doNotReleaseAlone,
  });

  final bool escortRequired;
  final bool wheelchairVehicleRequired;

  /// The seat label where there is one, `true` for "a fixed seat, unnamed",
  /// null for no such arrangement.
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

/// One of the crew who actually carried this child recently.
///
/// Offered in the feedback form so a parent can pick a name instead of
/// describing a man. Drawn from the journeys the child was manifested on, not
/// from the roster — the roster says who was supposed to drive.
class RecentCrew {
  RecentCrew({
    required this.personId,
    required this.name,
    required this.role,
    required this.lastRodeOn,
  });

  final String personId;
  final String name;

  /// `DRIVER` or `ATTENDANT`.
  final String role;

  /// The last day this person carried the child, which is what a parent
  /// recognises them by.
  final DateTime? lastRodeOn;

  factory RecentCrew.fromJson(Map<String, dynamic> j) => RecentCrew(
        personId: j['personId'] as String,
        name: (j['name'] ?? '') as String,
        role: (j['role'] ?? '') as String,
        lastRodeOn: DateTime.tryParse((j['lastRodeOn'] ?? '') as String),
      );
}

/// Something a family has said about the crew, and where it got to.
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

  /// `PRAISE` or `CONCERN`.
  final String sentiment;
  final List<String> topics;
  final String? comment;
  final DateTime? occurredOn;

  /// `MORNING`, `AFTERNOON` or `UNSPECIFIED`.
  final String direction;

  /// `NEW`, `UNDER_REVIEW`, `RESOLVED`, `ESCALATED` or `CLOSED_NO_ACTION`.
  final String status;
  final DateTime? submittedAt;
  final String? crewName;

  bool get isPraise => sentiment == 'PRAISE';

  /// The office has finished with it, whatever it decided. What it decided is
  /// deliberately not sent to the family.
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

/// A day at school the family can look at, and the pictures from it.
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

/// One photograph or clip the child is in.
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

  /// For laying the grid out before the image has loaded. Falls back to square,
  /// which is wrong for nothing badly.
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

/// Where the family lives, as the school holds it.
///
/// The note matters more than the pin. Addressing here is landmark-based
/// rather than street-based — "the blue gate opposite the bakery" is how
/// somebody is actually found, and it is what a driver reads. The coordinates
/// are for the planner choosing which stop the child uses.
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

  /// What the address led to: the stop each child is actually assigned.
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

/// The stops one child rides between.
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

/// A planned stop, with the description the crew actually navigates by.
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

/// A lesson in the week.
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
      // The server sends this already resolved. The Map branch is the old
      // shape, kept so a not-yet-updated handset keeps working for one release.
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

/// What the school has said about how a child conducts themselves.
///
/// Merits and concerns arrive together and are shown together. A family given
/// only the concerns is handed a record of a difficult child; given only the
/// merits, they are handed nothing they can act on.
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

  /// MERIT, CONCERN or INCIDENT.
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

/// The standing tally, computed over every record rather than the page in hand
/// — a parent scrolling to page two should not watch the totals change.
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

  /// One word for the whole picture, for the figure strip on the home screen.
  /// Deliberately generous at the top: a child with a handful of merits and no
  /// concerns is doing well, and saying so is the point of showing it.
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

  /// The mark side of a piece of homework, which the list never showed.
  ///
  /// The API has been returning these all along; the model dropped them, so a
  /// parent could see that work existed and never what became of it.
  final DateTime? submittedAt;
  final num? score;
  final num? maxScore;
  final String? feedback;

  bool get handedIn => submittedAt != null;

  /// Negative when it is late. The screens render the word, not the number.
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
      // The server sends this already resolved. The Map branch is the old
      // shape, kept so a not-yet-updated handset keeps working for one release.
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
  });

  final String id;
  final num? score;
  final num maxScore;
  final num? percent;
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
      gradeLetter: j['gradeLetter'] as String?,
      isPass: j['isPass'] as bool?,
      wasAbsent: (j['wasAbsent'] ?? false) as bool,
      examTitle: (exam['title'] ?? 'Test') as String,
      // Under `exam`, not at the top level: a result row has no subject of
      // its own, it inherits the exam's.
      subject: _subjectOf(exam),
      colorHex: _colorOf(exam),
      date: DateTime.parse((exam['date'] ?? DateTime.now().toIso8601String()) as String).toLocal(),
    );
  }
}

class UpcomingExam {
  UpcomingExam({
    required this.id,
    required this.title,
    required this.subject,
    required this.colorHex,
    required this.date,
    required this.startMinute,
    required this.room,
  });

  final String id;
  final String title;
  final String subject;
  final String? colorHex;
  final DateTime date;
  final int? startMinute;
  final String? room;

  factory UpcomingExam.fromJson(Map<String, dynamic> j) {
    return UpcomingExam(
      id: j['id'] as String,
      title: (j['title'] ?? 'Test') as String,
      subject: _subjectOf(j),
      colorHex: _colorOf(j),
      date: DateTime.parse(j['date'] as String).toLocal(),
      startMinute: (j['startMinute'] as num?)?.toInt(),
      room: j['room'] as String?,
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

/// One of today's two runs, from the child's point of view.
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
      );

  /// What actually happened to this child on this run, said plainly.
  String get childLine {
    if (boardedAt != null && alightedAt != null) {
      return leg == 'OUT' ? 'Arrived at school' : 'Dropped off';
    }
    if (boardedAt != null) return 'On the bus';
    if (resolution == 'NO_SHOW') return 'Did not board';
    if (resolution == 'EXCUSED') return 'Excused — not riding';
    if (status == 'PLANNED' || status == 'ROSTERED') return 'Not started yet';
    return 'Waiting at the stop';
  }
}

/// A child's bus arrangement plus today's two runs.
class TransportInfo {
  TransportInfo({
    required this.ridesTheBus,
    required this.routeName,
    required this.routeColorHex,
    required this.seatNumber,
    required this.pickupStopName,
    required this.pickupLandmark,
    required this.dropoffStopName,
    required this.dropoffLandmark,
    required this.today,
  });

  final bool ridesTheBus;
  final String? routeName;
  final String? routeColorHex;
  final String? seatNumber;
  final String? pickupStopName;
  final String? pickupLandmark;
  final String? dropoffStopName;
  final String? dropoffLandmark;
  final List<TripToday> today;

  factory TransportInfo.fromJson(Map<String, dynamic> j) {
    final route = j['route'] as Map<String, dynamic>?;
    final pickup = j['pickupStop'] as Map<String, dynamic>?;
    final dropoff = j['dropoffStop'] as Map<String, dynamic>?;
    return TransportInfo(
      ridesTheBus: (j['ridesTheBus'] ?? false) as bool,
      routeName: route?['name'] as String?,
      routeColorHex: route?['colorHex'] as String?,
      seatNumber: j['seatNumber'] as String?,
      pickupStopName: pickup?['name'] as String?,
      pickupLandmark: pickup?['landmarkDescription'] as String?,
      dropoffStopName: dropoff?['name'] as String?,
      dropoffLandmark: dropoff?['landmarkDescription'] as String?,
      today: ((j['today'] as List?) ?? [])
          .map((e) => TripToday.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Where the bus is right now — or an honest reason why not.
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

  /// Where the stop is, so the map can draw it. Null on a stop the office has
  /// not placed yet, which is ordinary in a first term.
  final double? stopLat;
  final double? stopLon;

  /// Where the CHILD is, which is not the same question as where the bus is.
  ///
  /// `WAITING`, `ON_BOARD`, `ARRIVED` or `NOT_RIDING`. Null when the server is
  /// WITHHOLDING the answer rather than answering "no" — a guardian without
  /// location permission is being told nothing, not being told she is off the
  /// bus, and the screen must not render those the same way.
  final String? childState;
  final DateTime? boardedAt;
  final DateTime? alightedAt;

  /// Which way the bus is pointing, for the marker.
  final double? headingDeg;
  final double? speedKph;

  final String? busLabel;
  final String? plate;
  final String? driverName;

  /// This position was GENERATED, not reported by a bus on a road.
  ///
  /// Only ever true on a tenant the platform marks as a demonstration; a real
  /// school never receives a simulated position at all. It must be rendered as
  /// something nobody can miss — the entire reason for carrying the flag is
  /// that a person must not mistake a rehearsal for their child.
  final bool simulated;

  /// She is aboard right now. The only state in which the bus marker is also
  /// the child marker.
  bool get onBoard => childState == 'ON_BOARD';

  /// The bus has a position worth drawing.
  bool get hasFix => visible && lat != null && lon != null;

  /// The reasons, in words a parent should read rather than an enum.
  String get reasonText {
    switch (reason) {
      case 'no_trip_today':
        return 'No bus for this child today.';
      case 'outside_window':
        return 'The map opens twenty minutes before the bus is due.';
      case 'trip_not_started':
        return 'The bus has not set off yet.';
      case 'already_handed_over':
        return 'Already handed over — the map closes then.';
      case 'phone_not_verified':
        return 'Your number is not verified. Ask the school office.';
      case 'location_not_permitted':
        return 'The school has not granted location for this child.';
      case 'no_position_yet':
        return 'The bus has not reported a position yet.';
      default:
        return 'The map is closed at the moment.';
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

/// One approved alternative address for a child.
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

/// Everything the parent app asks the platform for.
///
/// One class rather than a call scattered across widgets, so that when an
/// endpoint moves there is exactly one place to change — and so the screens
/// read as screens rather than as HTTP.
class ParentApi {
  ParentApi._();

  static final ParentApi instance = ParentApi._();
  final ApiClient _api = ApiClient.instance;

  Future<List<Child>> children() async {
    final json = await _api.get('/parent/children');
    return (json as List).map((e) => Child.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Who has actually carried this child lately, so the feedback form can
  /// offer a name rather than a text box.
  Future<List<RecentCrew>> recentCrew(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/recent-crew');
    return (json as List)
        .map((e) => RecentCrew.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// What this parent has already said about the crew, and where it got to.
  Future<List<CrewFeedbackItem>> crewFeedback(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/crew-feedback?pageSize=50');
    return Paged.from<CrewFeedbackItem>(json, CrewFeedbackItem.fromJson).rows;
  }

  /// Send praise or a concern to the school office.
  ///
  /// [topics] may be empty and [comment] may be null against praise; the server
  /// insists on a comment for a concern, since the office cannot look into
  /// "he was rude" without knowing what happened.
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

  /// Photographs of this child at school, newest day first.
  Future<List<MemoryAlbum>> memories(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/memories?pageSize=24');
    return Paged.from<MemoryAlbum>(json, MemoryAlbum.fromJson).rows;
  }

  /// Where the school thinks this family lives, and the stops that produced.
  Future<HomeLocation> homeLocation() async {
    final json = await _api.get('/parent/home') as Map<String, dynamic>;
    return HomeLocation.fromJson(json);
  }

  /// Tell the school where home is.
  ///
  /// This does NOT move a child's bus stop — a route is planned and sequenced,
  /// and the office decides which stop each child uses. It is what they read
  /// when deciding.
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

  /// The child's own record, as the school holds it.
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

/// What the school has published about this child's conduct.
  Future<AttitudeSummary> attitude(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/attitude') as Map<String, dynamic>;
    return AttitudeSummary.fromJson(json);
  }

  /// "I have seen this." Recorded so the office knows whether a concern
  /// actually reached the family before they telephone about it.
  Future<void> markAttitudeSeen(String id) async {
    await _api.post('/parent/attitude/$id/seen');
  }

  Future<AttendanceSummary> attendance(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/attendance') as Map<String, dynamic>;
    return AttendanceSummary.fromJson(json);
  }

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
  }) async {
    await _api.post('/parent/leave-requests', {
      'studentId': studentId,
      'kind': kind,
      'fromDate': _dateOnly(from),
      'toDate': _dateOnly(to),
      'reason': reason,
    });
  }

  Future<void> cancelLeave(String id) => _api.post('/parent/leave-requests/$id/cancel');

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

  /// Days the child will not be riding — the transport half of a leave request,
  /// and separately requestable for the days a family drives them in themselves.
  Future<List<Map<String, dynamic>>> skipRides() async {
    final json = await _api.get('/parent/skip-rides?pageSize=50');
    return Paged.from<Map<String, dynamic>>(json, (m) => m).rows;
  }

  Future<List<Announcement>> announcements() async {
    final json = await _api.get('/parent/announcements?pageSize=50');
    return Paged.from<Announcement>(json, Announcement.fromJson).rows;
  }

  Future<FeeSummary> fees() async {
    final json = await _api.get('/parent/fees') as Map<String, dynamic>;
    return FeeSummary.fromJson(json);
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// A notice from the school office.
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
    required this.authorName,
    required this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final String priority;
  final DateTime? sentAt;
  final bool pinned;
  final bool requiresAcknowledgement;
  final String authorName;
  final DateTime? readAt;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        category: (j['category'] ?? 'ANNOUNCEMENT') as String,
        priority: (j['priority'] ?? 'NORMAL') as String,
        sentAt: j['sentAt'] == null ? null : DateTime.parse(j['sentAt'] as String).toLocal(),
        pinned: (j['pinned'] ?? false) as bool,
        requiresAcknowledgement: (j['requiresAcknowledgement'] ?? false) as bool,
        authorName: (j['authorName'] ?? '') as String,
        readAt: j['readAt'] == null ? null : DateTime.parse(j['readAt'] as String).toLocal(),
      );
}

/// One month's bill.
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

/// What the household owes, and when.
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


/* ---------------------------------------------------------------------------
 * Subject naming
 *
 * The API resolves a subject's name server-side from the X-Lang header and
 * sends one finished string. These helpers exist only to keep a handset that
 * has not updated yet working against the new server for one release — the Map
 * branch reads the old {name, nameEn, ...} shape.
 *
 * Delete both once the old APK is out of circulation.
 * ------------------------------------------------------------------------- */

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
