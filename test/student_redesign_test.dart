import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/student/home_tab.dart';
import 'package:student_app/screens/student/marks_tab.dart';
import 'package:student_app/screens/student/student_kit.dart';
import 'package:student_app/screens/student/timetable_tab.dart';
import 'package:student_app/theme/app_theme.dart';
import 'package:student_app/ui/format.dart';
import 'package:student_app/ui/home_kit.dart';

http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _lesson({
  required int period,
  required String subject,
  required int startMinute,
  String room = '12A',
  String teacher = 'Jiyan Shekhani',
  String colour = '#2563EB',
  bool inProgress = false,
  int? minutesLeft,
  int? minutesUntilStart,
}) =>
    {
      'id': 'cmlesson00000000000000$period',
      'weekday': 'WEDNESDAY',
      'period': period,
      'kind': 'LESSON',
      'room': room,
      'startMinute': startMinute,
      'endMinute': startMinute + 45,
      'subject': subject,
      'subjectNames': {'en': subject, 'ckb': subject, 'ar': subject},
      'subjectColorHex': colour,
      'teacherName': teacher,
      'teacherNames': {'en': teacher, 'ckb': teacher, 'ar': teacher},
      'inProgress': inProgress,
      'minutesUntilStart': minutesUntilStart,
      'minutesLeft': minutesLeft,
    };

Map<String, dynamic> _me({Map<String, bool> off = const {}}) => {
      'id': 'cmstudent00000000000000001',
      'code': 'STU-2026-00018',
      'name': 'Umar Bakhtiar',
      'names': {'en': 'Umar Bakhtiar', 'ckb': 'عومەر بەختیار', 'ar': 'عمر بختيار'},
      'gender': 'MALE',
      'dob': '2008-06-18T00:00:00.000Z',
      'photoUrl': null,
      'lastLoginAt': '2026-09-23T06:40:00.000Z',
      'school': {
        'name': 'Sardam School',
        'names': {'en': 'Sardam School', 'ckb': 'قوتابخانەی سەردەم', 'ar': 'مدرسة سردم'},
      },
      'schoolClass': {
        'id': 'cmclass000000000000000001',
        'name': 'Grade 12 A',
        'names': {'en': 'Grade 12 A', 'ckb': 'پۆلی ١٢ ئا', 'ar': 'الصف ١٢ أ'},
        'gradeLevel': 12,
        'section': 'A',
      },
      'features': {
        'housePoints': off['housePoints'] ?? true,
        'homeworkHandIn': off['homeworkHandIn'] ?? true,
        'idCard': off['idCard'] ?? true,
        'nextClass': off['nextClass'] ?? true,
        'awards': off['awards'] ?? true,
        'examPlanner': off['examPlanner'] ?? true,
      },
    };

final _today = {
  'weekday': 'WEDNESDAY',
  'slots': [
    _lesson(period: 1, subject: 'Homeroom', startMinute: 480, colour: '#10B981'),
    _lesson(
      period: 2,
      subject: 'Arabic Language',
      startMinute: 490,
      inProgress: true,
      minutesLeft: 9,
    ),
    _lesson(period: 3, subject: 'Islamic Education', startMinute: 535, colour: '#F59E0B'),
  ],
  'nextSlot': _lesson(
    period: 2,
    subject: 'Arabic Language',
    startMinute: 490,
    inProgress: true,
    minutesLeft: 9,
  ),
};

final _week = {
  'days': [
    {'weekday': 'SUNDAY', 'slots': <Object>[]},
    {
      'weekday': 'WEDNESDAY',
      'slots': [
        _lesson(period: 1, subject: 'Homeroom', startMinute: 480, colour: '#10B981'),
        _lesson(period: 2, subject: 'Arabic Language', startMinute: 490),
      ],
    },
  ],
};

final _marks = [
  {
    'id': 'cmmark0000000000000000001',
    'score': 45.8,
    'maxScore': 100,
    'percent': 45.8,
    'gradeLetter': 'F',
    'isPass': false,
    'wasAbsent': false,
    'wasExempt': false,
    'remark': null,
    'exam': {
      'kind': 'TERM',
      'title': 'Grade 7',
      'date': '2024-06-12T00:00:00.000Z',
      'subject': 'Kurdish Language',
      'subjectNames': {'en': 'Kurdish Language', 'ckb': 'زمانی کوردی', 'ar': 'اللغة الكردية'},
      'subjectColorHex': '#7C3AED',
    },
  },
  {
    'id': 'cmmark0000000000000000002',
    'score': 55.4,
    'maxScore': 100,
    'percent': 55.4,
    'gradeLetter': 'E',
    'isPass': true,
    'wasAbsent': false,
    'wasExempt': false,
    'remark': null,
    'exam': {
      'kind': 'TERM',
      'title': 'Grade 7',
      'date': '2024-06-14T00:00:00.000Z',
      'subject': 'Geography',
      'subjectNames': {'en': 'Geography', 'ckb': 'جوگرافیا', 'ar': 'الجغرافيا'},
      'subjectColorHex': '#0EA5E9',
    },
  },
];

