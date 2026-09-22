import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/session.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/student/student_login.dart';

void main() {
  final calls = <({String path, Map<String, dynamic> body})>[];

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.httpForTest = MockClient((request) async {
      calls.add((
        path: request.url.path,
        body: request.body.isEmpty ? const {} : (jsonDecode(request.body) as Map).cast<String, dynamic>(),
      ));
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'chooseSchool': [
              {'id': 'cmtenanterbil000000001', 'name': 'Erbil School', 'names': {'ckb': 'قوتابخانەی هەولێر'}},
              {'id': 'cmtenantduhok000000002', 'name': 'Duhok School', 'names': {'ckb': 'قوتابخانەی دهۆک'}},
            ],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{"message":"not here"}', 404);
    });
  });

  test('the code and password go without a school, and two matching schools come back as a choice', () async {
    await expectLater(
      Session.instance.signInAsStudent(' STU-2026-00190 ', 'pass-1234'),
      throwsA(isA<SchoolChoiceNeeded>().having((c) => c.schools.map((s) => s.id).toList(), 'schools', [
        'cmtenanterbil000000001',
        'cmtenantduhok000000002',
      ])),
    );
    final login = calls.singleWhere((c) => c.path.endsWith('/auth/login'));
    expect(login.body.containsKey('tenantId'), isFalse);
    expect(login.body['code'], 'STU-2026-00190');

    calls.clear();
    await expectLater(
      Session.instance.signInAsStudent('STU-2026-00190', 'pass-1234', tenantId: 'cmtenantduhok000000002'),
      throwsA(isA<SchoolChoiceNeeded>()),
    );
    expect(calls.single.body['tenantId'], 'cmtenantduhok000000002');
  });

  testWidgets('the sign-in screen asks for a code and a password, never for a school', (tester) async {
    await tester.pumpWidget(MaterialApp(home: StudentLoginScreen(onSignedIn: (_) {})));
    await tester.pumpAndSettle();

    expect(find.text(t('student.code')), findsOneWidget);
    expect(find.text(t('login.password')), findsOneWidget);
    expect(find.text(t('student.whichSchool')), findsNothing);
    expect(calls.where((c) => c.path.endsWith('/auth/schools')), isEmpty);
  });
}
