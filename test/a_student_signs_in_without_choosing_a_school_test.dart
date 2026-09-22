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
          utf8.encode(jsonEncode({'message': 'This code and password fit more than one child. Ask the school office to help you sign in.'})),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{"message":"not here"}', 404);
    });
  });

  test('only the code and password are sent, never a school', () async {
    await expectLater(
      Session.instance.signInAsStudent(' STU-2026-00190 ', 'pass-1234'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
    );
    final login = calls.singleWhere((c) => c.path.endsWith('/auth/login'));
    expect(login.body.keys.toSet(), {'code', 'password'});
    expect(login.body['code'], 'STU-2026-00190');
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
