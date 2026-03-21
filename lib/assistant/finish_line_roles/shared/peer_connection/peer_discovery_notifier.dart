import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

// ── Direction ─────────────────────────────────────────────────────────────────

enum PeerDirection { push, receive }

extension PeerDirectionLabel on PeerDirection {
  String get label =>
      this == PeerDirection.push ? '↑ SENDING' : '↓ RECEIVING';
}

// ── Peer config ───────────────────────────────────────────────────────────────

class PeerConfig {
  const PeerConfig({
    required this.role,
    required this.label,
    required this.direction,
  });

  final Role role;
  final String label;
  final PeerDirection direction;
}

/// Which peers each finish-line role connects to, and the primary data-flow
/// direction for each link.
///
/// BibRecorderV2 → Verifier (sends entries)
/// Verifier      → Fixer    (sends flagged entries)
/// Fixer         → BibRecorderV2 (sends corrections)
const Map<Role, List<PeerConfig>> kPeerConfig = {
  Role.bibRecorderV2: [
    PeerConfig(
      role: Role.verifier,
      label: 'Verifier',
      direction: PeerDirection.push,
    ),
    PeerConfig(
      role: Role.fixer,
      label: 'Fixer',
      direction: PeerDirection.receive,
    ),
  ],
  Role.verifier: [
    PeerConfig(
      role: Role.bibRecorderV2,
      label: 'Bib Recorder',
      direction: PeerDirection.receive,
    ),
    PeerConfig(
      role: Role.fixer,
      label: 'Fixer',
      direction: PeerDirection.push,
    ),
  ],
  Role.fixer: [
    PeerConfig(
      role: Role.verifier,
      label: 'Verifier',
      direction: PeerDirection.receive,
    ),
    PeerConfig(
      role: Role.bibRecorderV2,
      label: 'Bib Recorder',
      direction: PeerDirection.push,
    ),
  ],
};

/// Stub device names shown during discovery simulation.
/// TODO(XCE-230): replace with real mDNS / Nearby Connections device names.
const Map<Role, String> kStubDeviceNames = {
  Role.verifier: "Alex's iPhone",
  Role.bibRecorderV2: 'Coach iPad',
  Role.fixer: "Sam's iPhone",
};

// ── Status ────────────────────────────────────────────────────────────────────

enum PeerStatus { searching, found, connected, offline }

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Simulates local-network peer discovery using the shared race ID.
///
/// In production: replace the [Timer] logic with real mDNS / Nearby
/// Connections / WebSocket signalling. The [ChangeNotifier] API stays the same.
class PeerDiscoveryNotifier extends ChangeNotifier {
  PeerDiscoveryNotifier({required this.role, required this.raceId}) {
    for (final p in (kPeerConfig[role] ?? [])) {
      _statuses[p.role] = PeerStatus.searching;
    }
  }

  final Role role;
  final int raceId;

  final Map<Role, PeerStatus> _statuses = {};
  final List<Timer> _timers = [];

  PeerStatus statusFor(Role peerRole) =>
      _statuses[peerRole] ?? PeerStatus.searching;

  int get connectedCount =>
      _statuses.values.where((s) => s == PeerStatus.connected).length;

  bool get allConnected =>
      connectedCount == (kPeerConfig[role]?.length ?? 0);

  bool get anyConnected => connectedCount > 0;

  /// Starts simulated discovery. Call once after construction.
  void startDiscovery() {
    final peers = kPeerConfig[role] ?? [];
    final rng = Random();
    for (int i = 0; i < peers.length; i++) {
      final peerRole = peers[i].role;
      final foundMs = 1200 + i * 900 + rng.nextInt(600);
      final connMs = foundMs + 400;

      _timers.add(Timer(Duration(milliseconds: foundMs), () {
        _statuses[peerRole] = PeerStatus.found;
        notifyListeners();
      }));
      _timers.add(Timer(Duration(milliseconds: connMs), () {
        _statuses[peerRole] = PeerStatus.connected;
        notifyListeners();
      }));
    }
  }

  /// Call when a peer's network address disappears.
  void markOffline(Role peerRole) {
    _statuses[peerRole] = PeerStatus.offline;
    notifyListeners();
  }

  /// Call when a peer reconnects.
  void markConnected(Role peerRole) {
    _statuses[peerRole] = PeerStatus.connected;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }
}
