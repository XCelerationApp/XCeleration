import 'dart:async';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import '../utils/data_package.dart';
import 'dart:io';
import '../../utils/enums.dart';
import 'package:flutter/foundation.dart';

/// Represents a connected device with its properties
class ConnectedDevice {
  final DeviceName _deviceName;
  ConnectionStatus _status;
  String? _data;
  
  ConnectedDevice(this._deviceName, {String? data}) : 
    _status = ConnectionStatus.searching,
    _data = data;
  
  /// The name of the device
  DeviceName get name => _deviceName;
  
  /// The current connection status
  ConnectionStatus get status => _status;
  set status(ConnectionStatus value) {
    _status = value;
  }
  
  /// Data associated with this device
  String? get data => _data;
  set data(String? value) {
    _data = value;
  }
  
  /// Check if the device is finished
  bool get isFinished => _status == ConnectionStatus.finished;
  
  /// Check if the device is in error state
  bool get isError => _status == ConnectionStatus.error;

  void reset() {
    _status = ConnectionStatus.searching;
    _data = null;
  }
  
  @override
  String toString() => 'ConnectedDevice(name: $_deviceName, status: $_status, hasData: ${_data != null})';
}

/// Class to manage device connections and lists
class DevicesManager {
  final DeviceName _currentDeviceName;
  final DeviceType _currentDeviceType;
  final String? _data;

  ConnectedDevice? _coach;
  ConnectedDevice? _bibRecorder;
  ConnectedDevice? _raceTimer;
  
  /// Creates a device manager for the current device name and type
  /// 
  /// If the device is an advertiser, data must be provided
  DevicesManager(this._currentDeviceName, this._currentDeviceType, {String? data}) : _data = data {
    _initializeDevices();
  }
  
  void _initializeDevices() {
    if (_currentDeviceType == DeviceType.advertiserDevice) {
      if (_data == null) {
        throw Exception('Data to transfer must be provided for advertiser devices');
      }
      
      if (_currentDeviceName == DeviceName.coach) {
        _coach = ConnectedDevice(DeviceName.coach);
        _bibRecorder = ConnectedDevice(DeviceName.bibRecorder, data: _data);
      } else {
        _bibRecorder = ConnectedDevice(DeviceName.bibRecorder);
        _coach = ConnectedDevice(DeviceName.coach, data: _data);
      }
    } else {
      if (_currentDeviceName == DeviceName.coach) {
        _coach = ConnectedDevice(DeviceName.coach);
        _bibRecorder = ConnectedDevice(DeviceName.bibRecorder);
        _raceTimer = ConnectedDevice(DeviceName.raceTimer);
      } else {
        _bibRecorder = ConnectedDevice(DeviceName.bibRecorder);
        _coach = ConnectedDevice(DeviceName.coach);
      }
    }
  }
  
  /// Get the current device name
  DeviceName get currentDeviceName => _currentDeviceName;
  
  /// Get the current device type
  DeviceType get currentDeviceType => _currentDeviceType;
  
  /// Get the coach device if available
  ConnectedDevice? get coach => _coach;
  
  /// Get the bib recorder device if available
  ConnectedDevice? get bibRecorder => _bibRecorder;
  
  /// Get the race timer device if available
  ConnectedDevice? get raceTimer => _raceTimer;

  /// Get all connected devices (non-null only)
  List<ConnectedDevice> get devices => [
    if (_coach != null) _coach!,
    if (_bibRecorder != null) _bibRecorder!,
    if (_raceTimer != null) _raceTimer!,
  ];

  List<ConnectedDevice> get otherDevices => devices.where((device) => device.name != _currentDeviceName).toList();
  
  /// Check if a specific device exists
  bool hasDevice(DeviceName name) => otherDevices.any((device) => device.name == name);

  /// Get a specific device by name
  ConnectedDevice? getDevice(DeviceName name) {
    try {
      return devices.firstWhere((device) => device.name == name);
    } catch (e) {
      return null;
    }
  }
  
  /// Check if all managed devices have finished connecting
  bool allDevicesFinished() => otherDevices.every((device) => device.isFinished);


}

/// Service to manage device connections
class DeviceConnectionService {
  NearbyService? nearbyService;

  StreamSubscription? deviceMonitorSubscription;
  StreamSubscription? receivedDataSubscription;
  final List<Device> _connectedDevices = [];
  final Map<String, Function(Map<String, dynamic>)> _messageCallbacks = {};

