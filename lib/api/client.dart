import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../i18n/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_cache.dart';

const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://api.krsprotection.com',
);

class ApiException implements Exception {
  ApiException(this.message, this.status);

  final String message;
  final int status;

  bool get isAuth => status == 401;

  @override
  String toString() => message;
}

enum Renewal { renewed, rejected, unreachable }

class OfflineException extends ApiException {
  OfflineException()
      : super('No connection. Check the phone is on the network and try again.', 0);
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const _tokenKey = 'sm_access_token';
  static const _refreshKey = 'sm_refresh_token';
  static const _tenantKey = 'sm_tenant_id';

  static const _meKey = 'sm_me';

  static const List<String> _secretKeys = [_tokenKey, _refreshKey, _meKey];

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<void>? _migrating;

  Future<void> _migrateLegacySecrets() => _migrating ??= () async {
        final prefs = await SharedPreferences.getInstance();
        for (final key in _secretKeys) {
          final legacy = prefs.getString(key);
          if (legacy == null) continue;
          try {
            if (await _secure.read(key: key) == null) {
              await _secure.write(key: key, value: legacy);
            }
          } catch (e) {
            debugPrint('client: could not migrate $key to secure storage: $e');
            return;
          }
          await prefs.remove(key);
        }
      }();

  Future<String?> _readSecret(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (e) {
      debugPrint('client: could not read $key from secure storage: $e');
      return null;
    }
  }

