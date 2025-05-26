import 'dart:async';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import '../utils/data_package.dart';
import 'dart:io';
import '../../utils/enums.dart';
import 'package:flutter/foundation.dart';

/// Represents a connected device with its properties
class ConnectedDevice extends ChangeNotifier {
  final DeviceName _deviceName;
  ConnectionStatus _status;
  String? _data;

  ConnectedDevice(this._deviceName, {String? data})
      : _status = ConnectionStatus.searching,
        _data = data;

  /// The name of the device
  DeviceName get name => _deviceName;

  /// The current connection status
  ConnectionStatus get status => _status;
  set status(ConnectionStatus value) {
    if (_status != value) {
      _status = value;
      notifyListeners();
    }
  }
  
  /// Data associated with this device
  String? get data => _data;
  set data(String? value) {
    if (_data != value) {
      _data = value;
      notifyListeners();
    }
  }

  /// Check if the device is finished
  bool get isFinished => _status == ConnectionStatus.finished;

  /// Check if the device is in error state
  bool get isError => _status == ConnectionStatus.error;

  /// Reset the device to initial state
  void reset() {
    _status = ConnectionStatus.searching;
    _data = null;
    notifyListeners();
  }

  @override
  String toString() =>
      'ConnectedDevice(name: $_deviceName, status: $_status, hasData: ${_data != null})';
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
  DevicesManager(this._currentDeviceName, this._currentDeviceType,
      {String? data})
      : _data = data {
    _initializeDevices();
  }

