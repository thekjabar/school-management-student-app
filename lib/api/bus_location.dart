import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'crew_api.dart';

/// Why the bus has no position, when it has none.
///
/// Kept apart from "we have not got one yet" on purpose: a driver who refused
/// the permission and a driver whose first fix has not landed are owed
/// different sentences, and the screen can only say the right one if the two
/// states are distinguishable.
enum BusLocationState {
  /// Not started — no run is under way.
  off,

  /// Started, waiting on the first fix.
  waiting,

  /// Sending.
  live,

  /// The driver said no. Never asked again from here; the app carries on.
  denied,

  /// Refused permanently, or location is switched off on the handset. Only the
  /// system settings can change this, so the app must not pretend otherwise.
  blocked,

  /// Fixes are arriving, and they are useless.
  ///
  /// Android 12 and later let a person grant "Approximate" instead of
  /// "Precise", and a phone with GPS off or set to battery-saving does the same
  /// thing by another route: it answers from cell towers. What comes back is a
  /// coordinate accurate to a kilometre or two, repeated identically for hours
  /// with a speed of zero.
  ///
  /// Every fix this handset sent tonight looked like that — 2000 m accuracy,
  /// the same seven decimal places from 18:52 to 22:21 — and the map drew it as
  /// a confident dot on a street the driver was nowhere near. A position that
  /// cannot tell one district from the next is not a bus position, and saying
  /// so is the only honest thing to do with it.
  coarse,
}

/// Beyond this, a fix cannot tell one stop from another and must not be drawn
/// as though it can. A school stop is tens of metres across; a hundred and
/// fifty is already generous for deciding which one a bus is standing at.
const double kCoarseAccuracyM = 150;

/// Where the bus is, and telling the platform about it.
///
/// The whole platform was built around this and never received a single fix:
/// there was no location plugin in the app at all, so nearest-stop ordering
/// fell back to the office's order with an apology, every geofence the school
/// configured sat inert, no parent could watch a bus approach, and every
/// custody event reached the ledger with no coordinates against it. The server
/// side has been waiting the entire time — `crew/telemetry/positions` and its
/// policy endpoint are already there, rate-limited and tenant-checked.
///
/// One instance, owned by the app rather than a screen, because the run
/// outlives any particular page: a driver who backs out of the run screen to
/// look something up has not stopped driving the bus.
class BusLocation {
  BusLocation._();
  static final BusLocation instance = BusLocation._();

  /// The last known position, for the map to draw. Null until a first fix.
  final ValueNotifier<Position?> here = ValueNotifier<Position?>(null);

  /// What the driver should be told, if anything.
  final ValueNotifier<BusLocationState> state =
      ValueNotifier<BusLocationState>(BusLocationState.off);

  StreamSubscription<Position>? _stream;
  Timer? _flush;
  String? _tripId;
  TelemetryPolicy _policy = TelemetryPolicy.fallback;

  /// Fixes taken but not yet accepted by the server.
  ///
  /// A bus spends its morning in and out of coverage and the driver is not
  /// going to stop to nurse a network, so the points queue and go up in a batch
  /// when there is signal. Bounded, because an hour in a dead spot must not
  /// grow without limit on a cheap handset.
  final List<Map<String, dynamic>> _pending = [];
  static const int _maxPending = 600;

  bool get isRunning => _stream != null;

  /// Begin following the bus for [tripId].
  ///
  /// Safe to call repeatedly — the same trip is a no-op, a different one
  /// re-points the stream without dropping what is already queued.
  Future<void> start(String tripId) async {
    if (_tripId == tripId && _stream != null) return;
    if (_stream != null) await stop(flush: true);
    _tripId = tripId;

    final permitted = await _ensurePermission();
    if (!permitted) return;

    // The cadence is the server's to choose. A failure here is not a reason to
    // send nothing — it is a reason to use the documented defaults.
    try {
      _policy = await CrewApi.instance.telemetryPolicy();
    } catch (_) {
      _policy = TelemetryPolicy.fallback;
    }

    state.value = BusLocationState.waiting;

    // A fix straight away, rather than waiting for the bus to move.
    //
    // getPositionStream only emits once the phone has actually produced a new
    // location, which on a cold GPS can be half a minute, and with a distance
    // filter not until the bus has moved at all. So the map opened with no dot
    // on it, or with one that appeared late and then jumped. This asks for the
    // current position once, immediately, and the stream takes over after.
    //
    // Deliberately NOT getLastKnownPosition: that hands back wherever the phone
    // was hours ago, which on this screen would draw the bus somewhere it is
    // not. A missing dot is honest; a stale one is not.
    unawaited(
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      ).then((p) {
        if (_stream != null) _take(p);
      }).catchError((Object _) {
        // No first fix inside half a minute. The stream is still running and
        // will deliver one when the sky clears; nothing to say to the driver.
      }),
    );

