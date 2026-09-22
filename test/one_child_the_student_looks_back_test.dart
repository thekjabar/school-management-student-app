import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/session.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/student/student_app.dart';

Map<String, dynamic> _school({
  required String studentId,
  required String tenantId,
  required String schoolName,
  required bool stillEnrolled,
  required bool current,
  String? from,
  String? to,
}) =>
    {
      'studentId': studentId,
      'tenantId': tenantId,
      'schoolName': schoolName,
      'schoolNames': {'en': schoolName, 'ckb': schoolName, 'ar': schoolName},
      'from': from,
      'to': to,
      'stillEnrolled': stillEnrolled,
      'current': current,
    };

Map<String, dynamic> _me(String tenantId, String schoolName) => {
      'person': {
        'id': 'per_hana',
        'name': 'Hana Aziz',
        'names': {'en': 'Hana Aziz'},
        'phoneE164': '',
        'phoneVerified': false,
      },
      'active': {'tenantId': tenantId, 'tenantKind': 'SCHOOL', 'role': 'STUDENT'},
      'memberships': [
        {
          'tenantId': tenantId,
          'tenantKind': 'SCHOOL',
          'tenantName': schoolName,
          'role': 'STUDENT',
        },
      ],
    };

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  final calls = <({String path, String method, String? auth, String? tenant})>[];

  late bool openedNewest;
  late bool leftSchoolInView;

  setUp(() async {
    calls.clear();
    openedNewest = false;
    leftSchoolInView = false;
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.clear();
    Session.instance.mySchools.value = const [];
    Session.instance.readOnlyHere.value = false;

    ApiClient.instance.httpForTest = MockClient((request) async {
      final path = request.url.path;
      calls.add((
        path: path,
        method: request.method,
        auth: request.headers['Authorization'],
        tenant: request.headers['X-Tenant-Id'],
      ));

      if (path == '/me/schools') {
        return _json({
          'schools': [
            _school(
              studentId: 'stu_new',
              tenantId: 'ten_new',
              schoolName: 'Newest School',
              stillEnrolled: true,
              current: openedNewest,
              from: '2026-09-01',
            ),
            _school(
              studentId: 'stu_old',
              tenantId: 'ten_old',
              schoolName: 'Older School',
              stillEnrolled: false,
              current: leftSchoolInView || !openedNewest,
              from: '2023-09-01',
              to: '2026-06-30',
            ),
          ],
        });
      }

      if (path == '/me/schools/stu_new/open') {
        openedNewest = true;
        leftSchoolInView = false;
        return _json({
          'accessToken': 'token-for-newest',
          'refreshToken': 'refresh-for-newest',
          'studentId': 'stu_new',
          'tenantId': 'ten_new',
          'readOnly': false,
        });
      }

      if (path == '/me/schools/stu_old/open') {
        openedNewest = false;
        leftSchoolInView = true;
        return _json({
          'accessToken': 'token-for-older',
          'refreshToken': 'refresh-for-older',
          'studentId': 'stu_old',
          'tenantId': 'ten_old',
          'readOnly': true,
        });
      }

      if (path == '/auth/me') {
        return _json(
          openedNewest
              ? _me('ten_new', 'Newest School')
              : _me('ten_old', 'Older School'),
        );
      }

      if (path == '/auth/locale') return _json({'ok': true});

      return _json({'message': 'not here'}, 404);
    });
  });

  test('signing in with an old code lands the child in the school they are at now', () async {
    await Session.instance.settleNewestSchool();

    expect(
      calls.where((c) => c.path == '/me/schools/stu_new/open' && c.method == 'POST'),
      hasLength(1),
    );
    expect(Session.instance.me?.active.tenantId, 'ten_new');
    expect(Session.instance.readOnlyHere.value, isFalse);
  });

  test('the school in view is never swapped when the child is already at the newest', () async {
    openedNewest = true;

    await Session.instance.settleNewestSchool();

    expect(calls.where((c) => c.path.endsWith('/open')), isEmpty);
    expect(Session.instance.mySchools.value.first.studentId, 'stu_new');
  });

  test('every request after a switch carries the new school token, never the old one', () async {
    await ApiClient.instance.saveSession(access: 'token-before', tenantId: 'ten_old');

    await Session.instance.openSchool('stu_new');

    final after = calls
        .sublist(calls.indexWhere((c) => c.path == '/me/schools/stu_new/open') + 1)
        .where((c) => c.auth != null);
    expect(after, isNotEmpty);
    for (final call in after) {
      expect(call.auth, 'Bearer token-for-newest');
      expect(call.tenant, 'ten_new');
    }
  });

  test('a school the child has left opens to look at, not to change', () async {
    await Session.instance.openSchool('stu_old');

    expect(Session.instance.readOnlyHere.value, isTrue);
    expect(Session.instance.me?.active.tenantId, 'ten_old');
  });

  testWidgets('the child is told plainly when a school is theirs to look at only',
      (tester) async {
    Session.instance.readOnlyHere.value = false;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StudentReadOnlyBanner())),
    );
    await tester.pumpAndSettle();
    expect(find.text(t('student.readOnlyHere')), findsNothing);

    Session.instance.readOnlyHere.value = true;
    await tester.pumpAndSettle();
    expect(find.text(t('student.schoolLeft')), findsOneWidget);
    expect(find.text(t('student.readOnlyHere')), findsOneWidget);
  });
}
