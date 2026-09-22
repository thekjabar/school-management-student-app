import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/teacher_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/teacher/homework_marks.dart';
import 'package:student_app/ui/format.dart';

TeacherHomework _homework(String id) => TeacherHomework.fromJson({
      'id': id,
      'title': 'Page 9',
      'dueDate': '2026-09-20T00:00:00.000Z',
      'assignedOn': '2026-09-15T00:00:00.000Z',
      'publishedAt': null,
      'maxScore': '10',
      'subject': {'name': 'Maths'},
      'class': {'name': 'Class 1'},
      '_count': {'submissions': 3},
    });

Future<void> _openMarks(WidgetTester tester, Map<String, dynamic> sheet) async {
  ApiClient.instance.httpForTest = MockClient((request) async => http.Response.bytes(
        utf8.encode(jsonEncode(sheet)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ));
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: HomeworkMarksScreen(homework: _homework('cmhw2'))));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.current.value = Lang.en;
  });
  final json = <String, dynamic>{
    'homework': {'id': 'cmhw1', 'title': 'Page 4', 'maxScore': 10, 'className': 'Class 1', 'subjectName': 'Maths'},
    'students': [
      {'studentId': 'a', 'code': 'S-1', 'rollNumber': '1', 'name': 'Aram', 'status': 'NOT_SUBMITTED', 'score': null},
      {'studentId': 'b', 'code': 'S-2', 'rollNumber': '2', 'name': 'Zhina', 'status': 'GRADED', 'score': 8.5},
      {'studentId': 'c', 'code': 'S-3', 'rollNumber': null, 'name': 'Dana', 'status': 'SUBMITTED', 'score': null},
    ],
  };

  final handedIn = <String, dynamic>{
    'homework': {
      'id': 'cmhw2',
      'title': 'Page 9',
      'maxScore': 10,
      'className': 'Class 1',
      'subjectName': 'Maths',
      'dueDate': '2026-09-20T00:00:00.000Z',
      'handInOpen': true,
    },
    'students': [
      {
        'studentId': 'a',
        'code': 'S-1',
        'rollNumber': '1',
        'name': 'Aram',
        'status': 'SUBMITTED',
        'score': null,
        'submittedAt': '2026-09-19T10:30:00.000Z',
        'handedInText': 'I answered all five.',
        'feedback': null,
        'gradedAt': null,
        'files': [
          {
            'id': 'att1',
            'assetId': 'asset1',
            'mime': 'image/jpeg',
            'bytes': 2048,
            'originalFilename': 'page9.jpg',
            'readyToOpen': true,
          },
          {
            'id': 'att2',
            'assetId': 'asset2',
            'mime': 'image/jpeg',
            'bytes': null,
            'originalFilename': null,
            'readyToOpen': false,
          },
        ],
      },
      {
        'studentId': 'b',
        'code': 'S-2',
        'rollNumber': '2',
        'name': 'Zhina',
        'status': 'GRADED',
        'score': 8.5,
        'submittedAt': '2026-09-18T09:00:00.000Z',
        'handedInText': null,
        'feedback': 'Neat work',
        'gradedAt': '2026-09-21T09:00:00.000Z',
        'files': [],
      },
      {
        'studentId': 'c',
        'code': 'S-3',
        'rollNumber': null,
        'name': 'Dana',
        'status': 'NOT_SUBMITTED',
        'score': null,
      },
    ],
  };

  test('the marking sheet reads what the teacher API sends', () {
    final sheet = HomeworkSheet.fromJson(json);
    expect(sheet.id, 'cmhw1');
    expect(sheet.maxScore, 10);
    expect(sheet.rows.map((r) => r.studentId), ['a', 'b', 'c']);
    expect(sheet.rows[1].score, 8.5);
    expect(sheet.changedEntries(), isEmpty);
  });

  test('only changed marks and states are sent, a cleared mark as null', () {
    final sheet = HomeworkSheet.fromJson(json);
    sheet.rows[0].score = 7;
    sheet.rows[1].score = null;
    sheet.rows[2].status = 'EXCUSED';
    expect(sheet.changedEntries(), [
      {'studentId': 'a', 'score': 7},
      {'studentId': 'b', 'score': null},
      {'studentId': 'c', 'status': 'EXCUSED'},
    ]);
    sheet.rows[0].score = null;
    expect(sheet.changedEntries().map((e) => e['studentId']), ['b', 'c']);
  });

  test('the homework list keeps the maximum mark it was set with', () {
    final item = TeacherHomework.fromJson({
      'id': 'h',
      'title': 'x',
      'dueDate': '2026-09-20T00:00:00.000Z',
      'assignedOn': '2026-09-15T00:00:00.000Z',
      'publishedAt': null,
      'maxScore': '20',
      'subject': {'name': 'Maths'},
      'class': {'name': 'Class 1'},
      '_count': {'submissions': 3},
    });
    expect(item.maxScore, 20);
  });

  test('the sheet carries what each student handed in', () {
    final sheet = HomeworkSheet.fromJson(handedIn);
    expect(sheet.handInOpen, isTrue);
    expect(sheet.dueDate, isNotNull);

    final aram = sheet.rows[0];
    expect(aram.handedIn, isTrue);
    expect(aram.marked, isFalse);
    expect(aram.handedInText, 'I answered all five.');
    expect(aram.submittedAt, isNotNull);
    expect(aram.files.map((f) => f.assetId), ['asset1', 'asset2']);
    expect(aram.files[0].filename, 'page9.jpg');
    expect(aram.files[1].readyToOpen, isFalse);
    expect(aram.files[1].filename, isNull);

    final zhina = sheet.rows[1];
    expect(zhina.marked, isTrue);
    expect(zhina.feedback, 'Neat work');
    expect(zhina.handedIn, isFalse, reason: 'no words and no files is nothing handed in');

    final dana = sheet.rows[2];
    expect(dana.handedIn, isFalse);
    expect(dana.files, isEmpty);
    expect(dana.submittedAt, isNull);
  });

  test('reading a hand-in does not make the sheet look edited', () {
    final sheet = HomeworkSheet.fromJson(handedIn);
    expect(sheet.changedEntries(), isEmpty);
    sheet.rows[0].score = 9;
    expect(sheet.changedEntries(), [
      {'studentId': 'a', 'score': 9},
    ]);
  });

  test('a homework that takes no hand-ins says so', () {
    final sheet = HomeworkSheet.fromJson(json);
    expect(sheet.handInOpen, isFalse);
    expect(sheet.dueDate, isNull);
    expect(sheet.rows.every((r) => !r.handedIn), isTrue);
  });

  testWidgets('the teacher sees what the student handed in, words and files', (tester) async {
    await _openMarks(tester, handedIn);

    expect(
      find.text(t('teacher.handInNothing')),
      findsNWidgets(2),
      reason: 'two of the three handed nothing in',
    );
    expect(
      find.textContaining(t('teacher.handInWork')),
      findsOneWidget,
      reason: 'only the student who handed something in offers it',
    );

    await tester.tap(find.textContaining(t('teacher.handInWork')));
    await tester.pumpAndSettle();

    expect(find.text(t('teacher.handInWords')), findsOneWidget);
    expect(find.text('I answered all five.'), findsOneWidget);
    expect(find.text('page9.jpg'), findsOneWidget);
    expect(find.text(t('msg.fileFallback')), findsOneWidget);
    expect(find.textContaining(t('msg.fileChecking')), findsOneWidget);
  });

  testWidgets('a marked student carries the day it was marked', (tester) async {
    await _openMarks(tester, handedIn);

    final marked = HomeworkSheet.fromJson(handedIn).rows[1];
    expect(
      find.textContaining(tv('teacher.markedOn', {'name': shortDate(marked.gradedAt)})),
      findsOneWidget,
    );
  });

  test('every hand-in state has wording in all three languages', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      for (final state in [...homeworkStates, 'GRADED']) {
        expect(homeworkStateLabel(state).startsWith('teacher.'), isFalse, reason: '$state in ${lang.code}');
      }
      for (final key in [
        'teacher.alsoSetFor',
        'teacher.homeworkSetMany',
        'teacher.markHomework',
        'teacher.homeworkNoMarks',
        'teacher.maxMark',
        'teacher.notMarked',
        'teacher.handInWork',
        'teacher.handInWords',
        'teacher.handInNothing',
        'teacher.handInAt',
        'teacher.markedOn',
        'msg.fileChecking',
      ]) {
        expect(tableFor(lang).containsKey(key), isTrue, reason: '$key in ${lang.code}');
      }
    }
    AppLocale.current.value = Lang.en;
  });
}
