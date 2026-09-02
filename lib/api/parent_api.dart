import '../i18n/strings.dart';
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

/// One report card the school has published, as it appears in the list.
///
/// A DOCUMENT rather than a live view: the figures were frozen when the school
/// generated it, and a correction arrives as a new [version] rather than as an
/// edit to this one. Almost every figure on it is separately nullable, because
/// a school prints what it prints — a card with a rank and no class size, or
/// attendance and no GPA, is ordinary.
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

  /// Null on the whole-year document. [wholeYear] says so outright.
  final String? termId;
  final String? termName;
  final bool wholeYear;

  final String academicYearName;

  /// Nullable: a card need not name the class it was written for.
  final String? className;
  final int subjectCount;

  final num? overallScore;

  /// The word the school printed — 'B+', or a Kurdish word. Not translated,
  /// not derived from [overallScore], and never rewritten here.
  final String? overallGrade;
  final num? gpa;
  final int? classRank;
  final int? classSize;
  final int? daysPresent;
  final int? daysAbsent;
  final int? daysLate;
  final int? daysExcused;

  /// THREE states. null is 'the school printed no promotion decision', which
  /// is not 'not promoted' and must never be shown as it.
  final bool? promoted;

  final DateTime publishedAt;

  /// Null until this family first opens the card. It is the flag the office
  /// checks before telephoning a family who says the report never arrived.
  final DateTime? openedAt;

  /// The school attached a rendered document. It is NOT a promise that anyone
  /// can fetch it: there is no parent-facing route that serves a report-card
  /// PDF, and the address on the detail can be null even when this is true.
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

/// One line of a report card: what the child got in one subject.
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

  /// Already in the reader's language, and on a card it is the label FROZEN
  /// onto the line when the document was generated — which wins over the
  /// subject's name today, so a subject renamed in March does not rewrite a
  /// report a family printed in January. Never passed through t().
  final String subject;
  final String subjectId;
  final String? colorHex;

  /// null is 'no mark'; 0 is a mark of nothing. They are different answers.
  final num? score;
  final num maxScore;
  final num? percent;
  final String? gradeLetter;
  final num? gradePoint;

  /// THREE states, as on [ReportCardSummary.promoted].
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

/// One report card with every subject line on it.
///
/// Not an upgraded [ReportCardSummary] — the two shapes are different answers.
/// The list has a subject count and no lines; this has the lines, the two
/// written comments, and an opened-at that is never null, because asking for
/// this is what sets it.
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

  /// Written by the class teacher and by the principal, in whatever language
  /// they typed. School text: shown verbatim.
  final String? homeroomComment;
  final String? principalComment;

  final DateTime publishedAt;

  /// Never null here: the server answers with the moment it stamped.
  final DateTime openedAt;

  /// The object-store address of the rendered document, when there is one.
  /// Nothing in the app fetches it: no parent-facing route serves a report-card
  /// PDF, and the asset's own schema says the document must not be publicly
  /// fetchable. Carried so the shape matches the server, not so it can be
  /// opened.
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

/// The grade the school released for one subject in one term.
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

  /// Translated by the server, in the language the request asked for.
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

/// One term of released grades, grouped by the server.
///
/// The grouping is not the app's: 'her second term' is the unit a family
/// thinks in, and forty subject rows across three terms is a list nobody
/// reads. The counts and the average come with it, so nothing here has to be
/// worked out from the subjects — and must not be. Subjects appear as the
/// school releases them, so four of nine is a correct answer and the five that
/// are absent are not failures.
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

  /// Plain calendar days, kept in UTC on purpose. These are date columns and
  /// arrive as UTC midnight; moving them to the phone's zone would slide the
  /// first and last day of a term across a date boundary west of Greenwich.
  final DateTime startsOn;
  final DateTime endsOn;

  final String academicYearName;
  final String className;
  final int subjectCount;

  /// Passed plus failed need NOT be [subjectCount]: a subject the school left
  /// unjudged is in neither.
  final int subjectsPassed;
  final int subjectsFailed;

  /// The school's own mean of the released percentages. Null when no subject
  /// in the term carries one.
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

