import 'dart:async';

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'client.dart';

class Push {
  Push._();

  static const String appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'e884c0e5-93aa-482d-80b4-d9bed167a21c',
  );

  static bool _started = false;

  static bool get started => _started;

  static String? _personId;

  static String? _identityToken;

  static Future<void> start() async {
    if (_started || appId.isEmpty) return;
    _started = true;
    try {
      if (kDebugMode) OneSignal.Debug.setLogLevel(OSLogLevel.error);
      OneSignal.initialize(appId);
    } catch (e) {
      debugPrint('push: init failed: $e');
      _started = false;
    }
  }

  static Future<void> identify(String personId, {String? identityToken}) async {
    if (!_started || personId.isEmpty) return;

    if (identityToken == null || identityToken.isEmpty) {
      _personId = null;
      _identityToken = null;
      debugPrint(
        'push: /auth/me carried no identity token — this handset stays '
        'anonymous rather than claiming an external id it cannot prove',
      );
      return;
    }

    if (!Platform.isAndroid) {
      _personId = null;
      _identityToken = null;
      debugPrint('push: identity verification is Android-only in this SDK — '
          'staying anonymous rather than claiming an id unverified');
      return;
    }

    _personId = personId;
    _identityToken = identityToken;
    try {
      await OneSignal.loginWithJWT(personId, identityToken);
    } catch (e) {
      debugPrint('push: login failed: $e');
      return;
    }
    unawaited(_registerWhenSubscribed());
  }

  static Future<void> _registerWhenSubscribed() async {
    if (_personId == null || _identityToken == null) return;

    for (var attempt = 0; attempt < 12; attempt++) {
      final id = subscriptionId;
      if (id != null) {
        if (id == _registered) return;

        final person = _personId;
        final token = _identityToken;
        if (person != null && token != null) {
          try {
            await OneSignal.loginWithJWT(person, token);
          } catch (e) {
            debugPrint('push: re-login failed: $e');
          }
        }

        try {
          await ApiClient.instance.post('/push/devices', {
            'subscriptionId': id,
            'platform': Platform.isIOS ? 'IOS_APNS' : 'ANDROID_FCM',
          });
          _registered = id;
        } catch (e) {
          debugPrint('push: registering with the API failed: $e');
        }
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    debugPrint('push: no subscription id after 12s — permission is probably off');
  }

  static String? _registered;

  static Future<void> forget() async {
    if (!_started) return;
    final id = _registered;
    if (id != null) {
      try {
        await ApiClient.instance.delete('/push/devices', {'subscriptionId': id});
      } catch (e) {
        debugPrint('push: unregistering with the API failed: $e');
      }
      _registered = null;
    }
    _personId = null;
    _identityToken = null;
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('push: logout failed: $e');
    }
  }

  static bool get granted {
    try {
      return OneSignal.Notifications.permission;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> askPermission() async {
    if (!_started) return false;
    try {
      final ok = await OneSignal.Notifications.requestPermission(true);
      if (ok) unawaited(_registerWhenSubscribed());
      return ok;
    } catch (e) {
      debugPrint('push: permission request failed: $e');
      return false;
    }
  }

  static String? get subscriptionId {
    try {
      final id = OneSignal.User.pushSubscription.id;
      return (id == null || id.startsWith('local-')) ? null : id;
    } catch (_) {
      return null;
    }
  }
}
