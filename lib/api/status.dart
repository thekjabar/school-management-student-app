import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.dart';

const String kStatusBase = String.fromEnvironment(
  'STATUS_BASE',
  defaultValue: 'https://status-api.krsprotection.com',
);

const String kStatusKey = String.fromEnvironment('STATUS_KEY');

const String kAppVersion = String.fromEnvironment('APP_VERSION');

enum PlatformState { ok, notice, maintenance }

@immutable
class PlatformStatus {
  const PlatformStatus({
    required this.state,
    this.id,
    this.title,
    this.message,
    this.startsAt,
    this.endsAt,
    this.dismissible = true,
    this.retryAfterSeconds,
  });

  static const allClear = PlatformStatus(state: PlatformState.ok);

  final PlatformState state;
  final String? id;
  final String? title;
  final String? message;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool dismissible;
  final int? retryAfterSeconds;

  bool get blocks => state == PlatformState.maintenance;

  static PlatformStatus? fromJson(Map<String, dynamic> json) {
    final state = switch (json['state']) {
      'ok' => PlatformState.ok,
      'notice' => PlatformState.notice,
      'maintenance' => PlatformState.maintenance,
      _ => null,
    };
    if (state == null) return null;
    if (state == PlatformState.ok) return allClear;

    return PlatformStatus(
      state: state,
      id: _text(json['id']),
      title: _text(json['title']),
      message: _text(json['message']),
      startsAt: _moment(json['startsAt']),
      endsAt: _moment(json['endsAt']),
      dismissible: json['dismissible'] is bool
          ? json['dismissible'] as bool
          : state != PlatformState.maintenance,
      retryAfterSeconds: (json['retryAfterSeconds'] as num?)?.toInt(),
    );
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static DateTime? _moment(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

class PlatformStatusService {
  PlatformStatusService._();

  static final PlatformStatusService instance = PlatformStatusService._();

  static const _dismissedKey = 'sm_status_dismissed';

  static const _timeout = Duration(seconds: 3);

  static const quietPeriod = Duration(minutes: 1);

  http.Client _http = http.Client();

  @visibleForTesting
  set httpForTest(http.Client client) => _http = client;

  String _key = kStatusKey;

  @visibleForTesting
  set keyForTest(String key) => _key = key;

  final ValueNotifier<PlatformStatus> current =
      ValueNotifier<PlatformStatus>(PlatformStatus.allClear);

  String _app = '';

  String? _dismissedId;

  String? get dismissedId => _dismissedId;

  DateTime? _rechecked;

  Future<void>? _asking;

  bool get configured => _key.isNotEmpty;

  bool get suppressed {
    final answer = current.value;
    return answer.state == PlatformState.notice &&
        answer.id != null &&
        answer.id == _dismissedId;
  }

  Future<void> start(String app) async {
    _app = app;
    try {
      final prefs = await SharedPreferences.getInstance();
      _dismissedId = prefs.getString(_dismissedKey);
    } catch (e) {
      debugPrint('status: could not read the dismissed notice: $e');
    }
    await refresh();
  }

  Future<void> refresh() {
    if (!configured) return Future<void>.value();
    final running = _asking;
    if (running != null) return running;
    final started = _ask();
    _asking = started;
    return started;
  }

  void recheckAfterFailure() {
    final last = _rechecked;
    final now = DateTime.now();
    if (last != null && now.difference(last) < quietPeriod) return;
    _rechecked = now;
    unawaited(refresh());
  }

  Future<void> dismiss(String id) async {
    _dismissedId = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedKey, id);
    } catch (e) {
      debugPrint('status: could not remember the dismissed notice: $e');
    }
  }

  Future<void> _ask() async {
    try {
      final res = await _http
          .get(_endpoint(), headers: {'X-Status-Key': _key})
          .timeout(_timeout);
      if (res.statusCode != 200) return;

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map<String, dynamic>) return;

      final answer = PlatformStatus.fromJson(body);
      if (answer != null) current.value = answer;
    } catch (e) {
      debugPrint('status: could not reach the status service: $e');
    } finally {
      _asking = null;
    }
  }

  Uri _endpoint() => Uri.parse('$kStatusBase/api/status').replace(
        queryParameters: {
          if (_app.isNotEmpty) 'app': _app,
          'lang': AppLocale.current.value.serverCode.toLowerCase(),
          if (kAppVersion.isNotEmpty) 'version': kAppVersion,
        },
      );

  @visibleForTesting
  void resetForTest() {
    current.value = PlatformStatus.allClear;
    _app = '';
    _key = kStatusKey;
    _dismissedId = null;
    _rechecked = null;
    _asking = null;
  }
}
