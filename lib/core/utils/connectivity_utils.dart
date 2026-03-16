import 'dart:io';

/// Utility for checking network connectivity before making network requests.
class ConnectivityUtils {
  /// Returns `true` if the device can reach the internet by performing a
  /// DNS lookup. More reliable than `connectivity_plus` on real devices,
  /// which only checks network interface state and can return false negatives
  /// on mobile data or certain Wi-Fi configurations.
  ///
  /// [lookupFn] can be injected in tests to avoid real network I/O.
  static Future<bool> isOnline({
    Future<List<InternetAddress>> Function(String)? lookupFn,
  }) async {
    try {
      final lookup = lookupFn ?? InternetAddress.lookup;
      final result = await lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
