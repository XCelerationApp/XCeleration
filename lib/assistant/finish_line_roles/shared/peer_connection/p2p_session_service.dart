import 'dart:async';
import 'dart:convert';

import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/xce_peer_name.dart';
import 'package:xceleration/core/utils/connection_interfaces.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

/// A connection state transition for a single peer, emitted by [P2PSessionService].
///
/// [role] identifies the peer. [state] is the raw Nearby Connections session
/// state. [deviceName] is the human-readable hostname from the structured
/// advertised name (`xce|ROLE|RACE|HOSTNAME`).
class PeerStateEvent {
  const PeerStateEvent({
    required this.role,
    required this.state,
    required this.deviceName,
  });

  final Role role;
  final SessionState state;
  final String deviceName;
}

/// Maximum number of messages buffered per peer while they are offline.
/// When this cap is reached the oldest message is evicted to make room.
const int _kQueueCap = 500;

/// Maximum number of sequence numbers retained in the seen-sequence set per
/// sender.  Older entries are evicted once this cap is reached.
const int _kSeenSequenceCap = 1000;

/// Wraps [NearbyConnectionsInterface] and exposes typed [MessageEnvelope]
/// send/receive for the three finish-line roles.
///
/// Responsibilities:
/// - Initialises a single Nearby Connections instance using the fixed service
///   type `xce-finline` (declared in iOS Info.plist) and the structured device
///   name `xce|ROLE|RACE_ID|HOSTNAME` so peers can identify each other and
///   filter by race without a secondary handshake.
/// - Keeps `Role → deviceId` and `deviceId → Role` maps up-to-date as
///   devices connect and disconnect.
/// - Exposes [sendMessage] for typed outbound messages and [incomingMessages]
///   for typed inbound messages.
/// - Stamps every outbound message with a monotonic sequence number and
///   tracks un-ACKed messages in [_pendingAck]. On disconnect the pending
///   messages are re-queued in front of the offline queue so they are
///   re-delivered in order on reconnect.
/// - Receiver side deduplicates re-delivered messages using the sequence
///   number and sends a lightweight ACK after each processed message.
/// - Drops messages from unrecognised device IDs silently (defence against
///   misconfigured devices).
/// - Emits [peerStateEvents] so subscribers (e.g. [PeerDiscoveryNotifier])
///   can derive UI connection state without running a second NC session.
class P2PSessionService {
  P2PSessionService({
    required this.localRole,
    required this.raceId,
    required NearbyConnectionsInterface nearbyConnections,
    required SharedPreferences prefs,
  })  : _nearbyConnections = nearbyConnections,
        _prefs = prefs;

  final Role localRole;
  final int raceId;
  final NearbyConnectionsInterface _nearbyConnections;
  final SharedPreferences _prefs;

  String get _sequenceKey => 'p2p_seq_${raceId}_${localRole.name}';

  // Role ↔ device-ID look-ups for currently connected peers.
  final Map<String, Role> _deviceIdToRole = {};
  final Map<Role, String> _roleToDeviceId = {};

  // Per-peer outbound queues for messages buffered while the peer is offline.
  final Map<Role, List<MessageEnvelope>> _outboundQueues = {};

  // Messages sent but not yet ACKed, keyed by target role then sequence number.
  final Map<Role, Map<int, MessageEnvelope>> _pendingAck = {};

  // Sequence numbers seen from each sender role, for deduplication.
  // Bounded to [_kSeenSequenceCap] entries per sender to prevent unbounded growth.
  final Map<Role, Set<int>> _seenSequences = {};

  // Monotonically increasing counter — assigned at sendMessage time.
  int _nextSequence = 0;

  final StreamController<(Role, MessageEnvelope)> _incomingController =
      StreamController.broadcast();

  // sync: true so that add() delivers events synchronously to listeners,
  // ensuring PeerDiscoveryNotifier sees state changes immediately.
  final StreamController<PeerStateEvent> _peerEventsController =
      StreamController.broadcast(sync: true);

  StreamSubscription<dynamic>? _stateSubscription;
  StreamSubscription<dynamic>? _dataSubscription;

  // Guard against re-entrant init callback — see [init].
  bool _discoveryStarted = false;

  // Debounce timers for invitePeer, keyed by device ID.  Prevents rapid-fire
  // invitations when the native layer emits multiple notConnected events in a
  // burst (e.g. after a "Connection invalid" error), which would otherwise
  // cause a connect → disconnect → connect loop that takes 10-15 s to settle.
  final Map<String, Timer> _inviteTimers = {};
  static const Duration _inviteDebounce = Duration(seconds: 2);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Typed stream of messages received from peer devices.
  ///
  /// Each event is a `(Role sender, MessageEnvelope msg)` record.
  /// Messages from unrecognised device IDs are silently dropped.
  /// ACK envelopes are never emitted here — they are handled internally.
  Stream<(Role, MessageEnvelope)> get incomingMessages =>
      _incomingController.stream;

