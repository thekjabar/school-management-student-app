import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import 'run_order.dart';

const double kHomeReachM = 100;

const double kSchoolReachM = 150;

const double kAccuracyCapM = 50;

const Duration kFreshFix = Duration(seconds: 30);

const int kStopWaitMinSeconds = 20;

const int kStopWaitMaxSeconds = 90;

enum PresenceState { unplaced, noFix, far, here }

class Presence {
  const Presence(this.state, [this.metres]);

  final PresenceState state;

  final int? metres;

  bool get allowed => state == PresenceState.here || state == PresenceState.unplaced;

  String? get note => switch (state) {
        PresenceState.noFix => t('driver.presence.noFix'),
        PresenceState.far => tn('driver.presence.far', distanceAway(metres ?? 0)),
        _ => null,
      };
}

double reachLimitM(int? radiusM, {required bool school}) =>
    math.max((radiusM ?? 0).toDouble(), school ? kSchoolReachM : kHomeReachM);

bool fixIsFresh(Position? fix, DateTime now) =>
    fix != null && now.difference(fix.timestamp).abs() < kFreshFix;

Presence presenceAt({
  required Position? fix,
  required double? lat,
  required double? lon,
  required double limitM,
  DateTime? now,
}) {
  if (lat == null || lon == null || (lat == 0 && lon == 0)) {
    return const Presence(PresenceState.unplaced);
  }
  final at = now ?? DateTime.now();
  if (fix == null || !fixIsFresh(fix, at)) return const Presence(PresenceState.noFix);
  final metres = metresBetween(LatLng(fix.latitude, fix.longitude), LatLng(lat, lon));
  final accuracy = fix.accuracy.isFinite ? fix.accuracy : 0.0;
  final slack = accuracy.clamp(0.0, kAccuracyCapM);
  return metres - slack <= limitM
      ? Presence(PresenceState.here, metres.round())
      : Presence(PresenceState.far, metres.round());
}

Presence stopPresence(PlannedStop stop, {required bool school, required Position? fix, DateTime? now}) =>
    presenceAt(
      fix: fix,
      lat: stop.lat,
      lon: stop.lon,
      limitM: reachLimitM(stop.radiusM, school: school),
      now: now,
    );

Presence gatePresence(SchoolGate? gate, {required Position? fix, DateTime? now}) => presenceAt(
      fix: fix,
      lat: gate != null && gate.placed ? gate.lat : null,
      lon: gate != null && gate.placed ? gate.lon : null,
      limitM: reachLimitM(gate?.radiusM, school: true),
      now: now,
    );

ReportedFix? reportedFix(Position? fix, {DateTime? now}) {
  final at = now ?? DateTime.now();
  if (fix == null || !fixIsFresh(fix, at) || !fix.accuracy.isFinite || fix.accuracy < 0) return null;
  return ReportedFix(
    lat: fix.latitude,
    lon: fix.longitude,
    accuracyM: fix.accuracy.round().clamp(0, 100000),
    ageMs: at.difference(fix.timestamp).inMilliseconds.clamp(0, 86400000),
  );
}

int requiredWaitSeconds(PlannedStop stop) =>
    stop.dwellSeconds.clamp(kStopWaitMinSeconds, kStopWaitMaxSeconds);

int? notHereWaitLeft(PlannedStop stop, {DateTime? now}) {
  final arrived = stop.arrivedAt;
  if (arrived == null) return null;
  final left = requiredWaitSeconds(stop) - (now ?? DateTime.now()).difference(arrived).inSeconds;
  return left <= 0 ? 0 : left;
}

bool mayMarkNotHere(PlannedStop stop, {DateTime? now}) => notHereWaitLeft(stop, now: now) == 0;

bool mayMoveOnOut(PlannedStop stop) => stop.remaining == 0;

String waitClock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
