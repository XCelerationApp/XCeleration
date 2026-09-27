import 'dart:async';

import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:xceleration/core/connection/controller/wireless_connection_controller.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/connection_interfaces.dart';
import 'package:xceleration/core/utils/connection_utils.dart';
import 'package:xceleration/core/utils/data_protocol.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/platform_checker.dart';

/// Phones sharing races over a pretend radio, so the real connection code
/// on two or more phones can be run against each other in one test.
///
/// Each [FakePhone] behaves like the iPhone plugin (MultipeerConnectivity
/// behind `packages/flutter_nearby_connections`): a browsing phone finds
/// advertising phones with the same service type, invites one, both sides
/// go connecting then connected, and messages go only over a connection
/// both sides still have. Delays, lost messages, dropped connections and
/// the app going to the background can all be set up, and with fakeAsync a
/// ten-minute search takes no real time.
///
/// Use [openSharing] to open a sharing screen's controller on a phone.
class FakeNearbyNetwork {
  final List<FakePhone> _phones = [];

  /// How long a browsing phone takes to see an advertising one.
  Duration discoveryDelay = const Duration(milliseconds: 500);

  /// How long an accepted invitation takes to connect.
  Duration connectDelay = const Duration(milliseconds: 300);

  /// How long a message takes to arrive.
  Duration messageDelay = const Duration(milliseconds: 20);

  /// How long an invitation waits before giving up, as on iOS.
  Duration inviteTimeout = const Duration(seconds: 10);

  /// Return true to lose a message on the way. It still counts as sent.
  bool Function(FakePhone from, FakePhone to, String message)? loseMessage;

  /// Messages delivered, as "from -> to".
  final List<String> delivered = [];

  int _nextSession = 1;

  FakePhone phone(String label) {
    final phone = FakePhone._(this, label);
    _phones.add(phone);
    return phone;
  }

  /// Drops the connection between [a] and [b] at both ends, as walking out
  /// of range does.
  void dropConnection(FakePhone a, FakePhone b) {
    final ab = a._devices[b.name];
    final ba = b._devices[a.name];
    if (ab != null) ab.state = SessionState.notConnected;
    if (ba != null) ba.state = SessionState.notConnected;
    a._emit();
    b._emit();
  }

  FakePhone? _advertiserNamed(String name, String serviceType) {
    for (final p in _phones) {
      if (p.name == name &&
          p._serviceType == serviceType &&
          p._advertising &&
          !p._inBackground) {
        return p;
      }
    }
    return null;
  }

  FakePhone? _phoneNamed(String name, String serviceType) {
    for (final p in _phones) {
      if (p.name == name && p._serviceType == serviceType) return p;
    }
    return null;
  }

  /// Schedules each browsing phone to find the advertising phones it does
  /// not know yet, and to lose any unconnected one that stopped.
  void _refreshDiscovery() {
    for (final browser in _phones) {
      if (!browser._browsing || browser._inBackground) continue;
      final type = browser._serviceType;
      for (final advertiser in _phones) {
        if (identical(advertiser, browser) ||
            !advertiser._advertising ||
            advertiser._inBackground ||
            advertiser._serviceType != type ||
            advertiser.name == null ||
            browser._devices.containsKey(advertiser.name)) {
          continue;
        }
        final generation = browser._generation;
        final name = advertiser.name!;
        Timer(discoveryDelay, () {
          if (browser._generation != generation ||
              !browser._browsing ||
              browser._inBackground ||
              _advertiserNamed(name, type!) == null ||
              browser._devices.containsKey(name)) {
            return;
          }
          browser._devices[name] = _Peer(name);
          browser._emit();
        });
      }
      // Lost: a known phone no longer advertising, never connected.
      final lost = browser._devices.values
          .where((peer) =>
              peer.state == SessionState.notConnected &&
              _advertiserNamed(peer.name, type ?? '') == null)
          .map((peer) => peer.name)
          .toList();
      if (lost.isNotEmpty) {
        for (final name in lost) {
          browser._devices.remove(name);
        }
        browser._emit();
      }
    }
  }
}

class _Peer {
  _Peer(this.name);
  final String name;
  SessionState state = SessionState.notConnected;

  /// The connection this entry belongs to; both ends share it.
  int session = 0;
}

