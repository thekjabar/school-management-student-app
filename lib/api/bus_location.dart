import 'dart:async';

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
}

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

    _stream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        // Distance rather than time is what keeps a parked bus quiet: a bus at
        // a stop for four minutes should not spend four minutes of battery and
        // data saying it has not moved.
        distanceFilter: 15,
      ),
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
    if (state.value == BusLocationState.waiting) {
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
