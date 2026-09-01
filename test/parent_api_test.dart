// Runs the parent app's OWN api layer against the live platform.
//
// Not a mock in sight. Every bug that reached the user in the console got
// through because the API was tested with curl while the CLIENT was never run —
// and the client is where the failures live: a field renamed, a shape that is
// an object where the model expects a list, a null the parser did not allow.
// curl says 200 and the screen still throws.
//
// So this signs in as a real guardian, calls every method the screens call, and
// pushes the real responses through the real model constructors. If a factory
// cannot parse what the server actually sends, this fails here rather than on
// somebody's phone.
//
//   flutter test test/parent_api_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/api/session.dart';

const phone = '07501100001';
const password = 'School@123';

void main() {
  // The token store is a Flutter plugin; in a test it needs a backing map.
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding installs an HttpOverrides that answers every request with
  // 400 and never touches the network. That is the right default for a widget
  // test and useless here: the whole point is to speak to the real platform.
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  late Child child;

  setUpAll(() async {
    final result = await Session.instance.signIn(phone, password);
    expect(result.me.id, isNotEmpty, reason: 'sign-in returned no person');
    expect(result.me.role, 'GUARDIAN');

    final children = await ParentApi.instance.children();
    expect(children, isNotEmpty, reason: 'this guardian has no children linked');
    child = children.first;
  });

  test('children parse, and carry what the home screen shows', () async {
    final children = await ParentApi.instance.children();
    for (final c in children) {
      expect(c.studentId, isNotEmpty);
      expect(c.name, isNotEmpty);
      expect(c.className, isNotEmpty, reason: 'the child picker shows the class');
    }
  });

  test('timetable parses into days of lessons', () async {
    final days = await ParentApi.instance.timetable(child.studentId);
    expect(days, isNotEmpty, reason: 'no timetable came back');
    final lessons = days.expand((d) => d.lessons).toList();
    expect(lessons, isNotEmpty);
    // The home screen sorts on period and prints a clock time from startMinute.
    expect(lessons.first.period, greaterThan(0));
    expect(lessons.any((l) => l.startMinute != null), isTrue);
    expect(lessons.any((l) => l.subject.isNotEmpty), isTrue);
  });

  test('homework parses, and the due-date arithmetic works', () async {
    final rows = await ParentApi.instance.homework(child.studentId);
    expect(rows, isNotEmpty);
    for (final h in rows) {
      expect(h.title, isNotEmpty);
      // daysLeft drives the "3 days late" / "due today" label.
      expect(h.daysLeft, isA<int>());
    }
  });

  test('published marks parse with a percentage', () async {
    final rows = await ParentApi.instance.results(child.studentId);
    expect(rows, isNotEmpty);
    final marked = rows.where((r) => !r.wasAbsent).toList();
    expect(marked, isNotEmpty);
    for (final r in marked) {
      expect(r.subject, isNotEmpty);
      expect(r.maxScore, greaterThan(0));
      // The home card averages on percent; a null here shows as an empty stat.
      expect(r.percent, isNotNull);
    }
  });

  test('upcoming exams parse', () async {
    final rows = await ParentApi.instance.upcomingExams(child.studentId);
    for (final e in rows) {
      expect(e.title, isNotEmpty);
      expect(e.subject, isNotEmpty);
    }
  });

  test('attendance parses with a rate the card can colour', () async {
    final a = await ParentApi.instance.attendance(child.studentId);
    expect(a.total, greaterThan(0), reason: 'no register has been marked');
    expect(a.ratePercent, inInclusiveRange(0, 100));
    expect(a.present + a.absent + a.late + a.excused, lessThanOrEqualTo(a.total + 1));
  });

  test('transport parses, including today\'s runs', () async {
    final t = await ParentApi.instance.transport(child.studentId);
    expect(t.ridesTheBus, isTrue, reason: 'this child should be on a bus in the demo data');
    expect(t.routeName, isNotNull);
    expect(t.pickupStopName, isNotNull);
    for (final run in t.today) {
      expect(run.tripId, isNotEmpty);
      expect(['OUT', 'RETURN'], contains(run.leg));
      // childLineKey feeds the home card's headline; it must always name a
      // real translation.
      expect(run.childLineKey, startsWith('bus.child.'));
    }
  });

  test('live bus parses, and gives a reason when the map is shut', () async {
    final rows = await ParentApi.instance.live();
    expect(rows, isNotEmpty);
    for (final l in rows) {
      expect(l.studentId, isNotEmpty);
      if (!l.visible) {
        // The bus tab prints this sentence rather than an empty map.
        expect(l.reasonText, isNotEmpty);
      }
    }
  });

  test('drop-off options parse', () async {
    final data = await ParentApi.instance.dropoffOptions(child.studentId);
    expect(data.note, isNotEmpty);
    for (final o in data.options) {
      expect(o.label, isNotEmpty);
    }
  });

  test('announcements parse for the messages tab', () async {
    final rows = await ParentApi.instance.announcements();
    expect(rows, isNotEmpty, reason: 'the messages tab would be empty');
    for (final n in rows) {
      expect(n.title, isNotEmpty);
      expect(n.body, isNotEmpty);
    }
    // The audience is resolved per family: a notice aimed at a grade this
    // family is not in must not appear.
    expect(rows.any((n) => n.title.contains('Excursion')), isFalse,
        reason: 'a grade-4 notice reached a family with no child in grade 4');
  });

  test('fees parse for the card and the fees screen', () async {
    final f = await ParentApi.instance.fees();
    expect(f.outstandingIqd, greaterThanOrEqualTo(0));
    expect(f.invoices, isNotEmpty, reason: 'nothing has been billed to this household');
    for (final i in f.invoices) {
      expect(i.serial, isNotEmpty);
      expect(i.totalIqd, greaterThan(0));
      expect(i.balanceIqd, lessThanOrEqualTo(i.totalIqd));
    }
  });

  test('leave requests parse, and one can be raised and withdrawn', () async {
    final before = await ParentApi.instance.leaveRequests();

    final today = DateTime.now();
    await ParentApi.instance.requestLeave(
      studentId: child.studentId,
      kind: 'SICK',
      from: today,
      to: today,
      reason: 'Automated check from the app test. Safe to ignore.',
    );

    final after = await ParentApi.instance.leaveRequests();
    expect(after.length, greaterThan(before.length), reason: 'the request was not created');

    final mine = after.firstWhere((r) => r.reason?.contains('Automated check') ?? false);
    expect(mine.status, 'PENDING');
    await ParentApi.instance.cancelLeave(mine.id);
  });

  test('a wrong password is reported as one, not as something else', () async {
    try {
      await Session.instance.signIn(phone, 'not-the-password');
      fail('a wrong password was accepted');
    } on ApiException catch (e) {
      expect(e.status, 401);
      expect(e.message.toLowerCase(), contains('not right'));
    }
  });
}
