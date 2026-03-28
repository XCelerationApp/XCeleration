import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
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

// ── Status ────────────────────────────────────────────────────────────────────

enum PeerStatus { searching, found, connected, offline }

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Adapts [P2PSessionService] peer connection events into [PeerStatus] UI state.
///
/// Subscribes to [P2PSessionService.peerStateEvents] rather than running its
/// own Nearby Connections session, ensuring the "connected" status shown in
/// [ConnectionSetupScreen] and [PeerStatusStrip] reflects whether P2P messages
/// can actually flow — not a parallel discovery session.
///
/// The [ChangeNotifier] API (statusFor, deviceNameFor, etc.) is unchanged from
/// the previous implementation so existing callers require no updates.
class PeerDiscoveryNotifier extends ChangeNotifier {
  PeerDiscoveryNotifier({
    required this.role,
    required this.raceId,
    required P2PSessionService session,
  }) {
    for (final p in (kPeerConfig[role] ?? [])) {
      _statuses[p.role] = PeerStatus.searching;
    }
    _sub = session.peerStateEvents.listen(_onPeerStateEvent);
  }

  final Role role;
  final int raceId;

  final Map<Role, PeerStatus> _statuses = {};

  /// Real device hostnames keyed by peer role, populated once a peer is found.
  final Map<Role, String> _deviceNames = {};

  StreamSubscription<PeerStateEvent>? _sub;

  PeerStatus statusFor(Role peerRole) =>
      _statuses[peerRole] ?? PeerStatus.searching;

  /// Returns the real device hostname for [peerRole], or null if not yet found.
  String? deviceNameFor(Role peerRole) => _deviceNames[peerRole];

  int get connectedCount =>
      _statuses.values.where((s) => s == PeerStatus.connected).length;

  bool get allConnected =>
      connectedCount == (kPeerConfig[role]?.length ?? 0);

  bool get anyConnected => connectedCount > 0;

  void _onPeerStateEvent(PeerStateEvent event) {
    final expectedRoles =
        (kPeerConfig[role] ?? []).map((p) => p.role).toSet();
    if (!expectedRoles.contains(event.role)) return;

    final prev = _statuses[event.role];
    bool changed = false;

    switch (event.state) {
      case SessionState.notConnected:
        if (prev == PeerStatus.connected || prev == PeerStatus.found) {
          // Peer was known — it has gone offline.
          _statuses[event.role] = PeerStatus.offline;
          changed = true;
        } else {
          // First contact — mark as found (P2PSessionService handles inviting).
          _statuses[event.role] = PeerStatus.found;
          _deviceNames[event.role] = event.deviceName;
          changed = true;
        }
      case SessionState.connecting:
        if (prev != PeerStatus.found && prev != PeerStatus.connected) {
          _statuses[event.role] = PeerStatus.found;
          _deviceNames[event.role] = event.deviceName;
          changed = true;
        }
      case SessionState.connected:
        if (prev != PeerStatus.connected) {
          _statuses[event.role] = PeerStatus.connected;
          _deviceNames[event.role] = event.deviceName;
          changed = true;
        }
    }

    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
