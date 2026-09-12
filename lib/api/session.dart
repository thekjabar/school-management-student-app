import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.dart';
import 'client.dart';
import 'offline_cache.dart';
import 'push.dart';

const List<String> kGuardianRoles = ['GUARDIAN'];

const List<String> kTeacherRoles = ['TEACHER'];

const List<String> kCrewRoles = ['DRIVER', 'ATTENDANT'];

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

class Me {
  Me({
    required this.id,
    required this.name,
    required this.phone,
    required this.phoneVerified,
    required this.memberships,
    required this.active,
    this.locale,
    this.pushIdentityToken,
    this.passwordMustChange = false,
  });

  final String id;
  final String name;
  final String phone;
  final bool phoneVerified;
  final List<Membership> memberships;
  final Membership active;

  final String? pushIdentityToken;

  final String? locale;

  final bool passwordMustChange;

  String get role => active.role;
  String get schoolName => active.tenantName;
  bool can(String permission) => active.permissions.contains(permission);

  List<Membership> schoolsFor(List<String> roles) =>
      memberships.where((m) => roles.contains(m.role)).toList(growable: false);

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
      locale: person['locale'] as String?,
      pushIdentityToken: (j['pushIdentityToken'] ?? person['pushIdentityToken'])
          as String?,
      passwordMustChange:
          ((j['blockers'] as Map<String, dynamic>?)?['passwordMustChange'] ??
              false) as bool,
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

class SignInResult {
  SignInResult({required this.me, required this.mustChangePassword});

  final Me me;
  final bool mustChangePassword;
}

class Session {
  Session._();

  static final Session instance = Session._();

  static bool passwordChangeRequired = false;

  static const _schoolChosenKey = 'sm_school_chosen';

  Me? _me;
  Me? get me => _me;

  final ValueNotifier<String?> activeTenant = ValueNotifier<String?>(null);

  final ApiClient _api = ApiClient.instance;

  Future<SignInResult> signIn(String phone, String password) async {
    final body = await _api.post('/auth/login', {
      'phone': phone.trim(),
      'password': password,
    }) as Map<String, dynamic>;

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
    await Push.identify(me.id, identityToken: me.pushIdentityToken);
    return SignInResult(
      me: me,
      mustChangePassword: (body['mustChangePassword'] ?? false) as bool,
    );
  }

  Future<Me?> switchTenant(String tenantId) async {
    final body =
        await _api.post('/auth/tenant', {'tenantId': tenantId}) as Map<String, dynamic>;
    await _api.saveSession(
      access: body['accessToken'] as String,
      tenantId: tenantId,
    );
    await OfflineCache.instance.clear();

    final me = await refresh();
    if (me != null && me.active.tenantId != tenantId) {
      throw ApiException('That school did not open. Try again.', 409);
    }
    return me;
  }

  Future<bool> schoolChosen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_schoolChosenKey) ?? false;
  }

  Future<void> markSchoolChosen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_schoolChosenKey, true);
  }

  Future<Me?> refresh() async {
    final Map<String, dynamic> json;
    try {
      json = await _api.get('/auth/me') as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.isAuth) {
        _me = null;
        return null;
      }
      if (e.status == 403 && _api.tenantId != null) {
        await _api.forgetTenant();
        return refresh();
      }
      rethrow;
    }

    _me = Me.fromJson(json);
    await _api.setTenant(_me!.active.tenantId);
    activeTenant.value = _me!.active.tenantId;
    await _api.saveMe(jsonEncode(json));
    await Push.identify(_me!.id, identityToken: _me!.pushIdentityToken);
    await syncLocale();
    return _me;
  }

  Future<Me?> restoreMe() async {
    try {
      final raw = await _api.loadMe();
      if (raw == null) return null;
      _me = Me.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      activeTenant.value = _me!.active.tenantId;
      return _me;
    } catch (_) {
      return null;
    }
  }

  Future<void> setLocale(Lang lang) async {
    await _api.post('/auth/locale', {'locale': lang.serverCode});
  }

  Future<void> syncLocale() async {
    if (_me?.locale == AppLocale.current.value.serverCode) return;
    try {
      await setLocale(AppLocale.current.value);
    } on ApiException {
      // ignore: empty_catches
    }
  }

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
      // ignore: empty_catches
    }
    _me = null;
    activeTenant.value = null;
    await _api.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_schoolChosenKey);
    _api.signalSignedOut();
    await Push.forget();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
