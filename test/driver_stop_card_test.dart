import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/crew_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/driver/roster_kit.dart';
import 'package:student_app/screens/driver/trip_screen.dart';

RiderOnStop _rider(
  String id,
  String name, {
  DateTime? boardedAt,
  DateTime? alightedAt,
  String? resolution,
  bool assistance = false,
}) =>
    RiderOnStop(
      studentId: id,
      name: name,
      pickup: null,
      seatNumber: '12',
      requiresAssistance: assistance,
      boardedAt: boardedAt,
      alightedAt: alightedAt,
      resolution: resolution,
    );

PlannedStop _stop({
  required List<RiderOnStop> students,
  DateTime? arrivedAt,
  DateTime? departedAt,
  bool skipped = false,
  String? skippedReason,
  String name = 'Ari Hawre Ahmed Mohammed Karim',
  String stopId = 'ckstopaaaaaaaaaaaaaaaaaaa',
}) =>
    PlannedStop(
      stopId: stopId,
      name: name,
      landmark: 'Ankawa, near the church of Mar Yousif on the main road',
      lat: 36.2,
      lon: 44.0,
      plannedSequence: 1,
      metresAway: 850,
      students: students,
      arrivedAt: arrivedAt,
      departedAt: departedAt,
      skipped: skipped,
      skippedReason: skippedReason,
      etaAt: DateTime(2026, 9, 13, 6, 54),
      etaIsActual: false,
      dwellSeconds: 60,
      driveSeconds: 120,
    );

class _Case {
  const _Case(this.label, this.card, this.expects);

  final String label;
  final Widget Function() card;
  final List<String> expects;
}

