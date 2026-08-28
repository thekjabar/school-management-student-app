import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../i18n/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the platform lives.
///
/// Overridable at build time so a tester can point a debug build at a laptop:
///
///     flutter run --dart-define=API_BASE=http://10.0.2.2:8080/api
///
/// One host for all eight services. The gateway routes by path prefix, so this
/// client never has to know which service answers `/parent/children` — and a
/// service can be split or moved without an app release, which matters when the
/// app is on three thousand phones nobody can force to update.
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://school.mrwari.com/api',
);

/// An error worth showing to the person holding the phone.
///
/// The API writes its messages for that person rather than for a log, so they
/// are carried through unchanged instead of being replaced with "Error 400".
class ApiException implements Exception {
  ApiException(this.message, this.status);

  final String message;
  final int status;

  /// The session is gone and no retry will help.
  bool get isAuth => status == 401;

  @override
  String toString() => message;
}

/// Thrown when the phone genuinely cannot reach the platform.
class OfflineException extends ApiException {
  OfflineException()
      : super('No connection. Check the phone is on the network and try again.', 0);
}

/// The one HTTP client the whole app shares.
///
/// Holds the access token, renews it when it expires, and gives up cleanly when
/// the session is really over. Everything above this layer deals in decoded
/// JSON and typed exceptions; nothing above it ever sees a status code.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const _tokenKey = 'sm_access_token';
  static const _refreshKey = 'sm_refresh_token';
  static const _tenantKey = 'sm_tenant_id';

  final http.Client _http = http.Client();

  String? _access;
  String? _refresh;
  String? _tenantId;

  String? get tenantId => _tenantId;
  bool get hasSession => _access != null;

  /// Reads the tokens saved on this phone, if any.
  ///
  /// Called once at start-up. A driver signs in on the first morning and should
  /// not be asked again on the second — a login screen at 06:40 with cold hands
  /// is how people end up sharing accounts.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _access = prefs.getString(_tokenKey);
    _refresh = prefs.getString(_refreshKey);
    _tenantId = prefs.getString(_tenantKey);
  }

  Future<void> saveSession({
    required String access,
    String? refresh,
    String? tenantId,
  }) async {
    _access = access;
    if (refresh != null) _refresh = refresh;
    if (tenantId != null) _tenantId = tenantId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, access);
    if (refresh != null) await prefs.setString(_refreshKey, refresh);
    if (tenantId != null) await prefs.setString(_tenantKey, tenantId);
  }

  /// Record which school this session is acting for, without touching the token.
  Future<void> setTenant(String id) async {
    _tenantId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tenantKey, id);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _tenantId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_tenantKey);
  }

  /// Fires when the session ends for good, so the app can return to sign-in
  /// without every screen having to check.
  final StreamController<void> _signedOut = StreamController<void>.broadcast();
  Stream<void> get onSignedOut => _signedOut.stream;

  Map<String, String> _headers({bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (_access != null) 'Authorization': 'Bearer $_access',
        'X-Tenant-Id': ?_tenantId,
        // The language the app is showing RIGHT NOW, so the server can answer
        // in it. Read per request rather than captured once: the parent can
        // change language at any moment, and the very next request has to
        // carry the new one.
        'X-Lang': AppLocale.current.value.code,
      };

  /// Renewal is single-flight.
  ///
  /// The server ROTATES the refresh token and treats a reuse as theft, revoking
  /// the whole family. A home screen that fires five requests at once would
  /// present the same refresh token five times, the second would be read as a
  /// reuse, and the driver would be thrown out mid-run. One shared future means
  /// concurrent callers all wait on the same renewal.
  Future<bool>? _renewing;

  Future<bool> _renew() {
    return _renewing ??= () async {
      try {
        if (_refresh == null) return false;
        final res = await _http
            .post(
              Uri.parse('$kApiBase/auth/refresh'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': _refresh}),
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode != 200 && res.statusCode != 201) return false;
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final token = body['accessToken'] as String?;
        if (token == null) return false;
        await saveSession(
          access: token,
          refresh: body['refreshToken'] as String?,
        );
        return true;
      } catch (_) {
        return false;
      } finally {
        // Cleared on the next microtask so everyone awaiting this attempt sees
        // the same answer before another can start.
        scheduleMicrotask(() => _renewing = null);
      }
    }();
  }

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);

  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body);

  Future<dynamic> delete(String path, [Object? body]) => _send('DELETE', path, body);

  Future<dynamic> _send(String method, String path, [Object? body, bool retry = true]) async {
    final uri = Uri.parse('$kApiBase$path');
    http.Response res;

    try {
      final request = http.Request(method, uri)
        ..headers.addAll(_headers(json: body != null));
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _http.send(request).timeout(const Duration(seconds: 25));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('The school system is not answering. Try again in a moment.', 0);
    } catch (_) {
      throw OfflineException();
    }

    // One retry, and only for an expired token. A 403 is a permission answer;
    // asking the same question twice does not change it.
    if (res.statusCode == 401 && retry) {
      if (await _renew()) return _send(method, path, body, false);
      await clear();
      if (!_signedOut.isClosed) _signedOut.add(null);
      throw ApiException('Your session has ended. Please sign in again.', 401);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }

    throw ApiException(_messageFrom(res), res.statusCode);
  }

  String _messageFrom(http.Response res) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final message = body is Map ? body['message'] : null;
      if (message is String) return message;
      if (message is List && message.isNotEmpty) return message.join('\n');
    } catch (_) {
      // Not JSON. Fall through to something honest rather than dumping HTML.
    }
    if (res.statusCode >= 500) return 'Something went wrong at the school system.';
    if (res.statusCode == 403) return 'Your account is not allowed to do that.';
    if (res.statusCode == 404) return 'That is not there any more.';
    return 'That did not go through.';
  }
}

/// Convenience for the paged envelope every list endpoint returns.
class Paged<T> {
  Paged({required this.rows, required this.total, required this.page, required this.pages});

  final List<T> rows;
  final int total;
  final int page;
  final int pages;

  static Paged<T> from<T>(dynamic json, T Function(Map<String, dynamic>) item) {
    if (json is List) {
      // A few endpoints return a bare array — the teacher's classes, for one,
      // because a teacher never has enough of them to page.
      final rows = json.map((e) => item(e as Map<String, dynamic>)).toList();
      return Paged(rows: rows, total: rows.length, page: 1, pages: 1);
    }
    final map = json as Map<String, dynamic>;
    return Paged(
      rows: ((map['rows'] as List?) ?? [])
          .map((e) => item(e as Map<String, dynamic>))
          .toList(),
      total: (map['total'] as num?)?.toInt() ?? 0,
      page: (map['page'] as num?)?.toInt() ?? 1,
      pages: (map['pages'] as num?)?.toInt() ?? 1,
    );
  }
}
