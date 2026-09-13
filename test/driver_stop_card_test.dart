import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/crew_api.dart';
import 'package:student_app/i18n/strings.dart';
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
}) =>
    PlannedStop(
      stopId: 'ckstopaaaaaaaaaaaaaaaaaaa',
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
  final StopCard Function() card;
  final List<String> expects;
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
        onChanged: () {},
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
  ];

  for (final lang in Lang.values) {
    for (final c in cases) {
      testWidgets('${c.label} fits 360dp at 1.3x in ${lang.code}', (tester) async {
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
                    child: c.card(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

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