/// One phone's radio: what the plugin's MPCManager is on an iPhone. Every
/// [NearbyConnectionsInterface] made on the phone shares it, and events go
/// to the one initialised last, as the plugin's method channel does.
class FakePhone {
  FakePhone._(this.network, this.label);

  final FakeNearbyNetwork network;

  /// For test messages only.
  final String label;

  String? _serviceType;

  /// The name this phone announces, such as 'Coach' or 'Race Timer'.
  String? name;

  bool _advertising = false;
  bool _browsing = false;
  bool _inBackground = false;

  /// Bumped at each setup, so work scheduled for an earlier one is dropped.
  int _generation = 0;

  final Map<String, _Peer> _devices = {};
  FakeNearbyConnections? _active;

  /// A new connection layer on this phone, as `NearbyConnections()` makes.
  FakeNearbyConnections connections() => FakeNearbyConnections._(this);

  /// The phones this phone knows, as "name: state".
  List<String> get knownPeers => [
        for (final peer in _devices.values) '${peer.name}: ${peer.state.name}',
      ];

  /// iOS ends every session in the background and stops advertising and
  /// browsing until the app comes back.
  void goToBackground() {
    _inBackground = true;
    _disconnectAll();
    _devices.clear();
    _emit();
  }

  void returnToForeground() {
    _inBackground = false;
    network._refreshDiscovery();
  }

  void _setup(String serviceType, String deviceName) {
    _stopAdvertising();
    _stopBrowsing();
    _disconnectAll();
    _devices.clear();
    _generation++;
    _serviceType = serviceType;
    name = deviceName;
    _emit();
  }

  void _startAdvertising() {
    _advertising = true;
    network._refreshDiscovery();
  }

  void _stopAdvertising() {
    if (!_advertising) return;
    _advertising = false;
    network._refreshDiscovery();
  }

  void _startBrowsing() {
    _browsing = true;
    network._refreshDiscovery();
  }

  void _stopBrowsing() {
    if (!_browsing) return;
    _browsing = false;
    _disconnectAll();
    _emit();
  }

  void _disconnectAll() {
    for (final peer in _devices.values) {
      _disconnect(peer, emit: false);
    }
  }

  void _disconnect(_Peer peer, {bool emit = true}) {
    if (peer.state == SessionState.notConnected) return;
    final session = peer.session;
    peer.state = SessionState.notConnected;
    final remote = network._phoneNamed(peer.name, _serviceType ?? '');
    final back = remote?._devices[name];
    if (back != null && back.session == session) {
      back.state = SessionState.notConnected;
      remote!._emit();
    }
    if (emit) _emit();
  }

  void _invite(String deviceId) {
    final peer = _devices[deviceId];
    if (peer == null || peer.state != SessionState.notConnected) return;
    final session = network._nextSession++;
    peer
      ..state = SessionState.connecting
      ..session = session;
    _emit();

    final remote = network._advertiserNamed(deviceId, _serviceType ?? '');
    if (remote == null) {
      Timer(network.inviteTimeout, () {
        if (peer.session == session &&
            peer.state == SessionState.connecting) {
          peer.state = SessionState.notConnected;
          _emit();
        }
      });
      return;
    }

    // The advertiser accepts at once: a phone inviting again has lost the
    // last session, so that side of it ends first.
    final existing = remote._devices[name];
    if (existing != null) remote._disconnect(existing, emit: false);
    final back = _Peer(name!)
      ..state = SessionState.connecting
      ..session = session;
    remote._devices[name!] = back;
    remote._emit();

    Timer(network.connectDelay, () {
      if (peer.session != session || back.session != session) return;
      if (peer.state != SessionState.connecting ||
          back.state != SessionState.connecting) {
        return;
      }
      peer.state = SessionState.connected;
      back.state = SessionState.connected;
      _emit();
      remote._emit();
    });
  }

  bool _send(String deviceId, String message) {
    final peer = _devices[deviceId];
    if (peer == null || peer.state != SessionState.connected) return false;
    final remote = network._phoneNamed(deviceId, _serviceType ?? '');
    final back = remote?._devices[name];
    if (remote == null ||
        back == null ||
        back.session != peer.session ||
        back.state != SessionState.connected) {
      return false;
    }
    if (network.loseMessage?.call(this, remote, message) ?? false) {
      return true;
    }
    final session = peer.session;
    final from = name!;
    Timer(network.messageDelay, () {
      // Lost if the connection ended on the way.
      if (back.session != session ||
          back.state != SessionState.connected) {
        return;
      }
      network.delivered.add('$from -> ${remote.name}');
      remote._active?._data.add(<String, dynamic>{
        'deviceId': deviceId,
        'senderDeviceId': from,
        'message': message,
      });
    });
    return true;
  }

