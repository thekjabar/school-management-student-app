import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:student_app/api/crew_api.dart';
import 'package:student_app/api/directions.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/driver/run_order.dart';
import 'package:student_app/screens/driver/run_route_cache.dart';

RiderOnStop _rider(String id, {DateTime? boardedAt, DateTime? alightedAt, String? resolution}) => RiderOnStop(
      studentId: id,
      name: 'Child $id',
      pickup: null,
      seatNumber: null,
      requiresAssistance: false,
      boardedAt: boardedAt,
      alightedAt: alightedAt,
      resolution: resolution,
    );

PlannedStop _stop(
  String id,
  int sequence, {
  double? lat,
  double? lon,
  DateTime? arrivedAt,
  DateTime? departedAt,
  bool skipped = false,
  bool noRiders = false,
  List<RiderOnStop>? riders,
}) =>
    PlannedStop(
      stopId: id,
      name: id,
      landmark: null,
      lat: lat,
      lon: lon,
      plannedSequence: sequence,
      metresAway: null,
      students: riders ?? (noRiders ? const [] : [_rider('ck$id')]),
      arrivedAt: arrivedAt,
      departedAt: departedAt,
      skipped: skipped,
      etaAt: null,
      etaIsActual: false,
      dwellSeconds: 0,
      driveSeconds: 0,
    );

const _gate = SchoolGate(stopId: 'ckgate', name: 'Sunrise School', lat: 36.20, lon: 44.00);

List<String> _ids(RunArrangement run) => [for (final s in run.stops) s.stopId];

