import 'dart:async';
import 'dart:convert';

import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/core/utils/connection_interfaces.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

import 'p2p_session_service_test.mocks.dart';

@GenerateMocks([NearbyConnectionsInterface])
void main() {
  late MockNearbyConnectionsInterface mockNearby;
  late P2PSessionService service;

  // Callbacks captured from the mock so tests can drive them directly.
  late Function(List<Device>) capturedStateCallback;
  late Function(dynamic) capturedDataCallback;

  setUp(() async {
    mockNearby = MockNearbyConnectionsInterface();

    service = P2PSessionService(
      localRole: Role.bibRecorderV2,
      raceId: 42,
      nearbyConnections: mockNearby,
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
      Device('verifier-device-id', 'xce-verifier', 2 /* SessionState.connected */),
    ]);
  }

  BibEntryMessage makeEntry() => BibEntryMessage(
        finishPosition: 1,
        bib: 42,
        status: BibEntryStatus.resolved,
        timestamp: DateTime.utc(2026, 3, 20),
      );

  // ---------------------------------------------------------------------------
  // sendMessage
  // ---------------------------------------------------------------------------

  group('sendMessage', () {
    test('sends serialised JSON to the correct device ID', () async {
      await connectVerifier();

      final envelope = MessageEnvelope.wrapBibEntry(makeEntry());
      await service.sendMessage(Role.verifier, envelope);

      verify(mockNearby.sendMessage(
        'verifier-device-id',
        jsonEncode(envelope.toJson()),
      )).called(1);
    });

    test('does not call sendMessage when peer is not connected', () async {
      final envelope = MessageEnvelope.wrapBibEntry(makeEntry());

      await service.sendMessage(Role.verifier, envelope);

      verifyNever(mockNearby.sendMessage(any, any));
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
      capturedDataCallback({
        'senderDeviceId': 'verifier-device-id',
        'message': jsonEncode(envelope.toJson()),
      });

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
  // Peer discovery
  // ---------------------------------------------------------------------------

  group('peer discovery', () {
    test('invites peer when it is found but not yet connected', () async {
      await capturedStateCallback([
        Device('verifier-device-id', 'xce-verifier', 0 /* SessionState.notConnected */),
      ]);

      verify(mockNearby.invitePeer(
        deviceID: 'verifier-device-id',
        deviceName: 'xce-verifier',
      )).called(1);
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
        Device('other-recorder-id', 'xce-bibRecorderV2',
            0 /* SessionState.notConnected */),
      ]);

      verifyNever(mockNearby.invitePeer(
        deviceID: 'other-recorder-id',
        deviceName: anyNamed('deviceName'),
      ));
    });

    test('removes peer from connected map when it disconnects', () async {
      await connectVerifier();

      // Verifier disconnects.
      await capturedStateCallback([
        Device('verifier-device-id', 'xce-verifier', 0 /* SessionState.notConnected */),
      ]);

      // Send should now be a no-op — verifier no longer in map.
      final envelope = MessageEnvelope.wrapBibEntry(makeEntry());
      await service.sendMessage(Role.verifier, envelope);
      verifyNever(mockNearby.sendMessage(any, any));
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
        Device('fixer-device-id', 'xce-fixer', 2 /* SessionState.connected */),
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
