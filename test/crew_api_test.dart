// The driver app's own API layer, against the live platform.
//
// Same contract as parent_api_test: no mocks, real responses through the real
// model constructors, so a renamed field fails here rather than on a bus.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/crew_api.dart';
import 'package:student_app/api/session.dart';

const phone = '07701100001';
const password = 'School@123';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    final r = await Session.instance.signIn(phone, password);
    expect(r.me.role, anyOf('DRIVER', 'ATTENDANT'), reason: 'not a crew account');
  });

  test('today parses', () async {
    final rows = await CrewApi.instance.today();
    // ignore: avoid_print
    print('  today: ${rows.length} run(s)');
    for (final t in rows) {
      // ignore: avoid_print
      print('    ${t.routeName} ${t.leg} ${t.status} bus=${t.vehicleLabel} plate=${t.plate}');
    }
  });

  test('the week parses, and a plan comes back for one of its runs', () async {
    final rows = await CrewApi.instance.trips(days: 14);
    expect(rows, isNotEmpty, reason: 'no runs at all in a fortnight');
    // ignore: avoid_print
    print('  fortnight: ${rows.length} run(s)');

    final trip = rows.first;
    final plan = await CrewApi.instance.plan(trip.id);
    expect(plan.stops, isNotEmpty, reason: 'a run with no stops');
    // ignore: avoid_print
    print('  plan: ${plan.stops.length} stops, '
        '${plan.counts.expected} expected, ${plan.counts.boarded} boarded');
    for (final s in plan.stops.take(3)) {
      // ignore: avoid_print
      print('    ${s.plannedSequence}. ${s.name} — ${s.students.length} rider(s)');
    }

    final counts = await CrewApi.instance.headcount(trip.id);
    expect(counts.summary, isNotEmpty);

    final sweep = await CrewApi.instance.sweepState(trip.id);
    // ignore: avoid_print
    print('  sweep: required=${sweep.required_} confirmed=${sweep.confirmedAt}');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('the crew profile parses', () async {
    final me = await CrewApi.instance.me();
    expect(me, isNotEmpty);
  });
}