  Future<void> _writeSecret(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } catch (e) {
      debugPrint('client: could not write $key to secure storage: $e');
    }
  }

  final http.Client _http = http.Client();

  String? _access;
  String? _refresh;
  String? _tenantId;

  String? get tenantId => _tenantId;
  bool get hasSession => _access != null;

  Future<void> restore() async {
    await _migrateLegacySecrets();
    final prefs = await SharedPreferences.getInstance();
    _access = await _readSecret(_tokenKey);
    _refresh = await _readSecret(_refreshKey);
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

    await _writeSecret(_tokenKey, access);
    if (refresh != null) await _writeSecret(_refreshKey, refresh);
    if (tenantId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantKey, tenantId);
    }
  }

  Future<void> saveMe(String json) => _writeSecret(_meKey, json);

  Future<String?> loadMe() async {
    await _migrateLegacySecrets();
    return _readSecret(_meKey);
  }

  Future<void> setTenant(String id) async {
    _tenantId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tenantKey, id);
  }

  Future<void> forgetTenant() async {
    _tenantId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tenantKey);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _tenantId = null;
    await OfflineCache.instance.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tenantKey);
    for (final key in _secretKeys) {
      try {
        await _secure.delete(key: key);
      } catch (e) {
        debugPrint('client: could not clear $key from secure storage: $e');
      }
      await prefs.remove(key);
    }
  }

  final StreamController<void> _signedOut = StreamController<void>.broadcast();
  Stream<void> get onSignedOut => _signedOut.stream;

  void signalSignedOut() {
    if (!_signedOut.isClosed) _signedOut.add(null);
  }

  Map<String, String> _headers({bool json = false, String? tenantId}) => {
        if (json) 'Content-Type': 'application/json',
        if (_access != null) 'Authorization': 'Bearer $_access',
        'X-Tenant-Id': ?(tenantId ?? _tenantId),
        'X-Lang': AppLocale.current.value.code,
      };

  Future<Renewal>? _renewing;

  Future<Renewal> _renew() {
    return _renewing ??= () async {
      try {
        if (_refresh == null) return Renewal.rejected;
        final res = await _http
            .post(
              Uri.parse('$kApiBase/auth/refresh'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': _refresh}),
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
          return Renewal.rejected;
        }
        if (res.statusCode != 200 && res.statusCode != 201) return Renewal.unreachable;

        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final token = body['accessToken'] as String?;
        if (token == null) return Renewal.unreachable;
        await saveSession(
          access: token,
          refresh: body['refreshToken'] as String?,
        );
        return Renewal.renewed;
      } on TimeoutException {
        return Renewal.unreachable;
      } catch (_) {
        return Renewal.unreachable;
      } finally {
        scheduleMicrotask(() => _renewing = null);
      }
    }();
  }

  Future<dynamic> get(String path, {String? tenantId}) =>
      _send('GET', path, null, true, tenantId);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);

  Future<dynamic> postAs(String? tenantId, String path, [Object? body]) =>
      _send('POST', path, body, true, tenantId);

  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body);

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);

  Future<dynamic> delete(String path, [Object? body]) => _send('DELETE', path, body);

  Future<dynamic> _send(
    String method,
    String path, [
    Object? body,
    bool retry = true,
    String? tenantId,
  ]) async {
    final uri = Uri.parse('$kApiBase$path');
    http.Response res;

    try {
      final request = http.Request(method, uri)
        ..headers.addAll(_headers(json: body != null, tenantId: tenantId));
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _http.send(request).timeout(const Duration(seconds: 25));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('The school system is not answering. Try again in a moment.', 0);
    } catch (_) {
      throw OfflineException();
    }

    if (res.statusCode == 401 && retry && !path.startsWith('/auth/login')) {
      switch (await _renew()) {
        case Renewal.renewed:
          return _send(method, path, body, false, tenantId);
        case Renewal.unreachable:
          throw OfflineException();
        case Renewal.rejected:
          await clear();
          signalSignedOut();
          throw ApiException('Your session has ended. Please sign in again.', 401);
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }

    throw ApiException(_messageFrom(res), res.statusCode);
  }

  Future<dynamic> upload(
    String path, {
    required String field,
    required Uint8List bytes,
    required String filename,
    required String mime,
    Map<String, String> fields = const {},
  }) =>
      _sendFile(path, field, bytes, filename, mime, fields);

  Future<dynamic> _sendFile(
    String path,
    String field,
    Uint8List bytes,
    String filename,
    String mime,
    Map<String, String> fields, [
    bool retry = true,
  ]) async {
    final uri = Uri.parse('$kApiBase$path');

    final boundary = '----ksp'
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}'
        '${Random.secure().nextInt(0x7fffffff).toRadixString(16)}';

    final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

    final form = BytesBuilder();
    void line(String s) => form.add(utf8.encode('$s\r\n'));
    fields.forEach((name, value) {
      line('--$boundary');
      line('Content-Disposition: form-data; name="$name"');
      line('');
      line(value);
    });
    line('--$boundary');
    line('Content-Disposition: form-data; name="$field"; filename="$safeName"');
    line('Content-Type: $mime');
    line('');
    form.add(bytes);
    line('');
    line('--$boundary--');

    http.Response res;
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll(_headers())
        ..headers['Content-Type'] = 'multipart/form-data; boundary=$boundary'
        ..bodyBytes = form.takeBytes();
      final streamed = await _http.send(request).timeout(const Duration(seconds: 90));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('The school system is not answering. Try again in a moment.', 0);
    } catch (_) {
      throw OfflineException();
    }

    if (res.statusCode == 401 && retry && !path.startsWith('/auth/login')) {
      switch (await _renew()) {
        case Renewal.renewed:
          return _sendFile(path, field, bytes, filename, mime, fields, false);
        case Renewal.unreachable:
          throw OfflineException();
        case Renewal.rejected:
          await clear();
          signalSignedOut();
          throw ApiException('Your session has ended. Please sign in again.', 401);
      }
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
    }
    if (res.statusCode >= 500) return 'Something went wrong at the school system.';
    if (res.statusCode == 403) return 'Your account is not allowed to do that.';
    if (res.statusCode == 404) return 'That is not there any more.';
    return 'That did not go through.';
  }
}

class Paged<T> {
  Paged({required this.rows, required this.total, required this.page, required this.pages});

  final List<T> rows;
  final int total;
  final int page;
  final int pages;

  static Paged<T> from<T>(dynamic json, T Function(Map<String, dynamic>) item) {
    if (json is List) {
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
