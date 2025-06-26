import 'dart:async';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'data_package.dart';

/// Interface for the protocol layer
abstract class ProtocolInterface {
  /// Add a device to the protocol
  void addDevice(Device device);

  /// Remove a device from the protocol
  void removeDevice(String deviceId);

  /// Handle incoming message from a device
  Future<void> handleMessage(Package package, String senderId);

  /// Send data to a specific device
  Future<void> sendData(String? data, String senderId);

  /// Handle data transfer (both sending and receiving)
  Future<String?> handleDataTransfer({
    required String deviceId,
    String? dataToSend,
    bool isReceiving = false,
    required bool Function() shouldContinueTransfer,
  });

  /// Check if a device has finished its transfer
  bool isFinished(String deviceId);

  /// Terminate the protocol
  void terminate();

  /// Dispose resources
  void dispose();

  /// Check if the protocol is terminated
  bool get isTerminated;
}

/// Interface for the nearby connections service
abstract class NearbyConnectionsInterface {
  /// Initialize connections
  Future<dynamic> init(
      {required String serviceType,
      String? deviceName,
      required Strategy strategy,
      required Function callback});

  /// Start advertising for connections
  FutureOr<dynamic> startAdvertisingPeer();

  /// Start browsing for connections
  FutureOr<dynamic> startBrowsingForPeers();

  /// Stop advertising
  FutureOr<dynamic> stopAdvertisingPeer();

  /// Stop browsing
  FutureOr<dynamic> stopBrowsingForPeers();

  /// Send a message to a device
  FutureOr<dynamic> sendMessage(String deviceID, String message);

  /// Invite a device to connect
  FutureOr<dynamic> invitePeer(
      {required String deviceID, required String deviceName});

  /// Disconnect from a device
  FutureOr<dynamic> disconnectPeer({required String deviceID});

  // Data received stream
  StreamSubscription<dynamic> dataReceivedSubscription(
      {required dynamic Function(dynamic) callback});

  /// Get data received stream
  StreamSubscription<dynamic> stateChangedSubscription(
      {required dynamic Function(List<Device>) callback});
}

/// Interface for device connection management
abstract class DeviceConnectionServiceInterface {
  /// Initialize the connection service
  Future<bool> init();

  /// Check if the service can still be used (not disposed)
  bool get isActive;

  /// Monitor connection status of devices
  Future<void> monitorDevicesConnectionStatus({
    Future<void> Function(Device device)? deviceFoundCallback,
    Future<void> Function(Device device)? deviceConnectingCallback,
    Future<void> Function(Device device)? deviceConnectedCallback,
    Duration timeout = const Duration(seconds: 60),
    Future<void> Function()? timeoutCallback,
  });

  /// Send message to a device
  Future<bool> sendMessageToDevice(Device device, Package package);

  /// Monitor messages from a device
  Future<String?> monitorMessageReceives(Device device,
      {required Function(Package, String) messageReceivedCallback});

  /// Stop monitoring messages
  void stopMessageMonitoring(String token);

  /// Invite a device to connect
  Future<bool> inviteDevice(Device device);

  /// Check if nearby connections functionality works
  Future<bool> checkIfNearbyConnectionsWorks(
      {Duration timeout = const Duration(seconds: 5)});

  /// Dispose the service and release resources
  void dispose();
}
