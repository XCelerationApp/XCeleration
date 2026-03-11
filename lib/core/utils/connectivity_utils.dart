import 'package:connectivity_plus/connectivity_plus.dart';

/// Utility for checking network connectivity before making network requests.
class ConnectivityUtils {
  /// Returns `true` if the device has any active network connection
  /// (Wi-Fi, mobile, ethernet, etc.). Returns `false` if offline or if
  /// the connectivity check throws.
  static Future<bool> isOnline({Connectivity? connectivity}) async {
    try {
      final results =
          await (connectivity ?? Connectivity()).checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}
