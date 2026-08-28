import 'dart:async';

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'client.dart';

/// Push notifications.
///
/// Everything OneSignal-shaped lives behind this one class so the rest of the
/// app never imports the SDK. That is not tidiness: push is the part of this
/// product most likely to be swapped out — a school group with its own
/// provider, or a move to FCM plus HMS directly — and a hundred call sites
/// holding an OneSignal type would make that a rewrite.
///
/// Addressing is by EXTERNAL ID, which is our own Person id, never the device
/// token. Tokens rotate on reinstall and on a phone restore, and a system that
/// loses a family when they reinstall loses exactly the families who
/// reinstalled because it was not working. The server sends to the person;
/// OneSignal works out which handsets that means today.
class Push {
  Push._();

  /// The OneSignal application id.
  ///
  /// Not a secret — it ships inside every copy of every OneSignal app on the
  /// store, and it can only be used to *receive*. The REST key that can send
  /// is server-side only and is never compiled into the app.
  static const String appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'e884c0e5-93aa-482d-80b4-d9bed167a21c',
  );

  static bool _started = false;

  /// The person this handset is signed in as, kept so the OneSignal login can
  /// be re-issued once a subscription actually exists.
  static String? _personId;

  /// Bring the SDK up. Safe to call more than once.
  ///
  /// Deliberately does NOT ask for permission. The Android 13 dialog gets one
  /// chance in the life of an install, and spending it on a cold start — before
  /// the parent knows what this app is — is how an app ends up unable to report
  /// that a child never got off the bus.
  static Future<void> start() async {
    if (_started || appId.isEmpty) return;
    _started = true;
    try {
      if (kDebugMode) OneSignal.Debug.setLogLevel(OSLogLevel.error);
      OneSignal.initialize(appId);
    } catch (e) {
      // Push failing must never stop the app from starting. A parent who
      // cannot get notifications still needs to see whether their child is at
      // school.
      debugPrint('push: init failed: $e');
      _started = false;
    }
  }

  /// Tie this handset to a person, so the server can address them by our id.
  ///
  /// Also tells our own API that this person has a live install. The server
  /// needs that to pick free push over an SMS the school pays for; without it
  /// every parent quietly falls through to the paid channel.
  static Future<void> identify(String personId) async {
    if (!_started || personId.isEmpty) return;
    _personId = personId;
    try {
      await OneSignal.login(personId);
    } catch (e) {
      debugPrint('push: login failed: $e');
      return;
    }
    unawaited(_registerWhenSubscribed());
  }

  /// OneSignal assigns a subscription id asynchronously, and on a first launch
  /// it is not ready the moment login() returns. Rather than guess a delay,
  /// watch for it — and give up quietly if it never arrives, because a phone
  /// with notifications refused will never produce one and must not retry
  /// forever.
  static Future<void> _registerWhenSubscribed() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final id = subscriptionId;
      if (id != null) {
        if (id == _registered) return;

        // Re-issue the login now that a subscription exists.
        //
        // login() at sign-in runs BEFORE notification permission is granted, so
        // there is no push subscription yet to attach to the user. The one
        // created a moment later when permission is granted lands on the
        // anonymous user instead, and the server — which addresses everyone by
        // external id — gets "All included players are not subscribed" and the
        // parent is never told anything. Calling login() again once the
        // subscription is real is what binds the two.
        final person = _personId;
        if (person != null) {
          try {
            await OneSignal.login(person);
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

  /// Cut this handset loose on sign-out.
  ///
  /// Not optional: phones are shared here — one handset between two parents, or
  /// handed to an older child — and a device that stays subscribed after
  /// sign-out delivers one family's safety alerts to another family.
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
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('push: logout failed: $e');
    }
  }

  /// Whether the phone has already granted notification permission.
  static bool get granted {
    try {
      return OneSignal.Notifications.permission;
    } catch (_) {
      return false;
    }
  }

  /// Ask for permission, at a moment the parent can see why.
  ///
  /// Returns whether it was granted. On Android 12 and below there is no
  /// runtime permission and this returns true without showing anything.
  static Future<bool> askPermission() async {
    if (!_started) return false;
    try {
      final ok = await OneSignal.Notifications.requestPermission(true);
      // Granting is usually what finally produces a subscription id, so this
      // is the moment the registration that failed at sign-in can succeed.
      if (ok) unawaited(_registerWhenSubscribed());
      return ok;
    } catch (e) {
      debugPrint('push: permission request failed: $e');
      return false;
    }
  }

  /// The subscription id, once OneSignal has registered this handset.
  ///
  /// Only useful for diagnosis — "is this phone actually subscribed" is the
  /// first question when a parent says notifications are not arriving.
  static String? get subscriptionId {
    try {
      final id = OneSignal.User.pushSubscription.id;
      // A 'local-' prefix means the SDK has not completed registration yet.
      return (id == null || id.startsWith('local-')) ? null : id;
    } catch (_) {
      return null;
    }
  }
}
