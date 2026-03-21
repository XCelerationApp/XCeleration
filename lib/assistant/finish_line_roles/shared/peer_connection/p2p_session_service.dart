import 'dart:async';
import 'dart:convert';

import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/core/utils/connection_interfaces.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

/// Prefix embedded in each device's advertised name so peers can identify
/// each other's [Role] without a secondary handshake.
///
/// Format: `xce-<roleName>` e.g. `xce-bibRecorderV2`
const _kDeviceNamePrefix = 'xce-';

/// Maximum number of messages buffered per peer while they are offline.
/// When this cap is reached the oldest message is evicted to make room.
const int _kQueueCap = 500;

/// Wraps [NearbyConnectionsInterface] and exposes typed [MessageEnvelope]
/// send/receive for the three finish-line roles.
///
/// Responsibilities:
/// - Initialises a single Nearby Connections instance scoped to the race via
///   `serviceType = 'xce-race-<raceId>'`.
/// - Advertises the local device's role via a name prefix so peers can
///   identify each other.
/// - Keeps `Role → deviceId` and `deviceId → Role` maps up-to-date as
///   devices connect and disconnect.
/// - Exposes [sendMessage] for typed outbound messages and [incomingMessages]
///   for typed inbound messages.
/// - Drops messages from unrecognised device IDs silently (defence against
///   misconfigured devices).
class P2PSessionService {
  P2PSessionService({
    required this.localRole,
    required this.raceId,
    required NearbyConnectionsInterface nearbyConnections,
  }) : _nearbyConnections = nearbyConnections;

  final Role localRole;
  final int raceId;
  final NearbyConnectionsInterface _nearbyConnections;

  // Role ↔ device-ID look-ups for currently connected peers.
  final Map<String, Role> _deviceIdToRole = {};
  final Map<Role, String> _roleToDeviceId = {};

  // Per-peer outbound queues for messages buffered while the peer is offline.
  final Map<Role, List<MessageEnvelope>> _outboundQueues = {};

  final StreamController<(Role, MessageEnvelope)> _incomingController =
      StreamController.broadcast();

  StreamSubscription<dynamic>? _stateSubscription;
  StreamSubscription<dynamic>? _dataSubscription;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Typed stream of messages received from peer devices.
  ///
  /// Each event is a `(Role sender, MessageEnvelope msg)` record.
  /// Messages from unrecognised device IDs are silently dropped.
  Stream<(Role, MessageEnvelope)> get incomingMessages =>
      _incomingController.stream;

  /// Initialises Nearby Connections, starts advertising and browsing, and
  /// wires up state-change and data-received subscriptions.
  ///
  /// Must be called once before [sendMessage] or [incomingMessages].
  Future<void> init() async {
    await _nearbyConnections.init(
      serviceType: 'xce-race-$raceId',
      deviceName: '$_kDeviceNamePrefix${localRole.name}',
      strategy: Strategy.P2P_CLUSTER,
      callback: (isRunning) async {
        if (isRunning != true) return;
        try {
          await _nearbyConnections.startAdvertisingPeer();
          await _nearbyConnections.startBrowsingForPeers();
        } catch (e) {
          Logger.e(
              '[P2PSessionService] Failed to start advertising/browsing: $e');
        }
      },
    );

    _stateSubscription = _nearbyConnections.stateChangedSubscription(
      callback: _onDevicesChanged,
    );

    _dataSubscription = _nearbyConnections.dataReceivedSubscription(
      callback: _onDataReceived,
    );
  }

  /// Serialises [msg] to JSON and sends it to the peer device running [target].
  ///
  /// If [target] is not currently connected the message is added to its
  /// outbound queue and will be flushed automatically when it reconnects.
  Future<void> sendMessage(Role target, MessageEnvelope msg) async {
    final deviceId = _roleToDeviceId[target];
    if (deviceId == null) {
      final queue = _outboundQueues.putIfAbsent(target, () => []);
      if (queue.length >= _kQueueCap) {
        queue.removeAt(0);
        Logger.d(
            '[P2PSessionService] Queue cap hit for $target — oldest message evicted.');
      }
      queue.add(msg);
      return;
    }
    try {
      final json = jsonEncode(msg.toJson());
      await _nearbyConnections.sendMessage(deviceId, json);
    } catch (e) {
      Logger.e('[P2PSessionService] sendMessage to $target failed: $e');
    }
  }

