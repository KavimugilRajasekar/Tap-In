import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class FingerprintAuth {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if device supports biometric authentication
  static Future<bool> hasBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      print("Error checking biometrics: $e");
      return false;
    }
  }

  /// Gets list of available biometric types
  static Future<List<BiometricType>> getBiometricsTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print("Error getting biometrics types: $e");
      return <BiometricType>[];
    }
  }

  /// Authenticates user with biometrics
  static Future<bool> authenticate() async {
    try {
      bool isAuthenticated = false;

      // Check if device supports biometrics
      bool canCheckBiometrics = await hasBiometrics();
      if (!canCheckBiometrics) {
        print("Device doesn't support biometric authentication");
        return false;
      }

      // Get available biometric types
      List<BiometricType> availableBiometrics = await getBiometricsTypes();

      // Authenticate with biometrics
      isAuthenticated = await _auth.authenticate(
        localizedReason: 'Scan your fingerprint to authenticate',
        biometricOnly: true,
      );

      return isAuthenticated;
    } on PlatformException catch (e) {
      print("Authentication error: $e");
      return false;
    }
  }
}
