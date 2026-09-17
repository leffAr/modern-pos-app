import 'dart:async';
import 'package:flutter/foundation.dart';
// Note: Requires `local_auth` package to be added in pubspec.yaml if actually implemented
// import 'package:local_auth/local_auth.dart';

class SecurityService {
  Timer? _autoLogoutTimer;
  final Duration _timeoutDuration = const Duration(minutes: 30); // Auto logout setelah 30 menit inaktif

  /// Mulai timer auto-logout
  void startAutoLogoutTimer({required VoidCallback onTimeout}) {
    _autoLogoutTimer?.cancel();
    _autoLogoutTimer = Timer(_timeoutDuration, onTimeout);
    if (kDebugMode) {
      print('Auto-logout timer started for 30 minutes.');
    }
  }

  /// Panggil fungsi ini setiap kali ada interaksi pengguna (tap di layar)
  void userActivityDetected({required VoidCallback onTimeout}) {
    startAutoLogoutTimer(onTimeout: onTimeout);
  }

  void cancelAutoLogout() {
    _autoLogoutTimer?.cancel();
  }

  /// Cek dukungan biometrik (Fingerprint/FaceID)
  Future<bool> checkBiometricSupport() async {
    // final LocalAuthentication auth = LocalAuthentication();
    // return await auth.canCheckBiometrics || await auth.isDeviceSupported();
    return true; // Dummy implementation
  }

  /// Minta otentikasi biometrik
  Future<bool> authenticateWithBiometrics() async {
    // final LocalAuthentication auth = LocalAuthentication();
    // try {
    //   return await auth.authenticate(
    //     localizedReason: 'Gunakan sidik jari untuk login kasir',
    //     options: const AuthenticationOptions(stickyAuth: true),
    //   );
    // } catch (e) {
    //   print(e);
    //   return false;
    // }
    return true; // Dummy implementation
  }
}
