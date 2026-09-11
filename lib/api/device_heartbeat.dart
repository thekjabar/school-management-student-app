import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import 'bus_location.dart';
import 'client.dart';
import 'crew_api.dart';
import 'push.dart';
import 'session.dart';

class DeviceHeartbeat with WidgetsBindingObserver {
  DeviceHeartbeat._();

  static final DeviceHeartbeat instance = DeviceHeartbeat._();

  static const int _idleIntervalSeconds = 900;

  static const int _fallbackIntervalSeconds = 60;

  static const int _maxFlushBatch = 60;

  static const int _maxQueued = 240;

  static const Duration _maxBacklogAge = Duration(hours: 24);

  static const Duration _resumeDebounce = Duration(seconds: 30);

  static const int _maxRefusals = 3;

  bool _running = false;

  String? _deviceId;
  bool _deviceKnown = false;

  String? _deviceOwnerPersonId;

  String? _tripId;
  Timer? _timer;
  bool _beating = false;
  int _serverIntervalSeconds = _fallbackIntervalSeconds;
  int _refusals = 0;
  DateTime? _lastBeatAt;

  final List<Map<String, dynamic>> _queue = [];

  bool get isRunning => _running;

  int get queuedCount => _queue.length;

  int get _intervalSeconds {
    final server = _serverIntervalSeconds.clamp(30, 3600);
    return _tripId == null ? (server > _idleIntervalSeconds ? server : _idleIntervalSeconds) : server;
  }

