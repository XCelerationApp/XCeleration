import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
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

// ── Service type ──────────────────────────────────────────────────────────────

/// Fixed Bonjour service type (≤ 15 chars) declared in ios/Runner/Info.plist
/// under NSBonjourServices as `_xce-finline._tcp`.
const _kServiceType = 'xce-finline';

// ── Role encoding ─────────────────────────────────────────────────────────────

String _roleCode(Role role) => switch (role) {
      Role.bibRecorderV2 => 'BIB',
      Role.verifier => 'VFR',
      Role.fixer => 'FIX',
      _ => 'UNK',
    };

Role? _roleFromCode(String code) => switch (code) {
      'BIB' => Role.bibRecorderV2,
      'VFR' => Role.verifier,
      'FIX' => Role.fixer,
      _ => null,
    };

/// Builds the advertised device name, encoding role and race ID so peers can
/// identify each other without an extra handshake message.
///
/// Format: `xce|<ROLE_CODE>|<RACE_ID>|<HOSTNAME>`
String _buildAdvertisedName(Role role, int raceId) =>
    'xce|${_roleCode(role)}|$raceId|${Platform.localHostname}';

/// Parses a device name built by [_buildAdvertisedName].
/// Returns `(role, raceId, humanName)` or `null` for non-XCeleration devices.
(Role, int, String)? _parseDeviceName(String deviceName) {
  final parts = deviceName.split('|');
  if (parts.length < 4 || parts[0] != 'xce') return null;
  final peerRole = _roleFromCode(parts[1]);
  if (peerRole == null) return null;
  final peerRaceId = int.tryParse(parts[2]);
  if (peerRaceId == null) return null;
  // Rejoin remaining parts in case the hostname itself contains '|'.
  final humanName = parts.sublist(3).join('|');
  return (peerRole, peerRaceId, humanName);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Discovers nearby finish-line peers using [flutter_nearby_connections].
///
/// Call [startDiscovery] once after construction. The notifier advertises this
/// device's role and race ID, browses for peers sharing the same race ID, and
/// auto-invites them on first contact.
///
/// The [ChangeNotifier] API (statusFor, deviceNameFor, etc.) is unchanged from
/// the stub so existing callers require no updates.
class PeerDiscoveryNotifier extends ChangeNotifier {
  PeerDiscoveryNotifier({required this.role, required this.raceId}) {
    for (final p in (kPeerConfig[role] ?? [])) {
      _statuses[p.role] = PeerStatus.searching;
    }
  }

  final Role role;
  final int raceId;

  final Map<Role, PeerStatus> _statuses = {};

  /// Real device hostnames keyed by peer role, populated once a peer is found.
  final Map<Role, String> _deviceNames = {};

  /// NearbyService device IDs keyed by peer role, used for disconnect on dispose.
  final Map<Role, String> _deviceIds = {};

  NearbyService? _nearbyService;
  StreamSubscription? _stateSubscription;

  PeerStatus statusFor(Role peerRole) =>
      _statuses[peerRole] ?? PeerStatus.searching;

  /// Returns the real device hostname for [peerRole], or null if not yet found.
  String? deviceNameFor(Role peerRole) => _deviceNames[peerRole];

  int get connectedCount =>
      _statuses.values.where((s) => s == PeerStatus.connected).length;

  bool get allConnected =>
      connectedCount == (kPeerConfig[role]?.length ?? 0);

  bool get anyConnected => connectedCount > 0;

  /// Starts real peer discovery. Call once after construction.
  ///
  /// Advertises this device's role and race ID over [_kServiceType] (Bonjour /
  /// Nearby Connections), then browses for peer devices. Discovered peers with
  /// a matching race ID are auto-invited; state changes are mapped to
  /// [PeerStatus] and broadcast via [notifyListeners].
  Future<void> startDiscovery() async {
    final service = NearbyService();
    _nearbyService = service;

    await service.init(
      serviceType: _kServiceType,
      deviceName: _buildAdvertisedName(role, raceId),
      strategy: Strategy.P2P_CLUSTER,
      callback: (isRunning) async {
        if (isRunning == true) {
          await service.stopAdvertisingPeer();
          await service.stopBrowsingForPeers();
          await Future.delayed(const Duration(milliseconds: 200));
          await service.startAdvertisingPeer();
          await service.startBrowsingForPeers();
        }
      },
    );

    _stateSubscription = service.stateChangedSubscription(
      callback: _onStateChanged,
    );
  }

  void _onStateChanged(List<Device> devices) {
    final expectedRoles =
        (kPeerConfig[role] ?? []).map((p) => p.role).toSet();
    bool changed = false;

    for (final device in devices) {
      final parsed = _parseDeviceName(device.deviceName);
      if (parsed == null) continue;
      final (peerRole, peerRaceId, humanName) = parsed;
      if (peerRaceId != raceId) continue;
      if (!expectedRoles.contains(peerRole)) continue;

      final prev = _statuses[peerRole];

      switch (device.state) {
        case SessionState.notConnected:
          if (prev == PeerStatus.connected || prev == PeerStatus.found) {
            // Peer was known — it has gone offline.
            _statuses[peerRole] = PeerStatus.offline;
            changed = true;
          } else {
            // First contact — auto-invite and mark as found.
            _nearbyService?.invitePeer(
              deviceID: device.deviceId,
              deviceName: device.deviceName,
            );
            _statuses[peerRole] = PeerStatus.found;
            _deviceNames[peerRole] = humanName;
            _deviceIds[peerRole] = device.deviceId;
            changed = true;
          }
        case SessionState.connecting:
          if (prev != PeerStatus.found && prev != PeerStatus.connected) {
            _statuses[peerRole] = PeerStatus.found;
            _deviceNames[peerRole] = humanName;
            _deviceIds[peerRole] = device.deviceId;
            changed = true;
          }
        case SessionState.connected:
          if (prev != PeerStatus.connected) {
            _statuses[peerRole] = PeerStatus.connected;
            _deviceNames[peerRole] = humanName;
            _deviceIds[peerRole] = device.deviceId;
            changed = true;
          }
      }
    }

    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _nearbyService?.stopAdvertisingPeer();
    _nearbyService?.stopBrowsingForPeers();
    for (final deviceId in _deviceIds.values) {
      _nearbyService?.disconnectPeer(deviceID: deviceId);
    }
    super.dispose();
  }
}
