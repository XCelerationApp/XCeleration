import 'package:xceleration/core/utils/connectivity_utils.dart';

/// Service for checking network connectivity.
///
/// Inject this into classes that need connectivity checks so the check
/// can be replaced with a mock in tests.
class ConnectivityService {
  const ConnectivityService();

  /// Returns true if the device has an active network connection.
  Future<bool> isOnline() => ConnectivityUtils.isOnline();
}