  Future<bool> checkIfNearbyConnectionsWorks({Duration timeout = const Duration(seconds: 5)}) async {
    Completer<bool> completer = Completer<bool>();
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        // Try to initialize NearbyService - this will fail if permissions are denied
        final testService = NearbyService();
        await testService.init(
          serviceType: 'test',
          deviceName: 'test',
          strategy: Strategy.P2P_STAR,
          callback: (isRunning) {
            completer.complete(isRunning);
          },
        );
        Timer(timeout, () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        });
        
        return completer.future;
      } catch (e) {
        debugPrint('Failed to initialize NearbyService: $e');
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
          debugPrint('Device not in list of expected devices: ${device.deviceName}');
          continue; // Skip this device but continue processing others
        }
        
        debugPrint('Processing device ${device.deviceName} with state ${device.state}');
        
        if (device.state == SessionState.notConnected) {
          if (_connectedDevices.contains(device)) {
            _connectedDevices.remove(device);
            await deviceLostCallback?.call(device);
          }
          // Only call deviceFoundCallback for newly discovered devices
          if (!_connectedDevices.contains(device)) {
            await deviceFoundCallback?.call(device);
          }
        }
        else if (device.state == SessionState.connecting) {
          await deviceConnectingCallback?.call(device);
        }
        else if (device.state == SessionState.connected) {
          if (!_connectedDevices.contains(device)) {
            _connectedDevices.add(device);
            await deviceConnectedCallback?.call(device);
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
      debugPrint('Device found. Sending invite...');
      await nearbyService!.invitePeer(deviceID: device.deviceId, deviceName: device.deviceName);
    } else if (device.state == SessionState.connected) {
      debugPrint('Device is already connected: ${device.deviceName}');
    } else {
      debugPrint('Device is connecting, not sending invite: ${device.state}');
    }
  }

  Future<void> disconnectDevice(Device device) async {
    if (device.state != SessionState.connected) {
      debugPrint('Device not connected');
      return;
    }
    await nearbyService!.disconnectPeer(deviceID: device.deviceId);
    debugPrint('Disconnected from device');
  }


  Future<void> sendMessageToDevice(Device device, Package package) async {
    if (nearbyService == null) {
      debugPrint('ERROR: nearbyService is null');
      throw Exception('NearbyService not initialized');
    }
    
    if (device.state != SessionState.connected) {
      debugPrint('Device not connected - Cannot send message');
      return;
    }
    debugPrint('Sending message to device ${device.deviceName}}');
    try {
      await nearbyService!.sendMessage(device.deviceId, package.toString());
      debugPrint('Message sent successfully to ${device.deviceName}');
    } catch (e) {
      debugPrint('Error sending message to ${device.deviceName}: $e');
      rethrow;
    }
  }

  void monitorMessageReceives(Device device, {required Function(Package, String) messageReceivedCallback}) {
    debugPrint('Setting up message monitoring for device: ${device.deviceName}');
    
    // Store the callback for this specific device
    _messageCallbacks[device.deviceId] = (Map<String, dynamic>? data) async {
      try {
        debugPrint('Raw data received: $data');
        if (data == null || !data.containsKey('message') || !data.containsKey('senderDeviceId')) {
          debugPrint('Received invalid data format: $data');
          return;
        }

        // Parse the message string into a Package object
        try {
          debugPrint('Attempting to parse message: ${data['message']}');
          final String packageString = data['message'];
          
          final package = Package.fromString(packageString);
          debugPrint('Successfully parsed package: ${package.type}');
          await messageReceivedCallback(package, data['senderDeviceId']);
        } catch (e) {
          debugPrint('Error parsing package: $e');
        }
      } catch (e) {
        debugPrint('Error processing received data: $e');
      }
    };

    // Only set up the subscription once
    if (receivedDataSubscription == null) {
      debugPrint('Creating new data subscription');
      receivedDataSubscription = nearbyService!.dataReceivedSubscription(callback: (data) async {
        debugPrint('Data received in subscription: $data');
        try {
          final callback = _messageCallbacks[data['senderDeviceId']];
          if (callback != null) {
            await callback(data.cast<String, dynamic>());
          } else {
            debugPrint('No callback found for device ID: ${data['senderDeviceId']}');
          }
        } catch (e) {
          debugPrint('Error in data received subscription: $e');
        }
      });
    } else {
      debugPrint('Using existing data subscription');
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

  /// Creates a device manager for the specified device name and type
  static DevicesManager createDevices(
      DeviceName deviceName, 
      DeviceType deviceType, 
      {String? data}
  ) {
    return DevicesManager(deviceName, deviceType, data: data);
  }

  static Future<bool> waitForDataTransferCompletion(DevicesManager devices) async {
    final completer = Completer<bool>();
    
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (devices.allDevicesFinished()) {
        timer.cancel();
        completer.complete(true);
      }
    });
    
    return completer.future;
  }
}