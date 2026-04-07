import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/core/utils/connection_interfaces.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

import 'p2p_session_service_test.mocks.dart';

@GenerateMocks([NearbyConnectionsInterface, SharedPreferences])
void main() {
  late MockNearbyConnectionsInterface mockNearby;
  late MockSharedPreferences mockPrefs;
  late P2PSessionService service;

  // Callbacks captured from the mock so tests can drive them directly.
  late Function(List<Device>) capturedStateCallback;
  late Function(dynamic) capturedDataCallback;

  setUp(() async {
    mockNearby = MockNearbyConnectionsInterface();
    mockPrefs = MockSharedPreferences();

    when(mockPrefs.getInt(any)).thenReturn(null);
    when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.remove(any)).thenAnswer((_) async => true);

    service = P2PSessionService(
      localRole: Role.bibRecorderV2,
      raceId: 42,
      nearbyConnections: mockNearby,
      prefs: mockPrefs,
    );

    when(mockNearby.init(
      serviceType: anyNamed('serviceType'),
      deviceName: anyNamed('deviceName'),
      strategy: anyNamed('strategy'),
      callback: anyNamed('callback'),
    )).thenAnswer((_) async => null);

    when(mockNearby.stateChangedSubscription(callback: anyNamed('callback')))
        .thenAnswer((invocation) {
      capturedStateCallback =
          invocation.namedArguments[#callback] as Function(List<Device>);
      return StreamController<dynamic>().stream.listen((_) {});
    });

    when(mockNearby.dataReceivedSubscription(callback: anyNamed('callback')))
        .thenAnswer((invocation) {
      capturedDataCallback = invocation.namedArguments[#callback];
      return StreamController<dynamic>().stream.listen((_) {});
    });

    when(mockNearby.startAdvertisingPeer()).thenAnswer((_) async => null);
    when(mockNearby.startBrowsingForPeers()).thenAnswer((_) async => null);
    when(mockNearby.stopAdvertisingPeer()).thenAnswer((_) async => null);
    when(mockNearby.stopBrowsingForPeers()).thenAnswer((_) async => null);
    when(mockNearby.invitePeer(
      deviceID: anyNamed('deviceID'),
      deviceName: anyNamed('deviceName'),
    )).thenAnswer((_) async => null);
    when(mockNearby.sendMessage(any, any)).thenAnswer((_) async => null);
    when(mockNearby.disconnectPeer(deviceID: anyNamed('deviceID')))
        .thenAnswer((_) async => null);

    await service.init();
  });

  tearDown(() async {
    await service.dispose();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Simulates a peer device connecting and entering the [connected] state.
  Future<void> connectVerifier() async {
    await capturedStateCallback([
      Device('verifier-device-id', 'xce|VFR|42|test-phone', 2 /* SessionState.connected */),
    ]);
  }

  /// Simulates the verifier disconnecting (notConnected state).
  Future<void> disconnectVerifier() async {
    await capturedStateCallback([
      Device('verifier-device-id', 'xce|VFR|42|test-phone', 0 /* SessionState.notConnected */),
    ]);
  }

  BibEntryMessage makeEntry() => BibEntryMessage(
        finishPosition: 1,
        bib: 42,
        status: BibEntryStatus.resolved,
        timestamp: DateTime.utc(2026, 3, 20),
      );

  BibEntryMessage makeEntryAt(int pos) => BibEntryMessage(
        finishPosition: pos,
        bib: pos,
        status: BibEntryStatus.resolved,
        timestamp: DateTime.utc(2026, 3, 20),
      );

  /// Simulates the verifier sending a message to the local device.
  void receiveFromVerifier(MessageEnvelope envelope) {
    capturedDataCallback({
      'senderDeviceId': 'verifier-device-id',
      'message': jsonEncode(envelope.toJson()),
    });
  }

  /// Returns all non-ACK messages captured by [mockNearby.sendMessage] to
  /// 'verifier-device-id', decoded.
  List<MessageEnvelope> captureRegularSends() {
    return verify(mockNearby.sendMessage('verifier-device-id', captureAny))
        .captured
        .map((json) => MessageEnvelope.fromJson(
              (jsonDecode(json as String) as Map).cast<String, dynamic>(),
            ))
        .where((e) => e.type != MessageType.ack)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // sendMessage
  // ---------------------------------------------------------------------------

  group('sendMessage', () {
    test('sends stamped JSON to the correct device ID', () async {
      await connectVerifier();

      final envelope = MessageEnvelope.wrapBibEntry(makeEntry());
      await service.sendMessage(Role.verifier, envelope);

      // First message gets sequence 0.
      verify(mockNearby.sendMessage(
        'verifier-device-id',
        jsonEncode(envelope.withSequence(0).toJson()),
      )).called(1);
    });

    test('does not call sendMessage when peer is not connected', () async {
      final envelope = MessageEnvelope.wrapBibEntry(makeEntry());

      await service.sendMessage(Role.verifier, envelope);

      verifyNever(mockNearby.sendMessage(any, any));
    });
  });

  // ---------------------------------------------------------------------------
  // Offline queue
  // ---------------------------------------------------------------------------

  group('offline queue', () {
    test('queues messages sent while peer is offline', () async {
      final envelope = MessageEnvelope.wrapBibEntry(makeEntry());
      await service.sendMessage(Role.verifier, envelope);

      expect(service.pendingCount(Role.verifier), 1);
      verifyNever(mockNearby.sendMessage(any, any));
    });

    test('flushes queued messages in FIFO order on reconnect', () async {
      final e1 = MessageEnvelope.wrapBibEntry(makeEntryAt(1));
      final e2 = MessageEnvelope.wrapBibEntry(makeEntryAt(2));
      final e3 = MessageEnvelope.wrapBibEntry(makeEntryAt(3));

      await service.sendMessage(Role.verifier, e1);
      await service.sendMessage(Role.verifier, e2);
      await service.sendMessage(Role.verifier, e3);

      expect(service.pendingCount(Role.verifier), 3);
      verifyNever(mockNearby.sendMessage(any, any));

      await connectVerifier();

      expect(service.pendingCount(Role.verifier), 0);

      // Sequences assigned at queue time: e1→0, e2→1, e3→2.
      final captured = verify(mockNearby.sendMessage(
        'verifier-device-id',
        captureAny,
      )).captured;

      expect(captured.length, 3);
      expect(captured[0], jsonEncode(e1.withSequence(0).toJson()));
      expect(captured[1], jsonEncode(e2.withSequence(1).toJson()));
      expect(captured[2], jsonEncode(e3.withSequence(2).toJson()));
    });

    test('evicts oldest message when queue cap is exceeded', () async {
      for (int i = 0; i < 500; i++) {
        await service.sendMessage(
          Role.verifier,
          MessageEnvelope.wrapBibEntry(makeEntryAt(i)),
        );
      }
      expect(service.pendingCount(Role.verifier), 500);

      final newMsg = MessageEnvelope.wrapBibEntry(makeEntryAt(500));
      await service.sendMessage(Role.verifier, newMsg);

      expect(service.pendingCount(Role.verifier), 500);

      await connectVerifier();
      final captured = verify(mockNearby.sendMessage(
        'verifier-device-id',
        captureAny,
      )).captured;

      // 500 messages flushed — position 500 (seq 500) must be last.
      final envelopes = captured
          .map((json) => MessageEnvelope.fromJson(
                (jsonDecode(json as String) as Map).cast<String, dynamic>(),
              ))
          .toList();

      expect(envelopes.last.sequence, 500);
      // Sequence 0 (position 0, the evicted message) must not appear.
      expect(envelopes.every((e) => e.sequence != 0), isTrue);
    });

    test('pendingCount returns 0 when peer is connected', () async {
      await connectVerifier();
      expect(service.pendingCount(Role.verifier), 0);
    });

    test('pendingCount returns 0 after flush on reconnect', () async {
      await service.sendMessage(Role.verifier, MessageEnvelope.wrapBibEntry(makeEntry()));
      expect(service.pendingCount(Role.verifier), 1);

      await connectVerifier();
      expect(service.pendingCount(Role.verifier), 0);
    });

    test('queue for one peer does not affect another peer', () async {
      await service.sendMessage(Role.verifier, MessageEnvelope.wrapBibEntry(makeEntry()));

      expect(service.pendingCount(Role.verifier), 1);
      expect(service.pendingCount(Role.fixer), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // incomingMessages
  // ---------------------------------------------------------------------------

  group('incomingMessages', () {
    test('emits typed envelope from a connected peer', () async {
      await connectVerifier();

      final envelope = MessageEnvelope.wrapBibEntry(makeEntry());

      final eventFuture = service.incomingMessages.first;
      receiveFromVerifier(envelope);

      final (senderRole, receivedEnvelope) = await eventFuture;
      expect(senderRole, Role.verifier);
      expect(receivedEnvelope.type, MessageType.bibEntry);
    });

    test('drops messages from unknown device IDs', () async {
      final events = <(Role, MessageEnvelope)>[];
      final sub = service.incomingMessages.listen(events.add);

      capturedDataCallback({
        'senderDeviceId': 'unknown-device-id',
        'message': jsonEncode(MessageEnvelope.wrapBibEntry(makeEntry()).toJson()),
      });

      await Future.delayed(Duration.zero);
      expect(events, isEmpty);
      await sub.cancel();
    });

    test('drops messages with malformed JSON', () async {
      await connectVerifier();

      final events = <(Role, MessageEnvelope)>[];
      final sub = service.incomingMessages.listen(events.add);

      capturedDataCallback({
        'senderDeviceId': 'verifier-device-id',
        'message': 'not-valid-json{{{',
      });

      await Future.delayed(Duration.zero);
      expect(events, isEmpty);
      await sub.cancel();
    });

    test('drops messages with missing senderDeviceId', () async {
      final events = <(Role, MessageEnvelope)>[];
      final sub = service.incomingMessages.listen(events.add);

      capturedDataCallback({
        'message': jsonEncode(MessageEnvelope.wrapBibEntry(makeEntry()).toJson()),
      });

      await Future.delayed(Duration.zero);
      expect(events, isEmpty);
      await sub.cancel();
    });
  });

  // ---------------------------------------------------------------------------
  // ACK delivery guarantee
  // ---------------------------------------------------------------------------

  group('ACK delivery guarantee', () {
    test('sent message is re-queued to offline queue on disconnect', () async {
      await connectVerifier();

      await service.sendMessage(Role.verifier, MessageEnvelope.wrapBibEntry(makeEntry()));
      // Message is in _pendingAck — offline queue is still empty.
      expect(service.pendingCount(Role.verifier), 0);

      await disconnectVerifier();

      // Pending message has been moved back to the offline queue.
      expect(service.pendingCount(Role.verifier), 1);
    });

    test('ACK receipt prevents message from being re-queued on disconnect',
        () async {
      await connectVerifier();

      await service.sendMessage(Role.verifier, MessageEnvelope.wrapBibEntry(makeEntry()));

      // Simulate receiving ACK for sequence 0.
      receiveFromVerifier(MessageEnvelope.wrapAck(0));
      await Future.delayed(Duration.zero);

      await disconnectVerifier();

      // ACKed message must not be re-queued.
      expect(service.pendingCount(Role.verifier), 0);
    });

    test(
        're-queued pending messages are prepended to offline queue in sequence order',
        () async {
      // Queue m1, m2 offline before first connect.
      final m1 = MessageEnvelope.wrapBibEntry(makeEntryAt(1));
      final m2 = MessageEnvelope.wrapBibEntry(makeEntryAt(2));
      await service.sendMessage(Role.verifier, m1); // seq 0
      await service.sendMessage(Role.verifier, m2); // seq 1

      // Connect: flushes [m1(0), m2(1)] to _pendingAck.
      await connectVerifier();

      // Disconnect without ACKs: m1, m2 re-queued to front of offline queue.
      await disconnectVerifier();

      // Queue m3, m4 while offline.
      final m3 = MessageEnvelope.wrapBibEntry(makeEntryAt(3));
      final m4 = MessageEnvelope.wrapBibEntry(makeEntryAt(4));
      await service.sendMessage(Role.verifier, m3); // seq 2
      await service.sendMessage(Role.verifier, m4); // seq 3

      expect(service.pendingCount(Role.verifier), 4);

      // Reset tracked interactions so we only inspect the reconnect flush.
      clearInteractions(mockNearby);

      // Reconnect: flush [m1(0), m2(1), m3(2), m4(3)] in order.
      await connectVerifier();

      final envelopes = captureRegularSends();
      expect(envelopes.length, 4);
      expect(envelopes[0].sequence, 0);
      expect(envelopes[1].sequence, 1);
      expect(envelopes[2].sequence, 2);
      expect(envelopes[3].sequence, 3);
    });

    test('duplicate sequence number is dropped and not emitted to stream',
        () async {
      await connectVerifier();

      final events = <(Role, MessageEnvelope)>[];
      final sub = service.incomingMessages.listen(events.add);

      final envelope = MessageEnvelope.wrapBibEntry(makeEntry()).withSequence(5);
      receiveFromVerifier(envelope);
      await Future.delayed(Duration.zero);

      // Same sequence again — re-delivery.
      receiveFromVerifier(envelope);
      await Future.delayed(Duration.zero);

      expect(events.length, 1);
      await sub.cancel();
    });

    test('ACK envelope is never emitted to incomingMessages', () async {
      await connectVerifier();

      final events = <(Role, MessageEnvelope)>[];
      final sub = service.incomingMessages.listen(events.add);

      receiveFromVerifier(MessageEnvelope.wrapAck(7));
      await Future.delayed(Duration.zero);

      expect(events, isEmpty);
      await sub.cancel();
    });

    test('sends ACK back to sender after receiving a sequenced message',
        () async {
      await connectVerifier();

      final envelope =
          MessageEnvelope.wrapBibEntry(makeEntry()).withSequence(9);
      receiveFromVerifier(envelope);
      await Future.delayed(Duration.zero);

      final captured = verify(mockNearby.sendMessage(
        'verifier-device-id',
        captureAny,
      )).captured;

      final acks = captured
          .map((json) => MessageEnvelope.fromJson(
                (jsonDecode(json as String) as Map).cast<String, dynamic>(),
              ))
          .where((e) => e.type == MessageType.ack)
          .toList();

      expect(acks.length, 1);
      expect(acks.first.sequence, 9);
    });

    test('duplicate re-delivery receives ACK again but is not emitted', () async {
      await connectVerifier();

      final events = <(Role, MessageEnvelope)>[];
      final sub = service.incomingMessages.listen(events.add);

      final envelope =
          MessageEnvelope.wrapBibEntry(makeEntry()).withSequence(3);

      receiveFromVerifier(envelope);
      await Future.delayed(Duration.zero);
      receiveFromVerifier(envelope); // duplicate
      await Future.delayed(Duration.zero);

      expect(events.length, 1);

      // Both deliveries should have prompted an ACK.
      final captured = verify(mockNearby.sendMessage(
        'verifier-device-id',
        captureAny,
      )).captured;
      final acks = captured
          .map((json) => MessageEnvelope.fromJson(
                (jsonDecode(json as String) as Map).cast<String, dynamic>(),
              ))
          .where((e) => e.type == MessageType.ack && e.sequence == 3)
          .toList();

      expect(acks.length, 2);
      await sub.cancel();
    });
  });

  // ---------------------------------------------------------------------------
  // Peer discovery
  // ---------------------------------------------------------------------------

  group('peer discovery', () {
    test('invites peer when it is found but not yet connected', () {
      fakeAsync((async) {
        capturedStateCallback([
          Device('verifier-device-id', 'xce|VFR|42|test-phone', 0 /* SessionState.notConnected */),
        ]);

        // Invitation is debounced — advance past the 2 s window.
        async.elapse(const Duration(seconds: 2));

        verify(mockNearby.invitePeer(
          deviceID: 'verifier-device-id',
          deviceName: 'xce|VFR|42|test-phone',
        )).called(1);
      });
    });

    test('ignores devices with unrecognised name format', () async {
      await capturedStateCallback([
        Device('rogue-id', 'SomeOtherApp', 2 /* SessionState.connected */),
      ]);

      final events = <(Role, MessageEnvelope)>[];
      final sub = service.incomingMessages.listen(events.add);

      capturedDataCallback({
        'senderDeviceId': 'rogue-id',
        'message': jsonEncode(MessageEnvelope.wrapBibEntry(makeEntry()).toJson()),
      });

      await Future.delayed(Duration.zero);
      expect(events, isEmpty);
      await sub.cancel();
    });

    test('ignores devices with the same role as localRole', () async {
      // Another bibRecorderV2 device should not be invited or tracked.
      await capturedStateCallback([
        Device('other-recorder-id', 'xce|BIB|42|other-phone',
            0 /* SessionState.notConnected */),
      ]);

      verifyNever(mockNearby.invitePeer(
        deviceID: 'other-recorder-id',
        deviceName: anyNamed('deviceName'),
      ));
    });

    test('ignores devices from a different race ID', () async {
      // raceId 99 ≠ 42 (the service's raceId) — must not be invited or tracked.
      await capturedStateCallback([
        Device('other-race-id', 'xce|VFR|99|test-phone', 0 /* SessionState.notConnected */),
      ]);

      verifyNever(mockNearby.invitePeer(
        deviceID: 'other-race-id',
        deviceName: anyNamed('deviceName'),
      ));
    });

    test('removes peer from connected map when it disconnects', () async {
      await connectVerifier();

      // Verifier disconnects.
      await disconnectVerifier();

      // Send should now queue offline — no transport call.
      final envelope = MessageEnvelope.wrapBibEntry(makeEntry());
      await service.sendMessage(Role.verifier, envelope);
      verifyNever(mockNearby.sendMessage(any, any));
    });
  });

  // ---------------------------------------------------------------------------
  // peerStateEvents
  // ---------------------------------------------------------------------------

  group('peerStateEvents', () {
    test('emits connected event when peer connects', () async {
      final events = <PeerStateEvent>[];
      final sub = service.peerStateEvents.listen(events.add);

      await connectVerifier();

      expect(events.length, 1);
      expect(events.first.role, Role.verifier);
      expect(events.first.state, SessionState.connected);
      expect(events.first.deviceName, 'test-phone');
      await sub.cancel();
    });

    test('emits notConnected event when peer disconnects', () async {
      await connectVerifier();

      final events = <PeerStateEvent>[];
      final sub = service.peerStateEvents.listen(events.add);

      await disconnectVerifier();

      expect(events.length, 1);
      expect(events.first.role, Role.verifier);
      expect(events.first.state, SessionState.notConnected);
      await sub.cancel();
    });

    test('emits connecting event for connecting state', () async {
      final events = <PeerStateEvent>[];
      final sub = service.peerStateEvents.listen(events.add);

      await capturedStateCallback([
        Device('verifier-device-id', 'xce|VFR|42|test-phone', 1 /* SessionState.connecting */),
      ]);

      expect(events.length, 1);
      expect(events.first.role, Role.verifier);
      expect(events.first.state, SessionState.connecting);
      await sub.cancel();
    });

    test('does not emit events for unrecognised device names', () async {
      final events = <PeerStateEvent>[];
      final sub = service.peerStateEvents.listen(events.add);

      await capturedStateCallback([
        Device('rogue-id', 'SomeOtherApp', 2 /* connected */),
      ]);

      expect(events, isEmpty);
      await sub.cancel();
    });

    test('does not emit events for different race IDs', () async {
      final events = <PeerStateEvent>[];
      final sub = service.peerStateEvents.listen(events.add);

      await capturedStateCallback([
        Device('other-race-id', 'xce|VFR|99|test-phone', 2 /* connected */),
      ]);

      expect(events, isEmpty);
      await sub.cancel();
    });
  });

  // ---------------------------------------------------------------------------
  // out-of-order deduplication (XCE-519)
  // ---------------------------------------------------------------------------

  group('out-of-order deduplication', () {
    test('all three messages delivered out of order are processed exactly once',
        () async {
      await connectVerifier();

      final events = <(Role, MessageEnvelope)>[];
      final sub = service.incomingMessages.listen(events.add);

      // Deliver seq 1, then 3, then 2 — all three must reach the stream.
      receiveFromVerifier(
          MessageEnvelope.wrapBibEntry(makeEntryAt(1)).withSequence(1));
      receiveFromVerifier(
          MessageEnvelope.wrapBibEntry(makeEntryAt(3)).withSequence(3));
      receiveFromVerifier(
          MessageEnvelope.wrapBibEntry(makeEntryAt(2)).withSequence(2));
      await Future.delayed(Duration.zero);

      expect(events.length, 3);
      await sub.cancel();
    });

    test('redelivered duplicate after out-of-order burst is still dropped',
        () async {
      await connectVerifier();

      final events = <(Role, MessageEnvelope)>[];
      final sub = service.incomingMessages.listen(events.add);

      final envelope =
          MessageEnvelope.wrapBibEntry(makeEntryAt(1)).withSequence(1);
      receiveFromVerifier(
          MessageEnvelope.wrapBibEntry(makeEntryAt(3)).withSequence(3));
      receiveFromVerifier(envelope);
      receiveFromVerifier(
          MessageEnvelope.wrapBibEntry(makeEntryAt(2)).withSequence(2));
      receiveFromVerifier(envelope); // duplicate of seq 1
      await Future.delayed(Duration.zero);

      expect(events.length, 3);
      await sub.cancel();
    });

    test('seen-sequence set is bounded — entries beyond cap are evicted',
        () async {
      await connectVerifier();

      final events = <(Role, MessageEnvelope)>[];
      final sub = service.incomingMessages.listen(events.add);

      // Deliver 1001 unique messages — all should be processed (none dropped
      // as duplicates), confirming cap eviction does not cause false drops.
      for (int i = 0; i <= 1000; i++) {
        receiveFromVerifier(
            MessageEnvelope.wrapBibEntry(makeEntryAt(i % 10)).withSequence(i));
      }
      await Future.delayed(Duration.zero);

      expect(events.length, 1001);
      await sub.cancel();
    });
  });

  // ---------------------------------------------------------------------------
  // mid-flush message loss fix (XCE-520)
  // ---------------------------------------------------------------------------

  group('mid-flush message loss', () {
    test(
        'all queued messages are re-queued after a mid-flush disconnect',
        () async {
      // Queue 5 messages while offline.
      for (int i = 1; i <= 5; i++) {
        await service.sendMessage(
            Role.verifier, MessageEnvelope.wrapBibEntry(makeEntryAt(i)));
      }
      expect(service.pendingCount(Role.verifier), 5);

      // Make sends fail starting from the 3rd message.
      int sendCount = 0;
      when(mockNearby.sendMessage(any, any)).thenAnswer((_) async {
        sendCount++;
        if (sendCount > 2) throw Exception('peer disconnected');
      });

      // Connect triggers flush; 3rd send throws.
      await capturedStateCallback([
        Device('verifier-device-id', 'xce|VFR|42|test-phone',
            2 /* connected */),
      ]);

      // Disconnect re-queues everything in _pendingAck (all 5 messages were
      // pre-registered before the first send was attempted).
      await capturedStateCallback([
        Device('verifier-device-id', 'xce|VFR|42|test-phone',
            0 /* notConnected */),
      ]);

      // All 5 messages must be back in the offline queue.
      expect(service.pendingCount(Role.verifier), 5);
    });
  });

  // ---------------------------------------------------------------------------
  // sequence number persistence (XCE-521)
  // ---------------------------------------------------------------------------

  group('sequence number persistence', () {
    test('init() restores _nextSequence from SharedPreferences', () async {
      when(mockPrefs.getInt('p2p_seq_42_bibRecorderV2')).thenReturn(7);

      final restoredService = P2PSessionService(
        localRole: Role.bibRecorderV2,
        raceId: 42,
        nearbyConnections: mockNearby,
        prefs: mockPrefs,
      );
      await restoredService.init();

      // Connect verifier and send — first message should get sequence 7.
      await capturedStateCallback([
        Device('verifier-device-id', 'xce|VFR|42|test-phone', 2),
      ]);
      await restoredService.sendMessage(
          Role.verifier, MessageEnvelope.wrapBibEntry(makeEntry()));

      final captured =
          verify(mockNearby.sendMessage('verifier-device-id', captureAny))
              .captured;
      final sent = captured
          .map((j) => MessageEnvelope.fromJson(
                (jsonDecode(j as String) as Map).cast<String, dynamic>(),
              ))
          .where((e) => e.type != MessageType.ack)
          .toList();

      expect(sent.first.sequence, 7);
      await restoredService.dispose();
    });

    test('sendMessage() persists the updated sequence counter', () async {
      await connectVerifier();
      await service.sendMessage(
          Role.verifier, MessageEnvelope.wrapBibEntry(makeEntry()));

      verify(mockPrefs.setInt('p2p_seq_42_bibRecorderV2', 1)).called(1);
    });

    test('clearPersistedSequence() removes the key from storage', () async {
      await service.clearPersistedSequence();

      verify(mockPrefs.remove('p2p_seq_42_bibRecorderV2')).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // dispose
  // ---------------------------------------------------------------------------

  group('dispose', () {
    test('closes the incomingMessages stream', () async {
      var done = false;
      service.incomingMessages.listen(null, onDone: () => done = true);

      await service.dispose();
      await Future.delayed(Duration.zero);

      expect(done, isTrue);
    });

    test('disconnects all connected peers on dispose', () async {
      await connectVerifier();
      await capturedStateCallback([
        Device('fixer-device-id', 'xce|FIX|42|test-phone', 2 /* SessionState.connected */),
      ]);

      await service.dispose();

      verify(mockNearby.disconnectPeer(deviceID: 'verifier-device-id'))
          .called(1);
      verify(mockNearby.disconnectPeer(deviceID: 'fixer-device-id')).called(1);
    });

    test('is safe to call twice', () async {
      await service.dispose();
      // Second dispose should not throw.
      await service.dispose();
    });
  });
}
