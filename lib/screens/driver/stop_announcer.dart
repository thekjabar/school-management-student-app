import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/bus_location.dart';
import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import 'approach_prompts.dart';
import 'stop_presence.dart';

class StopAnnouncer {
  StopAnnouncer._();

  static final StopAnnouncer instance = StopAnnouncer._();

  static const String _mutedKey = 'driver.voice.muted';

  static String _firedKey(String tripId) => 'driver.voice.fired.$tripId';

  static const Duration _bannerFor = Duration(seconds: 8);

  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  final ValueNotifier<String?> banner = ValueNotifier<String?>(null);

  FlutterTts? _tts;
  final Map<Lang, String?> _voices = {};
  Timer? _bannerTimer;

  String? _tripId;
  String _leg = 'OUT';
  List<ApproachTarget> _targets = const [];
  bool _running = false;
  bool _listening = false;
  Set<String>? _fired;
  bool _mutedRestored = false;

  void track({
    required String tripId,
    required String leg,
    required List<PlannedStop> stops,
    required SchoolGate? school,
    required bool running,
  }) {
    if (_tripId != tripId) {
      _tripId = tripId;
      _fired = null;
      unawaited(_restore(tripId));
    }
    _leg = leg;
    _targets = approachTargets(stops: stops, leg: leg, school: school);
    _running = running;
    if (running && !_listening) {
      _listening = true;
      BusLocation.instance.here.addListener(_onFix);
    } else if (!running) {
      _detach();
    }
    if (running) _onFix();
  }

  void release(String tripId) {
    if (_tripId != tripId) return;
    _running = false;
    _detach();
    unawaited(_tts?.stop());
  }

  Future<void> toggleMute() async {
    muted.value = !muted.value;
    if (muted.value) unawaited(_tts?.stop());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedKey, muted.value);
    } catch (_) {
    }
  }

  void _detach() {
    if (!_listening) return;
    _listening = false;
    BusLocation.instance.here.removeListener(_onFix);
  }

  Future<void> _restore(String tripId) async {
    var fired = <String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      fired = (prefs.getStringList(_firedKey(tripId)) ?? const []).toSet();
      if (!_mutedRestored) {
        _mutedRestored = true;
        muted.value = prefs.getBool(_mutedKey) ?? false;
      }
    } catch (_) {
    }
    if (_tripId != tripId) return;
    _fired = fired;
    _onFix();
  }

  Future<void> _remember(String tripId, Set<String> fired) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_firedKey(tripId), fired.toList());
    } catch (_) {
    }
  }

  void _onFix() {
    final tripId = _tripId;
    final fired = _fired;
    final fix = BusLocation.instance.here.value;
    if (!_running || tripId == null || fired == null || fix == null) return;
    if (!fixIsFresh(fix, DateTime.now())) return;
    final cues = approachCues(
      targets: _targets,
      bus: LatLng(fix.latitude, fix.longitude),
      accuracyM: fix.accuracy,
      fired: fired,
    );
    if (cues.isEmpty) return;
    unawaited(_remember(tripId, fired));
    for (final cue in cues) {
      unawaited(_announce(cue));
    }
  }

  Future<void> _announce(ApproachCue cue) async {
    final app = AppLocale.current.value;
    _showBanner(approachPrompt(cue, leg: _leg, lang: app));
    unawaited(_vibrate(cue.stage));
    if (muted.value) return;
    try {
      final tts = _tts ??= FlutterTts();
      final chosen = await _voiceFor(tts, app);
      if (chosen == null) return;
      await tts.setLanguage(chosen.$2);
      await tts.speak(approachPrompt(cue, leg: _leg, lang: chosen.$1));
    } catch (_) {
    }
  }

  Future<(Lang, String)?> _voiceFor(FlutterTts tts, Lang app) async {
    for (final lang in {app, Lang.ar, Lang.en}) {
      if (!_voices.containsKey(lang)) _voices[lang] = await _locale(tts, lang);
    }
    final lang = voiceLanguage(app, (l) => _voices[l] != null);
    return lang == null ? null : (lang, _voices[lang]!);
  }

  Future<String?> _locale(FlutterTts tts, Lang lang) async {
    for (final locale in kVoiceLocales[lang] ?? const <String>[]) {
      try {
        if (await tts.isLanguageAvailable(locale) == true) return locale;
      } catch (_) {
      }
    }
    return null;
  }

  Future<void> _vibrate(ApproachStage stage) async {
    if (stage == ApproachStage.near) {
      await HapticFeedback.mediumImpact();
      return;
    }
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.vibrate();
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

  void _showBanner(String text) {
    banner.value = text;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(_bannerFor, () => banner.value = null);
  }
}