  /// Stream of raw peer connection state changes.
  ///
  /// Emitted for every [SessionState] transition on a peer whose device name
  /// matches the XCeleration format and shares the same [raceId]. Subscribers
  /// such as [PeerDiscoveryNotifier] use this to derive UI connection state
  /// without running a second Nearby Connections session.
  Stream<PeerStateEvent> get peerStateEvents => _peerEventsController.stream;

  /// Initialises Nearby Connections, starts advertising and browsing, and
  /// wires up state-change and data-received subscriptions.
  ///
  /// Uses the fixed service type `xce-finline` (declared in iOS Info.plist)
  /// and the structured device name `xce|ROLE|RACE_ID|HOSTNAME` so that all
  /// finish-line roles share one NC session per race.
  ///
  /// Must be called once before [sendMessage] or [incomingMessages].
  Future<void> init() async {
    _nextSequence = _prefs.getInt(_sequenceKey) ?? 0;

    await _nearbyConnections.init(
      serviceType: kXceServiceType,
      deviceName: buildXceAdvertisedName(localRole, raceId),
      strategy: Strategy.P2P_CLUSTER,
      callback: (isRunning) async {
        if (isRunning != true) return;
        if (_discoveryStarted) return;
        _discoveryStarted = true;
        try {
          await _nearbyConnections.startAdvertisingPeer();
          await _nearbyConnections.startBrowsingForPeers();
        } catch (e) {
          _discoveryStarted = false;
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

  /// Serialises [msg] to JSON, stamps a sequence number, and sends it to the
  /// peer device running [target].
  ///
  /// If [target] is currently connected the message is sent immediately and
  /// tracked in the pending-ACK map until the peer acknowledges receipt.
  /// If [target] is not connected the stamped message is added to its outbound
  /// queue and will be flushed automatically when it reconnects.
  Future<void> sendMessage(Role target, MessageEnvelope msg) async {
    final stamped = msg.withSequence(_nextSequence++);
    _prefs.setInt(_sequenceKey, _nextSequence).ignore();
    final deviceId = _roleToDeviceId[target];
    if (deviceId == null) {
      final queue = _outboundQueues.putIfAbsent(target, () => []);
      if (queue.length >= _kQueueCap) {
        queue.removeAt(0);
        Logger.d(
            '[P2PSessionService] Queue cap hit for $target — oldest message evicted.');
      }
      queue.add(stamped);
      return;
    }
    try {
      final json = jsonEncode(stamped.toJson());
      await _nearbyConnections.sendMessage(deviceId, json);
      final ack = _pendingAck.putIfAbsent(target, () => {});
      ack[stamped.sequence!] = stamped;
      // Cap pending-ACK map to prevent unbounded growth if peer never ACKs.
      if (ack.length > _kQueueCap) {
        ack.remove(ack.keys.first);
      }
    } catch (e) {
      Logger.e('[P2PSessionService] sendMessage to $target failed: $e');
      // Re-queue the message for retry on next flush.
      final queue = _outboundQueues.putIfAbsent(target, () => []);
      if (queue.length < _kQueueCap) {
        queue.add(stamped);
      }
    }
  }

  /// Returns the number of messages currently buffered in the offline queue
  /// for [peer].
  ///
  /// Non-zero only when [peer] is offline.  Useful for showing a badge in the
  /// peer-status strip.
  int pendingCount(Role peer) => _outboundQueues[peer]?.length ?? 0;

  /// Removes the persisted sequence number for this race + role from storage.
  ///
  /// Call this when a race ends or is deleted so that stale counters do not
  /// accumulate in SharedPreferences.
  Future<void> clearPersistedSequence() async {
    await _prefs.remove(_sequenceKey);
  }

  /// Stops advertising/browsing, cancels subscriptions, and closes the streams.
  Future<void> dispose() async {
    for (final timer in _inviteTimers.values) {
      timer.cancel();
    }
    _inviteTimers.clear();
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
    if (!_peerEventsController.isClosed) {
      await _peerEventsController.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _onDevicesChanged(List<Device> devices) async {
    for (final device in devices) {
      final parsed = parseXceDeviceName(device.deviceName);
      if (parsed == null) continue;
      final (role, peerRaceId, humanName) = parsed;
      if (peerRaceId != raceId) continue;
      if (role == localRole) continue;

      switch (device.state) {
        case SessionState.connected:
          _inviteTimers.remove(device.deviceId)?.cancel();
          // Clean up stale device ID if the role reconnected with a new one.
          final oldDeviceId = _roleToDeviceId[role];
          if (oldDeviceId != null && oldDeviceId != device.deviceId) {
            _deviceIdToRole.remove(oldDeviceId);
          }
          _deviceIdToRole[device.deviceId] = role;
          _roleToDeviceId[role] = device.deviceId;
          _peerEventsController.add(
            PeerStateEvent(
                role: role, state: SessionState.connected, deviceName: humanName),
          );
          await _flushQueue(role);
        case SessionState.notConnected:
          // Re-queue any un-ACKed messages before the device goes offline so
          // they are re-delivered in order on the next reconnect.
          _requeuePending(role);
          // Device visible but not connected — debounce the auto-invite so
          // rapid-fire notConnected events from the native layer don't spawn
          // competing invitations that prevent the connection from stabilising.
          _scheduleInvite(device.deviceId, device.deviceName);
          _peerEventsController.add(
            PeerStateEvent(
                role: role,
                state: SessionState.notConnected,
                deviceName: humanName),
          );
          // Clean up maps in case this device was previously connected.
          _deviceIdToRole.remove(device.deviceId);
          _roleToDeviceId.remove(role);
        case SessionState.connecting:
          _peerEventsController.add(
            PeerStateEvent(
                role: role,
                state: SessionState.connecting,
                deviceName: humanName),
          );
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

      // ACKs are transport-level — remove from pending and do not forward.
      if (envelope.type == MessageType.ack) {
        final seq = envelope.sequence;
        if (seq != null) _pendingAck[senderRole]?.remove(seq);
        return;
      }

      final seq = envelope.sequence;
      if (seq != null) {
        final seen = _seenSequences.putIfAbsent(senderRole, () => {});
        if (seen.contains(seq)) {
          // Duplicate re-delivery — acknowledge again and drop.
          unawaited(_sendAck(senderDeviceId, seq));
          return;
        }
        seen.add(seq);
        // Evict the oldest (first) entry once the cap is reached.
        if (seen.length > _kSeenSequenceCap) {
          seen.remove(seen.first);
        }
        unawaited(_sendAck(senderDeviceId, seq));
      }

      _incomingController.add((senderRole, envelope));
    } catch (e) {
      Logger.d('[P2PSessionService] Failed to parse incoming message: $e');
    }
  }

  /// Sends a lightweight ACK back to [deviceId] confirming [sequence].
  Future<void> _sendAck(String deviceId, int sequence) async {
    try {
      final ack = MessageEnvelope.wrapAck(sequence);
      await _nearbyConnections.sendMessage(deviceId, jsonEncode(ack.toJson()));
    } catch (e) {
      Logger.e('[P2PSessionService] Failed to send ACK for seq $sequence: $e');
    }
  }

  /// Schedules an [invitePeer] call for [deviceId] after [_inviteDebounce].
  ///
  /// If a timer is already running for this device it is cancelled and
  /// restarted, so only the last notConnected event in a burst actually
  /// triggers the invitation.  This prevents the rapid-fire invite loop
  /// observed when the native Multipeer Connectivity layer drops and
  /// re-discovers the peer repeatedly.
  void _scheduleInvite(String deviceId, String deviceName) {
    _inviteTimers[deviceId]?.cancel();
    _inviteTimers[deviceId] = Timer(_inviteDebounce, () async {
      _inviteTimers.remove(deviceId);
      try {
        await _nearbyConnections.invitePeer(
          deviceID: deviceId,
          deviceName: deviceName,
        );
      } catch (e) {
        Logger.e('[P2PSessionService] invitePeer($deviceId) failed: $e');
      }
    });
  }

  /// Drains the outbound queue for [role], sending each buffered message in
  /// FIFO order.  Assumes the peer is already registered in [_roleToDeviceId].
  ///
  /// All messages are registered in [_pendingAck] before any send is attempted.
  /// If a send fails mid-flush, the remaining unsent messages are already in
  /// [_pendingAck] and will be re-queued by [_requeuePending] when the peer's
  /// next disconnect event fires — preventing permanent message loss.
  Future<void> _flushQueue(Role role) async {
    final queue = _outboundQueues.remove(role);
    if (queue == null || queue.isEmpty) return;

    // Pre-register every message so none are lost if the peer drops mid-flush.
    final ackMap = _pendingAck.putIfAbsent(role, () => {});
    for (final msg in queue) {
      ackMap[msg.sequence!] = msg;
    }

    final deviceId = _roleToDeviceId[role];
    if (deviceId == null) {
      // Peer disconnected between the connected event and the flush — move
      // the pre-registered messages back to the outbound queue so they are
      // re-delivered on the next reconnect.
      _requeuePending(role);
      return;
    }
    for (final msg in queue) {
      try {
        await _nearbyConnections.sendMessage(deviceId, jsonEncode(msg.toJson()));
      } catch (e) {
        Logger.e('[P2PSessionService] Flush sendMessage to $role failed: $e');
        // Remaining messages are already in _pendingAck; _requeuePending will
        // move them back to the offline queue on the next disconnect event.
        return;
      }
    }
  }

  /// Moves all un-ACKed messages for [role] back to the front of the offline
  /// queue in ascending sequence order, so they are re-delivered before any
  /// newer messages on the next reconnect.
  void _requeuePending(Role role) {
    final pending = _pendingAck.remove(role);
    if (pending == null || pending.isEmpty) return;
    final sorted = pending.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final existing = _outboundQueues.remove(role) ?? [];
    _outboundQueues[role] = [
      ...sorted.map((e) => e.value),
      ...existing,
    ];
  }
}

