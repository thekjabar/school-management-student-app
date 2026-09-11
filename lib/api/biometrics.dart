import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../i18n/strings.dart';

class Biometrics {
  Biometrics._();

  static final _auth = LocalAuthentication();

  static Future<bool> get available async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> confirm({required String reason}) async {
    try {
      if (!await _auth.isDeviceSupported()) return true;
      final enrolled = await _auth.getAvailableBiometrics();
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck && enrolled.isEmpty) return true;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
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

  static String get leaveReason => t('leave.confirmWithBiometrics');
}
