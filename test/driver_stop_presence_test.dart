import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:student_app/api/crew_api.dart';
import 'package:student_app/screens/driver/run_order.dart';
import 'package:student_app/screens/driver/stop_presence.dart';

Position _fix(double lat, double lon, {double accuracy = 8, Duration age = Duration.zero, DateTime? now}) =>
    Position(
      latitude: lat,
      longitude: lon,
      timestamp: (now ?? DateTime.now()).subtract(age),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

double _north(double metres) => metres / 111195;

PlannedStop _stop({DateTime? arrivedAt, int dwellSeconds = 55, List<RiderOnStop> students = const []}) => PlannedStop(
      stopId: 'ckstopaaaaaaaaaaaaaaaaaaa',
      name: 'Ari',
      landmark: null,
      lat: 36.2,
      lon: 44.0,
      plannedSequence: 1,
      metresAway: null,
      students: students,
      arrivedAt: arrivedAt,
      departedAt: null,
      skipped: false,
      etaAt: null,
      etaIsActual: false,
      dwellSeconds: dwellSeconds,
      driveSeconds: 0,
    );

RiderOnStop _rider({DateTime? boardedAt, String? resolution}) => RiderOnStop(
      studentId: 'cka',
      name: 'Ari',
      pickup: null,
      seatNumber: null,
      requiresAssistance: false,
      boardedAt: boardedAt,
      alightedAt: null,
      resolution: resolution,
    );

void main() {
  final now = DateTime(2026, 9, 14, 7, 30);

  test('the reach is the stop radius with a 100 m floor at home and 150 m at school', () {
    expect(reachLimitM(null, school: false), 100);
    expect(reachLimitM(60, school: false), 100);
    expect(reachLimitM(140, school: false), 140);
    expect(reachLimitM(120, school: true), 150);
    expect(reachLimitM(220, school: true), 220);
  });

  test('inside the reach, far away, no fix, stale fix and an unplaced stop', () {
    Presence at(double metres, {double accuracy = 8, Duration age = Duration.zero}) => presenceAt(
          fix: _fix(36.2 + _north(metres), 44.0, accuracy: accuracy, age: age, now: now),
          lat: 36.2,
          lon: 44.0,
          limitM: 100,
          now: now,
        );

    expect(at(60).state, PresenceState.here);
    expect(at(350).state, PresenceState.far);
    expect(at(350).metres, 350);
    expect(at(140, accuracy: 45).state, PresenceState.here);
    expect(at(160, accuracy: 400).state, PresenceState.far);
    expect(at(20, age: const Duration(seconds: 31)).state, PresenceState.noFix);
    expect(at(20, age: const Duration(seconds: 29)).state, PresenceState.here);
    expect(presenceAt(fix: null, lat: 36.2, lon: 44.0, limitM: 100, now: now).state, PresenceState.noFix);
    expect(presenceAt(fix: null, lat: null, lon: null, limitM: 100, now: now).allowed, isTrue);
  });

  test('a fresh fix is sent with its accuracy and age; a stale one is not sent', () {
    final fresh = reportedFix(_fix(36.2, 44.0, accuracy: 12.4, age: const Duration(seconds: 3), now: now), now: now);
    expect(fresh?.accuracyM, 12);
    expect(fresh?.ageMs, 3000);
    expect(reportedFix(_fix(36.2, 44.0, age: const Duration(seconds: 45), now: now), now: now), isNull);
  });

  test('not here waits the stop dwell after arriving, clamped to 20..90 seconds', () {
    expect(notHereWaitLeft(_stop(), now: now), isNull);
    expect(notHereWaitLeft(_stop(arrivedAt: now.subtract(const Duration(seconds: 10))), now: now), 45);
    expect(mayMarkNotHere(_stop(arrivedAt: now.subtract(const Duration(seconds: 55))), now: now), isTrue);
    expect(requiredWaitSeconds(_stop(dwellSeconds: 5)), 20);
    expect(requiredWaitSeconds(_stop(dwellSeconds: 400)), 90);
  });

  test('moving on needs every child picked up or marked not here', () {
    expect(mayMoveOnOut(_stop(students: [_rider()])), isFalse);
    expect(mayMoveOnOut(_stop(students: [_rider(boardedAt: now)])), isTrue);
    expect(mayMoveOnOut(_stop(students: [_rider(resolution: 'NO_SHOW')])), isTrue);
    expect(mayMoveOnOut(_stop()), isTrue);
  });

  test('heading-up follows the GPS course when moving and the road ahead when slow', () {
    const bus = LatLng(36.2, 44.0);
    expect(followBearing(heading: 185, speed: 8, bus: bus), 185);
    final east = LatLng(36.2, 44.0 + 0.002);
    expect(followBearing(heading: 10, speed: 0.4, bus: bus, next: east)!, closeTo(90, 1));
    final south = [bus, LatLng(36.2 - 0.0001, 44.0), LatLng(36.2 - 0.001, 44.0)];
    expect(followBearing(heading: -1, speed: 0, bus: bus, road: south, next: east)!, closeTo(180, 1));
    expect(followBearing(heading: -1, speed: 0, bus: bus), isNull);
    expect(angleGap(350, 10), 20);
    expect(angleGap(90, 270), 180);
  });
}
