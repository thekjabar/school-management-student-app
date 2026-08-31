import 'dart:convert';

import 'client.dart';
import 'push.dart';

/// One school (or operator) a person belongs to, and what they may do there.
class Membership {
  Membership({
    required this.tenantId,
    required this.tenantKind,
    required this.tenantName,
    required this.role,
    required this.permissions,
    this.campusId,
  });

  final String tenantId;
  final String tenantKind;
  final String tenantName;
  final String role;
  final List<String> permissions;
  final String? campusId;

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
        tenantId: j['tenantId'] as String,
        tenantKind: (j['tenantKind'] ?? 'SCHOOL') as String,
        tenantName: (j['tenantName'] ?? '') as String,
        role: j['role'] as String,
        permissions: ((j['permissions'] as List?) ?? []).cast<String>(),
        campusId: j['campusId'] as String?,
      );
}

/// Who is signed in.
class Me {
  Me({
    required this.id,
    required this.name,
    required this.phone,
    required this.phoneVerified,
    required this.memberships,
    required this.active,
  });

  final String id;
  final String name;
  final String phone;
  final bool phoneVerified;
  final List<Membership> memberships;
  final Membership active;

  String get role => active.role;
  String get schoolName => active.tenantName;
  bool can(String permission) => active.permissions.contains(permission);

  /// The first name, which is what a greeting should use. Kurdish full names
  /// run to four parts and "Good morning, Karwan Ahmed Rasul Baban" reads like
  /// a summons.
  String get firstName => name.split(' ').first;

  factory Me.fromJson(Map<String, dynamic> j) {
    final person = j['person'] as Map<String, dynamic>;
    final active = j['active'] as Map<String, dynamic>;
    final memberships = ((j['memberships'] as List?) ?? [])
        .map((e) => Membership.fromJson(e as Map<String, dynamic>))
        .toList();

    return Me(
      id: person['id'] as String,
      name: (person['name'] ?? '') as String,
      phone: (person['phoneE164'] ?? '') as String,
      phoneVerified: (person['phoneVerified'] ?? false) as bool,
      memberships: memberships,
      active: Membership(
        tenantId: active['tenantId'] as String,
        tenantKind: (active['tenantKind'] ?? 'SCHOOL') as String,
        tenantName: memberships
            .where((m) => m.tenantId == active['tenantId'])
            .map((m) => m.tenantName)
            .firstOrNull ??
            '',
        role: active['role'] as String,
        permissions: ((active['permissions'] as List?) ?? []).cast<String>(),
        campusId: active['campusId'] as String?,
      ),
    );
  }
}

/// The result of signing in.
class SignInResult {
  SignInResult({required this.me, required this.mustChangePassword});

  final Me me;
  final bool mustChangePassword;
}

/// Sign-in, sign-out, and who am I.
///
/// Kept apart from the HTTP client so that the client knows nothing about
/// people — it moves tokens and JSON, and this decides what a person is.
class Session {
  Session._();

  static final Session instance = Session._();

  Me? _me;
  Me? get me => _me;

  final ApiClient _api = ApiClient.instance;

  /// Sign in with a phone number and a password.
  ///
  /// The number is the identity: the school already holds a verified number for
  /// every guardian and every member of staff, and inventing a username would
  /// only be one more thing to lose.
  Future<SignInResult> signIn(String phone, String password) async {
    final body = await _api.post('/auth/login', {
      'phone': phone.trim(),
      'password': password,
    }) as Map<String, dynamic>;

    // The mobile apps have no cookie jar, so the refresh token comes back in
    // the body as well as in a Set-Cookie header the phone will ignore.
    await _api.saveSession(
      access: body['accessToken'] as String,
      refresh: body['refreshToken'] as String?,
    );

    final memberships = ((body['memberships'] as List?) ?? [])
        .map((e) => Membership.fromJson(e as Map<String, dynamic>))
        .toList();
    if (memberships.isNotEmpty) {
      await _api.saveSession(
        access: body['accessToken'] as String,
        tenantId: memberships.first.tenantId,
      );
    }

    final me = await refresh();
    if (me == null) {
      throw ApiException('Signed in, but your account could not be loaded.', 500);
    }
    // Tie the handset to this person so the server can address them by our own
    // id rather than by a device token that changes on every reinstall.
    await Push.identify(me.id);
    return SignInResult(
      me: me,
      mustChangePassword: (body['mustChangePassword'] ?? false) as bool,
    );
  }

  /// Re-read the account from the server.
  ///
  /// Returns null only when the server has ANSWERED that the session is no
  /// longer good. Anything else — no signal, a timeout, the platform being
  /// down — is rethrown, because the caller has to be able to tell those apart.
  ///
  /// It used to catch every ApiException and return null, and OfflineException
  /// is an ApiException: a phone in a lift produced the same answer as a
  /// stood-down account, and the app sent both to the login screen.
  Future<Me?> refresh() async {
    final Map<String, dynamic> json;
    try {
      json = await _api.get('/auth/me') as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.isAuth) {
        _me = null;
        return null;
      }
      rethrow;
    }

    _me = Me.fromJson(json);
    await _api.setTenant(_me!.active.tenantId);
    // Kept so the app can open offline next time.
    await _api.saveMe(jsonEncode(json));
    // Also here, not only in signIn: a session restored from disk on a cold
    // start never passes through signIn, and would be subscribed to nothing.
    await Push.identify(_me!.id);
    return _me;
  }

  /// Who this phone last knew to be signed in, read from disk.
  ///
  /// Used to draw the app before — and, with no signal, instead of — an answer
  /// from the server. Never used to decide whether a session is VALID: the
  /// tokens are the authority on that and the server is the judge of the
  /// tokens. This only decides what to put on screen meanwhile.
  Future<Me?> restoreMe() async {
    try {
      final raw = await _api.loadMe();
      if (raw == null) return null;
      _me = Me.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _me;
    } catch (_) {
      // A payload written by an older build whose shape has since changed. Not
      // worth a crash on start-up — the server will supply a fresh one.
      return null;
    }
  }

  /// Change your own password. Ends every other session, by design.
  Future<void> changePassword(String current, String next) async {
    await _api.post('/auth/password/change', {
      'currentPassword': current,
      'newPassword': next,
    });
  }

  Future<void> signOut() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Signing out locally matters more than the server acknowledging it.
    }
    _me = null;
    await _api.clear();
    // Phones get shared here — one handset between two parents, or handed down
    // to an older child. A device still subscribed after sign-out delivers one
    // family's alerts to another.
    await Push.forget();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
