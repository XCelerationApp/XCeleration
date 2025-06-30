import 'dart:async';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:xceleration/core/utils/connection_interfaces.dart';

/// Implementation of NearbyServiceInterface using Flutter Nearby Connections

class NearbyConnections implements NearbyConnectionsInterface {
  late final NearbyService _nearbyService;

  NearbyConnections() {
    _nearbyService = NearbyService();
  }

  @override
  Future<dynamic> init(
      {required String serviceType,
      String? deviceName,
      required Strategy strategy,
      required Function callback}) async {
    return _nearbyService.init(
        serviceType: serviceType,
        deviceName: deviceName,
        strategy: strategy,
        callback: callback);
  }

  @override
  FutureOr<dynamic> startBrowsingForPeers() async {
    return _nearbyService.startBrowsingForPeers();
  }

  @override
  FutureOr<dynamic> stopBrowsingForPeers() async {
    return _nearbyService.stopBrowsingForPeers();
  }

  @override
  FutureOr<dynamic> startAdvertisingPeer() async {
    return _nearbyService.startAdvertisingPeer();
  }

  @override
  FutureOr<dynamic> stopAdvertisingPeer() async {
    return _nearbyService.stopAdvertisingPeer();
  }

  @override
  StreamSubscription<dynamic> stateChangedSubscription(
      {required dynamic Function(List<Device>) callback}) {
    return _nearbyService.stateChangedSubscription(callback: callback);
  }

  @override
  FutureOr<dynamic> invitePeer(
      {required String deviceID, required String deviceName}) async {
    return _nearbyService.invitePeer(
        deviceID: deviceID, deviceName: deviceName);
  }

  @override
  FutureOr<dynamic> disconnectPeer({required String deviceID}) async {
    return _nearbyService.disconnectPeer(deviceID: deviceID);
  }

  @override
  FutureOr<dynamic> sendMessage(String deviceID, String message) {
    return _nearbyService.sendMessage(deviceID, message);
  }

  @override
  StreamSubscription<dynamic> dataReceivedSubscription(
      {required dynamic Function(dynamic) callback}) {
    return _nearbyService.dataReceivedSubscription(callback: callback);
  }
}