/// One exam the school has already put in the diary for the child's class.
///
/// The opposite end of [ExamResultItem]: this is a date still to come, that is
/// a mark already published for one already sat. The two arrive from different
/// routes and mean different things to a family, and nothing here merges them.
///
/// It belongs to the CLASS rather than to the child, so every subject the class
/// is scheduled to sit comes back — including any this child does not.
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

  /// QUIZ, MONTHLY, MIDTERM, FINAL, NATIONAL, PRACTICAL, ORAL or MAKEUP.
  final String kind;

  /// Genuinely absent on plenty of rows: the column is nullable and the
  /// translation overlay can only REPLACE a title, never invent one.
  ///
  /// It used to be defaulted to the English word 'Test', which put an
  /// untranslated string on a Kurdish screen every time a teacher scheduled an
  /// exam without naming it. A screen falls back to [subject] instead, which is
  /// what the school would have called it anyway.
  final String? title;

  /// Flat and already in the reader's language on this route.
  final String subject;
  final String? colorHex;

  /// The day of the exam. The server sends a plain date at UTC midnight, so
  /// only the day part means anything.
  final DateTime date;

  final int? startMinute;
  final int? durationMin;
  final String? room;
  final num maxScore;

  /// The kind of exam as an i18n key, so the screen says it in the parent's
  /// language rather than in the API's vocabulary.
  ///
  /// Null for a kind this build has no word for. A ninth kind added to the
  /// server later must not reach a phone as a raw MAKEUP-shaped enum; the row
  /// simply says less.
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

  /// What actually happened to this child on this run — as an i18n key, so
  /// the screen says it in the parent's language rather than in English.
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
  ///
  /// These were hard-coded English on a screen that exists in three languages,
  /// and — worse — half of them were names the server has never sent. It
  /// answers window_not_open_yet, trip_ended, already_alighted, no_fix_yet,
  /// no_bus_assigned, no_schedule, trip_cancelled and simulated_feed_withheld;
  /// this switch was matching outside_window, trip_not_started,
  /// already_handed_over and no_position_yet. Every one of those fell past the
  /// cases to "The map is closed at the moment", which tells a parent nothing
  /// about a child on a bus.
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

  /// The exams already scheduled for the child's class, soonest first.
  ///
  /// No query string, because the endpoint declares none: no page size, no date
  /// window, no way to ask for a fifty-first row. Whatever the school has put in
  /// the diary arrives capped at fifty, and there is no "show more" a screen
  /// could honestly offer.
  ///
  /// Draft exams never appear, and a cancelled one stops appearing rather than
  /// arriving flagged — so an exam a family saw yesterday can simply be gone,
  /// with nothing for the app to hang an explanation on.
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

  /// The report cards the school has actually published for this child.
  ///
  /// Published ones only. A card the office is withholding, one that a newer
  /// version has replaced, and one that was never generated all arrive the same
  /// way — absent — so nothing above this may say the school produced none.
  ///
  /// No paging: the server takes forty and reads no page parameter. Forty
  /// published cards is most of a childhood.
  Future<List<ReportCardSummary>> reportCards(String studentId) async {
    final json = await _api.get('/parent/children/$studentId/report-cards');
    return (json as List)
        .map((e) => ReportCardSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// One card, with every subject line on it.
  ///
  /// Calling this IS the receipt. The server stamps the moment the family first
  /// opened the card as a side effect of answering, once and never again, and
  /// there is no acknowledgement to send afterwards. So it is called when a
  /// parent opens a card and at no other time: filling a list from it, or
  /// fetching a card ahead of a tap, would sign for a report nobody read.
  ///
  /// Retrying is safe — the stamp is written only while it is still empty, so a
  /// second read cannot move the date the office quotes back to a family.
  ///
  /// 404 'That report card is not available.' answers every reason at once: no
  /// such card, another child's, withheld, superseded, unpublished. The caller
  /// must not guess which.
  Future<ReportCardDetail> reportCard(String studentId, String id) async {
    final json = await _api.get('/parent/children/$studentId/report-cards/$id')
        as Map<String, dynamic>;
    return ReportCardDetail.fromJson(json);
  }

  /// The term grades the school has released, grouped by term.
  ///
  /// The row the school stands behind: it survives a re-mark and carries the
  /// weighting that produced it, which is what makes it worth showing instead
  /// of an average of exam marks worked out on the phone.
  ///
  /// [termId] filters server-side. It is worth knowing that a term id the
  /// server does not recognise is not an error there — it answers with an empty
  /// list — and that nothing in the API lists a family's terms, so a screen
  /// offering a term picker has to build it from the terms in an unfiltered
  /// answer. An empty string is dropped rather than sent, since the server
  /// would read it as no filter at all.
  Future<List<TermGradeGroup>> termGrades(String studentId, {String? termId}) async {
    final filter = (termId == null || termId.isEmpty) ? '' : '?termId=$termId';
    final json = await _api.get('/parent/children/$studentId/term-grades$filter');
    return (json as List)
        .map((e) => TermGradeGroup.fromJson(e as Map<String, dynamic>))
        .toList();
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

  /// The register for a window, or for the term when none is given.
  ///
  /// from and to are what the endpoint has always accepted; nothing asked for
  /// them until the home card's period picker did.
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

  /// Plain calendar days. The server is comparing against a date column, so an
  /// instant with a time on it would drop the first or last day depending on
  /// which side of midnight the phone happens to be.
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
  }) async {
    final why = reason.trim();
    await _api.post('/parent/leave-requests', {
      'studentId': studentId,
      'kind': kind,
      'fromDate': _dateOnly(from),
      'toDate': _dateOnly(to),
      // Left out when blank, never sent empty. The sheet labels the reason
      // optional and the DTO agrees - but it is @Length(2, 500) WHEN PRESENT,
      // so an empty string was refused and a parent who simply had nothing to
      // add could not report their child away at all.
      'reason': ?(why.isEmpty ? null : why),
    });
  }

  Future<void> cancelLeave(String id) => _api.post('/parent/leave-requests/$id/cancel');

  /// Say the notice has been read and understood.
  ///
  /// Some of these decide who may collect a child, which is why the server
  /// takes the person from the token and offers no field to name somebody else.
  /// The app had the button and never made the call: "Got it" closed the sheet
  /// and nothing else, so a parent believed they had replied and the office's
  /// list of who had not answered still had their name on it.
  ///
  /// Acknowledging twice is a success on the server, so a second tap after a
  /// dropped connection is safe.
  Future<void> acknowledgeAnnouncement(String id) =>
      _api.post('/parent/announcements/$id/acknowledge', const <String, dynamic>{});

  // ---- Asking the office to correct your own details ----------------------
  //
  // Under /auth, not /parent: the gateway sends /api/auth/ to identity-service,
  // which owns people, and /api/parent/ to students-service, which does not.
  // The same path under the wrong prefix is a 404 in production and works
  // perfectly against a laptop.

  /// The corrections this person has asked for, newest first.
  Future<List<ProfileChange>> profileChanges() async {
    final json = await _api.get('/auth/profile/change-requests');
    final rows = json is Map ? (json['rows'] as List?) ?? const [] : (json as List?) ?? const [];
    return rows.map((e) => ProfileChange.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Ask the office to correct one or more of your own details.
  ///
  /// Every argument is optional and only what is passed is asked for. An empty
  /// string clears a field; leaving it null means "not changing this one".
  ///
  /// The phone number is deliberately absent. It is how a person signs in and
  /// how the school knows who may collect their child, so it has its own
  /// request with a confirmation code, and the server refuses it here by name.
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

  /// Withdraw a correction the office has not answered yet.
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

  /// "I have read this one."
  ///
  /// Scoped to the caller by the server: a guardian marks their own reading,
  /// never the other parent's. Idempotent, so a second tap on a notice already
  /// read is a success rather than an error — which is what lets the screen
  /// fire this on every open without first checking.
  Future<void> markAnnouncementRead(String id) async {
    await _api.post('/parent/announcements/$id/read');
  }

  /// Mark every notice this guardian can see as read.
  ///
  /// Answers with how many rows actually CHANGED — the ones already read are
  /// not counted again — so the screen can say something true afterwards
  /// instead of repeating the number it optimistically ticked off itself.
  Future<int> markAllAnnouncementsRead() async {
    final json = await _api.post('/parent/announcements/read-all');
    return json is Map ? ((json['marked'] as num?)?.toInt() ?? 0) : 0;
  }

  Future<FeeSummary> fees() async {
    final json = await _api.get('/parent/fees') as Map<String, dynamic>;
    return FeeSummary.fromJson(json);
  }

  /// What this school will accept as a payment notice, and where to send the
  /// money. Asked BEFORE any form is drawn, because a school that has switched
  /// self-declaration off should be shown its own bank details and a telephone
  /// number, not a send button.
  ///
  /// Null means this platform does not answer the parent money routes at all.
  /// The gateway forwards `/parent/fees` to the money service by name and
  /// sends everything else under `/parent/` to the students service, which has
  /// no such handler and answers 404 — so `/parent/payments`, `/parent/receipts`
  /// and `/parent/invoices` are unreachable until three lines are added to it.
  /// Rather than let a parent meet three tabs of dead controls, the screen asks
  /// this one question first and draws only what the platform in front of it
  /// can actually answer. The day the gateway learns those paths, the rest of
  /// the screen appears without an app release.
  Future<PaymentOptions?> paymentOptions() async {
    try {
      final json = await _api.get('/parent/payments/options') as Map<String, dynamic>;
      return PaymentOptions.fromJson(json);
    } on ApiException catch (e) {
      // Only a 404 means "nothing here". A 403, a 502 or a timeout is a real
      // answer about a route that exists, and belongs on screen as one.
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Every payment recorded against this household — the ones the office
  /// entered as well as the ones the family declared.
  ///
  /// Deliberately unfiltered. The route understands only `pending` and
  /// `confirmed`; any other value is ignored and the whole list comes back
  /// anyway, so a "Rejected" filter sent to the server would look as though it
  /// had worked and quietly show everything. Whatever the screen narrows, it
  /// narrows here on the phone.
  ///
  /// Fifty is the server's ceiling, not a preference: asking for a hundred
  /// silently yields fifty, so the count is asked for honestly and the screen
  /// says when there is more than it is showing.
  Future<Paged<DeclaredPayment>> payments({int pageSize = 50}) async {
    final json = await _api.get('/parent/payments?pageSize=$pageSize');
    return Paged.from<DeclaredPayment>(json, DeclaredPayment.fromJson);
  }

  /// The family's own receipts.
  ///
  /// Cancelled ones are left out by the server, which is what makes every row
  /// here openable. The stubs hanging off a payment are not filtered that way,
  /// so those are checked one by one instead.
  Future<Paged<PaymentReceipt>> receipts({int pageSize = 50}) async {
    final json = await _api.get('/parent/receipts?pageSize=$pageSize');
    return Paged.from<PaymentReceipt>(json, PaymentReceipt.fromJson);
  }

  /// A link to the receipt as the office would print it.
  ///
  /// The first open renders the PDF and stores it, so it can be slow; the link
  /// it answers with lives ten minutes, so it is fetched on every open and
  /// never kept.
  Future<StoredDocument> receiptPdf(String receiptId) async {
    final json = await _api.get('/parent/receipts/$receiptId/pdf') as Map<String, dynamic>;
    return StoredDocument.fromJson(json);
  }

  /// The same for a bill. A draft has never been issued and has no PDF, so the
  /// screen does not offer this on one.
  Future<StoredDocument> invoicePdf(String invoiceId) async {
    final json = await _api.get('/parent/invoices/$invoiceId/pdf') as Map<String, dynamic>;
    return StoredDocument.fromJson(json);
  }

  /// Tell the school a payment has been made.
  ///
  /// A notice, not a payment. It lands awaiting confirmation and moves no
  /// balance until somebody at the office says so — which is the whole point:
  /// an unverified screenshot must not settle a bill, and a family that cannot
  /// see what it has already told the school pays twice.
  ///
  /// Exactly one of [invoiceId] and [studentId] is sent, and one of them always
  /// is. A guardian whose children are in two households — after a separation,
  /// or a remarriage — is refused outright when neither is named, because the
  /// office cannot tell which household the money is for either. Sending both
  /// risks the server's "that bill belongs to a different household".
  ///
  /// [idempotencyKey] is made once when the form opens rather than once per
  /// tap: that is what turns a second tap on a bad connection into a replay
  /// instead of a second claim the office has to unpick. A 409 means two
  /// identical claims raced each other past the server's own replay lookup —
  /// the same good outcome through a different door, so it is not an error.
  Future<void> declarePayment({
    required int amountIqd,
    required String method,
    required String idempotencyKey,
    String? invoiceId,
    String? studentId,
    DateTime? paidAt,
    String? reference,
    String? notes,
  }) async {
    final ref = reference?.trim() ?? '';
    final note = notes?.trim() ?? '';
    try {
      await _api.post('/parent/payments', {
        'amountIqd': amountIqd,
        'method': method,
        'idempotencyKey': idempotencyKey,
        // An empty string fails every one of these validators, so a field the
        // parent did not fill in is left out of the body rather than sent
        // blank. The server has its own defaults for all of them.
        if (invoiceId != null && invoiceId.isNotEmpty) 'invoiceId': invoiceId,
        if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
        if (paidAt != null) 'paidAt': paidAt.toUtc().toIso8601String(),
        if (ref.isNotEmpty) 'reference': ref,
        // Two characters is the server's floor for a note; one is refused.
        if (note.length >= 2) 'notes': note,
      });
    } on ApiException catch (e) {
      if (e.status == 409) return;
      rethrow;
    }
  }

  /// Take a declared payment back.
  ///
  /// Offered only while the payment is still awaiting confirmation: once the
  /// office has dealt with it the server refuses, and a control that cannot
  /// succeed should not be on screen.
  ///
  /// No reason is sent. The route takes an optional one of three characters or
  /// more, and a confirmation dialog is not a place to type; the office sees
  /// who withdrew it either way.
  Future<void> withdrawPayment(String paymentId) async {
    await _api.post('/parent/payments/$paymentId/withdraw');
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
    this.acknowledgedAt,
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

  /// When this parent said they had read it, if they have.
  ///
  /// The server has always sent it; nothing read it, so the Got it button had
  /// no way to know whether it still had anything to do.
  final DateTime? acknowledgedAt;
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
        acknowledgedAt: j['acknowledgedAt'] == null
            ? null
            : DateTime.parse(j['acknowledgedAt'] as String).toLocal(),
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



/// A person's name as the money service sends it, or null when there is none.
String? _twoPartName(Map<String, dynamic>? j) {
  if (j == null) return null;
  final name = '${j['nameGiven'] ?? ''} ${j['nameFamily'] ?? ''}'.trim();
  return name.isEmpty ? null : name;
}

/// What this school will take, and how it wants to be told about it.
class PaymentOptions {
  PaymentOptions({
    required this.allowSelfDeclare,
    required this.requireProofForTransfer,
    required this.methods,
    required this.currencyCode,
    required this.instructions,
  });

  /// Whether this school takes payment notices through the app at all. Off, and
  /// there is no form — only [instructions].
  final bool allowSelfDeclare;

  /// Whether a bank transfer must carry a photograph of the slip.
  ///
  /// There is no parent upload route anywhere on the platform, so while this is
  /// true a bank transfer declared from a phone is refused every time and the
  /// form does not offer it. Kept as a field rather than buried in the screen
  /// because this is the flag that turns it back on the day an upload route
  /// exists.
  final bool requireProofForTransfer;

  /// The methods the server will accept. Read from here rather than written out
  /// in the app: CARD is a real payment method in the schema and is deliberately
  /// not one a parent may claim, and that list is the server's to change.
  final List<String> methods;

  final String currencyCode;

  /// The school's own words — which bank, which account, who to ring.
  final String? instructions;

  /// The methods a parent can actually get accepted from this app today.
  List<String> get usableMethods => [
        for (final m in methods)
          if (!(m == 'BANK_TRANSFER' && requireProofForTransfer)) m,
      ];

  factory PaymentOptions.fromJson(Map<String, dynamic> j) {
    final written = (j['paymentInstructions'] as String?)?.trim() ?? '';
    return PaymentOptions(
      allowSelfDeclare: (j['allowParentSelfDeclare'] ?? false) as bool,
      // The server's own default, repeated here so a field missing from an
      // older deployment errs towards refusing the transfer form rather than
      // towards showing one that always fails.
      requireProofForTransfer: (j['requireProofForTransfer'] ?? true) as bool,
      methods: ((j['methods'] as List?) ?? const []).map((e) => '$e').toList(),
      currencyCode: (j['currencyCode'] ?? 'IQD') as String,
      instructions: written.isEmpty ? null : written,
    );
  }
}

/// A receipt, in the two shapes the platform sends it.
///
/// The list route sends the whole thing — serial, amount, method, the bill and
/// the child it names — and never sends a cancelled one. The stub hanging off a
/// payment carries only enough to open it, plus the one field the list cannot
/// have: [voidedAt]. A cancelled receipt has no PDF to open, so the control is
/// drawn from [open] rather than from an id being present.
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

/// One payment against this household, and what the office made of it.
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

  /// PENDING_CONFIRMATION, CONFIRMED, REJECTED, REVERSED, FAILED or WITHDRAWN.
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

  /// What the withdraw route writes in front of the family's own reason.
  static const _withdrawnMark = 'Withdrawn by the family';

  /// The family took this back themselves.
  ///
  /// The schema has a WITHDRAWN state and the withdraw route does not use it —
  /// it writes REJECTED with this marker on the reason. Printing the raw status
  /// would tell a parent the school had refused a payment they cancelled
  /// themselves, so the marker, not the status, is what the screen branches on.
  bool get withdrawnByFamily =>
      status == 'REJECTED' && (rejectedReason ?? '').startsWith(_withdrawnMark);

  /// Why it was refused, in the office's words — with the withdraw marker taken
  /// off, because the screen already says who cancelled it.
  String? get refusal {
    final reason = rejectedReason?.trim() ?? '';
    if (reason.isEmpty) return null;
    if (!withdrawnByFamily) return reason;
    var rest = reason.substring(_withdrawnMark.length).trim();
    if (rest.startsWith(':')) rest = rest.substring(1).trim();
    return rest.isEmpty ? null : rest;
  }

  /// When the money moved, as far as anybody knows.
  ///
  /// Both of the server's dates are nullable and an office-entered row often
  /// carries neither, so this falls back to when the row was written rather
  /// than printing a dash where a date belongs.
  DateTime get when => paidAt ?? receivedAt ?? createdAt;

  /// The receipt worth offering, if there is one.
  ///
  /// Cancelled ones are skipped: the PDF route refuses them, and nothing that
  /// is not yet confirmed has a receipt at all.
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

/// A PDF the platform rendered and stored, and a link to it that dies in ten
/// minutes.
class StoredDocument {
  StoredDocument({required this.url, required this.filename, required this.latinOnly});

  final String url;
  final String filename;

  /// True when this deployment has no Arabic-capable font, so a Kurdish or
  /// Arabic document has come out in Latin letters. Worth saying out loud
  /// rather than letting a parent think the school printed it wrong.
  final bool latinOnly;

  factory StoredDocument.fromJson(Map<String, dynamic> j) => StoredDocument(
        url: (j['url'] ?? '') as String,
        filename: (j['filename'] ?? '') as String,
        latinOnly: (j['latinOnly'] ?? false) as bool,
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

/// A correction a parent has asked the office to make to their own record.
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

  /// PENDING, APPROVED, REJECTED or CANCELLED — the same four the office's
  /// screen shows, and the same four a leave request has.
  final String status;
  final DateTime requestedAt;

  /// What was asked for, as label and value, ready to print. Built from
  /// whichever of the name parts and the email the request actually carried,
  /// so a correction to one field does not render four empty rows.
  final List<({String field, String value})> fields;

  final String? reason;

  /// Why the office refused, in their words. The reason a rejection is worth
  /// showing at all.
  final String? decisionNote;
  final DateTime? decidedAt;

  bool get pending => status == 'PENDING';

  factory ProfileChange.fromJson(Map<String, dynamic> j) {
    final asked = <({String field, String value})>[];
    void take(String key) {
      final v = j[key];
      if (v is String) asked.add((field: key, value: v));
    }

    // The server may send the proposal flat or under a 'proposed' object;
    // both shapes are read rather than guessing which one this build talks to.
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
