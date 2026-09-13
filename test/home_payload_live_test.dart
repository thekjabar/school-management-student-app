import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/boot.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/api/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  test('home payload loads for a guardian without the package', () async {
    await Session.instance.signIn('07501190001', 'School@123');
    final children = await ParentApi.instance.children();
    final child = children.first;
    await Entitlements.instance.ensureLoaded();
    final now = Entitlements.instance.current.value;
    for (final key in const [ParentSection.bus, ParentSection.timetable, ParentSection.attendance, ParentSection.assignments, ParentSection.attitude, ParentSection.calendar]) {
      stdout.writeln('$key -> ${now.access(child.studentId, key)}');
    }
    try {
      final payload = await HomePayload.fetch(
        child.studentId,
        open: (section) => now.access(child.studentId, section) == SectionAccess.open,
      );
      stdout.writeln('home ok: ${payload.homework.length} homework, ${payload.week.length} days');
    } catch (e, st) {
      stdout.writeln('HOME FAILED: ${e.runtimeType}: $e');
      stdout.writeln(st.toString().split('\n').take(12).join('\n'));
      rethrow;
    }
  });
}
