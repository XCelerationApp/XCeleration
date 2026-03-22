import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

/// A BibRecorder session discovered during the lobby browse phase.
class DiscoveredSession {
  const DiscoveredSession({required this.raceId, required this.hostName});

  final int raceId;

  /// Human-readable device hostname, suitable for display in the session list.
  final String hostName;
}

/// Browses for advertising BibRecorder sessions without establishing a
/// connection.
///
/// Used by [VerifierScreen] and [FixerScreen] during the lobby phase to
/// discover real race IDs before the user taps to join. Does NOT invite peers
/// — it is read-only discovery.
///
/// Call [start] once after construction. The [sessions] list is updated as
/// BibRecorders appear. Dispose to stop browsing.
class LobbyScanner extends ChangeNotifier {
  LobbyScanner({required this.localRole});

  final Role localRole;

  final List<DiscoveredSession> _sessions = [];

  NearbyService? _nearbyService;
  StreamSubscription? _stateSubscription;

  /// Currently discovered BibRecorder sessions.
  List<DiscoveredSession> get sessions => List.unmodifiable(_sessions);

  /// Starts passive browsing for BibRecorder advertisements.
  ///
  /// Advertises with [raceId] = 0 so the BibRecorder's [PeerDiscoveryNotifier]
  /// ignores this device (it filters by race ID). Only browses — never invites.
  Future<void> start() async {
    final service = NearbyService();
    _nearbyService = service;

    await service.init(
      serviceType: kXceServiceType,
      deviceName: 'xce|${_roleCode(localRole)}|0|${Platform.localHostname}',
      strategy: Strategy.P2P_CLUSTER,
      callback: (isRunning) async {
        if (isRunning == true) {
          // Browse only — suppress advertising to avoid confusing the BibRecorder.
          await service.stopAdvertisingPeer();
          await Future.delayed(const Duration(milliseconds: 200));
          await service.startBrowsingForPeers();
        }
      },
    );

    _stateSubscription = service.stateChangedSubscription(
      callback: _onStateChanged,
    );
  }

  void _onStateChanged(List<Device> devices) {
    bool changed = false;
    for (final device in devices) {
      final parsed = parseXceDeviceName(device.deviceName);
      if (parsed == null) continue;
      final (peerRole, peerRaceId, humanName) = parsed;
      // Only surface BibRecorder sessions; ignore raceId 0 (other scanners).
      if (peerRole != Role.bibRecorderV2 || peerRaceId == 0) continue;
      if (_sessions.any((s) => s.raceId == peerRaceId)) continue;
      _sessions.add(DiscoveredSession(raceId: peerRaceId, hostName: humanName));
      changed = true;
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _nearbyService?.stopBrowsingForPeers();
    super.dispose();
  }
}

String _roleCode(Role role) => switch (role) {
      Role.bibRecorderV2 => 'BIB',
      Role.verifier => 'VFR',
      Role.fixer => 'FIX',
      _ => 'UNK',
    };