  void _initializeDevices() {
    if (_currentDeviceType == DeviceType.advertiserDevice) {
      if (_data == null) {
        throw Exception(
            'Data to transfer must be provided for advertiser devices');
      }

      if (_currentDeviceName == DeviceName.coach) {
        _coach = ConnectedDevice(DeviceName.coach);
        _bibRecorder = ConnectedDevice(DeviceName.bibRecorder, data: _data);
      } else if (_currentDeviceName == DeviceName.bibRecorder) {
        _bibRecorder = ConnectedDevice(DeviceName.bibRecorder);
        _coach = ConnectedDevice(DeviceName.coach, data: _data);
      } else {
        _raceTimer = ConnectedDevice(DeviceName.raceTimer);
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

  void reset() {
    debugPrint('Resetting devices');
    _initializeDevices();
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

  List<ConnectedDevice> get otherDevices =>
      devices.where((device) => device.name != _currentDeviceName).toList();

  /// Check if a specific device exists
  bool hasDevice(DeviceName name) =>
      otherDevices.any((device) => device.name == name);

  /// Get a specific device by name
  ConnectedDevice? getDevice(DeviceName name) {
    try {
      return devices.firstWhere((device) => device.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Check if all managed devices have finished connecting
  bool allDevicesFinished() =>
      otherDevices.every((device) => device.isFinished);
}

/// Service to manage device connections
class DeviceConnectionService {
  NearbyService? nearbyService;

  StreamSubscription? deviceMonitorSubscription;
  StreamSubscription? receivedDataSubscription;
  final List<Device> _connectedDevices = [];
  final Map<String, Function(Map<String, dynamic>)> _messageCallbacks = {};
  
  // Cancellation support
  final Map<String, Completer<void>> _cancellationCompleters = {};
  bool _isDisposed = false;

  /// Checks if the service can still be used (not disposed)
  bool get isActive => !_isDisposed;

  /// Creates a cancellation token for an operation that can be cancelled
  String _createCancellationToken(String operationName) {
    final token = '${operationName}_${DateTime.now().millisecondsSinceEpoch}';
    _cancellationCompleters[token] = Completer<void>();
    return token;
  }

  /// Checks if an operation with the given token should be cancelled
  bool _shouldCancel(String token) {
    return _isDisposed || (_cancellationCompleters[token]?.isCompleted ?? false);
  }

  /// Cancels an operation with the given token
  void _cancelOperation(String token) {
    if (!(_cancellationCompleters[token]?.isCompleted ?? true)) {
      _cancellationCompleters[token]?.complete();
    }
  }

  /// Cleans up a cancellation token
  void _cleanupToken(String token) {
    _cancellationCompleters.remove(token);
  }

  /// Check if nearby connections functionality works on this device
  Future<bool> checkIfNearbyConnectionsWorks({
    Duration timeout = const Duration(seconds: 5)
  }) async {
    // Don't proceed if the service is disposed
    if (_isDisposed) return false;
    
    final token = _createCancellationToken('check_nearby');
    final completer = Completer<bool>();
    
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Create timeout timer
        final timer = Timer(timeout, () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        });

        try {
          // Try to initialize NearbyService - this will fail if permissions are denied
          final testService = NearbyService();
          await testService.init(
            serviceType: 'test',
            deviceName: 'test',
            strategy: Strategy.P2P_STAR,
            callback: (isRunning) {
              if (!completer.isCompleted) {
                completer.complete(isRunning);
              }
            },
          );
          
          // Check for cancellation while waiting for result
          await Future.any([
            completer.future,
            Future.doWhile(() async {
              await Future.delayed(const Duration(milliseconds: 50));
              if (_shouldCancel(token)) {
                completer.complete(false);
                return false;
              }
              return !completer.isCompleted;
            })
          ]);
          
          // Cleanup
          timer.cancel();
          testService.stopAdvertisingPeer();
          testService.stopBrowsingForPeers();
          
          return completer.future;
        } catch (e) {
          debugPrint('Failed to initialize NearbyService: $e');
          timer.cancel();
          return false;
        }
      } else {
        return false;
      }
    } finally {
      _cleanupToken(token);
    }
  }

  /// Initialize the connection service
  Future<bool> init(
      String serviceType, String deviceName, DeviceType deviceType) async {
    // Don't proceed if the service is disposed
    if (_isDisposed) return false;
    
    final token = _createCancellationToken('init');
    final completer = Completer<bool>();
    
    try {
      // Clean up any existing resources first
      _cleanupResources();
      
      nearbyService = NearbyService();
      receivedDataSubscription = null;
      
      await nearbyService!.init(
        serviceType: serviceType,
        deviceName: deviceName,
        strategy: Strategy.P2P_STAR,
        callback: (isRunning) async {
          // Check if we've been disposed or cancelled while initializing
          if (_shouldCancel(token) || !isRunning) {
            completer.complete(false);
            return;
          }
          
          try {
            if (deviceType == DeviceType.browserDevice) {
              await nearbyService!.stopBrowsingForPeers();
              await Future.delayed(const Duration(milliseconds: 200));
              if (_shouldCancel(token)) {
                completer.complete(false);
                return;
              }
              await nearbyService!.startBrowsingForPeers();
            } else {
              await nearbyService!.stopAdvertisingPeer();
              await Future.delayed(const Duration(milliseconds: 200));
              if (_shouldCancel(token)) {
                completer.complete(false);
                return;
              }
              await nearbyService!.startAdvertisingPeer();
            }
            
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          } catch (e) {
            debugPrint('Error during initialization: $e');
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
        }
      );
      
      // Set a timeout to prevent hanging
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          debugPrint('Init timeout reached');
          completer.complete(false);
        }
      });
      
      return await completer.future;
    } catch (e) {
      debugPrint('Error initializing NearbyService: $e');
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    } finally {
      _cleanupToken(token);
    }
  }

  /// Monitor device connection status with improved cancellation support
  Future<void> monitorDevicesConnectionStatus({
    required List<String> deviceNames,
    Future<void> Function(Device device)? deviceLostCallback,
    Future<void> Function(Device device)? deviceFoundCallback,
    Future<void> Function(Device device)? deviceConnectingCallback,
    Future<void> Function(Device device)? deviceConnectedCallback,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    // Don't proceed if the service is disposed
    if (_isDisposed || nearbyService == null) return;
    
    final token = _createCancellationToken('monitor_devices');
    
    try {
      // Cancel any existing subscription
      await deviceMonitorSubscription?.cancel();
      
      // Create a new subscription
      deviceMonitorSubscription =
          nearbyService!.stateChangedSubscription(callback: (devicesList) async {
        // Check if we've been cancelled
        if (_shouldCancel(token)) return;
        
        for (var device in devicesList) {
          // Skip if we're no longer active
          if (_shouldCancel(token)) return;
          
          // Check if this is a device we're interested in
          if (!deviceNames.contains(device.deviceName)) {
            debugPrint('Device not in list of expected devices: ${device.deviceName}');
            continue; // Skip this device but continue processing others
          }

          debugPrint('Processing device ${device.deviceName} with state ${device.state}');

          if (device.state == SessionState.notConnected) {
            if (_connectedDevices.contains(device)) {
              _connectedDevices.remove(device);
              if (!_shouldCancel(token) && deviceLostCallback != null) {
                await deviceLostCallback(device);
              }
            }
            // Only call deviceFoundCallback for newly discovered devices
            if (!_connectedDevices.contains(device) && !_shouldCancel(token)) {
              if (deviceFoundCallback != null) {
                await deviceFoundCallback(device);
              }
            }
          } else if (device.state == SessionState.connecting) {
            if (!_shouldCancel(token) && deviceConnectingCallback != null) {
              await deviceConnectingCallback(device);
            }
          } else if (device.state == SessionState.connected) {
            if (!_connectedDevices.contains(device) && !_shouldCancel(token)) {
              _connectedDevices.add(device);
              if (deviceConnectedCallback != null) {
                await deviceConnectedCallback(device);
              }
            }
          }
        }
      });

      // Set a timeout that will automatically cancel monitoring
      if (timeout.inSeconds > 0) {
        Timer(timeout, () {
          if (!_shouldCancel(token)) {
            _cancelOperation(token);
          }
        });
      }
      
      // Wait for cancellation
      while (!_shouldCancel(token)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Cleanup
      await deviceMonitorSubscription?.cancel();
      deviceMonitorSubscription = null;
    } catch (e) {
      debugPrint('Error monitoring device connections: $e');
    } finally {
      _cleanupToken(token);
    }
  }

  /// Invite a device to connect with improved error handling
  Future<bool> inviteDevice(Device device) async {
    // Don't proceed if the service is disposed
    if (_isDisposed || nearbyService == null) return false;
    
    try {
      if (device.state == SessionState.notConnected) {
        debugPrint('Device found. Sending invite to ${device.deviceName}...');
        await nearbyService!.invitePeer(
          deviceID: device.deviceId, 
          deviceName: device.deviceName
        );
        return true;
      } else if (device.state == SessionState.connected) {
        debugPrint('Device is already connected: ${device.deviceName}');
        return true;
      } else {
        debugPrint('Device is connecting, not sending invite: ${device.state}');
        return false;
      }
    } catch (e) {
      debugPrint('Error inviting device ${device.deviceName}: $e');
      return false;
    }
  }

  /// Disconnect from a device with improved error handling
  Future<bool> disconnectDevice(Device device) async {
    // Don't proceed if the service is disposed
    if (_isDisposed || nearbyService == null) return false;
    
    try {
      if (device.state != SessionState.connected) {
        debugPrint('Device not connected, cannot disconnect from ${device.deviceName}');
        return false;
      }
      
      await nearbyService!.disconnectPeer(deviceID: device.deviceId);
      debugPrint('Disconnected from device ${device.deviceName}');
      return true;
    } catch (e) {
      debugPrint('Error disconnecting from device ${device.deviceName}: $e');
      return false;
    }
  }

  /// Send a message to a device with improved error handling and cancellation
  Future<bool> sendMessageToDevice(Device device, Package package) async {
    // Don't proceed if the service is disposed
    if (_isDisposed || nearbyService == null) {
      debugPrint('Cannot send message - service inactive');
      return false;
    }

    if (device.state != SessionState.connected) {
      debugPrint('Device not connected - Cannot send message to ${device.deviceName}');
      return false;
    }
    
    final token = _createCancellationToken('send_message');
    
    try {
      debugPrint('Sending message to device ${device.deviceName}');
      
      // Check for cancellation
      if (_shouldCancel(token)) {
        debugPrint('Send message operation cancelled');
        return false;
      }
      
      await nearbyService!.sendMessage(device.deviceId, package.toString());
      debugPrint('Message sent successfully to ${device.deviceName}');
      return true;
    } catch (e) {
      debugPrint('Error sending message to ${device.deviceName}: $e');
      return false;
    } finally {
      _cleanupToken(token);
    }
  }

  /// Monitor messages received from a device with improved error handling and cancellation
  String monitorMessageReceives(Device device, {
    required Function(Package, String) messageReceivedCallback
  }) {
    // Don't proceed if the service is disposed
    if (_isDisposed || nearbyService == null) {
      return '';
    }
    
    final token = _createCancellationToken('monitor_messages');
    debugPrint('Setting up message monitoring for device: ${device.deviceName}');

    // Store the callback for this specific device
    _messageCallbacks[device.deviceId] = (Map<String, dynamic>? data) async {
      // Check for cancellation
      if (_shouldCancel(token)) return;
      
      try {
        debugPrint('Raw data received: $data');
        if (data == null ||
            !data.containsKey('message') ||
            !data.containsKey('senderDeviceId')) {
          debugPrint('Received invalid data format: $data');
          return;
        }

        // Parse the message string into a Package object
        try {
          if (_shouldCancel(token)) return;
          
          debugPrint('Attempting to parse message: ${data['message']}');
          final String packageString = data['message'];

          final package = Package.fromString(packageString);
          debugPrint('Successfully parsed package: ${package.type}');
          
          if (!_shouldCancel(token)) {
            await messageReceivedCallback(package, data['senderDeviceId']);
          }
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
      receivedDataSubscription =
          nearbyService!.dataReceivedSubscription(callback: (data) async {
        // Check for cancellation
        if (_shouldCancel(token)) return;
            
        debugPrint('Data received in subscription: $data');
        try {
          final callback = _messageCallbacks[data['senderDeviceId']];
          if (callback != null) {
            await callback(data.cast<String, dynamic>());
          } else {
            debugPrint(
                'No callback found for device ID: ${data['senderDeviceId']}');
          }
        } catch (e) {
          debugPrint('Error in data received subscription: $e');
        }
      });
    } else {
      debugPrint('Using existing data subscription');
    }
    
    return token;
  }

  /// Stop monitoring messages for a specific operation
  void stopMessageMonitoring(String token) {
    if (token.isNotEmpty) {
      _cancelOperation(token);
    }
  }

  /// Clean up resources without fully disposing the service
  void _cleanupResources() {
    receivedDataSubscription?.cancel();
    receivedDataSubscription = null;
    deviceMonitorSubscription?.cancel();
    deviceMonitorSubscription = null;
    _messageCallbacks.clear();
    
    // Disconnect from all connected devices
    final devicesCopy = List<Device>.from(_connectedDevices);
    for (var device in devicesCopy) {
      disconnectDevice(device);
    }
    _connectedDevices.clear();
    
    // Stop advertising and browsing
    nearbyService?.stopBrowsingForPeers();
    nearbyService?.stopAdvertisingPeer();
  }

  /// Fully dispose the service and all resources
  void dispose() {
    if (_isDisposed) return;
    
    debugPrint('Disposing DeviceConnectionService');
    _isDisposed = true;
    
    // Cancel all pending operations
    for (var token in _cancellationCompleters.keys) {
      _cancelOperation(token);
    }
    
    // Clean up resources
    _cleanupResources();
    
    // Clear all state
    _cancellationCompleters.clear();
    nearbyService = null;
  }

  /// Creates a device manager for the specified device name and type
  static DevicesManager createDevices(
      DeviceName deviceName, DeviceType deviceType,
      {String? data}) {
    return DevicesManager(deviceName, deviceType, data: data);
  }

  /// Wait for data transfer to complete with proper cancellation support
  static Future<bool> waitForDataTransferCompletion(
      DevicesManager devices, {Duration timeout = const Duration(seconds: 30)}) async {
    final completer = Completer<bool>();
    Timer? timer;
    
    // Create a periodic timer to check completion status
    timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (devices.allDevicesFinished()) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });
    
    // Add a timeout
    if (timeout.inSeconds > 0) {
      Future.delayed(timeout, () {
        timer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
    }

    return completer.future;
  }
}
