@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/student/home_tab.dart';
import 'package:student_app/screens/student/marks_tab.dart';
import 'package:student_app/screens/student/profile_tab.dart';
import 'package:student_app/screens/student/timetable_tab.dart';
import 'package:student_app/theme/app_theme.dart';

const _outDir = r'D:\abdulsamad\design\student-redesign\built';

const _fonts = [
  r'C:\Windows\Fonts\segoeui.ttf',
  r'C:\Windows\Fonts\arial.ttf',
  r'C:\Windows\Fonts\tahoma.ttf',
];

http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _lesson({
  required int period,
  required Map<String, String> subject,
  required int startMinute,
  required Map<String, String> teacher,
  String room = '12A',
  String colour = '#2563EB',
  bool inProgress = false,
  int? minutesLeft,
}) =>
    {
      'id': 'cmlesson00000000000000$period',
      'weekday': 'WEDNESDAY',
      'period': period,
      'kind': 'LESSON',
      'room': room,
      'startMinute': startMinute,
      'endMinute': startMinute + 45,
      'subject': subject['en'],
      'subjectNames': subject,
      'subjectColorHex': colour,
      'teacherName': teacher['en'],
      'teacherNames': teacher,
      'inProgress': inProgress,
      'minutesUntilStart': null,
      'minutesLeft': minutesLeft,
    };

const _homeroom = {'en': 'Homeroom', 'ckb': 'پۆل', 'ar': 'الصف'};
const _arabic = {'en': 'Arabic Language', 'ckb': 'زمانی عەرەبی', 'ar': 'اللغة العربية'};
const _islamic = {'en': 'Islamic Education', 'ckb': 'پەروەردەی ئیسلامی', 'ar': 'التربية الإسلامية'};
const _maths = {'en': 'Mathematics', 'ckb': 'بیرکاری', 'ar': 'الرياضيات'};
const _jiyan = {'en': 'Jiyan Shekhani', 'ckb': 'ژیان شێخانی', 'ar': 'جيان شيخاني'};
const _vian = {'en': 'Vian Weisi', 'ckb': 'ڤیان وەیسی', 'ar': 'فيان ويسي'};
const _ali = {'en': 'Ali Hussain', 'ckb': 'عەلی حوسێن', 'ar': 'علي حسين'};

final _slots = [
  _lesson(period: 1, subject: _homeroom, teacher: _jiyan, startMinute: 480, colour: '#10B981'),
  _lesson(
    period: 2,
    subject: _arabic,
    teacher: _jiyan,
    startMinute: 490,
    inProgress: true,
    minutesLeft: 9,
  ),
  _lesson(period: 3, subject: _islamic, teacher: _vian, startMinute: 535, colour: '#F59E0B'),
  _lesson(period: 4, subject: _maths, teacher: _ali, startMinute: 580, colour: '#7C3AED'),
];

final _me = {
  'id': 'cmstudent00000000000000001',
  'code': 'STU-2026-00018',
  'name': 'Umar Bakhtiar Dana',
  'names': {
    'en': 'Umar Bakhtiar Dana',
    'ckb': 'عومەر بەختیار دانا',
    'ar': 'عمر بختيار دانا',
  },
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
    'housePoints': true,
    'homeworkHandIn': true,
    'idCard': true,
    'nextClass': true,
    'awards': false,
    'examPlanner': true,
  },
};

Map<String, dynamic> _mark(
  String id,
  Map<String, String> subject,
  double score,
  String letter,
  bool pass,
  String colour,
  String date,
) =>
    {
      'id': id,
      'score': score,
      'maxScore': 100,
      'percent': score,
      'gradeLetter': letter,
      'isPass': pass,
      'wasAbsent': false,
      'wasExempt': false,
      'remark': null,
      'exam': {
        'kind': 'TERM',
        'title': 'Grade 12',
        'date': date,
        'subject': subject['en'],
        'subjectNames': subject,
        'subjectColorHex': colour,
      },
    };