void main() {
  setUp(() => AppLocale.current.value = Lang.en);

  group('nearestNeighbourOrder', () {
    test('starts at the cheapest stop and always moves to the cheapest remaining one', () {
      final at = [10.0, 1.0, 5.0, 2.0];
      final order = nearestNeighbourOrder(
        at.length,
        (to) => at[to],
        (from, to) => (at[from] - at[to]).abs(),
      );
      expect(order, [1, 3, 2, 0]);
    });

    test('keeps the earlier stop on a tie', () {
      expect(nearestNeighbourOrder(3, (_) => 1, (_, _) => 1), [0, 1, 2]);
    });

    test('handles an empty run', () {
      expect(nearestNeighbourOrder(0, (_) => 0, (_, _) => 0), isEmpty);
    });
  });

  group('arrangeRun', () {
    final far = _stop('far', 1, lat: 36.30, lon: 44.00);
    final mid = _stop('mid', 2, lat: 36.25, lon: 44.00);
    final near = _stop('near', 3, lat: 36.21, lon: 44.00);

    test('morning, bus known: closest stop to the bus first, then nearest onward', () {
      final run = arrangeRun(
        stops: [far, mid, near],
        leg: 'OUT',
        nearest: true,
        bus: const LatLng(36.205, 44.0),
        school: _gate,
      );
      expect(_ids(run), ['near', 'mid', 'far']);
      expect(run.basis, RunBasis.fromBus);
      expect(run.next!.stopId, 'near');
    });

    test('the bus position decides which stop comes first, not the office sequence', () {
      final run = arrangeRun(
        stops: [near, mid, far],
        leg: 'OUT',
        nearest: true,
        bus: const LatLng(36.31, 44.0),
      );
      expect(_ids(run), ['far', 'mid', 'near']);
    });

    test('office order keeps the office sequence for the stops still to do', () {
      final run = arrangeRun(
        stops: [near, far, mid],
        leg: 'OUT',
        nearest: false,
        bus: const LatLng(36.205, 44.0),
      );
      expect(_ids(run), ['far', 'mid', 'near']);
      expect(run.basis, RunBasis.office);
    });

    test('finished stops come first in the order they were served', () {
      final early = DateTime(2026, 9, 13, 7, 0);
      final later = DateTime(2026, 9, 13, 7, 10);
      final run = arrangeRun(
        stops: [
          _stop('a', 1, lat: 36.30, lon: 44.0, departedAt: later),
          _stop('b', 2, lat: 36.25, lon: 44.0, departedAt: early),
          near,
        ],
        leg: 'OUT',
        nearest: true,
        bus: const LatLng(36.24, 44.0),
      );
      expect(_ids(run), ['b', 'a', 'near']);
    });

    test('a stop the bus has arrived at stays first until it is left', () {
      final run = arrangeRun(
        stops: [far, mid, _stop('here', 4, lat: 36.30, lon: 44.0, arrivedAt: DateTime(2026, 9, 13, 7))],
        leg: 'OUT',
        nearest: true,
        bus: const LatLng(36.21, 44.0),
      );
      expect(_ids(run).first, 'here');
      expect(run.next!.stopId, 'here');
    });

    test('without a bus position and nothing done, the office order is kept and said so', () {
      final run = arrangeRun(stops: [near, far, mid], leg: 'OUT', nearest: true, school: _gate);
      expect(_ids(run), ['far', 'mid', 'near']);
      expect(run.basis, RunBasis.noPosition);
    });

    test('without a bus position the order carries on from the last stop left', () {
      final run = arrangeRun(
        stops: [_stop('left', 1, lat: 36.30, lon: 44.0, departedAt: DateTime(2026, 9, 13, 7)), near, mid],
        leg: 'OUT',
        nearest: true,
      );
      expect(_ids(run), ['left', 'mid', 'near']);
      expect(run.basis, RunBasis.fromLastStop);
    });

    test('afternoon without a bus position starts from school', () {
      final run = arrangeRun(stops: [far, mid, near], leg: 'RETURN', nearest: true, school: _gate);
      expect(_ids(run), ['near', 'mid', 'far']);
      expect(run.basis, RunBasis.fromSchool);
    });

    test('stops with no position go last and the school row keeps its end of the run', () {
      final gateRow = _stop('ckgate', 9, lat: 36.20, lon: 44.0, noRiders: true);
      final lost = _stop('lost', 0);
      final morning = arrangeRun(
        stops: [gateRow, lost, far, near],
        leg: 'OUT',
        nearest: true,
        bus: const LatLng(36.205, 44.0),
        school: _gate,
      );
      expect(_ids(morning), ['near', 'far', 'lost', 'ckgate']);

      final afternoon = arrangeRun(
        stops: [lost, far, gateRow, near],
        leg: 'RETURN',
        nearest: true,
        bus: const LatLng(36.205, 44.0),
        school: _gate,
      );
      expect(_ids(afternoon), ['ckgate', 'near', 'far', 'lost']);
      expect(runNumbers(afternoon.stops, _gate.stopId), [null, 1, 2, 3]);
    });

    test('a supplied travel cost wins over straight-line distance', () {
      final run = arrangeRun(
        stops: [far, mid, near],
        leg: 'OUT',
        nearest: true,
        bus: const LatLng(36.205, 44.0),
        cost: (from, to) => to.latitude == 36.30 ? 1 : 1000 + (from.latitude - to.latitude).abs(),
        road: true,
      );
      expect(_ids(run).first, 'far');
      expect(run.road, isTrue);
    });

    test('distances are measured from the bus and cleared for unplaced stops', () {
      final run = arrangeRun(
        stops: [near, _stop('lost', 5)],
        leg: 'OUT',
        nearest: true,
        bus: const LatLng(36.20, 44.0),
      );
      expect(run.stops.first.metresAway, closeTo(1112, 2));
      expect(run.stops.last.metresAway, isNull);
    });

    test('the server sequence numbers are never changed', () {
      final run = arrangeRun(
        stops: [far, mid, near],
        leg: 'OUT',
        nearest: true,
        bus: const LatLng(36.205, 44.0),
      );
      expect({for (final s in run.stops) s.stopId: s.plannedSequence}, {'far': 1, 'mid': 2, 'near': 3});
    });
  });

  group('route legs', () {
    test('morning ends at school, afternoon starts there', () {
      final done = _stop('done', 1, lat: 36.3, lon: 44.0, departedAt: DateTime(2026, 9, 13, 7));
      final next = _stop('next', 2, lat: 36.25, lon: 44.0);
      final later = _stop('later', 3, lat: 36.22, lon: 44.0);

      final out = runWaypoints(stops: [done, next, later], leg: 'OUT', school: _gate);
      expect([for (final w in out) w.key], ['pin-0', 'pin-1', 'pin-2', 'school']);
      expect(legStates(out), [LegState.next, LegState.later, LegState.later]);

      final back = runWaypoints(stops: [next, later], leg: 'RETURN', school: _gate);
      expect(back.first.school, isTrue);
      expect(back.first.done, isFalse);
      expect(legStates(back), [LegState.later, LegState.later]);

      final boarded = [
        _stop('next', 2, lat: 36.25, lon: 44.0, riders: [_rider('ck1', boardedAt: DateTime(2026, 9, 13, 14))]),
        _stop('later', 3, lat: 36.22, lon: 44.0, riders: [_rider('ck2', resolution: 'NO_SHOW'), _rider('ck3', boardedAt: DateTime(2026, 9, 13, 14))]),
      ];
      final home = runWaypoints(stops: boarded, leg: 'RETURN', school: _gate);
      expect(home.first.done, isTrue);
      expect(legStates(home), [LegState.next, LegState.later]);
    });

    test('once every stop is served the leg into school is the next one', () {
      final a = _stop('a', 1, lat: 36.3, lon: 44.0, departedAt: DateTime(2026, 9, 13, 7));
      final b = _stop('b', 2, lat: 36.25, lon: 44.0, skipped: true);
      final c = _stop('c', 3, lat: 36.22, lon: 44.0, departedAt: DateTime(2026, 9, 13, 7, 5));
      final out = runWaypoints(stops: [a, b, c], leg: 'OUT', school: _gate);
      expect([for (final w in out) w.id], ['a', 'c', 'school']);
      expect(legStates(out), [LegState.done, LegState.next]);
    });
  });

  group('run target', () {
    final boardedAt = DateTime(2026, 9, 13, 14);
    final gateRow = _stop('ckgate', 0, lat: 36.20, lon: 44.0, noRiders: true);

    test('afternoon, before the boarding check is complete, the only target is school', () {
      final stops = [
        gateRow,
        _stop('home1', 1, lat: 36.25, lon: 44.0, riders: [_rider('ck1'), _rider('ck2', boardedAt: boardedAt)]),
        _stop('home2', 2, lat: 36.30, lon: 44.0, riders: [_rider('ck3')]),
      ];
      final target = runTarget(stops: stops, leg: 'RETURN', school: _gate)!;
      expect(target.school, isTrue);
      expect(target.stop, isNull);
      expect(target.students, 2);
    });

    test('afternoon, once every child is checked, the first home stop is the target', () {
      final home1 = _stop('home1', 1, lat: 36.25, lon: 44.0, riders: [_rider('ck1', boardedAt: boardedAt)]);
      final stops = [
        gateRow,
        home1,
        _stop('home2', 2, lat: 36.30, lon: 44.0, riders: [_rider('ck3', resolution: 'NO_SHOW')]),
      ];
      final target = runTarget(stops: stops, leg: 'RETURN', school: _gate)!;
      expect(target.school, isFalse);
      expect(identical(target.stop, home1), isTrue);
    });

    test('afternoon with every home stop served has no target left', () {
      final stops = [
        _stop('home1', 1, lat: 36.25, lon: 44.0, departedAt: boardedAt, riders: [_rider('ck1', boardedAt: boardedAt, alightedAt: boardedAt)]),
      ];
      expect(runTarget(stops: stops, leg: 'RETURN', school: _gate), isNull);
    });

    test('morning ends at school: after the last home stop the target is school with the children aboard', () {
      final stops = [
        _stop('home1', 1, lat: 36.25, lon: 44.0, departedAt: boardedAt, riders: [_rider('ck1', boardedAt: boardedAt)]),
        _stop('home2', 2, lat: 36.30, lon: 44.0, skipped: true, riders: [_rider('ck2', resolution: 'NO_SHOW')]),
        _stop('home3', 3, lat: 36.22, lon: 44.0, departedAt: boardedAt, riders: [_rider('ck3', boardedAt: boardedAt), _rider('ck4', boardedAt: boardedAt)]),
        gateRow,
      ];
      final target = runTarget(stops: stops, leg: 'OUT', school: _gate)!;
      expect(target.school, isTrue);
      expect(target.students, 3);

      final waypoints = runWaypoints(stops: stops, leg: 'OUT', school: _gate);
      expect(waypoints.where((w) => !w.done).single.school, isTrue);
    });

    test('morning with a home stop still to do targets that stop, not school', () {
      final open = _stop('home1', 1, lat: 36.25, lon: 44.0);
      final target = runTarget(stops: [open, gateRow], leg: 'OUT', school: _gate)!;
      expect(identical(target.stop, open), isTrue);
    });

    test('afternoon order before boarding starts from school, not from a bus far away', () {
      final near = _stop('near', 1, lat: 36.21, lon: 44.0);
      final mid = _stop('mid', 2, lat: 36.25, lon: 44.0);
      final far = _stop('far', 3, lat: 36.30, lon: 44.0);
      final run = arrangeRun(
        stops: [far, mid, near],
        leg: 'RETURN',
        nearest: true,
        bus: const LatLng(36.31, 44.0),
        school: _gate,
      );
      expect(_ids(run), ['near', 'mid', 'far']);
      expect(run.basis, RunBasis.schoolFirst);
      expect(orderWaitsForBus(run.basis), isFalse);
    });
  });

  group('route cache rules', () {
    final near = _stop('near', 1, lat: 36.21, lon: 44.0);
    final mid = _stop('mid', 2, lat: 36.25, lon: 44.0);
    final far = _stop('far', 3, lat: 36.30, lon: 44.0);

    test('the route key ignores progress and the boarding check, so neither refetches', () {
      final before = runRouteKey(leg: 'RETURN', waypoints: runWaypoints(stops: [near, mid, far], leg: 'RETURN', school: _gate));
      final boarded = [
        for (final s in [near, mid, far])
          _stop(s.stopId, s.plannedSequence, lat: s.lat, lon: s.lon, riders: [_rider('ck${s.stopId}', boardedAt: DateTime(2026, 9, 13, 14))]),
      ];
      final after = runRouteKey(leg: 'RETURN', waypoints: runWaypoints(stops: boarded, leg: 'RETURN', school: _gate));
      expect(after, before);

      final served = [
        _stop('near', 1, lat: 36.21, lon: 44.0, departedAt: DateTime(2026, 9, 13, 15), riders: [_rider('cknear', boardedAt: DateTime(2026, 9, 13, 14))]),
        boarded[1],
        boarded[2],
      ];
      expect(runRouteKey(leg: 'RETURN', waypoints: runWaypoints(stops: served, leg: 'RETURN', school: _gate)), before);
    });

    test('the route key changes when a stop is skipped, a stop has nobody riding, or the order changes', () {
      String key(List<PlannedStop> stops) => runRouteKey(leg: 'OUT', waypoints: runWaypoints(stops: stops, leg: 'OUT', school: _gate));
      final base = key([near, mid, far]);
      expect(key([near, _stop('mid', 2, lat: 36.25, lon: 44.0, skipped: true), far]), isNot(base));
      expect(key([near, _stop('mid', 2, lat: 36.25, lon: 44.0, riders: [_rider('ckm', resolution: 'NO_SHOW')]), far]), isNot(base));
      expect(key([mid, near, far]), isNot(base));
      expect(runRouteKey(leg: 'RETURN', waypoints: runWaypoints(stops: [near, mid, far], leg: 'RETURN', school: _gate)), isNot(base));
    });

    test('the bus leg key is the target alone, so a moving bus never asks again', () {
      final waypoints = runWaypoints(stops: [near, mid, far], leg: 'OUT', school: _gate);
      final key = busLegKey(leg: 'OUT', target: waypoints.first);
      final book = RunRouteBook()..putBusLeg(key, BusLeg(from: const LatLng(36.10, 44.0), line: const [LatLng(36.10, 44.0), LatLng(36.21, 44.0)]));
      final rebuilt = runWaypoints(stops: [near, mid, far], leg: 'OUT', school: _gate);
      expect(book.decidedBusLeg(busLegKey(leg: 'OUT', target: rebuilt.where((w) => !w.done).first)), isTrue);
      expect(book.busLegs.length, 1);
      final moved = runWaypoints(stops: [_stop('near', 1, lat: 36.21, lon: 44.0, departedAt: DateTime(2026, 9, 13, 7)), mid, far], leg: 'OUT', school: _gate);
      expect(book.decidedBusLeg(busLegKey(leg: 'OUT', target: moved.where((w) => !w.done).first)), isFalse);
    });

    test('a bus leg is only fetched when the bus is away from the stop it just left', () {
      final start = runWaypoints(stops: [near, mid, far], leg: 'OUT', school: _gate);
      expect(busLegNeeded(waypoints: start, bus: const LatLng(36.10, 44.0)), isTrue);
      expect(busLegNeeded(waypoints: start, bus: const LatLng(36.2101, 44.0)), isFalse);

      final left = runWaypoints(
        stops: [_stop('near', 1, lat: 36.21, lon: 44.0, departedAt: DateTime(2026, 9, 13, 7)), mid, far],
        leg: 'OUT',
        school: _gate,
      );
      expect(busLegNeeded(waypoints: left, bus: const LatLng(36.2105, 44.0)), isFalse);
      expect(busLegNeeded(waypoints: left, bus: const LatLng(36.23, 44.0)), isTrue);

      final toSchool = runWaypoints(stops: [near, mid, far], leg: 'RETURN', school: _gate);
      expect(busLegNeeded(waypoints: toSchool, bus: const LatLng(36.10, 44.0)), isTrue);
      expect(busLegNeeded(waypoints: toSchool, bus: const LatLng(36.2001, 44.0)), isFalse);
    });

    test('the phase changes on the order toggle and when boarding completes, not on progress', () {
      final open = [near, mid];
      final phase = runPhase(leg: 'RETURN', stops: open, nearest: true);
      expect(runPhase(leg: 'RETURN', stops: open, nearest: false), isNot(phase));
      final boarded = [
        for (final s in open)
          _stop(s.stopId, s.plannedSequence, lat: s.lat, lon: s.lon, riders: [_rider('ck${s.stopId}', boardedAt: DateTime(2026, 9, 13, 14))]),
      ];
      final homes = runPhase(leg: 'RETURN', stops: boarded, nearest: true);
      expect(homes, isNot(phase));
      final served = [
        _stop('near', 1, lat: 36.21, lon: 44.0, departedAt: DateTime(2026, 9, 13, 15), riders: [_rider('cknear', boardedAt: DateTime(2026, 9, 13, 14))]),
        boarded[1],
      ];
      expect(runPhase(leg: 'RETURN', stops: served, nearest: true), homes);
    });

    test('a pinned order is kept while the bus moves and stops are served, and rebuilt for a new stop', () {
      const pinned = PinnedOrder(order: ['near', 'mid', 'far'], basis: RunBasis.fromBus, road: true);
      expect(canKeepOrder(pinned: null, open: const ['near'], busKnown: true), isFalse);
      expect(canKeepOrder(pinned: pinned, open: const ['near', 'mid', 'far'], busKnown: true), isTrue);
      expect(canKeepOrder(pinned: pinned, open: const ['far'], busKnown: true), isTrue);
      expect(canKeepOrder(pinned: pinned, open: const ['far', 'new'], busKnown: true), isFalse);

      const guessed = PinnedOrder(order: ['near', 'mid'], basis: RunBasis.noPosition, road: false);
      expect(canKeepOrder(pinned: guessed, open: const ['near'], busKnown: false), isTrue);
      expect(canKeepOrder(pinned: guessed, open: const ['near'], busKnown: true), isFalse);

      final kept = arrangeRun(
        stops: [near, mid, far],
        leg: 'OUT',
        nearest: true,
        bus: const LatLng(36.31, 44.0),
        keepOrder: const ['mid', 'near', 'far'],
      );
      expect(_ids(kept), ['mid', 'near', 'far']);
      expect(openStopIds([near, _stop('x', 9, lat: 36.4, lon: 44.0, skipped: true), mid], null), ['near', 'mid']);
    });

    test('the saved book survives a round trip and keeps only recent routes', () {
      final book = RunRouteBook();
      for (var i = 0; i < 6; i++) {
        book.putRoute('r$i', [
          [LatLng(36.0 + i / 100, 44.0), const LatLng(36.123456, 44.654321)],
        ]);
      }
      book.putBusLeg('b', const BusLeg(from: LatLng(36.1, 44.1)));
      book.putOrder('OUT:stops:nearest', const PinnedOrder(order: ['a', 'b'], basis: RunBasis.fromBus, road: true));
      book.matrix['x>y'] = [120.0, 900.0];

      final back = RunRouteBook.fromJson(book.toJson());
      expect(back.routes.keys, ['r2', 'r3', 'r4', 'r5']);
      expect(back.routes['r5']!.first.last.latitude, closeTo(36.123456, 1e-6));
      expect(back.decidedBusLeg('b'), isTrue);
      expect(back.busLegs['b']!.line, isNull);
      expect(back.orders['OUT:stops:nearest']!.order, ['a', 'b']);
      expect(back.orders['OUT:stops:nearest']!.basis, RunBasis.fromBus);
      expect(back.matrix['x>y'], [120.0, 900.0]);
      expect(RunRouteBook.fromJson('garbage').routes, isEmpty);
    });

    test('polyline6 encoding round-trips', () {
      const line = [LatLng(36.191234, 44.009876), LatLng(36.2, 43.99), LatLng(-12.5, 170.000001)];
      final back = Directions.decodePolyline6(Directions.encodePolyline6(line));
      expect(back.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(back[i].latitude, closeTo(line[i].latitude, 1e-6));
        expect(back[i].longitude, closeTo(line[i].longitude, 1e-6));
      }
      expect(Directions.encodePolyline6(const [LatLng(3.85, -12.02), LatLng(4.07, -12.095), LatLng(4.3252, -12.6453)]),
          '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    });
  });

  group('distanceAway', () {
    test('metres under a kilometre, one decimal of kilometres above it', () {
      expect(distanceAway(0), '0 m away');
      expect(distanceAway(850), '850 m away');
      expect(distanceAway(999), '999 m away');
      expect(distanceAway(1000), '1.0 km away');
      expect(distanceAway(4135), '4.1 km away');
      expect(distanceAway(12345), '12 km away');
    });

    test('keeps the number in every language', () {
      for (final lang in Lang.values) {
        AppLocale.current.value = lang;
        expect(distanceAway(4135), contains('4.1'));
        expect(distanceAway(640), contains('640'));
      }
    });
  });

  group('Directions geometry', () {
    test('decodes a polyline6 string', () {
      final line = Directions.decodePolyline6('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(line.length, 3);
      expect(line[0].latitude, closeTo(3.85, 1e-9));
      expect(line[0].longitude, closeTo(-12.02, 1e-9));
      expect(line[2].latitude, closeTo(4.3252, 1e-9));
      expect(line[2].longitude, closeTo(-12.6453, 1e-9));
    });

    test('cuts the out-and-back spur where a leg reaches a stop and turns around', () {
      const a = LatLng(36.0, 44.0);
      const b = LatLng(36.001, 44.0);
      const c = LatLng(36.002, 44.0);
      const stop = LatLng(36.002, 44.001);
      const d = LatLng(36.003, 44.0);
      final legs = Directions.trimSpurs([
        [a, b, c, stop],
        [stop, c, d],
      ]);
      expect(legs[0], [a, b, c]);
      expect(legs[1], [c, d]);
    });

    test('leaves a leg alone when the route carries straight on', () {
      const a = LatLng(36.0, 44.0);
      const stop = LatLng(36.001, 44.0);
      const d = LatLng(36.002, 44.0);
      final legs = Directions.trimSpurs([
        [a, stop],
        [stop, d],
      ]);
      expect(legs[0], [a, stop]);
      expect(legs[1], [stop, d]);
    });
  });

  group('SchoolGate.fromPack', () {
    test('uses the campus gate stop, reading decimal strings', () {
      final gate = SchoolGate.fromPack({
        'campus': {'name': 'Sunrise School', 'lat': '36.1', 'lon': '44.1'},
        'stopProgress': [
          {
            'stop': {'id': 'ckhome', 'name': 'Home', 'lat': '36.3', 'lon': '44.3', 'isCampusGate': false},
          },
          {
            'stop': {'id': 'ckgate', 'name': 'Main gate', 'lat': '36.2', 'lon': '44.2', 'isCampusGate': true},
          },
        ],
      });
      expect(gate.stopId, 'ckgate');
      expect(gate.name, 'Sunrise School');
      expect(gate.lat, 36.2);
      expect(gate.lon, 44.2);
      expect(gate.placed, isTrue);
    });

    test('falls back to the campus position when the gate has none', () {
      final gate = SchoolGate.fromPack({
        'campus': {'name': 'Sunrise School', 'lat': 36.1, 'lon': 44.1},
        'stopProgress': const [],
      });
      expect(gate.stopId, isNull);
      expect(gate.lat, 36.1);
      expect(gate.placed, isTrue);
    });
  });
}
