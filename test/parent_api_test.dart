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
      // NOT the title. Exam.title is nullable on the server and plenty of rows
      // arrive without one; the screens fall back to the subject, so that is
      // the field that has to be there.
      expect(e.subject, isNotEmpty);
      expect(e.maxScore, greaterThan(0));
      expect(e.kind, isNotEmpty);
    }
  });

  test('attendance parses with a rate the card can colour', () async {
    final a = await ParentApi.instance.attendance(child.studentId);
    expect(a.total, greaterThan(0), reason: 'no register has been marked');
    expect(a.ratePercent, inInclusiveRange(0, 100));
    expect(a.present + a.absent + a.late + a.excused, lessThanOrEqualTo(a.total + 1));
  });

  test('the attendance trend carries a band and a caption the screen can use', () async {
    final trend = await ParentApi.instance.attendanceTrend(child.studentId);

    expect(
      ['OK', 'WATCH', 'CONCERN', 'UNKNOWN'],
      contains(trend.band),
      reason: 'the banner takes its colour and wording from band alone',
    );
    expect(
      trend.termName != null || (trend.from != null && trend.to != null),
      isTrue,
      reason: 'every figure is captioned from the response, never from a hardcoded term',
    );

    if (trend.daysMarked == 0) {
      expect(trend.missedPercent, isNull, reason: 'nothing marked is not nought per cent');
      expect(trend.attendanceRate, isNull);
      expect(trend.band, 'UNKNOWN');
    } else {
      expect(trend.missedPercent, inInclusiveRange(0, 100));
      expect(trend.attendanceRate, inInclusiveRange(0, 100));
      expect(
        trend.daysMissed,
        trend.absent + trend.excused,
        reason: 'missed must mean what the office means by it',
      );
    }

    for (final m in trend.byMonth) {
      expect(
        m.monthNumber,
        inInclusiveRange(1, 12),
        reason: 'the bar label reads monthShort.<n>, so n must be a real month',
      );
    }

    if (trend.direction != null) {
      expect(['BETTER', 'WORSE', 'SAME'], contains(trend.direction));
      expect(trend.previous, isNotNull, reason: 'a direction with nothing to compare against');
    }
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

  test('consent forms parse, and every child on the account is in the book', () async {
    final book = await ParentApi.instance.consents();

    final children = await ParentApi.instance.children();
    expect(
      book.children.map((c) => c.studentId).toSet(),
      containsAll(children.map((c) => c.studentId)),
      reason: 'a child missing here cannot be signed for at all',
    );

    var awaiting = 0;
    for (final child in book.children) {
      expect(child.name, isNotEmpty);
      awaiting += child.awaitingCount;

      for (final form in child.forms) {
        expect(form.policyVersionId, isNotEmpty, reason: 'the form screen is opened by this id');
        expect(kConsentPurposes, contains(form.purpose));
        if (form.status != null) expect(kConsentStatuses, contains(form.status));
        if (form.status == 'GRANTED' || form.status == 'REFUSED') {
          expect(
            form.awaitingAnswer,
            isFalse,
            reason: 'the chip must never say "not answered yet" about a decision the family made',
          );
        }
        if (form.canWithdraw) {
          expect(form.status, 'GRANTED');
          expect(form.consentId, isNotNull, reason: 'withdrawing posts to this id');
        }
        for (final language in form.languages) {
          expect(kConsentBodyLanguages, contains(language));
        }
      }
    }
    expect(book.awaitingCount, awaiting, reason: 'the badge and the per-child pills must agree');
  });

  test('a consent form comes back with wording the parent can actually read', () async {
    final book = await ParentApi.instance.consents();
    final child = book.children.firstWhere(
      (c) => c.forms.isNotEmpty,
      orElse: () => ChildConsents(
        studentId: '',
        code: '',
        name: '',
        awaitingCount: 0,
        forms: const [],
      ),
    );
    if (child.forms.isEmpty) return;

    final detail = await ParentApi.instance.consentForm(
      policyVersionId: child.forms.first.policyVersionId,
      studentId: child.studentId,
    );
    expect(detail.studentId, child.studentId);
    expect(detail.form.policyVersionId, child.forms.first.policyVersionId);
    if (detail.form.languages.isNotEmpty) {
      expect(
        detail.form.wording,
        isNotNull,
        reason: 'the server says wording exists, so the screen must find a body to show',
      );
    }
  });

  test('route safety parses, and no rate is ever faked as a zero', () async {
    final children = await ParentApi.instance.children();
    expect(children, isNotEmpty);

    var riders = 0;
    for (final child in children) {
      final safety = await ParentApi.instance.routeSafety(child.studentId);

      expect(safety.from, isNotEmpty, reason: 'the screen captions every figure with the period');
      expect(safety.to, isNotEmpty);
      expect(safety.days, greaterThan(0));

      if (!safety.ridesTheBus) {
        expect(safety.route, isNull);
        expect(safety.child, isNull);
        expect(safety.alerts, isNull);
        expect(safety.reaching, isNull);
        continue;
      }
      riders++;

      final route = safety.route;
      final own = safety.child;
      final alerts = safety.alerts;
      final reaching = safety.reaching;
      expect(route, isNotNull, reason: 'the four blocks are null together, never one at a time');
      expect(own, isNotNull);
      expect(alerts, isNotNull);
      expect(reaching, isNotNull);

      for (final rate in <double?>[
        route!.checksCompletedRatePct,
        route.everyChildAccountedForRatePct,
        route.onTimeRatePct,
      ]) {
        if (rate != null) expect(rate, inInclusiveRange(0, 100));
      }

      if (route.notEnoughRuns) {
        expect(
          route.checksCompletedRatePct ?? route.everyChildAccountedForRatePct ?? route.onTimeRatePct,
          isNull,
          reason: 'a withheld rate must arrive as null, never as a 0% the parent would believe',
        );
      }
      expect(route.minimumRuns, greaterThan(0), reason: 'the withheld message quotes this number');
      expect(route.onTimeWithinSeconds, greaterThan(0));

      if (safety.locationHidden) {
        expect(route.name, isNull, reason: 'a restriction order must not leak the route');
        expect(route.code, isNull);
        expect(route.avgDelayMinutes, isNull);
      }

      expect(own!.tripsRidden, lessThanOrEqualTo(own.tripsExpected + own.notExpected));
      expect(alerts!.answered, lessThanOrEqualTo(alerts.raised));
      if (alerts.raised == 0) expect(alerts.answeredRatePct, isNull);
      expect(reaching!.delivered, lessThanOrEqualTo(reaching.sent));
      if (reaching.sent == 0) expect(reaching.deliveredRatePct, isNull);
    }

    expect(riders, greaterThan(0), reason: 'no child on this account rides a bus, so nothing was checked');
  });

  test('home arrivals parse, and the button is only offered once the bus has gone', () async {
    final rows = await ParentApi.instance.homeArrivals();
    for (final row in rows) {
      expect(row.tripId, isNotEmpty, reason: 'this is posted back as tripInstanceId');
      expect(row.studentId, isNotEmpty);
      if (row.awaitingConfirmation) {
        expect(row.offTheBus, isTrue, reason: 'confirming before the drop-off is refused by the server');
        expect(row.confirmedAt, isNull);
      }
      if (row.confirmedAt != null) expect(row.awaitingConfirmation, isFalse);
    }
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
