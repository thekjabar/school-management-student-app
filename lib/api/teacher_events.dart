import 'family_payments.dart';
import 'school_life.dart' show EventReplyKind;

String? _text(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _int(Object? raw) => raw is num ? raw.toInt() : 0;

bool _bool(Object? raw) => raw == true;

DateTime? _instant(Object? raw) => raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

class TeacherEvent {
  const TeacherEvent({
    required this.id,
    required this.title,
    required this.titleNames,
    required this.description,
    required this.descriptionNames,
    required this.place,
    required this.placeNames,
    required this.startsAt,
    required this.endsAt,
    required this.cancelled,
    required this.wholeSchool,
    required this.replyWanted,
    required this.replyClosesAt,
    required this.headcountWanted,
    required this.headcountMax,
    required this.myClassIds,
  });

  final String id;
  final String title;
  final LocalText titleNames;
  final String? description;
  final LocalText descriptionNames;
  final String? place;
  final LocalText placeNames;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool cancelled;
  final bool wholeSchool;
  final bool replyWanted;
  final DateTime? replyClosesAt;
  final bool headcountWanted;
  final int headcountMax;
  final List<String> myClassIds;

  String get titleText => titleNames.pick(title);

  String get descriptionText => descriptionNames.pick(description);

  String get placeText => placeNames.pick(place);

  factory TeacherEvent.fromJson(Map<String, dynamic> j) => TeacherEvent(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        titleNames: LocalText.fromJson(j['titleNames']),
        description: _text(j['description']),
        descriptionNames: LocalText.fromJson(j['descriptionNames']),
        place: _text(j['place']),
        placeNames: LocalText.fromJson(j['placeNames']),
        startsAt: _instant(j['startsAt']) ?? DateTime.now(),
        endsAt: _instant(j['endsAt']),
        cancelled: _bool(j['cancelled']),
        wholeSchool: _bool(j['wholeSchool']),
        replyWanted: _bool(j['replyWanted']),
        replyClosesAt: _instant(j['replyClosesAt']),
        headcountWanted: _bool(j['headcountWanted']),
        headcountMax: (j['headcountMax'] as num?)?.toInt() ?? 1,
        myClassIds: ((j['myClassIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(),
      );
}

class EventTally {
  const EventTally({
    required this.yes,
    required this.no,
    required this.maybe,
    required this.silent,
    required this.people,
  });

  final int yes;
  final int no;
  final int maybe;
  final int silent;
  final int people;

  int get asked => yes + no + maybe + silent;

  factory EventTally.fromJson(Map<String, dynamic>? j) => EventTally(
        yes: _int(j?['yes']),
        no: _int(j?['no']),
        maybe: _int(j?['maybe']),
        silent: _int(j?['silent']),
        people: _int(j?['people']),
      );
}

class EventChildReply {
  const EventChildReply({
    required this.studentId,
    required this.code,
    required this.rollNumber,
    required this.name,
    required this.names,
    required this.reply,
    required this.headcount,
  });

  final String studentId;
  final String code;
  final String? rollNumber;
  final String name;
  final LocalText names;
  final String? reply;
  final int headcount;

  String get childName => names.pick(name);

  bool get silent => reply == null;

  bool get coming => reply == EventReplyKind.yes;

  factory EventChildReply.fromJson(Map<String, dynamic> j) => EventChildReply(
        studentId: (j['studentId'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        rollNumber: _text(j['rollNumber']),
        name: (j['name'] ?? '') as String,
        names: LocalText.fromJson(j['names']),
        reply: _text(j['reply']),
        headcount: _int(j['headcount']),
      );
}

class EventClassReplies {
  const EventClassReplies({
    required this.classId,
    required this.className,
    required this.classNames,
    required this.students,
    required this.tally,
  });

  final String classId;
  final String? className;
  final LocalText classNames;
  final List<EventChildReply> students;
  final EventTally tally;

  String get classText => classNames.pick(className);

  factory EventClassReplies.fromJson(Map<String, dynamic> j) => EventClassReplies(
        classId: (j['classId'] ?? '') as String,
        className: _text(j['className']),
        classNames: LocalText.fromJson(j['classNames']),
        students: ((j['students'] as List?) ?? const [])
            .map((e) => EventChildReply.fromJson(e as Map<String, dynamic>))
            .toList(),
        tally: EventTally.fromJson(j['tally'] as Map<String, dynamic>?),
      );
}

class TeacherEventDetail {
  const TeacherEventDetail({required this.event, required this.classes});

  final TeacherEvent event;
  final List<EventClassReplies> classes;

  EventTally get total => EventTally(
        yes: classes.fold(0, (s, c) => s + c.tally.yes),
        no: classes.fold(0, (s, c) => s + c.tally.no),
        maybe: classes.fold(0, (s, c) => s + c.tally.maybe),
        silent: classes.fold(0, (s, c) => s + c.tally.silent),
        people: classes.fold(0, (s, c) => s + c.tally.people),
      );

  factory TeacherEventDetail.fromJson(Map<String, dynamic> j) => TeacherEventDetail(
        event: TeacherEvent.fromJson(j),
        classes: ((j['classes'] as List?) ?? const [])
            .map((e) => EventClassReplies.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
