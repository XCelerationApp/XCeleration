import 'dart:async';
import 'dart:convert';

import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_outbox.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/xce_peer_name.dart';
import 'package:xceleration/core/utils/connection_interfaces.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

/// A connection state transition for a single peer, emitted by [P2PSessionService].
///
/// [role] identifies the peer. [state] is the raw Nearby Connections session
/// state. [deviceName] is the human-readable hostname from the structured
/// advertised name (`xce|ROLE|RACE_KEY|HOSTNAME`).
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

/// Maximum number of sequence numbers retained in the seen-sequence set per
/// sender.  Older entries are evicted once this cap is reached.
const int _kSeenSequenceCap = 1000;

/// Wraps [NearbyConnectionsInterface] and exposes typed [MessageEnvelope]
/// send/receive for the three finish-line roles.
///
/// Responsibilities:
/// - Initialises a single Nearby Connections instance using the fixed service
///   type `xce-finline` (declared in iOS Info.plist) and the structured device
///   name `xce|ROLE|RACE_KEY|HOSTNAME` so peers can identify each other and
///   filter by race without a secondary handshake.
/// - Keeps `Role → deviceId` and `deviceId → Role` maps up-to-date as
///   devices connect and disconnect.
/// - Exposes [sendMessage] for typed outbound messages and [incomingMessages]
///   for typed inbound messages.
/// - Stamps every outbound message with a monotonic sequence number and
///   tracks un-ACKed messages in [_pendingAck]. On disconnect the pending
///   messages are re-queued in front of the offline queue so they are
///   re-delivered in order on reconnect. Messages still un-ACKed after
///   [ackRetryInterval] on a live connection are re-sent.
/// - Persists every message in [IP2POutbox] until it is ACKed, so queued
///   messages survive the app being killed and are re-sent after [init].
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
    required this.raceKey,
    required NearbyConnectionsInterface nearbyConnections,
    required SharedPreferences prefs,
    required IP2POutbox outbox,
    this.ackRetryInterval = const Duration(seconds: 5),
  })  : _nearbyConnections = nearbyConnections,
        _prefs = prefs,
        _outbox = outbox;

  final Role localRole;
  /// Local race id, used to key persisted state on this device.
  final int raceId;

  /// Cross-device race key (see [xceRaceKey]) that peers must share.
  final String raceKey;
  final NearbyConnectionsInterface _nearbyConnections;
  final SharedPreferences _prefs;
  final IP2POutbox _outbox;

  /// How long a message may go un-ACKed on a live connection before it is
  /// sent again.
  final Duration ackRetryInterval;
  Timer? _retryTimer;
  // Un-ACKed messages seen on the previous retry tick; anything still
  // un-ACKed on the next tick has waited at least [ackRetryInterval].
  Set<(Role, int)> _unackedLastTick = {};

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

  // Only one side of each pair should invite: when both do at once, Multipeer
  // tears down both half-open sessions and the pair churns. The role that
  // comes first in [Role] leads; the other only invites as a fallback if the
  // peer is still unconnected after [_followerInviteDelay].
  static const Duration _followerInviteDelay = Duration(seconds: 8);

  // Every instance drives the same native Nearby Connections session, so a
  // new session must not start advertising until the previous one has
  // finished stopping — otherwise the late stop call kills the new session.
  static Future<void> _pendingTeardown = Future.value();
  Future<void>? _disposeFuture;

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
  /// matches the XCeleration format and shares the same [raceKey]. Subscribers
  /// such as [PeerDiscoveryNotifier] use this to derive UI connection state
  /// without running a second Nearby Connections session.
  Stream<PeerStateEvent> get peerStateEvents => _peerEventsController.stream;

  /// Initialises Nearby Connections, starts advertising and browsing, and
  /// wires up state-change and data-received subscriptions.
  ///
  /// Uses the fixed service type `xce-finline` (declared in iOS Info.plist)
  /// and the structured device name `xce|ROLE|RACE_KEY|HOSTNAME` so that all
  /// finish-line roles share one NC session per race.
  ///
  /// Must be called once before [sendMessage] or [incomingMessages].
  Future<void> init() async {
    await _pendingTeardown;
    _nextSequence = _prefs.getInt(_sequenceKey) ?? 0;
    await _restoreOutbox();
    _retryTimer = Timer.periodic(ackRetryInterval, (_) => _retryUnacked());

    await _nearbyConnections.init(
      serviceType: kXceServiceType,
      deviceName: buildXceAdvertisedName(localRole, raceKey),
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
    // Persist before sending so the message survives the app being killed.
    try {
      await _outbox.add(raceId, localRole, target, stamped);
    } catch (e) {
      Logger.e('[P2PSessionService] Failed to persist message for $target: $e');
    }
    final deviceId = _roleToDeviceId[target];
    if (deviceId == null) {
      _outboundQueues.putIfAbsent(target, () => []).add(stamped);
      return;
    }
    // Track before sending: if the send fails the retry timer or the next
    // disconnect re-sends it.
    _pendingAck.putIfAbsent(target, () => {})[stamped.sequence!] = stamped;
    try {
      await _nearbyConnections.sendMessage(deviceId, jsonEncode(stamped.toJson()));
    } catch (e) {
      Logger.e('[P2PSessionService] sendMessage to $target failed: $e');
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
  ///
  /// Safe to call more than once; later calls return the first call's future.
  Future<void> dispose() {
    final future = _disposeFuture ??= _teardown();
    _pendingTeardown = future;
    return future;
  }

  Future<void> _teardown() async {
    _retryTimer?.cancel();
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
      final (role, peerRaceKey, humanName) = parsed;
      if (peerRaceKey != raceKey) continue;
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
          // Device visible but not connected — debounce the auto-invite so
          // rapid-fire notConnected events from the native layer don't spawn
          // competing invitations that prevent the connection from stabilising.
          _scheduleInvite(device.deviceId, device.deviceName,
              leads: localRole.index < role.index);
          _deviceIdToRole.remove(device.deviceId);
          // A stale device ID for a role that has since reconnected under a
          // new ID must not tear down the live connection.
          final currentDeviceId = _roleToDeviceId[role];
          if (currentDeviceId != null && currentDeviceId != device.deviceId) {
            continue;
          }
          // Re-queue any un-ACKed messages before the device goes offline so
          // they are re-delivered in order on the next reconnect.
          _requeuePending(role);
          _roleToDeviceId.remove(role);
          _peerEventsController.add(
            PeerStateEvent(
                role: role,
                state: SessionState.notConnected,
                deviceName: humanName),
          );
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
        if (seq != null) _onAck(senderRole, seq);
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

  void _onAck(Role role, int sequence) {
    _pendingAck[role]?.remove(sequence);
    _outboundQueues[role]?.removeWhere((m) => m.sequence == sequence);
    _outbox.remove(raceId, localRole, role, sequence).catchError((Object e) {
      Logger.e('[P2PSessionService] Failed to clear ACKed message: $e');
    });
  }

  /// Loads messages left un-ACKed by an earlier run into the offline queues
  /// and moves the sequence counter past them.
  Future<void> _restoreOutbox() async {
    final List<(Role, MessageEnvelope)> saved;
    try {
      saved = await _outbox.load(raceId, localRole);
    } catch (e) {
      Logger.e('[P2PSessionService] Failed to load outbox: $e');
      return;
    }
    for (final (target, msg) in saved) {
      _outboundQueues.putIfAbsent(target, () => []).add(msg);
      final seq = msg.sequence;
      if (seq != null && seq >= _nextSequence) _nextSequence = seq + 1;
    }
  }

  /// Re-sends messages that have stayed un-ACKed on a live connection for a
  /// full [ackRetryInterval] (e.g. the peer missed them without dropping).
  void _retryUnacked() {
    final current = <(Role, int)>{};
    for (final MapEntry(key: role, value: pending) in _pendingAck.entries) {
      final deviceId = _roleToDeviceId[role];
      for (final msg in pending.values) {
        final key = (role, msg.sequence!);
        current.add(key);
        if (deviceId != null && _unackedLastTick.contains(key)) {
          unawaited(Future.sync(() => _nearbyConnections.sendMessage(
                  deviceId, jsonEncode(msg.toJson())))
              .catchError((Object e) {
            Logger.e('[P2PSessionService] Retry to $role failed: $e');
          }));
        }
      }
    }
    _unackedLastTick = current;
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
  void _scheduleInvite(String deviceId, String deviceName,
      {required bool leads}) {
    _inviteTimers[deviceId]?.cancel();
    final delay = leads ? _inviteDebounce : _followerInviteDelay;
    _inviteTimers[deviceId] = Timer(delay, () async {
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

