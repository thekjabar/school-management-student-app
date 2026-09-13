import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:student_app/api/crew_api.dart';
import 'package:student_app/api/directions.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/driver/run_order.dart';

RiderOnStop _rider(String id) => RiderOnStop(
      studentId: id,
      name: 'Child $id',
      pickup: null,
      seatNumber: null,
      requiresAssistance: false,
      boardedAt: null,
      alightedAt: null,
      resolution: null,
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
}) =>
    PlannedStop(
      stopId: id,
      name: id,
      landmark: null,
      lat: lat,
      lon: lon,
      plannedSequence: sequence,
      metresAway: null,
      students: noRiders ? const [] : [_rider('ck$id')],
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
      expect(legStates(back), [LegState.next, LegState.later]);
    });

    test('once every stop is served the leg into school is the next one', () {
      final a = _stop('a', 1, lat: 36.3, lon: 44.0, departedAt: DateTime(2026, 9, 13, 7));
      final b = _stop('b', 2, lat: 36.25, lon: 44.0, skipped: true);
      final out = runWaypoints(stops: [a, b], leg: 'OUT', school: _gate);
      expect(legStates(out), [LegState.done, LegState.next]);
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
