import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_sync_service.dart';

/// Listens to connectivity and triggers sync on Wi‑Fi for spectator mode
class ConnectivitySyncService {
  final ISyncService _sync;
  final IAuthService _auth;

  ConnectivitySyncService({
    required ISyncService sync,
    required IAuthService auth,
  })  : _sync = sync,
        _auth = auth;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void start() {
    _sub ??= Connectivity().onConnectivityChanged.listen((results) async {
      // Wi‑Fi only
      if (_auth.isSignedIn && results.contains(ConnectivityResult.wifi)) {
        // We don't have global role state; just trigger sync when on Wi‑Fi.
        // Spectator push is a no-op; coach pushes will succeed too.
        try {
          await _sync.syncAll();
        } catch (_) {}
      }
    });

    // If the device is already on Wi‑Fi at launch, the listener won't fire.
    // Check current connectivity immediately and trigger sync if needed.
    _syncIfAlreadyOnWifi();
  }

  Future<void> _syncIfAlreadyOnWifi() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (_auth.isSignedIn && results.contains(ConnectivityResult.wifi)) {
        await _sync.syncAll();
      }
    } catch (_) {}
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
