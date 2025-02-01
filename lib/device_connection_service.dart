import 'dart:async';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'data_package.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

enum DeviceType { bibNumberDevice, raceTimerDevice }


class DeviceConnectionService {
  NearbyService? nearbyService;

  StreamSubscription? deviceMonitorSubscription;
  StreamSubscription? receivedDataSubscription;
  Device? _connectedDevice;

  Future<bool> checkIfNearbyConnectionsWorks() async {
    if (Platform.isAndroid) {
      return true;
    }
    else if (Platform.isIOS) {
      // if (!await Permission.nearbyWifiDevices.request().isGranted) {
      //   throw UnavailibleDeviceConnectionServiceException('Nearby connections permission not granted');
      // }
      return true;
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
      strategy: Strategy.P2P_POINT_TO_POINT,
      callback: (isRunning) async {
        if (isRunning) {
          if (deviceType == DeviceType.bibNumberDevice) {
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

  Future<void> monitorDeviceConnectionStatus(String deviceName, {
    Future<void> Function(Device device)? notConnectedCallback,
    Future<void> Function(Device device)? connectingToDeviceCallback,
    Future<void> Function(Device device)? connectedToDeviceCallback,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    // Start monitoring

    // Subscribe to state changes
    deviceMonitorSubscription = nearbyService!.stateChangedSubscription(callback: (devicesList) async {
      for (var device in devicesList) {
        if (device.deviceName != deviceName) {
          return;
        }
        print("Found device");
        if (device.state == SessionState.notConnected) {
          if (notConnectedCallback != null) {
            await notConnectedCallback(device);
          }
        }
        if (device.state == SessionState.connecting) {
          if (connectingToDeviceCallback != null) {
            await connectingToDeviceCallback(device);
          }
        }
        else if (device.state == SessionState.connected) {
          _connectedDevice = device;
          if (connectedToDeviceCallback != null) {
            await connectedToDeviceCallback(device);
          }
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
    _connectedDevice = null;
    print("Disconnected from device");
  }


  Future<void> sendMessageToDevice(Device device, Package package) async {
    if (device.state != SessionState.connected) {
      print("Device not connected - Cannot send message");
      return;
    }
    await nearbyService!.sendMessage(device.deviceId, package.toString());
  }

  Future<void> monitorMessageReceives(Device device, {Future<void> Function(Package)? messageReceivedCallback, Duration timeout = const Duration(seconds: 60)}) async {
    if (device.state != SessionState.connected) {
      print("Device not connected - Cannot receive message");
      return;
    }

    receivedDataSubscription = nearbyService!.dataReceivedSubscription(callback: (data) async {
      if (data['senderDeviceId'] != device.deviceId) {
        print('wrong device');
        return;
      }
      print("received message: ${data["message"]}");
      if (messageReceivedCallback != null) {
        await messageReceivedCallback(Package.fromString(data["message"]));
      }
    });
    await Future.delayed(timeout);
    await receivedDataSubscription?.cancel();
    
  }

  void dispose() {
    nearbyService?.stopBrowsingForPeers();
    nearbyService?.stopAdvertisingPeer();
    deviceMonitorSubscription?.cancel();
    receivedDataSubscription?.cancel();
    if (_connectedDevice != null) {
      disconnectDevice(_connectedDevice!);
    }
  }
}