final _attendance = {
  'termName': 'Term 1',
  'termNames': {'en': 'Term 1', 'ckb': 'خولی ١', 'ar': 'الفصل ١'},
  'from': '2026-09-01T00:00:00.000Z',
  'to': '2026-12-20T00:00:00.000Z',
  'present': 9,
  'late': 0,
  'absent': 0,
  'excused': 0,
  'leftEarly': 0,
  'total': 9,
  'ratePercent': 100,
  'exceptions': <Object>[],
};

final _glance = {
  'attendanceStatus': 'PRESENT',
  'minutesLate': null,
  'classesLeft': 2,
  'nextClass': _lesson(
    period: 2,
    subject: 'Arabic Language',
    startMinute: 490,
    inProgress: true,
    minutesLeft: 9,
  ),
  'nextExam': null,
  'dueToday': <Object>[],
};

void _routes(WidgetTester tester, {Map<String, bool> off = const {}}) {
  ApiClient.instance.httpForTest = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/student/me')) return _json(200, _me(off: off));
    if (path.endsWith('/student/timetable/today')) return _json(200, _today);
    if (path.endsWith('/student/timetable/week')) return _json(200, _week);
    if (path.endsWith('/student/marks')) return _json(200, _marks);
    if (path.endsWith('/student/attendance')) return _json(200, _attendance);
    if (path.endsWith('/student/today')) return _json(200, _glance);
    if (path.endsWith('/student/homework')) {
      return _json(200, {'rows': <Object>[], 'total': 0});
    }
    if (path.endsWith('/student/announcements')) {
      return _json(200, {'rows': <Object>[], 'total': 0});
    }
    return _json(200, <String, Object>{});
  });
}

