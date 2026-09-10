import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import 'bus_location.dart';
import 'client.dart';
import 'crew_api.dart';
import 'push.dart';
import 'session.dart';

/// "This handset is alive", said out loud on a timer.
///
/// `assessLink` in `heartbeat.controller.ts` has been able to raise
/// `background_location_denied`, `notifications_denied`,
/// `mock_location_detected`, `offline_queue_backing_up`, `battery_critical`,
/// `battery_optimisation_active` and `no_network` since telemetry was built,
/// and has raised none of them, because nothing on any handset ever posted a
/// heartbeat. When a bus went dark nobody could tell whether the phone had
/// died, Android had killed the app, or the driver was feeding it a fake
/// location — the three cases draw exactly the same picture from the outside,
/// and only one of them is a fault the office can fix.
///
/// FOUR of those seven are lit by this file, and it is worth naming which,
/// because a claim of seven would have an operator believing a warning is
/// watching when nothing here can raise it: `background_location_denied` and
/// `notifications_denied` from the two permissions, `mock_location_detected`
/// from the live fix, and `offline_queue_backing_up` from the measured outbox
/// depth. The other three stay dark, and this file is the reason:
/// `battery_critical` needs `batteryPct` with `powerState`,
/// `battery_optimisation_active` needs `batteryOptimisationExempt`, and
/// `no_network` needs `networkType`, and this app carries no plugin that can
/// measure any of the three. They are left ABSENT rather than guessed — see
/// [_compose].
///
/// This is the caller. [CrewApi.myCrewPhoneId], [CrewApi.sendHeartbeat] and
/// [CrewApi.flushHeartbeats] are the transport, written alongside this file
/// with the DTO fields read off `CrewHeartbeatController`; what was missing
/// was anything that ran them.
///
/// Three rules it must never break, because it runs behind a driver who is
/// driving:
///
///  * it never throws at its caller and never shows anything. A heartbeat that
///    interrupted a boarding would be worse than no heartbeat;
///  * it never invents a field. Every optional value here is measured on this
///    handset or absent, and the ones this app has no way to measure — battery,
///    carrier, signal, free disk, the device model — are simply not sent. The
///    server stores an absent field as null and an invented one as a fact;
///  * it stops dead when the answer is "this phone is not a crew handset".
///
/// ## Cadence, and who is actually watching
///
/// While a trip is running: whatever `nextHeartbeatSeconds` says, which is
/// sixty. That number is not ours to pick, and `DEVICE_SILENCE_ALERT_SECONDS`
/// is 180, so three beats fit inside the window a silent device is judged by
/// and a single dropped request cannot mark a bus that is fine as quiet.
///
/// But be exact about WHICH watcher, because the obvious reading is wrong and
/// an operator who believes a pager is armed will not go and look.
/// `DeviceSilenceWatchdog.openMissingEpisodes` — the job that opens a
/// `DeviceSilenceEvent` and pages dispatch every minute until somebody
/// acknowledges it — enumerates `tripInstance.vehicle.deviceAssignments`,
/// devices bound to the VEHICLE. A crew phone is bound to the PERSON
/// (`assignedPersonId`; the schema says exactly one of the two is ever set),
/// so it never appears in that list and NO beat from this file will page
/// anyone. What these beats do feed is `Device.lastHeartbeatAt` and, through
/// it, `overSilenceThreshold` on `GET operator/telemetry/devices/liveness`,
/// which walks every reporting device in the tenant however it is bound and
/// uses the same 180 seconds. That is a board somebody reads, not an alarm
/// that rings. Sixty seconds is right for it either way; what differs is who
/// finds out and how fast. Making a person-bound handset pageable is a change
/// to that watchdog's query, which is not this app's to make.
///
/// Off trip: [_idleIntervalSeconds], fifteen minutes. Nothing anywhere looks
/// harder at a handset whose bus is not on a live trip, so beating every
/// minute buys the office nothing; a quarter-hour still keeps "last heard" on
/// the liveness board fresh enough to tell a phone that is off from one that
/// was put in a drawer at four o'clock.
///
/// The bill matters here. A beat is about 300 bytes of JSON and, with TLS and
/// HTTP overhead on a fresh connection, call it a kilobyte on the wire. Two
/// ninety-minute runs a day at sixty seconds is 180 beats, and the other twenty
/// hours at fifteen minutes is another eighty — roughly a quarter of a megabyte
/// a day, about 8 MB a month, on handsets whose operators buy prepaid data by
/// the gigabyte. Beating every minute around the clock instead would be five
/// times that for information nobody is watching at 02:00.
class DeviceHeartbeat with WidgetsBindingObserver {
  DeviceHeartbeat._();

