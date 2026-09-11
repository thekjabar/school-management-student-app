import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'crew_api.dart';

enum BusLocationState {
  off,

  waiting,

  live,

  denied,

  blocked,

  coarse,
}

const double kCoarseAccuracyM = 150;

class BusLocation {
  BusLocation._();
  static final BusLocation instance = BusLocation._();

  final ValueNotifier<Position?> here = ValueNotifier<Position?>(null);

  final ValueNotifier<BusLocationState> state =
      ValueNotifier<BusLocationState>(BusLocationState.off);

  StreamSubscription<Position>? _stream;
  Timer? _flush;
  String? _tripId;
  TelemetryPolicy _policy = TelemetryPolicy.fallback;

  final List<Map<String, dynamic>> _pending = [];
  static const int _maxPending = 600;

  bool get isRunning => _stream != null;

  int get queuedCount => _pending.length;

  Future<void> start(String tripId) async {
    if (_tripId == tripId && _stream != null) return;
    if (_stream != null) await stop(flush: true);
    _tripId = tripId;

    final permitted = await _ensurePermission();
    if (!permitted) return;

    try {
      _policy = await CrewApi.instance.telemetryPolicy();
    } catch (_) {
      _policy = TelemetryPolicy.fallback;
    }

    state.value = BusLocationState.waiting;

    unawaited(
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      ).then((p) {
        if (_stream != null) _take(p);
      }).catchError((Object _) {
      }),
    );

    _stream = Geolocator.getPositionStream(
      locationSettings: _settings(),
    ).listen(
      _take,
      onError: (_) {
        state.value = BusLocationState.blocked;
      },
    );

    _flush = Timer.periodic(
      Duration(seconds: _policy.activeTripIntervalSeconds.clamp(5, 300)),
      (_) => _send(),
    );
  }

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
    }
  }

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
