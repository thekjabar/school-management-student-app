// Does the new staff announcements endpoint answer, and does the client parse
// what it sends? The controller was written against the parent one; this is the
// only thing that proves the two payloads actually agree.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/session.dart';
import 'package:student_app/api/teacher_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    final r = await Session.instance.signIn('07511100001', 'School@123');
    expect(r.me.role, 'TEACHER');
  });

  test('a teacher can read the school announcements', () async {
    final rows = await TeacherApi.instance.announcements();
    expect(rows, isNotEmpty, reason: 'no announcements reached the teacher');
    for (final a in rows.take(3)) {
      expect(a.id, isNotEmpty);
      expect(a.title, isNotEmpty);
      // ignore: avoid_print
      print('  ${a.title}  —  ${a.sentAt}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