    _stream = Geolocator.getPositionStream(
      locationSettings: _settings(),
    ).listen(
      _take,
      onError: (_) {
        // A stream error is usually location being switched off mid-run. Say
        // so rather than showing a stale dot that looks live.
        state.value = BusLocationState.blocked;
      },
    );

    _flush = Timer.periodic(
      Duration(seconds: _policy.activeTripIntervalSeconds.clamp(5, 300)),
      (_) => _send(),
    );
  }

  /// How often the handset should hand over a new fix.
  ///
  /// The first version filtered on fifteen metres and nothing else, which is
  /// the wrong trade for a screen a driver watches: below walking pace, and
  /// stopped in traffic, Android emitted nothing at all and the dot sat still
  /// while the bus crept forward. Five metres or five seconds moves with the
  /// bus and still says nothing worth saying while it is parked — Android only
  /// delivers on the interval if the position has actually changed.
  LocationSettings _settings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  /// Stop following, and make a last attempt to hand over what is queued.
  Future<void> stop({bool flush = true}) async {
    await _stream?.cancel();
    _stream = null;
    _flush?.cancel();
    _flush = null;
    if (flush) await _send();
    _tripId = null;
    state.value = BusLocationState.off;
  }

  void _take(Position p) {
    here.value = p;
    // Said out loud rather than drawn as certainty. A coarse fix still goes up
    // — the server records accuracyM and weighs it, and a bus with a bad sky
    // view is better tracked roughly than not at all — but the driver is told
    // his phone is guessing, because he is the only one who can fix it.
    final coarse = p.accuracy.isFinite && p.accuracy > kCoarseAccuracyM;
    if (coarse) {
      state.value = BusLocationState.coarse;
    } else if (state.value == BusLocationState.waiting ||
        state.value == BusLocationState.coarse) {
      state.value = BusLocationState.live;
    }
    if (_pending.length >= _maxPending) _pending.removeAt(0);
    _pending.add({
      'clientUuid': uuidV4(),
      'ts': p.timestamp.toUtc().toIso8601String(),
      'lat': p.latitude,
      'lon': p.longitude,
      // Every optional field is sent only when the handset actually measured
      // it. The server validates ranges and a fabricated zero is worse than an
      // absence — it is a claim.
      if (p.accuracy.isFinite && p.accuracy >= 0)
        'accuracyM': p.accuracy.round().clamp(0, 20000),
      if (p.speed.isFinite && p.speed >= 0)
        'speedKph': (p.speed * 3.6).clamp(0, 400).toDouble(),
      if (p.heading.isFinite && p.heading >= 0)
        'headingDeg': p.heading.round().clamp(0, 359),
      if (p.altitude.isFinite)
        'altitudeM': p.altitude.round().clamp(-500, 9000),
    });
  }

  /// Hand the queue over. Anything the server did not take stays queued.
  Future<void> _send() async {
    final tripId = _tripId;
    if (tripId == null || _pending.isEmpty) return;

    final batch = _pending.take(_policy.maxBatchPoints).toList();
    try {
      await CrewApi.instance.sendPositions(
        tripInstanceId: tripId,
        points: batch,
      );
      _pending.removeRange(0, batch.length);
    } catch (_) {
      // Out of coverage, or the server refused. Keep them: the next flush
      // tries again, and a bus that drove through a dead spot still has to be
      // able to say where it went.
    }
  }

  /// Ask once, and take no for an answer.
  ///
  /// A driver who says no gets an app that keeps working — everything except
  /// the map dot and the nearest-first ordering is unaffected — rather than a
  /// dialogue every time they open a screen.
  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      state.value = BusLocationState.blocked;
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        state.value = BusLocationState.denied;
        return false;
      case LocationPermission.deniedForever:
        state.value = BusLocationState.blocked;
        return false;
      case LocationPermission.always:
      case LocationPermission.whileInUse:
      case LocationPermission.unableToDetermine:
        return true;
    }
  }
}
