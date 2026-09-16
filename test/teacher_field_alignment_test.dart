import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/teacher/exams_tab.dart';
import 'package:student_app/screens/teacher/homework_tab.dart';
import 'package:student_app/ui/pickers.dart';

const _classes = {
  'rows': [
    {
      'assignmentId': 'ckassignment000000000001',
      'class': {'id': 'ckclass00000000000000001', 'name': 'Class 1A', 'studentCount': 24},
      'subject': {'id': 'cksubject0000000000001', 'name': 'Maths', 'defaultMaxScore': 100},
    },
  ],
};

const _terms = {
  'rows': [
    {'id': 'ckterm000000000000000001', 'isCurrent': true},
  ],
};

http.Response _json(Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Client _server() => MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/teacher/classes')) return _json(_classes);
      if (path.endsWith('/teacher/terms')) return _json(_terms);
      if (path.endsWith('/teacher/exams')) return _json({'rows': <Object?>[]});
      if (path.endsWith('/teacher/homework')) return _json({'rows': <Object?>[]});
      return http.Response('{"message":"not here"}', 404);
    });

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 1400);
  addTearDown(tester.view.reset);
}

Finder _boxOf(Finder inside) =>
    find.ancestor(of: inside, matching: find.byType(Container)).first;

Future<void> _openSheet(WidgetTester tester, Widget tab) async {
  _phone(tester);
  await tester.pumpWidget(MaterialApp(home: tab));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.current.value = Lang.en;
    ApiClient.instance.httpForTest = _server();
  });

  tearDown(() => AppLocale.current.value = Lang.en);

  testWidgets('a picker with no label of its own starts at its own top', (tester) async {
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            PickerField(label: '', value: '100', onTap: () {}),
            PickerField(label: 'Out of', value: '100', onTap: () {}),
          ],
        ),
      ),
    ));
    await tester.pump();

    final bare = find.byType(PickerField).first;
    final labelled = find.byType(PickerField).last;

    final bareBox = _boxOf(find.descendant(of: bare, matching: find.text('100')));
    final labelledBox = _boxOf(find.descendant(of: labelled, matching: find.text('100')));

    expect(tester.getTopLeft(bareBox).dy, tester.getTopLeft(bare).dy,
        reason: 'an empty label still takes room above the field');
    expect(tester.getSize(bare).height, tester.getSize(bareBox).height);
    expect(tester.getTopLeft(labelledBox).dy, greaterThan(tester.getTopLeft(labelled).dy));
  });

  testWidgets('the new test sheet lines up the date with the mark it is out of', (tester) async {
    await _openSheet(tester, const ExamsTab());

    final dateBox = _boxOf(find.byIcon(Icons.calendar_today_rounded));
    final outOfBox = _boxOf(find.descendant(
      of: find.byType(PickerField).last,
      matching: find.text('100'),
    ));

    expect(tester.getSize(dateBox).height, 48);
    expect(tester.getSize(outOfBox).height, closeTo(48, 2.5));
    expect(tester.getTopLeft(outOfBox).dy, tester.getTopLeft(dateBox).dy,
        reason: 'the two fields of the same row do not start at the same height');
    expect(
      tester.getTopLeft(find.text(t('teacher.outOf'))).dy,
      tester.getTopLeft(find.text(t('teacher.dueDate'))).dy,
      reason: 'the two labels of the same row do not start at the same height',
    );
  });

  testWidgets('the homework sheet lines up the due date with how long it takes, '
      'even though its label runs onto a second line', (tester) async {
    await _openSheet(tester, const HomeworkTab());

    final dateBox = _boxOf(find.byIcon(Icons.calendar_today_rounded));
    final minutesBox = _boxOf(find.descendant(
      of: find.byType(PickerField).last,
      matching: find.text(tn('teacher.minutes', 30)),
    ));

    expect(tester.getSize(find.text(t('teacher.howLong'))).height,
        greaterThan(tester.getSize(find.text(t('teacher.due'))).height));
    expect(tester.getTopLeft(minutesBox).dy, tester.getTopLeft(dateBox).dy,
        reason: 'the two fields of the same row do not start at the same height');
    expect(
      tester.getTopLeft(find.text(t('teacher.howLong'))).dy,
      tester.getTopLeft(find.text(t('teacher.due'))).dy,
      reason: 'the two labels of the same row do not start at the same height',
    );
  });
}
