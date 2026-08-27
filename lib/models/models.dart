/// The shapes the screens read.
///
/// Every one of these maps onto tables that already exist in the platform
/// schema — `Student`, `TimetableSlot`, `Homework`, `ExamResult`,
/// `ClassAttendance`, `VehicleLivePosition`. The field names deliberately match
/// the API's, so wiring the real endpoints later is a change of data source and
/// not a change of model.
library;

class Student {
  const Student({
    required this.id,
    required this.code,
    required this.name,
    required this.className,
    required this.photoUrl,
    required this.streakDays,
  });

  final String id;
  /// The human-facing code printed on a badge — STU-2026-00142.
  final String code;
  final String name;
  final String className;
  final String? photoUrl;
  /// Consecutive school days attended. A gentle nudge, never a punishment:
  /// it counts up and is simply absent when it would read as zero.
  final int streakDays;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// One period on the timetable.
class Session {
  const Session({
    required this.subject,
    required this.teacher,
    required this.room,
    required this.startMinute,
    required this.endMinute,
    this.isBreak = false,
  });

  final String subject;
  final String teacher;
  final String room;
  /// Minutes from midnight. The API stores bell times the same way, because a
  /// wall-clock string cannot be compared or offset without parsing it.
  final int startMinute;
  final int endMinute;
  final bool isBreak;

  static String hhmm(int minute) {
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }

  String get timeRange => '${hhmm(startMinute)} – ${hhmm(endMinute)}';

  bool isNowAt(int nowMinute) => nowMinute >= startMinute && nowMinute < endMinute;
  bool isPastAt(int nowMinute) => nowMinute >= endMinute;
}

enum AssignmentKind { lab, art, essay, problemSet, reading, project }

class Assignment {
  const Assignment({
    required this.id,
    required this.title,
    required this.subject,
    required this.due,
    required this.kind,
    this.submitted = false,
  });

  final String id;
  final String title;
  final String subject;
  final DateTime due;
  final AssignmentKind kind;
  final bool submitted;

  bool get isOverdue => !submitted && due.isBefore(DateTime.now());

  /// "Due today, 11:59 PM" reads faster than a date, and reading fast is the
  /// entire job of this line.
  String dueLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final days = dueDay.difference(today).inDays;
    final time = Session.hhmm(due.hour * 60 + due.minute);

    if (days < 0) return 'Overdue — was due $time';
    if (days == 0) return 'Due today, $time';
    if (days == 1) return 'Due tomorrow, $time';
    if (days < 7) return 'Due ${_weekday(due.weekday)}, $time';
    return 'Due ${_month(due.month)} ${due.day}, $time';
  }

  static String _weekday(int w) => const [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
      ][w - 1];

  static String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];
}

class SubjectGrade {
  const SubjectGrade({
    required this.subject,
    required this.score,
    required this.maxScore,
    required this.letter,
    required this.teacher,
    this.trend = 0,
  });

  final String subject;
  final double score;
  final double maxScore;
  final String letter;
  final String teacher;
  /// Change against the previous term, in percentage points.
  final double trend;

  /// A percentage, because subjects are marked out of different totals and an
  /// average of raw marks quietly weights whichever has the biggest denominator.
  double get percent => maxScore == 0 ? 0 : (score / maxScore) * 100;
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.trend,
  });

  final int present;
  final int absent;
  final int late;
  final int excused;
  final double trend;

  int get total => present + absent + late + excused;
  double get rate => total == 0 ? 0 : (present + late) / total * 100;
}

enum BusState { notStarted, approaching, boarded, atSchool, homeward, delivered }

/// What the bus tracker shows.
///
/// `asOf` is not decoration. A map that renders a stale position as though it
/// were live is the single most trust-destroying thing this kind of app can do,
/// so the screen always says how old the fix is and the model always carries it.
class BusStatus {
  const BusStatus({
    required this.state,
    required this.plate,
    required this.driverName,
    required this.stopName,
    required this.etaMinutesLow,
    required this.etaMinutesHigh,
    required this.asOf,
  });

  final BusState state;
  final String plate;
  final String driverName;
  final String stopName;
  /// A band, never a single number. The underlying estimate is not precise
  /// enough to justify a countdown, and a countdown that is wrong twice is
  /// never looked at again.
  final int etaMinutesLow;
  final int etaMinutesHigh;
  final DateTime asOf;

  int get staleSeconds => DateTime.now().difference(asOf).inSeconds;
  bool get isStale => staleSeconds > 120;

  String get etaLabel => state == BusState.approaching
      ? '$etaMinutesLow–$etaMinutesHigh min'
      : '—';

  String get stateLabel => switch (state) {
        BusState.notStarted => 'Not started',
        BusState.approaching => 'Approaching your stop',
        BusState.boarded => 'On the bus',
        BusState.atSchool => 'At school',
        BusState.homeward => 'On the way home',
        BusState.delivered => 'Delivered',
      };

  String get freshnessLabel {
    final s = staleSeconds;
    if (s < 20) return 'Live';
    if (s < 60) return 'Updated ${s}s ago';
    final m = s ~/ 60;
    return 'Last seen $m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
}

class ExamEntry {
  const ExamEntry({
    required this.subject,
    required this.date,
    required this.startMinute,
    required this.room,
    required this.kind,
  });

  final String subject;
  final DateTime date;
  final int startMinute;
  final String room;
  final String kind;

  int get daysAway {
    final now = DateTime.now();
    return DateTime(date.year, date.month, date.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }
}