final _marks = [
  _mark('cmmark0000000000000000001', {'en': 'Kurdish Language', 'ckb': 'زمانی کوردی', 'ar': 'اللغة الكردية'}, 45.8, 'F', false, '#7C3AED', '2026-06-12T00:00:00.000Z'),
  _mark('cmmark0000000000000000002', {'en': 'Economics', 'ckb': 'ئابووری', 'ar': 'الاقتصاد'}, 64.5, 'D', true, '#0EA5E9', '2026-06-13T00:00:00.000Z'),
  _mark('cmmark0000000000000000003', {'en': 'Geography', 'ckb': 'جوگرافیا', 'ar': 'الجغرافيا'}, 75.4, 'C', true, '#10B981', '2026-06-14T00:00:00.000Z'),
  _mark('cmmark0000000000000000004', {'en': 'History', 'ckb': 'مێژوو', 'ar': 'التاريخ'}, 89.7, 'A', true, '#F59E0B', '2026-06-15T00:00:00.000Z'),
];

void _routes() {
  ApiClient.instance.httpForTest = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/student/me')) return _json(200, _me);
    if (path.endsWith('/student/timetable/today')) {
      return _json(200, {'weekday': 'WEDNESDAY', 'slots': _slots, 'nextSlot': _slots[1]});
    }
    if (path.endsWith('/student/timetable/week')) {
      return _json(200, {
        'days': [
          {'weekday': 'SUNDAY', 'slots': _slots.take(2).toList()},
          {'weekday': 'MONDAY', 'slots': _slots.take(3).toList()},
          {'weekday': 'TUESDAY', 'slots': _slots},
          {'weekday': 'WEDNESDAY', 'slots': _slots},
          {'weekday': 'THURSDAY', 'slots': _slots.take(3).toList()},
        ],
      });
    }
    if (path.endsWith('/student/marks')) return _json(200, _marks);
    if (path.endsWith('/student/attendance')) {
      return _json(200, {
        'termName': 'Term 1',
        'termNames': {'en': 'Term 1', 'ckb': 'خولی یەکەم', 'ar': 'الفصل الأول'},
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
      });
    }
    if (path.endsWith('/student/today')) {
      return _json(200, {
        'attendanceStatus': 'PRESENT',
        'minutesLate': null,
        'classesLeft': 2,
        'nextClass': _slots[1],
        'nextExam': null,
        'dueToday': <Object>[],
      });
    }
    return _json(200, {'rows': <Object>[], 'total': 0});
  });
}

Future<void> _loadFonts() async {
  for (final family in ['Roboto', 'Segoe UI', 'Arial']) {
    final loader = FontLoader(family);
    var any = false;
    for (final path in _fonts) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loader.addFont(file.readAsBytes().then((b) => ByteData.view(Uint8List.fromList(b).buffer)));
      any = true;
    }
    if (any) await loader.load();
  }
}

Future<void> _shoot(WidgetTester tester, String name, Widget body) async {
  final key = GlobalKey();

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(AppLocale.current.value.code),
      theme: AppTheme.build(tint: Role.student.tint),
      home: RepaintBoundary(
        key: key,
        child: Directionality(
          textDirection: AppLocale.current.value.direction,
          child: Scaffold(backgroundColor: AppTheme.canvas, body: SafeArea(child: body)),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pumpAndSettle();

  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final dir = Directory(_outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('$_outDir\\$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppTheme.skin = Role.student;
    _routes();
  });

  tearDown(() {
    AppTheme.skin = Role.parent;
    AppTheme.dark = false;
    AppLocale.current.value = Lang.en;
  });

  final shots = <String, Widget Function()>{
    'home': () => StudentHome(onOpenTab: (_) {}),
    'marks': () => const StudentMarks(),
    'timetable': () => const StudentWeek(),
    'profile': () => const StudentProfileTab(),
  };

  for (final entry in shots.entries) {
    for (final variant in ['light', 'dark', 'kurdish']) {
      testWidgets('${entry.key} $variant', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 1500);
        addTearDown(tester.view.reset);

        AppTheme.dark = variant == 'dark';
        AppLocale.current.value = variant == 'kurdish' ? Lang.ckb : Lang.en;

        await _shoot(tester, '${entry.key}-$variant', entry.value());
      });
    }
  }
}