Future<void> _open(WidgetTester tester, Widget body) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 3200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(AppLocale.current.value.code),
      home: Directionality(
        textDirection: AppLocale.current.value.direction,
        child: Scaffold(backgroundColor: AppTheme.canvas, body: body),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.current.value = Lang.en;
    AppTheme.skin = Role.student;
    AppTheme.dark = false;
  });

  tearDown(() {
    AppTheme.skin = Role.parent;
    AppTheme.dark = false;
    AppLocale.current.value = Lang.en;
  });

  testWidgets('the home tab shows the next lesson, the tiles and today from real data',
      (tester) async {
    _routes(tester);
    await _open(tester, StudentHome(onOpenTab: (_) {}));

    expect(find.byType(StudentHero), findsOneWidget);
    expect(find.text('Arabic Language'), findsWidgets);
    expect(find.text(t('student.nextLesson')), findsOneWidget);
    expect(find.text(t('student.viewLesson')), findsOneWidget);

    expect(find.text(t('student.timetable')), findsOneWidget);
    expect(find.text(t('student.homework')), findsOneWidget);
    expect(find.text(t('student.marks')), findsOneWidget);
    expect(find.text(t('student.examPlanner')), findsOneWidget);
    expect(find.text(t('student.points')), findsOneWidget);

    expect(find.text(t('student.nowIn')), findsOneWidget);
    expect(find.text(tn('student.minutesLeft', 9)), findsOneWidget);

    expect(find.text(t('student.homeSchedule')), findsOneWidget);
    expect(find.text(t('student.viewFullTimetable')), findsOneWidget);
    expect(find.byType(ScheduleTimeline), findsWidgets);
    expect(find.text('Homeroom'), findsWidgets);
    expect(find.text(t('student.now')), findsWidgets);

    expect(find.text(t('student.homeworkDue')), findsNothing);
    expect(find.text(t('student.recentMarks')), findsNothing);
    expect(find.text(t('student.latestNews')), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a section the school switched off is gone, not broken', (tester) async {
    _routes(tester, off: {'housePoints': false, 'examPlanner': false, 'awards': false});
    await _open(tester, StudentHome(onOpenTab: (_) {}));

    expect(find.text(t('student.points')), findsNothing);
    expect(find.text(t('student.examPlanner')), findsNothing);
    expect(find.text(t('student.awards')), findsNothing);

    expect(find.text(t('student.timetable')), findsOneWidget,
        reason: 'switching one section off must not take the rest with it');
    expect(find.byType(StudentHero), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the marks tab shows attendance, the average and the school letter grades',
      (tester) async {
    _routes(tester);
    await _open(tester, const StudentMarks());

    expect(find.text(t('student.attendance')), findsOneWidget);
    expect(find.text('Term 1'), findsOneWidget);
    expect(find.text(t('student.present')), findsOneWidget);

    expect(find.text(t('marks.markedWork')), findsOneWidget);
    expect(find.text(t('marks.average')), findsOneWidget);

    expect(find.text(t('marks.published')), findsOneWidget);
    expect(find.text('Kurdish Language'), findsOneWidget);
    expect(find.text('45.8 / 100'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(find.byType(LetterBadge), findsNWidgets(2));
    expect(find.text(t('marks.allSubjects')), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the marks subject filter narrows the list to one subject', (tester) async {
    _routes(tester);
    await _open(tester, const StudentMarks());

    await tester.tap(find.text(t('marks.allSubjects')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geography').last);
    await tester.pumpAndSettle();

    expect(find.text('Geography'), findsWidgets);
    expect(find.text('Kurdish Language'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the timetable shows the school week, the lesson count and the real class',
      (tester) async {
    _routes(tester);
    await _open(tester, const StudentWeek());

    expect(find.byType(DayChips), findsOneWidget);
    expect(find.text(weekdayName('SUNDAY')), findsOneWidget);
    expect(find.text(weekdayName('WEDNESDAY')), findsWidgets);
    expect(find.textContaining('Grade 12 A'), findsOneWidget);
    expect(find.textContaining(tn('student.lessonCount', 2).split(' ').last), findsWidgets);
    expect(find.text('Arabic Language'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('every tab still lays out in Kurdish, right to left', (tester) async {
    AppLocale.current.value = Lang.ckb;
    _routes(tester);

    await _open(tester, StudentHome(onOpenTab: (_) {}));
    expect(Directionality.of(tester.element(find.byType(StudentHero))), TextDirection.rtl);
    expect(find.text(t('student.nextLesson')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _open(tester, const StudentMarks());
    expect(find.text(t('marks.published')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _open(tester, const StudentWeek());
    expect(find.byType(DayChips), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every tab still lays out in the dark', (tester) async {
    AppTheme.dark = true;
    _routes(tester);

    await _open(tester, StudentHome(onOpenTab: (_) {}));
    expect(find.byType(StudentHero), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _open(tester, const StudentMarks());
    expect(find.text(t('marks.published')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _open(tester, const StudentWeek());
    expect(find.byType(DayChips), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('the student skin belongs to the student alone', () {
    // These are the exact colours the parent, teacher, driver and admin apps
    // painted before the student redesign. If a student change reaches them,
    // one of these literals stops matching.
    const canvasLight = Color(0xFFFCFCFE);
    const canvasDark = Color(0xFF0A1324);
    const surfaceLight = Color(0xFFFFFFFF);
    const surfaceDark = Color(0xFF121A29);
    const borderLight = Color(0xFFEEEFF4);
    const borderDark = Color(0xFF212A3D);

    for (final role in [Role.parent, Role.teacher, Role.driver, Role.admin]) {
      test('${role.name} keeps the page it always had', () {
        AppTheme.skin = role;

        AppTheme.dark = false;
        expect(AppTheme.canvas, canvasLight);
        expect(AppTheme.surface, surfaceLight);
        expect(AppTheme.border, borderLight);

        AppTheme.dark = true;
        expect(AppTheme.canvas, canvasDark);
        expect(AppTheme.surface, surfaceDark);
        expect(AppTheme.border, borderDark);

        AppTheme.dark = false;
        AppTheme.skin = Role.parent;
      });
    }

    test('only the student gets the mint page', () {
      AppTheme.skin = Role.student;
      AppTheme.dark = false;
      expect(AppTheme.canvas, isNot(canvasLight));
      AppTheme.dark = true;
      expect(AppTheme.canvas, isNot(canvasDark));
      expect(AppTheme.surface, isNot(surfaceDark));

      AppTheme.dark = false;
      AppTheme.skin = Role.parent;
    });

    test('a timeline row with no student fields draws exactly as it did', () {
      const plain = ScheduleEntry(
        time: '08:00',
        subject: 'Maths',
        teacher: 'Ali',
        room: '12A',
        color: Color(0xFF2563EB),
      );
      expect(plain.timeSuffix, isNull);
      expect(plain.railColor, isNull);
      expect(plain.nowLabel, isNull,
          reason: 'the parent and teacher timelines must opt in, never inherit');

      const figure = IconFigure(
        icon: Icons.badge_outlined,
        label: 'Code',
        value: 'STU-2026-00018',
        caption: '',
        color: Color(0xFF2563EB),
      );
      expect(figure.fitValue, isFalse,
          reason: 'only the student asks a figure to shrink to fit');
    });
  });
}
