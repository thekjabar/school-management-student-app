import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
/// The backend has its own hostname, so the path does not repeat it: a call to
/// `/parent/children` is exactly that, and nginx maps it onto the gateway's
/// `/api` prefix at the edge. Changed from school.mrwari.com when the platform
/// moved to krsprotection.com — an app already on a phone keeps working only
/// until its next release, so a build carrying the old host is a build that
/// cannot sign anybody in.
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://api.krsprotection.com',
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

/// What came of trying to renew the access token.
///
/// Three outcomes, not two. This was a bool, and false meant all of: there is
/// no refresh token, the server refused it, the server answered 502, the
/// request timed out, the phone has no signal. The caller treated every one of
/// them as the end of the session and erased the tokens — so a gateway hiccup
/// at 07:40, the one minute of the day when the whole city opens the app at
/// once, signed everybody out and made them retype a password that was never
/// wrong.
///
/// A refresh token is only spent once the server has actually judged it.
enum Renewal { renewed, rejected, unreachable }

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

  /// The last confirmed answer from /auth/me, verbatim.
  ///
  /// Kept so the app can open on a phone with no signal. Without it the only
  /// way to know who is signed in was to ask the server, and being unable to
  /// ask was indistinguishable from being told no — which is how a parent in a
  /// basement ended up back at the login screen holding a perfectly good
  /// session.
  ///
  /// The tokens are the authority on whether the session is valid; this is only
  /// what to draw while the server is out of reach.
  static const _meKey = 'sm_me';

  /// The keys that are secrets, as against settings.
  ///
  /// Kept as one list because all three move together: they are written to the
  /// Keystore, they are migrated out of the old preferences file together, and
  /// on sign-out they are erased from both places together. `_tenantKey` is
  /// deliberately NOT here — which school a session is acting for is a setting,
  /// it is worth nothing to anyone who reads it, and leaving it in plain
  /// preferences keeps the ordinary path off the Keystore.
  static const List<String> _secretKeys = [_tokenKey, _refreshKey, _meKey];

  /// Where the secrets actually live: EncryptedSharedPreferences behind an
  /// Android Keystore key on Android, the Keychain on iOS.
  ///
  /// These three were in plain `shared_preferences`, which is an XML file in
  /// the app's data directory. No other app can read it — but Android cloud
  /// backup and device-to-device transfer copy that directory wholesale, so a
  /// crew member's access token, their rotating refresh token and their entire
  /// /auth/me payload (name, phone number, tenants, permission list) left the
  /// handset with the backup and arrived on whatever phone they set up next.
  /// This is the handset that carries forty children's names, faces and home
  /// pins. The manifest now also refuses backup outright, so the file that is
  /// left behind carries nothing worth taking either way.
  ///
  /// `resetOnError` is the plugin's default and is kept: a Keystore that has
  /// been invalidated (a factory reset restore, a lock-screen change on some
  /// OEM builds) then reads as empty rather than throwing, and the person signs
  /// in again — which is the correct outcome and not a crash on start-up.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    // Not `unlocked`: the app is opened at 06:40 by a driver whose phone has
    // just come off charge, and the Keychain item has to be readable from the
    // first unlock of the day rather than only while the screen is live.
    // `_this_device` keeps it out of iCloud Keychain, which is the iOS half of
    // the same backup problem this whole change is about.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Runs once per launch, before anything reads a secret.
  ///
  /// An install that is being UPGRADED still has its tokens in the old
  /// preferences file, and a driver halfway through a morning run must not be
  /// silently signed out by the upgrade that fixed this. So the old values are
  /// carried across on first run and only then deleted.
  Future<void>? _migrating;

  Future<void> _migrateLegacySecrets() => _migrating ??= () async {
        final prefs = await SharedPreferences.getInstance();
        for (final key in _secretKeys) {
          final legacy = prefs.getString(key);
          if (legacy == null) continue;
          try {
            // A value already in the Keystore is the newer one — this handset
            // has migrated before and the preferences copy is a leftover from a
            // write that failed to delete. Copying the old one over it would
            // hand back a spent refresh token, which the server reads as theft
            // and answers by revoking the whole family.
            if (await _secure.read(key: key) == null) {
              await _secure.write(key: key, value: legacy);
            }
          } catch (e) {
            // The Keystore refused. The plaintext copy STAYS: erasing it here
            // would sign out a driver mid-route to fix a privacy problem, which
            // is the wrong trade in the middle of a run. The next launch tries
            // again, and until then the session still works.
            debugPrint('client: could not migrate $key to secure storage: $e');
            return;
          }
          await prefs.remove(key);
        }
      }();

  /// Read one secret, treating an unavailable Keystore as "nothing stored".
  ///
  /// Never rethrows. This runs inside start-up, and a handset whose Keystore is
  /// in a state the plugin cannot use has to reach the sign-in screen rather
  /// than the crash reporter.
  Future<String?> _readSecret(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (e) {
      debugPrint('client: could not read $key from secure storage: $e');
      return null;
    }
  }

  /// Write one secret, or carry on without it.
  ///
  /// A failure here costs the session at the NEXT cold start, not this one:
  /// the token is already in memory and every request keeps working. That is
  /// the milder failure, and much milder than throwing out of sign-in and
  /// telling a driver at the bus that a password that was right was wrong.
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

  /// Reads the tokens saved on this phone, if any.
  ///
  /// Called once at start-up. A driver signs in on the first morning and should
  /// not be asked again on the second — a login screen at 06:40 with cold hands
  /// is how people end up sharing accounts.
  Future<void> restore() async {
    // Before the first read, so an upgrade finds its own tokens where it left
    // them rather than finding nothing and dropping to the login screen.
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

  /// Store the identity payload as it arrived, to be replayed offline.
  Future<void> saveMe(String json) => _writeSecret(_meKey, json);

  /// The last identity this phone saw, or null on a fresh install.
  Future<String?> loadMe() async {
    // Also migrated here and not only in [restore]: nothing in the language
    // makes restore() run first, and a build that read this before the
    // migration would show an upgrading driver a login screen.
    await _migrateLegacySecrets();
    return _readSecret(_meKey);
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
    await prefs.remove(_tenantKey);
    for (final key in _secretKeys) {
      // The Keystore first — that is where they live now. The _meKey goes with
      // the tokens: left behind, the next person to open this handset would be
      // greeted by the last one's name.
      try {
        await _secure.delete(key: key);
      } catch (e) {
        debugPrint('client: could not clear $key from secure storage: $e');
      }
      // And the old plaintext copy as well, unconditionally. On a handset whose
      // Keystore refused the migration the secret is still sitting in the
      // preferences file, and signing out has to erase it wherever it is —
      // phones are shared here, one handset between two parents.
      await prefs.remove(key);
    }
  }

  /// Fires when the session ends for good, so the app can return to sign-in
  /// without every screen having to check.
  final StreamController<void> _signedOut = StreamController<void>.broadcast();
  Stream<void> get onSignedOut => _signedOut.stream;

  /// Say out loud that the session is over.
  ///
  /// clear() only forgets the tokens. Signing out used to do exactly that and
  /// leave the gate still holding a person, so their app stayed on screen until
  /// some later request happened to come back 401 — and with no signal nothing
  /// comes back at all. On a handset passed between two parents, which the note
  /// in signOut says is normal here, the first one's children were still on
  /// screen after they had signed out.
  void signalSignedOut() {
    if (!_signedOut.isClosed) _signedOut.add(null);
  }

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
  Future<Renewal>? _renewing;

  Future<Renewal> _renew() {
    return _renewing ??= () async {
      try {
        // Nothing to present. Only the phone is involved in that answer, so it
        // is as final as a refusal.
        if (_refresh == null) return Renewal.rejected;
        final res = await _http
            .post(
              Uri.parse('$kApiBase/auth/refresh'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': _refresh}),
            )
            .timeout(const Duration(seconds: 15));
        // The server answered, and the answer was no.
        if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
          return Renewal.rejected;
        }
        // Anything else it said — 500, 502, a proxy's own error page — is not a
        // judgement on the token. It has not been spent, so it is kept.
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
        // Transport, or a body that would not parse. Either way the token was
        // never judged.
        return Renewal.unreachable;
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

  /// Replace a whole record, as against PATCH's "change these fields".
  ///
  /// Used where the server models the thing as a single value a caller sets
  /// outright — the family's home location, where sending half of it is a bug
  /// rather than a partial update.
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);

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
      switch (await _renew()) {
        case Renewal.renewed:
          return _send(method, path, body, false);
        case Renewal.unreachable:
          // Not refused — not reached. Tearing the session down here is what
          // turned a two-second gateway blip into a whole city retyping their
          // passwords. The tokens stay exactly where they are.
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

  /// Send one file to an endpoint that expects a form rather than JSON.
  ///
  /// Written out by hand instead of with http's MultipartRequest because
  /// naming a part's Content-Type needs `MediaType` from http_parser, and that
  /// is a whole package in pubspec.yaml for one line. The type is not optional:
  /// the upload endpoint checks it against the kind of file it was told to
  /// expect, and a part sent without one arrives as application/octet-stream
  /// and is refused.
  ///
  /// The bytes stay in memory, so the request can be built again after a token
  /// renewal. A 401 at the moment of upload then costs the person holding the
  /// phone nothing — which matters when the thing being uploaded is a
  /// photograph they would otherwise have to walk back and take again.
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

    // Only has to be a string that does not occur inside the photograph. The
    // clock alone is not enough on a handset that uploads twice in the same
    // microsecond, so there is randomness in it as well.
    final boundary = '----ksp'
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}'
        '${Random.secure().nextInt(0x7fffffff).toRadixString(16)}';

    // A filename arrives from a plugin, not from us, and it is written into a
    // header. Anything that could close the quotes or start a new header line
    // is taken out rather than trusted.
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
      // Longer than the twenty-five seconds a JSON call gets. This is a few
      // hundred kilobytes leaving a bus yard on one bar, and a driver told
      // "not answering" too early will take the photograph again rather than
      // wait for the one already going up.
      final streamed = await _http.send(request).timeout(const Duration(seconds: 90));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('The school system is not answering. Try again in a moment.', 0);
    } catch (_) {
      throw OfflineException();
    }

    if (res.statusCode == 401 && retry) {
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
