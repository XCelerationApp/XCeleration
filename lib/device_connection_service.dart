import 'dart:async';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'data_package.dart';
import 'dart:io';
import 'dart:convert';

enum DeviceType { browserDevice, advertiserDevice }


class DeviceConnectionService {
  NearbyService? nearbyService;

  StreamSubscription? deviceMonitorSubscription;
  StreamSubscription? receivedDataSubscription;
  final List<Device> _connectedDevices = [];
  final Map<String, Function(Map<String, dynamic>)> _messageCallbacks = {};

  Future<bool> checkIfNearbyConnectionsWorks() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        // Try to initialize NearbyService - this will fail if permissions are denied
        final testService = NearbyService();
        await testService.init(
          serviceType: 'test',
          deviceName: 'test',
          strategy: Strategy.P2P_STAR,
          callback: (isRunning) {},
        );
        testService.stopBrowsingForPeers();
        testService.stopAdvertisingPeer();
        return true;
      } catch (e) {
        print('Failed to initialize NearbyService: $e');
        return false;
      }
    }
    else {
      return false;
    }
  }

  Future<void> init(String serviceType, String deviceName, DeviceType deviceType) async {
    nearbyService = NearbyService();
    receivedDataSubscription = null;
    await nearbyService!.init(
      serviceType: serviceType, //'wirelessconn'
      deviceName: deviceName,
      strategy: Strategy.P2P_STAR,
      callback: (isRunning) async {
        if (isRunning) {
          if (deviceType == DeviceType.browserDevice) {
            await nearbyService!.stopBrowsingForPeers();
            await Future.delayed(Duration(microseconds: 200));
            await nearbyService!.startBrowsingForPeers();
          } else {
            await nearbyService!.stopAdvertisingPeer();
            await Future.delayed(Duration(microseconds: 200));
            await nearbyService!.startAdvertisingPeer();
          }
        }
      }
    );
  }

  Future<void> monitorDevicesConnectionStatus({
    required List<String> deviceNames, 
    Future<void> Function(Device device)? deviceLostCallback,
    Future<void> Function(Device device)? deviceFoundCallback,
    Future<void> Function(Device device)? deviceConnectingCallback,
    Future<void> Function(Device device)? deviceConnectedCallback,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    // Start monitoring

    // Subscribe to state changes
    deviceMonitorSubscription = nearbyService!.stateChangedSubscription(callback: (devicesList) async {
      for (var device in devicesList) {
        if (!deviceNames.contains(device.deviceName)) {
          return;
        }
        if (device.state == SessionState.notConnected) {
          if (_connectedDevices.contains(device)) {
            _connectedDevices.remove(device);
            await deviceLostCallback?.call(device);
          }
        }
        await deviceFoundCallback?.call(device);
        if (device.state == SessionState.connecting) {
          await deviceConnectingCallback?.call(device);
        }
        else if (device.state == SessionState.connected) {
          _connectedDevices.add(device);
          await deviceConnectedCallback?.call(device);
        }   
      }
    });

    // Add a timeout to prevent indefinite waiting
    await Future.delayed(timeout);
    await deviceMonitorSubscription?.cancel();
  }

  Future<void> inviteDevice(Device device) async {
    if (device.state == SessionState.notConnected) {
      print("Device found. Sending invite...");
      await nearbyService!.invitePeer(deviceID: device.deviceId, deviceName: device.deviceName);
    } else if (device.state == SessionState.connected) {
      print("Device is already connected: ${device.deviceName}");
    } else {
      print("Device is connecting, not sending invite: ${device.state}");
    }
  }

  Future<void> disconnectDevice(Device device) async {
    if (device.state != SessionState.connected) {
      print("Device not connected");
      return;
    }
    await nearbyService!.disconnectPeer(deviceID: device.deviceId);
    print("Disconnected from device");
  }


  Future<void> sendMessageToDevice(Device device, Package package) async {
    if (nearbyService == null) {
      print("ERROR: nearbyService is null");
      throw Exception("NearbyService not initialized");
    }
    
    if (device.state != SessionState.connected) {
      print("Device not connected - Cannot send message");
      return;
    }
    print("Sending message to device ${device.deviceName}: ${package.toString()}");
    try {
      await nearbyService!.sendMessage(device.deviceId, package.toString());
      print("Message sent successfully to ${device.deviceName}");
    } catch (e) {
      print("Error sending message to ${device.deviceName}: $e");
      rethrow;
    }
  }

  void monitorMessageReceives(Device device, {required Function(Package, String) messageReceivedCallback}) {
    print("Setting up message monitoring for device: ${device.deviceName}");
    
    // Store the callback for this specific device
    _messageCallbacks[device.deviceId] = (Map<String, dynamic>? data) async {
      try {
        print("Raw data received: $data");
        if (data == null || !data.containsKey('message') || !data.containsKey('senderDeviceId')) {
          print('Received invalid data format: $data');
          return;
        }

        // Parse the message string into a Package object
        try {
          print("Attempting to parse message: ${data['message']}");
          final packageJson = jsonDecode(data['message']);
          if (packageJson is! Map<String, dynamic>) {
            print('Invalid package format: not a JSON object');
            return;
          }
          
          final package = Package.fromJson(packageJson);
          print("Successfully parsed package: ${package.type}");
          await messageReceivedCallback(package, data['senderDeviceId']);
        } catch (e) {
          print('Error parsing package: $e');
        }
      } catch (e) {
        print('Error processing received data: $e');
      }
    };

    // Only set up the subscription once
    if (receivedDataSubscription == null) {
      print("Creating new data subscription");
      receivedDataSubscription = nearbyService!.dataReceivedSubscription(callback: (data) async {
        print("Data received in subscription: $data");
        try {
          final callback = _messageCallbacks[data['senderDeviceId']];
          if (callback != null) {
            await callback(data);
          } else {
            print("No callback found for device ID: ${data['senderDeviceId']}");
          }
        } catch (e) {
          print('Error in data received subscription: $e');
        }
      });
    } else {
      print("Using existing data subscription");
    }
  }

  void dispose() {
    receivedDataSubscription?.cancel();
    receivedDataSubscription = null;
    _messageCallbacks.clear();
    nearbyService?.stopBrowsingForPeers();
    nearbyService?.stopAdvertisingPeer();
    deviceMonitorSubscription?.cancel();
    for (var device in _connectedDevices) {
      disconnectDevice(device);
    }
    _connectedDevices.clear();
  }
}