  void _emit() {
    final list = [
      for (final peer in _devices.values)
        Device(peer.name, peer.name, peer.state.index),
    ];
    _active?._state.add(list);
  }
}

/// A phone's connection layer, as `NearbyConnections` is in the app.
class FakeNearbyConnections implements NearbyConnectionsInterface {
  FakeNearbyConnections._(this.phone);

  final FakePhone phone;
  final _state = StreamController<List<Device>>.broadcast(sync: true);
  final _data = StreamController<dynamic>.broadcast(sync: true);

  @override
  Future<dynamic> init({
    required String serviceType,
    String? deviceName,
    required Strategy strategy,
    required Function callback,
  }) async {
    phone._active = this;
    phone._setup(serviceType, deviceName ?? '');
    // The iOS plugin reports running a second later.
    await Future<void>.delayed(const Duration(seconds: 1));
    callback(true);
  }

  @override
  FutureOr<dynamic> startAdvertisingPeer() {
    phone._startAdvertising();
  }

  @override
  FutureOr<dynamic> stopAdvertisingPeer() {
    phone._stopAdvertising();
  }

  @override
  FutureOr<dynamic> startBrowsingForPeers() {
    phone._startBrowsing();
  }

  @override
  FutureOr<dynamic> stopBrowsingForPeers() {
    phone._stopBrowsing();
  }

  @override
  FutureOr<dynamic> invitePeer(
      {required String deviceID, required String deviceName}) {
    phone._invite(deviceID);
  }

  @override
  FutureOr<dynamic> disconnectPeer({required String deviceID}) {
    final peer = phone._devices[deviceID];
    if (peer != null) phone._disconnect(peer);
  }

  @override
  FutureOr<dynamic> sendMessage(String deviceID, String message) =>
      phone._send(deviceID, message);

  @override
  StreamSubscription<dynamic> stateChangedSubscription(
          {required dynamic Function(List<Device>) callback}) =>
      _state.stream.listen(callback);

  @override
  StreamSubscription<dynamic> dataReceivedSubscription(
          {required dynamic Function(dynamic) callback}) =>
      _data.stream.listen(callback);
}

class _IOS implements PlatformCheckerInterface {
  const _IOS();
  @override
  bool get isAndroid => false;
  @override
  bool get isIOS => true;
}

/// A sharing screen open on a phone: the real service, protocol and
/// controller the app uses, on the phone's fake radio.
class SharingSession {
  SharingSession._(this.devices, this.service, this.controller);

  final DevicesManager devices;
  final DeviceConnectionService service;
  final WirelessConnectionController controller;

  /// Times the screen said every phone was done.
  int completions = 0;

  /// What this phone received from [from], once done.
  String? receivedFrom(DeviceName from) => devices.getDevice(from)?.data;

  ConnectionStatus? statusOf(DeviceName other) =>
      devices.getDevice(other)?.status;

  void close() => controller.dispose();
}

/// Opens a sharing screen on [phone] as [me]. An advertiser sends
/// [dataFor]'s entries to each phone named; a browser receives.
SharingSession openSharing(
  FakePhone phone,
  DeviceName me,
  DeviceType type, {
  Map<DeviceName, String> dataFor = const {},
  bool toSpectator = false,
  String? wireName,
}) {
  final devices = DeviceConnectionService.createDevices(
    me,
    type,
    data: type == DeviceType.advertiserDevice ? '' : null,
    toSpectator: toSpectator,
  );
  for (final entry in dataFor.entries) {
    devices.getDevice(entry.key)?.data = entry.value;
  }
  final service = DeviceConnectionService(
    devices,
    'wirelessconn',
    wireName ?? getDeviceWireName(me),
    type,
    phone.connections(),
    platformChecker: const _IOS(),
    nearbyConnectionsFactory: phone.connections,
  );
  late final SharingSession session;
  final controller = WirelessConnectionController(
    deviceConnectionService: service,
    protocol: Protocol(deviceConnectionService: service),
    devices: devices,
    callback: () => session.completions++,
  );
  session = SharingSession._(devices, service, controller);
  controller.initialize();
  return session;
}
