import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../i18n/strings.dart';

/// The phone's own fingerprint or face check.
///
/// Used before an action taken ON a child's behalf that the school will act on
/// — a leave request removes a child from the register and stops the bus
/// waiting for them. A handset left unlocked on a kitchen table should not be
/// able to do that.
///
/// It is a confirmation, not an authentication: the session is already signed
/// in and the server has already decided who this guardian is. So a phone with
/// no biometrics enrolled is allowed through rather than locked out — refusing
/// would mean a parent with an older handset simply cannot ask for a day off.
class Biometrics {
  Biometrics._();

  static final _auth = LocalAuthentication();

  /// Whether this handset can actually ask.
  static Future<bool> get available async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Ask, and say whether to go ahead.
  ///
  /// Returns true when the person confirmed, and also when the handset has
  /// nothing to confirm with. Returns false only when somebody was asked and
  /// failed or cancelled.
  static Future<bool> confirm({required String reason}) async {
    try {
      if (!await _auth.isDeviceSupported()) return true;
      final enrolled = await _auth.getAvailableBiometrics();
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck && enrolled.isEmpty) return true;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // The device PIN or pattern is a valid answer. A parent whose finger
          // is wet, or who is wearing gloves in January, still needs to be able
          // to send the request.
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      // A handset with no hardware, no enrolment, or a temporarily locked
      // sensor must not become a handset that cannot ask for leave.
      const passable = {
        'NotAvailable',
        'NotEnrolled',
        'PasscodeNotSet',
        'no_fragment_activity',
      };
      if (passable.contains(e.code)) return true;
      return false;
    }
  }

  /// What to put on the prompt.
  static String get leaveReason => t('leave.confirmWithBiometrics');
}