  static final DeviceHeartbeat instance = DeviceHeartbeat._();

  /// Off-trip cadence. See the class note.
  static const int _idleIntervalSeconds = 900;

  /// Used until the server has told us otherwise. It is what
  /// `SAMPLING.heartbeatIntervalSeconds` is set to, so the first beat of the
  /// day is already at the right rate rather than guessing high.
  static const int _fallbackIntervalSeconds = 60;

  /// `HeartbeatFlushDto` is `@ArrayMaxSize(60)` and refuses a batch over it
  /// whole, so this is a hard ceiling and not a preference.
  static const int _maxFlushBatch = 60;

  /// Beats held for a coverage hole. Four batches — four hours of dead spot at
  /// the running cadence, which is longer than any run in the fleet — and then
  /// the oldest goes. A cheap handset must not fill up because a mast is down.
  static const int _maxQueued = 240;

  /// Older than this and the server refuses the beat anyway
  /// (`SAMPLING.maxBackfillAgeSeconds` is 48 hours). Pruned well inside that,
  /// because a day-old proof of life is history nobody is waiting for and it
  /// would only crowd out the beats that still matter.
  static const Duration _maxBacklogAge = Duration(hours: 24);

  /// After a resume, only beat if the last one is older than this. A driver
  /// flicking between this app and the phone book must not fire a request per
  /// flick.
  static const Duration _resumeDebounce = Duration(seconds: 30);

  /// Three refusals of the same kind and we stop until the app is restarted.
  /// A 404 loop against a device row that has been unbound is a request a
  /// minute, forever, that can never succeed.
  static const int _maxRefusals = 3;

  bool _running = false;

  /// The crew phone this person is carrying, or null for "there isn't one".
  ///
  /// [_deviceKnown] is separate because null is a REAL answer and has to be
  /// distinguishable from "not asked yet": most operators issue no handsets and
  /// a driver's own phone has no Device row, and on those the heartbeat is
  /// meant not to run at all.
  String? _deviceId;
  bool _deviceKnown = false;

  /// The person [_deviceId] was resolved FOR.
  ///
  /// A depot handset is signed in and out by three or four drivers in a day,
  /// and this object is a singleton that outlives every one of them. A cached
  /// device id is therefore not a fact about the phone, it is an IDENTITY, and
  /// an identity that survives a sign-out is a false record of who was driving.
  /// Nothing downstream catches it: `resolveTargets` in
  /// `heartbeat.controller.ts` checks only that the device belongs to the
  /// caller's ORGANISATION, never that it is issued to the caller, so a beat
  /// sent under the previous driver's device id is accepted, is written with
  /// the NEW driver's `personId` beside the OLD driver's `deviceId`, refreshes
  /// `Device.lastHeartbeatAt` for a phone that may be switched off in a locker,
  /// and closes any open silence episode for it as `DEVICE_RECOVERED` — a lie
  /// about the one signal this whole feature exists to produce.
  ///
  /// So the cache is keyed on the person, and every read of it is checked
  /// against whoever is signed in NOW. [stop] clearing it would be enough if
  /// [stop] were always reached; this does not rely on that.
  String? _deviceOwnerPersonId;

  String? _tripId;
  Timer? _timer;
  bool _beating = false;
  int _serverIntervalSeconds = _fallbackIntervalSeconds;
  int _refusals = 0;
  DateTime? _lastBeatAt;

  final List<Map<String, dynamic>> _queue = [];

  /// Whether the timer is armed. Nothing draws it yet; it is exposed so that a
  /// read-out can be added without reaching into the private field.
  bool get isRunning => _running;

  /// Beats waiting for coverage. Nought is the normal answer.
  int get queuedCount => _queue.length;

  /// How often the next beat is due, given what the server asked for and
  /// whether a trip is running.
  int get _intervalSeconds {
    final server = _serverIntervalSeconds.clamp(30, 3600);
    return _tripId == null ? (server > _idleIntervalSeconds ? server : _idleIntervalSeconds) : server;
  }

