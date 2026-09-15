import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/teacher_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/teacher/homework_marks.dart';

void main() {
  final json = <String, dynamic>{
    'homework': {'id': 'cmhw1', 'title': 'Page 4', 'maxScore': 10, 'className': 'Class 1', 'subjectName': 'Maths'},
    'students': [
      {'studentId': 'a', 'code': 'S-1', 'rollNumber': '1', 'name': 'Aram', 'status': 'NOT_SUBMITTED', 'score': null},
      {'studentId': 'b', 'code': 'S-2', 'rollNumber': '2', 'name': 'Zhina', 'status': 'GRADED', 'score': 8.5},
      {'studentId': 'c', 'code': 'S-3', 'rollNumber': null, 'name': 'Dana', 'status': 'SUBMITTED', 'score': null},
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

  test('every hand-in state has wording in all three languages', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      for (final state in [...homeworkStates, 'GRADED']) {
        expect(homeworkStateLabel(state).startsWith('teacher.'), isFalse, reason: '$state in ${lang.code}');
      }
      for (final key in ['teacher.alsoSetFor', 'teacher.homeworkSetMany', 'teacher.markHomework', 'teacher.homeworkNoMarks', 'teacher.maxMark', 'teacher.notMarked']) {
        expect(tableFor(lang).containsKey(key), isTrue, reason: '$key in ${lang.code}');
      }
    }
    AppLocale.current.value = Lang.en;
  });
}