  /// Returns the number of messages currently buffered for [peer].
  ///
  /// Non-zero only when [peer] is offline.  Useful for showing a badge in the
  /// peer-status strip.
  int pendingCount(Role peer) => _outboundQueues[peer]?.length ?? 0;

  /// Stops advertising/browsing, cancels subscriptions, and closes the stream.
  Future<void> dispose() async {
    await _stateSubscription?.cancel();
    await _dataSubscription?.cancel();

    for (final deviceId in List.of(_roleToDeviceId.values)) {
      try {
        await _nearbyConnections.disconnectPeer(deviceID: deviceId);
      } catch (_) {}
    }

    try {
      await _nearbyConnections.stopAdvertisingPeer();
      await _nearbyConnections.stopBrowsingForPeers();
    } catch (_) {}

    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _onDevicesChanged(List<Device> devices) async {
    for (final device in devices) {
      final role = _roleFromDeviceName(device.deviceName);
      if (role == null || role == localRole) continue;

      switch (device.state) {
        case SessionState.connected:
          _deviceIdToRole[device.deviceId] = role;
          _roleToDeviceId[role] = device.deviceId;
          await _flushQueue(role);
        case SessionState.notConnected:
          // Device visible but not connected — auto-invite.
          try {
            await _nearbyConnections.invitePeer(
              deviceID: device.deviceId,
              deviceName: device.deviceName,
            );
          } catch (e) {
            Logger.e(
                '[P2PSessionService] invitePeer(${device.deviceId}) failed: $e');
          }
          // Clean up maps in case this device was previously connected.
          _deviceIdToRole.remove(device.deviceId);
          _roleToDeviceId.remove(role);
        case SessionState.connecting:
          // Transitioning — wait for connected or notConnected.
          break;
      }
    }
  }

  void _onDataReceived(dynamic data) {
    try {
      final map = (data as Map).cast<String, dynamic>();
      final senderDeviceId = map['senderDeviceId'] as String?;
      final message = map['message'] as String?;
      if (senderDeviceId == null || message == null) return;

      final senderRole = _deviceIdToRole[senderDeviceId];
      if (senderRole == null) {
        Logger.d(
            '[P2PSessionService] Dropping message from unknown device: $senderDeviceId');
        return;
      }

      final envelope = MessageEnvelope.fromJson(
        (jsonDecode(message) as Map).cast<String, dynamic>(),
      );
      _incomingController.add((senderRole, envelope));
    } catch (e) {
      Logger.d('[P2PSessionService] Failed to parse incoming message: $e');
    }
  }

  /// Drains the outbound queue for [role], sending each buffered message in
  /// FIFO order.  Assumes the peer is already registered in [_roleToDeviceId].
  Future<void> _flushQueue(Role role) async {
    final queue = _outboundQueues.remove(role);
    if (queue == null || queue.isEmpty) return;
    final deviceId = _roleToDeviceId[role]!;
    for (final msg in queue) {
      try {
        await _nearbyConnections.sendMessage(deviceId, jsonEncode(msg.toJson()));
      } catch (e) {
        Logger.e('[P2PSessionService] Flush sendMessage to $role failed: $e');
      }
    }
  }

  /// Extracts a [Role] from a device name formatted as `xce-<roleName>`.
  ///
  /// Returns `null` for device names that don't follow this format (e.g.
  /// devices from other apps or misconfigured peers).
  static Role? _roleFromDeviceName(String deviceName) {
    if (!deviceName.startsWith(_kDeviceNamePrefix)) return null;
    final roleName = deviceName.substring(_kDeviceNamePrefix.length);
    return switch (roleName) {
      'bibRecorderV2' => Role.bibRecorderV2,
      'verifier' => Role.verifier,
      'fixer' => Role.fixer,
      _ => null,
    };
  }
}
