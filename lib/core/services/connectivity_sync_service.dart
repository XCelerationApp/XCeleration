import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_sync_service.dart';
import 'package:xceleration/core/utils/connectivity_utils.dart';

/// Listens to connectivity changes and local DB writes, triggering sync on
/// Wi‑Fi. A 2-second debounce prevents hammering the remote after rapid writes.
class ConnectivitySyncService {
  final ISyncService _sync;
  final IAuthService _auth;
  final Stream<void>? _writeStream;

  ConnectivitySyncService({
    required ISyncService sync,
    required IAuthService auth,
    Stream<void>? writeStream,
  })  : _sync = sync,
        _auth = auth,
        _writeStream = writeStream;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<void>? _writeSub;
  Timer? _debounceTimer;

  void start() {
    // Sync whenever the device connects to Wi‑Fi.
    _connectivitySub ??=
        Connectivity().onConnectivityChanged.listen((results) async {
      if (_auth.isSignedIn && results.contains(ConnectivityResult.wifi)) {
        try {
          await _sync.syncAll();
        } catch (_) {}
      }
    });

    // Debounce-sync after any local write (handles the "already on Wi-Fi" case).
    _writeSub ??= _writeStream?.listen((_) => _scheduleDebouncedSync());

    // If the device is already on Wi‑Fi at launch, the connectivity listener
    // won't fire — trigger an immediate sync.
    _syncIfOnWifi();
  }

  /// Debounce: wait 2 s after the last write before syncing, so rapid batched
  /// mutations (e.g. saving all race results) result in one round-trip.
  void _scheduleDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _syncIfOnWifi);
  }

  Future<void> _syncIfOnWifi() async {
    try {
      if (_auth.isSignedIn && await ConnectivityUtils.isOnline()) {
        await _sync.syncAll();
      }
    } catch (_) {}
  }

  void stop() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _writeSub?.cancel();
    _writeSub = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
