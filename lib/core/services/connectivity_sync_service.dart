import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:xceleration/core/services/sync_service.dart';
import 'package:xceleration/core/services/auth_service.dart';

/// Listens to connectivity and triggers sync on Wi‑Fi for spectator mode
class ConnectivitySyncService {
  ConnectivitySyncService._();
  static final ConnectivitySyncService instance = ConnectivitySyncService._();

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void start() {
    _sub ??= Connectivity().onConnectivityChanged.listen((results) async {
      // Wi‑Fi only
      if (AuthService.instance.isSignedIn &&
          results.contains(ConnectivityResult.wifi)) {
        // We don't have global role state; just trigger sync when on Wi‑Fi.
        // Spectator push is a no-op; coach pushes will succeed too.
        try {
          await SyncService.instance.syncAll();
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
      if (AuthService.instance.isSignedIn &&
          results.contains(ConnectivityResult.wifi)) {
        await SyncService.instance.syncAll();
      }
    } catch (_) {}
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