  Future<void> start() async {
    final me = Session.instance.me;

    if (_deviceOwnerPersonId != null && _deviceOwnerPersonId != me?.id) {
      _forgetIdentity();
    }

    if (_running) return;
    if (me == null) return;
    if (!me.can('trip.operate') && !me.can('custody.record')) return;

    _running = true;
    _refusals = 0;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_beat());
  }

  void stop() {
    _forgetIdentity();
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _forgetIdentity() {
    _deviceId = null;
    _deviceKnown = false;
    _deviceOwnerPersonId = null;
    _tripId = null;
    _queue.clear();
    _lastBeatAt = null;
    _refusals = 0;
    _serverIntervalSeconds = _fallbackIntervalSeconds;
  }

  void noteTrip(String? tripInstanceId) {
    final id = (tripInstanceId != null && tripInstanceId.isNotEmpty) ? tripInstanceId : null;
    if (_tripId == id) return;
    _tripId = id;
    if (!_running) return;
    unawaited(_beat());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running || state != AppLifecycleState.resumed) return;
    final last = _lastBeatAt;
    if (last != null && DateTime.now().difference(last) < _resumeDebounce) return;
    unawaited(_beat());
  }

  Future<String?> _resolveDevice(String personId) async {
    if (_deviceKnown && _deviceOwnerPersonId == personId) return _deviceId;
    if (_deviceOwnerPersonId != null && _deviceOwnerPersonId != personId) _forgetIdentity();
    try {
      final id = await CrewApi.instance.myCrewPhoneId();
      if (Session.instance.me?.id != personId) return null;
      _deviceId = id;
      _deviceKnown = true;
      _deviceOwnerPersonId = personId;
    } on ApiException catch (e) {
      if (e.status == 0 || e.status >= 500) return null;
      if (Session.instance.me?.id != personId) return null;
      _deviceId = null;
      _deviceKnown = true;
      _deviceOwnerPersonId = personId;
    } catch (_) {
      return null;
    }
    return _deviceId;
  }

  Future<void> _beat() async {
    if (!_running || _beating) return;
    final me = Session.instance.me;
    if (me == null) {
      stop();
      return;
    }
    final personId = me.id;
    _beating = true;
    try {
      final deviceId = await _resolveDevice(personId);
      if (!_running || Session.instance.me?.id != personId) return;
      if (deviceId == null) {
        if (_deviceKnown) {
          stop();
        }
        return;
      }

      final beat = await _compose(deviceId);
      if (!_running || Session.instance.me?.id != personId) return;

      try {
        final next = await CrewApi.instance.sendHeartbeat(beat);
        if (!_running || Session.instance.me?.id != personId) return;
        _lastBeatAt = DateTime.now();
        _refusals = 0;
        if (next != null && next > 0) _serverIntervalSeconds = next;
        if (_queue.isNotEmpty) await _flush(personId);
      } on ApiException catch (e) {
        if (!_running || Session.instance.me?.id != personId) return;
        _handleRefusal(e, beat);
      } catch (_) {
      }
    } catch (_) {
    } finally {
      _beating = false;
      _arm();
    }
  }

  Future<void> _flush(String personId) async {
    if (!_running || Session.instance.me?.id != personId) return;
    _prune();
    if (_queue.isEmpty) return;
    final batch = _queue.take(_maxFlushBatch).toList(growable: false);
    try {
      final next = await CrewApi.instance.flushHeartbeats(batch);
      if (!_running || Session.instance.me?.id != personId) return;
      _queue.removeRange(0, batch.length);
      if (next != null && next > 0) _serverIntervalSeconds = next;
    } on ApiException catch (e) {
      if (!_running || Session.instance.me?.id != personId) return;
      if (e.status == 0 || e.status >= 500) return;
      if (e.status == 400) {
        _queue.removeRange(0, batch.length);
        return;
      }
      _handleRefusal(e, null);
    } catch (_) {
    }
  }

  void _handleRefusal(ApiException e, Map<String, dynamic>? beat) {
    if (e.status == 0 || e.status >= 500) {
      if (beat != null) _enqueue(beat);
      return;
    }
    if (e.status == 400) {
      if (++_refusals >= _maxRefusals) stop();
      return;
    }
    if (e.status == 404) {
      _deviceKnown = false;
      _deviceId = null;
    }
    if (e.isAuth || e.status == 403 || ++_refusals >= _maxRefusals) {
      stop();
    }
  }

  void _enqueue(Map<String, dynamic> beat) {
    _queue.add(beat);
    _prune();
    while (_queue.length > _maxQueued) {
      _queue.removeAt(0);
    }
  }

  void _prune() {
    if (_queue.isEmpty) return;
    final cutoff = DateTime.now().toUtc().subtract(_maxBacklogAge);
    _queue.removeWhere((b) {
      final ts = DateTime.tryParse((b['ts'] as String?) ?? '');
      return ts == null || ts.isBefore(cutoff);
    });
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    if (!_running) return;
    _timer = Timer(Duration(seconds: _intervalSeconds), () {
      if (_running) unawaited(_beat());
    });
  }

  Future<Map<String, dynamic>> _compose(String deviceId) async {
    final beat = <String, dynamic>{
      'deviceId': deviceId,
      'ts': DateTime.now().toUtc().toIso8601String(),
    };
    if (_tripId != null) beat['tripInstanceId'] = _tripId;

    try {
      final permission = await Geolocator.checkPermission();
      switch (permission) {
        case LocationPermission.always:
          beat['locationPermissionAlways'] = true;
        case LocationPermission.whileInUse:
        case LocationPermission.denied:
        case LocationPermission.deniedForever:
          beat['locationPermissionAlways'] = false;
        case LocationPermission.unableToDetermine:
          break;
      }
    } catch (_) {
    }

    if (Push.started) beat['notificationPermission'] = Push.granted;

    if (BusLocation.instance.isRunning) {
      final fix = BusLocation.instance.here.value;
      if (fix != null) beat['mockLocationDetected'] = fix.isMocked;
    }

    beat['queuedEventCount'] = BusLocation.instance.queuedCount;

    if (Platform.isAndroid) {
      beat['osName'] = 'Android';
    } else if (Platform.isIOS) {
      beat['osName'] = 'iOS';
    }
    final version = _osVersion();
    if (version != null) beat['osVersion'] = version;

    return beat;
  }

  static String? _osVersion() {
    try {
      var raw = Platform.operatingSystemVersion.trim();
      final comma = raw.indexOf(',');
      if (comma > 0) raw = raw.substring(0, comma).trim();
      if (raw.isEmpty) return null;
      return raw.length > 40 ? raw.substring(0, 40) : raw;
    } catch (_) {
      return null;
    }
  }
}
