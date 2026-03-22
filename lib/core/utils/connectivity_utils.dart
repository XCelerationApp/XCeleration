import 'package:connectivity_plus/connectivity_plus.dart';

/// Utility for checking network connectivity before making network requests.
class ConnectivityUtils {
  /// Returns `true` if the device has any active network connection
  /// (Wi-Fi, mobile, ethernet, etc.). Returns `false` if offline or if
  /// the connectivity check throws.
  ///
  /// Note: `connectivity_plus` checks network interface state and may produce
  /// false negatives on mobile data or certain Wi-Fi configurations where an
  /// interface is up but has no real internet access. If that proves to be a
  /// problem, an alternative is to perform a DNS lookup via
  /// `InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5))`
  /// and return `true` only when the result is non-empty.
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