Future<void> _pump(WidgetTester tester, Lang lang, Widget child) async {
  AppLocale.current.value = lang;
  tester.view.physicalSize = const Size(360, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: lang.direction,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 2600),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

bool _live(WidgetTester tester, String label) {
  final ink = tester.widget<InkWell>(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
  );
  return ink.onTap != null;
}

void main() {
  final earlier = DateTime.now().subtract(const Duration(minutes: 10));
  final justNow = DateTime.now().subtract(const Duration(seconds: 5));

  StopCard card({
    required PlannedStop stop,
    String leg = 'OUT',
    bool running = true,
    bool started = true,
    bool current = true,
    bool locked = false,
  }) =>
      StopCard(
        stop: stop,
        tripId: 'cktripaaaaaaaaaaaaaaaaaaa',
        leg: leg,
        terminalStopId: 'ckgateaaaaaaaaaaaaaaaaaaa',
        schoolReached: false,
        running: running,
        started: started,
        current: current,
        locked: locked,
        onChanged: () {},
      );

  List<PlannedStop> returnRun({required bool checked}) => [
        _stop(
          stopId: 'ckstopbbbbbbbbbbbbbbbbbbb',
          name: 'Lana Azad Hassan Omar',
          students: [_rider('ckb', 'Lana Azad Hassan Omar', boardedAt: earlier)],
        ),
        _stop(
          stopId: 'ckstopccccccccccccccccccc',
          name: 'Rebin Dler Rasul Mahmood',
          students: [
            _rider('ckc', 'Rebin Dler Rasul Mahmood', resolution: checked ? 'NO_SHOW' : null),
          ],
        ),
        _stop(
          stopId: 'ckstopddddddddddddddddddd',
          name: 'Shvan Kamaran Aziz',
          students: [
            _rider('ckd', 'Shvan Kamaran Aziz', boardedAt: checked ? earlier : null),
          ],
        ),
      ];

  BoardingCheckCard boarding(List<PlannedStop> stops, {bool canCheck = true, String? lockedNoteKey}) =>
      BoardingCheckCard(
        stops: stops,
        schoolName: 'Sunrise International School of Erbil',
        canCheck: canCheck,
        lockedNoteKey: lockedNoteKey,
        busyStudent: null,
        busyAll: false,
        onBoard: (_, _) {},
        onNotHere: (_, _) {},
        onCorrect: (_, _) {},
        onAllOnBus: () {},
      );

  List<PlannedStop> outRun({required bool allOff}) => [
        _stop(
          stopId: 'ckstopbbbbbbbbbbbbbbbbbbb',
          arrivedAt: earlier,
          departedAt: earlier,
          students: [
            _rider('ckb', 'Lana Azad Hassan Omar', boardedAt: earlier, alightedAt: allOff ? justNow : null),
          ],
        ),
        _stop(
          stopId: 'ckstopccccccccccccccccccc',
          arrivedAt: earlier,
          departedAt: earlier,
          students: [
            _rider('ckc', 'Rebin Dler Rasul Mahmood', boardedAt: earlier, alightedAt: allOff ? justNow : null),
          ],
        ),
      ];

  SchoolArrivalCard arrival(List<PlannedStop> stops, {DateTime? arrivedAt}) => SchoolArrivalCard(
        stops: stops,
        schoolName: 'Sunrise International School of Erbil',
        running: true,
        started: true,
        canArrive: true,
        arrivedAt: arrivedAt,
        busyStudent: null,
        busyAll: false,
        onArrive: () {},
        onDrop: (_, _) {},
        onAllOff: () {},
      );

  final cases = <_Case>[
    _Case(
      'collapsed',
      () => card(
        stop: _stop(students: [_rider('cka', 'Ari Hawre')]),
        current: false,
      ),
      ['driver.nLeft'],
    ),
    _Case(
      'current OUT before arrival',
      () => card(stop: _stop(students: [_rider('cka', 'Ari Hawre Ahmed Mohammed Karim')])),
      ['driver.flow.guide', 'driver.flow.arrive', 'driver.flow.skip', 'driver.flow.child', 'driver.flow.leave', 'driver.arrived', 'driver.skipStop', 'driver.pickUp', 'driver.notHere', 'driver.movingOn'],
    ),
    _Case(
      'current OUT holding with several children',
      () => card(
        stop: _stop(
          arrivedAt: justNow,
          students: [
            _rider('cka', 'Ari Hawre Ahmed Mohammed Karim', assistance: true),
            _rider('ckb', 'Lana Azad Hassan Omar', boardedAt: justNow),
            _rider('ckc', 'Rebin Dler Rasul', resolution: 'NO_SHOW'),
            _rider('ckd', 'Shvan Kamaran Aziz', boardedAt: earlier, alightedAt: justNow),
          ],
        ),
      ),
      ['driver.flow.guideMany', 'driver.flow.children', 'driver.holdAtStop', 'driver.setDown', 'driver.wrong'],
    ),
    _Case(
      'current RETURN',
      () => card(
        leg: 'RETURN',
        stop: _stop(
          arrivedAt: earlier,
          students: [
            _rider('cka', 'Ari Hawre Ahmed Mohammed Karim', boardedAt: earlier),
            _rider('ckb', 'Lana Azad Hassan Omar', boardedAt: earlier),
          ],
        ),
      ),
      ['driver.handOver', 'driver.arrivedAt'],
    ),
    _Case(
      'done',
      () => card(
        current: false,
        stop: _stop(
          arrivedAt: earlier,
          departedAt: justNow,
          students: [_rider('cka', 'Ari Hawre', boardedAt: earlier)],
        ),
      ),
      ['driver.done'],
    ),
    _Case(
      'skipped',
      () => card(
        stop: _stop(
          skipped: true,
          skippedReason: 'Road closed by the police near the roundabout',
          students: [_rider('cka', 'Ari Hawre')],
        ),
      ),
      ['driver.skipped', 'driver.flow.skip'],
    ),
    _Case(
      'run ended with a child aboard',
      () => card(
        running: false,
        stop: _stop(
          arrivedAt: earlier,
          students: [_rider('cka', 'Ari Hawre', boardedAt: earlier)],
        ),
      ),
      ['driver.dropAfterEnd', 'driver.setDown'],
    ),
    _Case(
      'not set off yet',
      () => card(
        running: false,
        started: false,
        stop: _stop(students: [_rider('cka', 'Ari Hawre')]),
      ),
      ['driver.tickAfterSetOff', 'driver.arrived'],
    ),
    _Case(
      'RETURN home stop locked until the school check',
      () => card(
        leg: 'RETURN',
        locked: true,
        stop: _stop(students: [_rider('cka', 'Ari Hawre', boardedAt: earlier)]),
      ),
      ['driver.gate.checkFirst', 'driver.handOver', 'driver.movingOn'],
    ),
    _Case(
      'boarding at school, part checked',
      () => boarding(returnRun(checked: false)),
      ['driver.gate.boardingTitle', 'driver.gate.boardingHow', 'driver.gate.onTheBus', 'driver.notHere', 'driver.wrong', 'driver.gate.allOnBus'],
    ),
    _Case(
      'boarding at school, before the bus check',
      () => boarding(returnRun(checked: false), canCheck: false, lockedNoteKey: 'driver.mustCheckBus'),
      ['driver.mustCheckBus', 'driver.gate.onTheBus'],
    ),
    _Case(
      'boarding at school, done',
      () => boarding(returnRun(checked: true)),
      ['driver.gate.boardingTitle', 'driver.done'],
    ),
    _Case(
      'arrived at school, children still aboard',
      () => arrival(outRun(allOff: false)),
      ['driver.gate.arrivalTitle', 'driver.gate.arrivalHow', 'driver.arrived', 'driver.setDown', 'driver.recordAllOffOut', 'driver.gate.dropFirst'],
    ),
    _Case(
      'arrived at school, everyone off',
      () => arrival(outRun(allOff: true), arrivedAt: earlier),
      ['driver.gate.arrivalTitle', 'driver.done'],
    ),
  ];

  group('boarding check at school', () {
    testWidgets('incomplete: home stops locked, nothing handed over', (tester) async {
      final stops = returnRun(checked: false);
      expect(schoolCheckOpen('RETURN', stops), isTrue);
      expect(schoolCheckOpen('OUT', stops), isFalse);

      await _pump(tester, Lang.en, boarding(stops));
      expect(find.text(tv('driver.gate.checked', {'done': 1, 'all': 3})), findsOneWidget);
      expect(_live(tester, tn('driver.gate.allOnBus', 2)), isTrue);
      expect(_live(tester, t('driver.gate.onTheBus')), isTrue);

      await _pump(
        tester,
        Lang.en,
        card(leg: 'RETURN', locked: true, stop: stops.first),
      );
      expect(find.text(t('driver.gate.checkFirst')), findsOneWidget);
      expect(_live(tester, t('driver.handOver')), isFalse);
      expect(_live(tester, t('driver.movingOn')), isFalse);
      expect(_live(tester, t('driver.arrived')), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('complete: home stops unlocked, not-here child is not handed over', (tester) async {
      final stops = returnRun(checked: true);
      expect(schoolCheckOpen('RETURN', stops), isFalse);

      await _pump(tester, Lang.en, boarding(stops));
      expect(
        find.textContaining(tv('driver.gate.boardingDone', {'on': 2, 'away': 1})),
        findsWidgets,
      );
      expect(find.text(tn('driver.gate.allOnBus', 0)), findsNothing);

      await _pump(tester, Lang.en, card(leg: 'RETURN', stop: stops.first));
      expect(find.text(t('driver.gate.checkFirst')), findsNothing);
      expect(_live(tester, t('driver.handOver')), isTrue);

      await _pump(tester, Lang.en, card(leg: 'RETURN', stop: stops[1]));
      expect(find.text(t('driver.handOver')), findsNothing);
      expect(find.text(t('driver.pickUp')), findsNothing);
      expect(find.text(t('driver.notRiding')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('boarding check before Set off on the way home', () {
    CrewTrip trip(String status, {bool started = false, bool ended = false}) => CrewTrip.fromJson({
          'id': 'cktripaaaaaaaaaaaaaaaaaaa',
          'leg': 'RETURN',
          'status': status,
          'serviceDate': '2026-09-13',
          'startedAt': started ? '2026-09-13T11:00:00Z' : null,
          'endedAt': ended ? '2026-09-13T12:00:00Z' : null,
        });

    testWidgets('the check is live once the bus check is done, and Set off waits for it', (tester) async {
      final open = returnRun(checked: false);
      final done = returnRun(checked: true);

      expect(canCheckAtSchool(trip('ROSTERED')), isFalse);
      expect(canCheckAtSchool(trip('BLOCKED')), isFalse);
      expect(canCheckAtSchool(trip('BOARDING')), isTrue);
      expect(canCheckAtSchool(trip('IN_PROGRESS', started: true)), isTrue);
      expect(canCheckAtSchool(trip('COMPLETED', started: true, ended: true)), isFalse);
      expect(canCheckAtSchool(null), isFalse);

      expect(mustCheckBeforeSetOff('RETURN', false, open), isTrue);
      expect(mustCheckBeforeSetOff('RETURN', false, done), isFalse);
      expect(mustCheckBeforeSetOff('RETURN', true, open), isFalse);
      expect(mustCheckBeforeSetOff('OUT', false, open), isFalse);

      await _pump(tester, Lang.en, boarding(open, canCheck: canCheckAtSchool(trip('BOARDING'))));
      expect(find.text(t('driver.tickAfterSetOff')), findsNothing);
      expect(find.text(t('driver.gate.boardingHow')), findsOneWidget);
      expect(_live(tester, t('driver.gate.onTheBus')), isTrue);
      expect(_live(tester, t('driver.notHere')), isTrue);
      expect(_live(tester, tn('driver.gate.allOnBus', 2)), isTrue);

      await _pump(
        tester,
        Lang.en,
        boarding(open, canCheck: canCheckAtSchool(trip('ROSTERED')), lockedNoteKey: 'driver.mustCheckBus'),
      );
      expect(find.text(t('driver.mustCheckBus')), findsOneWidget);
      expect(_live(tester, t('driver.gate.onTheBus')), isFalse);
      expect(_live(tester, tn('driver.gate.allOnBus', 2)), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('arrived at school on the way in', () {
    testWidgets('the run cannot end until every child is off', (tester) async {
      final aboard = outRun(allOff: false);
      expect(mustDropAtSchool('OUT', aboard), isTrue);
      expect(mustDropAtSchool('RETURN', aboard), isFalse);

      await _pump(tester, Lang.en, arrival(aboard));
      expect(find.text(t('driver.gate.dropFirst')), findsOneWidget);
      expect(_live(tester, t('driver.arrived')), isTrue);
      expect(_live(tester, t('driver.setDown')), isFalse);
      expect(_live(tester, tn('driver.recordAllOffOut', 2)), isFalse);

      await _pump(tester, Lang.en, arrival(aboard, arrivedAt: justNow));
      expect(_live(tester, t('driver.setDown')), isTrue);
      expect(_live(tester, tn('driver.recordAllOffOut', 2)), isTrue);

      final off = outRun(allOff: true);
      expect(mustDropAtSchool('OUT', off), isFalse);
      await _pump(tester, Lang.en, arrival(off, arrivedAt: justNow));
      expect(find.text(t('driver.gate.dropFirst')), findsNothing);
      expect(find.textContaining(tn('driver.gate.offAtSchool', 2)), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  for (final lang in Lang.values) {
    for (final c in cases) {
      testWidgets('${c.label} fits 360dp at 1.3x in ${lang.code}', (tester) async {
        await _pump(tester, lang, c.card());

        expect(tester.takeException(), isNull);

        for (final key in c.expects) {
          final phrase = tableFor(lang)[key]!;
          final head = phrase
              .split('{n}')
              .map((p) => p.trim())
              .reduce((x, y) => y.length > x.length ? y : x);
          expect(
            find.textContaining(head, findRichText: true),
            findsWidgets,
            reason: '$key missing in ${c.label} (${lang.code})',
          );
        }

        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        AppLocale.current.value = Lang.en;
      });
    }
  }
}