  /// Start reporting. Idempotent, and safe to call before anything is known.
  ///
  /// Deliberately does no work of its own beyond arming: the first beat resolves
  /// the device id, and if there is no crew phone that first beat is also the
  /// last thing this object ever does.
  Future<void> start() async {
    final me = Session.instance.me;

    // A different person from the one the cache was filled for. On a handset
    // that lives in the depot rather than in a pocket that is the ordinary
    // case, not the exception, so his device id and his queued beats go before
    // anything is armed.
    //
    // FIRST, ahead of every return below, and against a null `me` as well as a
    // different one. An identity that outlives its owner because start() bailed
    // one line too early is the same lie as one that outlived stop(): the
    // relief who is a bus attendant on an account without either permission
    // turns back at the check below, and if the cache were still full when he
    // did, it would sit there waiting for whoever signs in after him.
    if (_deviceOwnerPersonId != null && _deviceOwnerPersonId != me?.id) {
      _forgetIdentity();
    }

    if (_running) return;
    // custody.record OR trip.operate — the controller's @RequirePermission is
    // any-of and its body checks nothing further, so either one gets in. An
    // account with neither would collect a 403 a minute for nothing.
    if (me == null) return;
    if (!me.can('trip.operate') && !me.can('custody.record')) return;

    _running = true;
    _refusals = 0;
    WidgetsBinding.instance.addObserver(this);
    // One on app start, whatever else happens today. A handset that is switched
    // on at 06:20 and does not open the run screen until 06:55 has been alive
    // for that half hour, and the board should say so.
    unawaited(_beat());
  }

  /// Stop reporting, let go of the timer, and forget WHO this was.
  ///
  /// Called from the driver shell's dispose, which is what sign-out amounts to:
  /// the gate rebuilds to the sign-in screen and the shell goes with it. The
  /// timer is owned here rather than by a widget, but nothing arms it except
  /// [start] and nothing survives this — a periodic request that outlived the
  /// screen that asked for it would keep a signed-out phone talking to the
  /// server, and a device id that outlived it would make the next driver report
  /// as the last one.
  void stop() {
    // Forgotten FIRST, and whether or not the timer was armed, because the
    // guard below is reached on the path that matters most: this object stops
    // itself when nobody has bound a crew phone to the driver, and again after
    // three refusals, and the shell's dispose then calls stop() on a service
    // that is already stopped. Forgetting after that guard would leave the
    // identity it had cached sitting there for the next driver, which is the
    // exact thing the guard was supposed to be protecting.
    _forgetIdentity();
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Drop everything that belonged to whoever was signed in.
  ///
  /// [_deviceId] and [_deviceKnown] go TOGETHER, because keeping the flag with
  /// a null id is its own leak in the other direction: the next driver would be
  /// told "no handset is bound to you" on the strength of an answer the server
  /// gave about somebody else, and would never beat at all for the rest of the
  /// session. The queued beats go too — every one of them names the old device
  /// id in its payload and flushing them later would post his handset's history
  /// under the new driver's account — along with the timings and the refusal
  /// count, which were measured against a device this person may not even have.
  ///
  /// [_tripId] goes too, and it is the one that bit hardest, because it was the
  /// one field [stop] could not reach: `stop` cleared it BELOW its
  /// `if (!_running) return`, and the commonest handset in the fleet is one
  /// where this service has already stopped ITSELF — for want of a bound crew
  /// phone, or after three refusals — while [noteTrip] carries on recording
  /// whichever run the driver opens. Sign out on that handset and the trip id
  /// outlived him. The next driver, who DOES have a crew phone, then sent his
  /// very first beat carrying the previous driver's `tripInstanceId`, and
  /// nothing downstream refuses it: `resolveTargets` resolves the trip through
  /// `tripForTenant`, which matches on `schoolTenantId`/`operatorTenantId` and
  /// nothing else, and then does `if (!vehicleId) vehicleId = trip.vehicleId` —
  /// so the beat is filed against the old driver's run AND the old driver's
  /// bus, and the cadence jumps to a minute for a trip this handset is not on.
  /// A trip id is an identity in exactly the way a device id is, and it is
  /// forgotten in the same place, on the same event, for the same reason.
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

  /// Which trip is under way, or null when none is.
  ///
  /// Drives the cadence and fills `tripInstanceId`, which is what turns a beat
  /// from "this phone is on" into "this phone is on and it is the one that is
  /// meant to be carrying children right now" — the case a dispatcher reading
  /// the liveness board is looking for. It does not page anybody; see the
  /// cadence note on this class for why not.
  void noteTrip(String? tripInstanceId) {
    final id = (tripInstanceId != null && tripInstanceId.isNotEmpty) ? tripInstanceId : null;
    if (_tripId == id) return;
    _tripId = id;
    if (!_running) return;
    // Say it immediately. The office learns a run has started from the trip
    // itself, but the FIRST beat carrying that trip id is what binds this
    // handset to it on the liveness board.
    unawaited(_beat());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running || state != AppLifecycleState.resumed) return;
    final last = _lastBeatAt;
    if (last != null && DateTime.now().difference(last) < _resumeDebounce) return;
    unawaited(_beat());
  }

