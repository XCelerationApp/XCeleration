import 'dart:async';

import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/core/utils/connection_interfaces.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

import 'peer_discovery_notifier_test.mocks.dart';

@GenerateMocks([NearbyConnectionsInterface, SharedPreferences])
void main() {
  late MockNearbyConnectionsInterface mockNearby;
  late MockSharedPreferences mockPrefs;
  late StreamController<PeerStateEvent> peerEventsController;
  late P2PSessionService session;
  late PeerDiscoveryNotifier notifier;

  setUp(() async {
    mockNearby = MockNearbyConnectionsInterface();
    mockPrefs = MockSharedPreferences();
    when(mockPrefs.getInt(any)).thenReturn(null);
    when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.remove(any)).thenAnswer((_) async => true);

    when(mockNearby.init(
      serviceType: anyNamed('serviceType'),
      deviceName: anyNamed('deviceName'),
      strategy: anyNamed('strategy'),
      callback: anyNamed('callback'),
    )).thenAnswer((_) async => null);
    when(mockNearby.stateChangedSubscription(callback: anyNamed('callback')))
        .thenAnswer((_) => StreamController<dynamic>().stream.listen((_) {}));
    when(mockNearby.dataReceivedSubscription(callback: anyNamed('callback')))
        .thenAnswer((_) => StreamController<dynamic>().stream.listen((_) {}));
    when(mockNearby.startAdvertisingPeer()).thenAnswer((_) async => null);
    when(mockNearby.startBrowsingForPeers()).thenAnswer((_) async => null);
    when(mockNearby.stopAdvertisingPeer()).thenAnswer((_) async => null);
    when(mockNearby.stopBrowsingForPeers()).thenAnswer((_) async => null);
    when(mockNearby.disconnectPeer(deviceID: anyNamed('deviceID')))
        .thenAnswer((_) async => null);

    session = P2PSessionService(
      localRole: Role.bibRecorderV2,
      raceId: 1,
      nearbyConnections: mockNearby,
      prefs: mockPrefs,
    );
    await session.init();

    notifier = PeerDiscoveryNotifier(
      role: Role.bibRecorderV2,
      raceId: 1,
      session: session,
    );
  });

  tearDown(() async {
    notifier.dispose();
    await session.dispose();
  });

  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------

  group('initial state', () {
    test('all expected peers start as searching', () {
      expect(notifier.statusFor(Role.verifier), PeerStatus.searching);
      expect(notifier.statusFor(Role.fixer), PeerStatus.searching);
    });

    test('anyConnected is false initially', () {
      expect(notifier.anyConnected, isFalse);
    });

    test('allConnected is false initially', () {
      expect(notifier.allConnected, isFalse);
    });

    test('deviceNameFor returns null when peer not yet found', () {
      expect(notifier.deviceNameFor(Role.verifier), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  // Inject a PeerStateEvent directly via the session's peerStateEvents stream.
  // We reach the stream through a fresh StreamController wired to the notifier.
  void emitEvent(PeerStateEvent event) {
    // We can't push to peerStateEvents directly since it's a broadcast stream
    // owned by P2PSessionService. Instead we use a separate
    // StreamController to drive the notifier in isolation.
    peerEventsController.add(event);
  }

  // Re-create the notifier driven by a controllable stream so we can inject
  // events without going through the full NC stack.
  PeerDiscoveryNotifier makeControlledNotifier(Role role) {
    peerEventsController = StreamController<PeerStateEvent>.broadcast();

    // Create a minimal fake P2PSessionService that exposes our controller's stream.
    final fakeSession = _FakeP2PSessionService(peerEventsController.stream, mockPrefs);
    return PeerDiscoveryNotifier(role: role, raceId: 1, session: fakeSession);
  }

  // ---------------------------------------------------------------------------
  // statusFor / deviceNameFor via controlled stream
  // ---------------------------------------------------------------------------

  group('statusFor', () {
    late PeerDiscoveryNotifier n;

    setUp(() {
      n = makeControlledNotifier(Role.bibRecorderV2);
    });

    tearDown(() {
      n.dispose();
      peerEventsController.close();
    });

    test('transitions to found on first notConnected event from unknown peer',
        () async {
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.notConnected,
        deviceName: 'verifier-phone',
      ));
      await Future.delayed(Duration.zero);
      expect(n.statusFor(Role.verifier), PeerStatus.found);
    });

    test('transitions to found on connecting event', () async {
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.connecting,
        deviceName: 'verifier-phone',
      ));
      await Future.delayed(Duration.zero);
      expect(n.statusFor(Role.verifier), PeerStatus.found);
    });

    test('transitions to connected on connected event', () async {
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.connected,
        deviceName: 'verifier-phone',
      ));
      await Future.delayed(Duration.zero);
      expect(n.statusFor(Role.verifier), PeerStatus.connected);
    });

    test('transitions to offline when previously connected peer disconnects',
        () async {
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.connected,
        deviceName: 'verifier-phone',
      ));
      await Future.delayed(Duration.zero);

      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.notConnected,
        deviceName: 'verifier-phone',
      ));
      await Future.delayed(Duration.zero);

      expect(n.statusFor(Role.verifier), PeerStatus.offline);
    });

    test(
        'keeps found status when notConnected fires during handshake (prev == found)',
        () async {
      // connecting sets status → found; a notConnected mid-handshake should
      // leave it at found rather than flashing offline.
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.connecting,
        deviceName: 'verifier-phone',
      ));
      await Future.delayed(Duration.zero);

      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.notConnected,
        deviceName: 'verifier-phone',
      ));
      await Future.delayed(Duration.zero);

      expect(n.statusFor(Role.verifier), PeerStatus.found);
    });

    test(
        'keeps found status when a second notConnected fires after initial discovery',
        () async {
      // First notConnected → found; second notConnected (re-invite cycle)
      // should still stay at found.
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.notConnected,
        deviceName: 'verifier-phone',
      ));
      await Future.delayed(Duration.zero);

      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.notConnected,
        deviceName: 'verifier-phone',
      ));
      await Future.delayed(Duration.zero);

      expect(n.statusFor(Role.verifier), PeerStatus.found);
    });

    test('ignores events for peers not in this role\'s peer config', () async {
      // bibRecorderV2's peer config does not include another bibRecorderV2.
      emitEvent(PeerStateEvent(
        role: Role.bibRecorderV2,
        state: SessionState.connected,
        deviceName: 'other-recorder',
      ));
      await Future.delayed(Duration.zero);

      expect(n.statusFor(Role.bibRecorderV2), PeerStatus.searching);
    });
  });

  // ---------------------------------------------------------------------------
  // deviceNameFor
  // ---------------------------------------------------------------------------

  group('deviceNameFor', () {
    late PeerDiscoveryNotifier n;

    setUp(() {
      n = makeControlledNotifier(Role.bibRecorderV2);
    });

    tearDown(() {
      n.dispose();
      peerEventsController.close();
    });

    test('is populated when peer is found', () async {
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.notConnected,
        deviceName: 'my-iphone',
      ));
      await Future.delayed(Duration.zero);
      expect(n.deviceNameFor(Role.verifier), 'my-iphone');
    });

    test('is updated when peer connects', () async {
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.connected,
        deviceName: 'my-iphone',
      ));
      await Future.delayed(Duration.zero);
      expect(n.deviceNameFor(Role.verifier), 'my-iphone');
    });
  });

  // ---------------------------------------------------------------------------
  // anyConnected / allConnected
  // ---------------------------------------------------------------------------

  group('anyConnected / allConnected', () {
    late PeerDiscoveryNotifier n;

    setUp(() {
      n = makeControlledNotifier(Role.bibRecorderV2);
    });

    tearDown(() {
      n.dispose();
      peerEventsController.close();
    });

    test('anyConnected becomes true when one peer connects', () async {
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.connected,
        deviceName: 'v',
      ));
      await Future.delayed(Duration.zero);
      expect(n.anyConnected, isTrue);
      expect(n.allConnected, isFalse);
    });

    test('allConnected becomes true when all peers connect', () async {
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.connected,
        deviceName: 'v',
      ));
      emitEvent(PeerStateEvent(
        role: Role.fixer,
        state: SessionState.connected,
        deviceName: 'f',
      ));
      await Future.delayed(Duration.zero);
      expect(n.allConnected, isTrue);
    });

    test('anyConnected becomes false when last peer goes offline', () async {
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.connected,
        deviceName: 'v',
      ));
      await Future.delayed(Duration.zero);

      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.notConnected,
        deviceName: 'v',
      ));
      await Future.delayed(Duration.zero);

      expect(n.anyConnected, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // notifyListeners
  // ---------------------------------------------------------------------------

  group('notifyListeners', () {
    late PeerDiscoveryNotifier n;

    setUp(() {
      n = makeControlledNotifier(Role.bibRecorderV2);
    });

    tearDown(() {
      n.dispose();
      peerEventsController.close();
    });

    test('fires when status changes', () async {
      var notified = false;
      n.addListener(() => notified = true);

      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.connected,
        deviceName: 'v',
      ));
      await Future.delayed(Duration.zero);

      expect(notified, isTrue);
    });

    test('does not fire when status is unchanged', () async {
      // Connect verifier first.
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.connected,
        deviceName: 'v',
      ));
      await Future.delayed(Duration.zero);

      var notifiedAgain = false;
      n.addListener(() => notifiedAgain = true);

      // Fire the same connected event — no state change expected.
      emitEvent(PeerStateEvent(
        role: Role.verifier,
        state: SessionState.connected,
        deviceName: 'v',
      ));
      await Future.delayed(Duration.zero);

      expect(notifiedAgain, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Fake P2PSessionService that exposes an externally controlled stream
// ---------------------------------------------------------------------------

class _FakeP2PSessionService extends P2PSessionService {
  _FakeP2PSessionService(this._events, SharedPreferences prefs)
      : super(
          localRole: Role.bibRecorderV2,
          raceId: 1,
          nearbyConnections: _NoOpNearbyConnections(),
          prefs: prefs,
        );

  final Stream<PeerStateEvent> _events;

  @override
  Stream<PeerStateEvent> get peerStateEvents => _events;
}

/// Minimal no-op NearbyConnectionsInterface for the fake session.
class _NoOpNearbyConnections implements NearbyConnectionsInterface {
  @override
  Future<dynamic> init(
          {required String serviceType,
          String? deviceName,
          required strategy,
          required Function callback}) async =>
      null;

  @override
  FutureOr<dynamic> startAdvertisingPeer() async => null;
  @override
  FutureOr<dynamic> startBrowsingForPeers() async => null;
  @override
  FutureOr<dynamic> stopAdvertisingPeer() async => null;
  @override
  FutureOr<dynamic> stopBrowsingForPeers() async => null;
  @override
  FutureOr<dynamic> sendMessage(String deviceID, String message) async => null;
  @override
  FutureOr<dynamic> invitePeer(
          {required String deviceID, required String deviceName}) async =>
      null;
  @override
  FutureOr<dynamic> disconnectPeer({required String deviceID}) async => null;

  @override
  StreamSubscription<dynamic> dataReceivedSubscription(
          {required Function(dynamic) callback}) =>
      StreamController<dynamic>().stream.listen((_) {});

  @override
  StreamSubscription<dynamic> stateChangedSubscription(
          {required Function(List<Device>) callback}) =>
      StreamController<dynamic>().stream.listen((_) {});
}
