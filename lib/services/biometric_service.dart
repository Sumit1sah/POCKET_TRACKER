import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps [LocalAuthentication] with app-specific defaults and error handling.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Returns true if the device hardware supports biometrics / device credentials
  /// (fingerprint, face, iris, or PIN/pattern/password fallback).
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Returns the list of enrolled biometrics (fingerprint, face, iris).
  static Future<List<BiometricType>> getEnrolledBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Prompt the user to authenticate.
  ///
  /// Returns `true` on success, `false` on failure or cancellation.
  /// Uses PIN/pattern/password as fallback automatically.
  static Future<bool> authenticate({
    String reason = 'Authenticate to access Pocketify',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,   // allow PIN/password fallback
          stickyAuth: true,       // keep prompt open if app goes background
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException catch (e) {
      // NotAvailable, NotEnrolled, LockedOut, etc. — all treated as failure
      // ignore: avoid_print
      print('[BiometricService] auth error: ${e.code} — ${e.message}');
      return false;
    }
  }
}