  /// Ask which handset this is, once per signed-in person.
  ///
  /// A refusal is remembered; being unreachable is not, because a phone in a
  /// yard with no signal has not been told anything yet.
  ///
  /// [personId] is not decoration. The answer is cached AGAINST it, a cache
  /// filled for anyone else is thrown away before the question is asked, and an
  /// answer that arrives after the account changed under it — a driver handing
  /// the phone over while `/crew/me/devices` is in flight — is discarded rather
  /// than written, because by then it is a fact about somebody who has gone.
  Future<String?> _resolveDevice(String personId) async {
    if (_deviceKnown && _deviceOwnerPersonId == personId) return _deviceId;
    // Only when there is somebody ELSE's answer sitting here. A null owner is
    // not a stale owner — it is the first resolve of this session, and there is
    // nothing to forget: every other field [_forgetIdentity] touches is only
    // ever written alongside an owner id. The distinction became load-bearing
    // once that method started clearing [_tripId], which is NOT owned by the
    // resolve: [noteTrip] can set it from the run screen before the first beat
    // has finished asking which handset this is, and forgetting it here would
    // drop the trip binding off the beat that was about to carry it.
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
      // The server answered, and the answer was no. Remember it, against him.
      _deviceId = null;
      _deviceKnown = true;
      _deviceOwnerPersonId = personId;
    } catch (_) {
      return null;
    }
    return _deviceId;
  }

  /// One beat, plus a slice of the backlog if there is one.
  Future<void> _beat() async {
    if (!_running || _beating) return;
    // Who this beat is about, pinned before the first await. A beat is a claim
    // that a NAMED person is holding a NAMED handset, and on a shared phone the
    // answer can change between resolving the device and posting it — so it is
    // re-checked after every await rather than assumed to have held.
    final me = Session.instance.me;
    if (me == null) {
      // Signed out. Not merely nothing to say: anything said now would be said
      // under the last driver's name.
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
          // No crew phone is bound to this person. Nothing on the fleet board
          // is expecting this handset, so reporting would invent a device that
          // does not exist. Stop, and do not try again this session.
          stop();
        }
        return;
      }

      final beat = await _compose(deviceId);
      if (!_running || Session.instance.me?.id != personId) return;

      try {
        final next = await CrewApi.instance.sendHeartbeat(beat);
        // The third await, and the third identity check. This one guards the
        // BACKLOG. Every beat in [_queue] names the device id it was composed
        // under, and [_flush] posts them with whatever bearer token this
        // handset holds NOW — so a driver handing the phone over while a beat
        // is in flight, which is the ordinary end of a run and precisely when a
        // backlog from the dead spot on the way back is sitting there, would
        // otherwise have his queued beats accepted under the next driver's
        // account: `resolveTargets` checks only the organisation, so they would
        // refresh `lastHeartbeatAt` for a handset already in his locker and
        // close its silence episode as `DEVICE_RECOVERED`.
        if (!_running || Session.instance.me?.id != personId) return;
        _lastBeatAt = DateTime.now();
        _refusals = 0;
        if (next != null && next > 0) _serverIntervalSeconds = next;
        // Only once the live beat is through: the current one is what keeps the
        // bus off the silent list, and the backlog is history that can wait a
        // minute longer.
        if (_queue.isNotEmpty) await _flush(personId);
      } on ApiException catch (e) {
        // Same check on the failure path. A beat that could not be sent belongs
        // to the person it was composed for, and queueing it against the
        // session of whoever is holding the phone now would only hand it to
        // [_flush] under the wrong name.
        if (!_running || Session.instance.me?.id != personId) return;
        _handleRefusal(e, beat);
      } catch (_) {
        // Anything else — a malformed response, a decoding failure — is not
        // proof the phone was offline. Drop the beat rather than build a
        // backlog out of a bug.
      }
    } catch (_) {
      // Never throws at a caller. There is no screen to tell.
    } finally {
      _beating = false;
      _arm();
    }
  }

  /// Hand over up to sixty queued beats, oldest first.
  ///
  /// [personId] is whoever the calling beat was started for, re-checked on the
  /// way in and again after the request. The backlog is an IDENTITY as much as
  /// [_deviceId] is — every entry in it names a device id that was resolved for
  /// one person — and the only safe rule is that a batch is posted, and its
  /// entries dropped, only while that person is still the one signed in.
  /// [_forgetIdentity] empties the queue on a handover, so removing a range
  /// measured before the request would otherwise take the NEW driver's beats,
  /// or throw for being longer than what is left.
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
      if (e.status == 0 || e.status >= 500) return; // still no data. Keep them.
      if (e.status == 400) {
        // The whole batch was refused — every beat in it too old or too skewed
        // to record. Re-sending would fail identically every minute forever.
        _queue.removeRange(0, batch.length);
        return;
      }
      _handleRefusal(e, null);
    } catch (_) {
      // Keep the batch; the next beat tries again.
    }
  }

  /// What to do with a server that said no.
  void _handleRefusal(ApiException e, Map<String, dynamic>? beat) {
    if (e.status == 0 || e.status >= 500) {
      // OfflineException and the 25-second timeout both arrive as status 0.
      // This is the case the flush endpoint exists for: the phone was ALIVE in
      // the dead spot, and the only way to prove that afterwards is to have
      // kept the beats it took while it was in there.
      if (beat != null) _enqueue(beat);
      return;
    }
    if (e.status == 400) {
      // Refused on its content — a clock more than five minutes fast, most
      // likely, which `SAMPLING.maxFutureSkewSeconds` refuses outright. Not
      // queued: it would be refused again tomorrow for the same reason. It
      // still counts against the budget below, because a handset whose clock is
      // wrong will fail identically on every beat and a request a minute
      // forever on a prepaid SIM is worse than being silent.
      if (++_refusals >= _maxRefusals) stop();
      return;
    }
    if (e.status == 404) {
      // The Device row has gone or been rebound. Ask again; if the answer is
      // now "no handset", the next beat stops for good.
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

  /// Build the payload.
  ///
  /// Field names are `HeartbeatDto` on `CrewHeartbeatController`, read off the
  /// server. Every optional one is included ONLY when this handset actually
  /// measured it: an absent field is recorded as null and costs nothing, while
  /// a plausible-looking default is a claim the office will act on.
  ///
  /// Not sent, for want of a plugin this app does not carry and will not gain
  /// for a telemetry field: `batteryPct` and `powerState`, `deviceModel`,
  /// `appVersion`, `networkType`, `carrierName`, `signalStrengthDbm`,
  /// `freeDiskMb`. `networkType` in particular is tempting — a failed POST
  /// looks like no coverage — but it is equally a server that is down or a
  /// captive-portal wifi, and `NONE` raises `no_network` against the operator's
  /// mast. `vehicleId` is left out too: the server takes it from the trip.
  Future<Map<String, dynamic>> _compose(String deviceId) async {
    final beat = <String, dynamic>{
      'deviceId': deviceId,
      'ts': DateTime.now().toUtc().toIso8601String(),
    };
    if (_tripId != null) beat['tripInstanceId'] = _tripId;

    // The field the whole thing was built for. On Android, "while in use" means
    // the tracking that keeps children visible stops the moment the phone goes
    // in a pocket, and from outside that is indistinguishable from a dead
    // handset. `unableToDetermine` is left out rather than reported as false.
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
      // The plugin could not answer. Say nothing rather than say no.
    }

    // Only when OneSignal is actually up. Push.granted answers false both for
    // "switched off" and for "the SDK never started", and push.dart says in as
    // many words that the heartbeat must leave the field out rather than turn
    // the second into a driver who denied notifications.
    if (Push.started) beat['notificationPermission'] = Push.granted;

    // A driver feeding the app a fake location. Read from the live stream only:
    // `here` keeps the last fix after a run ends, and reporting that hours
    // later would attach today's answer to yesterday's question.
    if (BusLocation.instance.isRunning) {
      final fix = BusLocation.instance.here.value;
      if (fix != null) beat['mockLocationDetected'] = fix.isMocked;
    }

    // The depth of the position outbox, measured — bus_location.dart keeps this
    // count for exactly this field. A handset whose outbox is filling up is one
    // whose record of the run is not reaching anybody, and the office has no
    // other way to see that from outside.
    beat['queuedEventCount'] = BusLocation.instance.queuedCount;

    // dart:io, no plugin. Worth having: half the faults on this fleet are one
    // Android version behaving differently from the next.
    if (Platform.isAndroid) {
      beat['osName'] = 'Android';
    } else if (Platform.isIOS) {
      beat['osName'] = 'iOS';
    }
    final version = _osVersion();
    if (version != null) beat['osVersion'] = version;

    return beat;
  }

  /// `Platform.operatingSystemVersion`, trimmed to what the DTO accepts.
  ///
  /// Android hands back "Android 13 (API 33), Build/TQ3A..." on some ROMs and
  /// `@Length(1, 40)` would refuse the whole beat over it, taking a real proof
  /// of life down with a build tag nobody reads. The part before the comma is
  /// the version; the rest is dropped, and it is clamped again in case a ROM
  /// puts something long in front of the comma too.
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
