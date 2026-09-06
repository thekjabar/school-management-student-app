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
  ///
  /// It being public is exactly why the external id below has to be PROVED
  /// rather than merely asserted. The app id is readable from all three APKs
  /// and a Person id is not secret either — it is in /auth/me and in every
  /// portal person listing — so for as long as `login()` was called with the id
  /// alone, anyone holding the two could register their own handset under a
  /// parent's alias and receive every push that parent receives: the boarded
  /// and set-down notices, naming the child, the stop and the minute.
  /// Uninstalling the app would not have revoked it and /push/devices would
  /// never have seen it.
  static const String appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'e884c0e5-93aa-482d-80b4-d9bed167a21c',
  );

  static bool _started = false;

  /// The person this handset is signed in as, kept so the OneSignal login can
  /// be re-issued once a subscription actually exists.
  static String? _personId;

  /// The server's proof that this handset really is that person.
  ///
  /// Minted per user by identity-service and handed down in the /auth/me
  /// payload; OneSignal Identity Verification checks it before it will attach a
  /// subscription to the external id. Held alongside [_personId] because the
  /// re-login below has to present it a second time.
  static String? _identityToken;

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
  ///
  /// [identityToken] is the per-user identity-verification token from
  /// /auth/me. WITHOUT IT NOTHING IS CLAIMED AT ALL. That is deliberate and it
  /// is the whole point of this change: an unverified `login()` is a claim the
  /// server never checks, so a stranger who knows a person id — which is not
  /// secret — could make the same claim from their own phone and start
  /// receiving that child's boarded and set-down notices. An app that receives
  /// no pushes is a support call; an app that lets a stranger receive a child's
  /// is the thing this platform exists to prevent. So a missing token is
  /// treated as "do not subscribe", not as "subscribe anyway".
  static Future<void> identify(String personId, {String? identityToken}) async {
    if (!_started || personId.isEmpty) return;

    if (identityToken == null || identityToken.isEmpty) {
      // Forgotten rather than kept, so nothing later in the launch — the
      // permission prompt, in particular — can re-issue a login on their
      // behalf.
      _personId = null;
      _identityToken = null;
      debugPrint(
        'push: /auth/me carried no identity token — this handset stays '
        'anonymous rather than claiming an external id it cannot prove',
      );
      return;
    }

    // `loginWithJWT` is the one call in this SDK that carries the proof, and it
    // reaches native code on ANDROID ONLY — on every other platform the Dart
    // side returns having done nothing at all. It is marked deprecated with
    // "not implemented" while OneSignal reworks Identity Verification, and it
    // is used here with that fully in view: the alternative is plain `login()`,
    // which is precisely the unverified claim this exists to remove.
    //
    // So off Android this handset stays anonymous, on the same reasoning as a
    // missing token above. That costs nothing today: the iOS target has no push
    // entitlement and no notification service extension, so it has never
    // received a notification. The day iOS is set up, this line is the one to
    // revisit — and it must be revisited by making verification work there, not
    // by dropping back to an unverified login.
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
      // ignore: deprecated_member_use
      await OneSignal.loginWithJWT(personId, identityToken);
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
    // Nobody is claimed, so there is nothing to attach a subscription to and
    // nothing to tell the API about. Reached from [askPermission], which runs
    // when the parent grants notifications and cannot know whether the login
    // above was declined for want of a token.
    //
    // Returning here rather than registering anyway is the point: POSTing to
    // /push/devices would tell the server this person has a live install, and
    // the server uses exactly that to choose free push over an SMS the school
    // pays for. An anonymous subscription registered under a person who is not
    // logged in would take the SMS away and put nothing in its place — the
    // parent would be told nothing at all, and no part of the system would
    // report a fault.
    if (_personId == null || _identityToken == null) return;

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
        final token = _identityToken;
        if (person != null && token != null) {
          try {
            // The same proof again, for the same reason as the first call: a
            // re-login without it would be an unverified claim, and OneSignal
            // with Identity Verification switched on would refuse it anyway.
            // ignore: deprecated_member_use
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
    // Goes with the person. A token left behind is a proof of an identity this
    // handset no longer holds, and phones are shared here.
    _identityToken = null;
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
