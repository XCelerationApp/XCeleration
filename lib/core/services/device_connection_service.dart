import 'dart:async';
import 'dart:math';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import '../utils/data_package.dart';
import 'dart:io';
import '../../utils/enums.dart';
import 'package:flutter/foundation.dart';
import '../utils/connection_utils.dart';
import 'package:xceleration/core/utils/logger.dart';

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
    Logger.d('Resetting devices');
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
  
  DevicesManager copy() {
    return DevicesManager(_currentDeviceName, _currentDeviceType, data: _data);
  }
}

/// Service to manage device connections
class DeviceConnectionService {
  // Permanent settings
  final int maxReconnectionAttempts = 8;
  final int _rescanBackoffSeconds = 7;


  // External service for nearby connections
  NearbyService? _nearbyService;


  final DevicesManager _devicesManager;
  final String _serviceType;
  final String _deviceName;
  final DeviceType _deviceType;
  
  // Subscription for data received
  StreamSubscription? receivedDataSubscription;
  StreamSubscription? deviceMonitorSubscription;
  
  final Map<String, Device> _deviceStateMap = {};
  final Map<String, int> _reconnectionAttempts = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, Completer<void>> _cancellationCompleters = {};
  final Map<String, Function> _messageCallbacks = {};
  
  Timer? _stagnationTimer;
  int _rescanAttempts = 0;

  // Flag to track if service is disposed
  bool _isDisposed = false;

  DeviceConnectionService(this._devicesManager, this._serviceType, this._deviceName, this._deviceType);
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
  
  /// Debounces a callback to prevent rapid UI updates
  void _debounceCallback(String deviceId, Function callback, {Duration duration = const Duration(milliseconds: 300)}) {
    if (_debounceTimers.containsKey(deviceId)) {
      _debounceTimers[deviceId]?.cancel();
    }
    
    _debounceTimers[deviceId] = Timer(duration, () {
      callback();
      _debounceTimers.remove(deviceId);
    });
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
          Logger.d('Failed to initialize NearbyService: $e');
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
  Future<bool> init() async {
    // Don't proceed if the service is disposed
    if (_isDisposed) return false;

    debugPrint('Initializing connection service');

    // Clean up any existing resources first
    _cleanupResources();
    
    final token = _createCancellationToken('init');
    final completer = Completer<bool>();
    
    try {
      _nearbyService = NearbyService();
      
      await _nearbyService!.init(
        serviceType: _serviceType,
        deviceName: _deviceName,
        strategy: Strategy.P2P_STAR,
        callback: (isRunning) async {
          // Check if we've been disposed or cancelled while initializing
          if (_shouldCancel(token) || !isRunning) {
            completer.complete(false);
            return;
          }
          
          try {
            if (_deviceType == DeviceType.browserDevice) {
              await _nearbyService!.stopBrowsingForPeers();
              await Future.delayed(const Duration(milliseconds: 200));
              if (_shouldCancel(token)) {
                completer.complete(false);
                return;
              }
              await _nearbyService!.startBrowsingForPeers();
            } else {
              await _nearbyService!.stopAdvertisingPeer();
              await Future.delayed(const Duration(milliseconds: 200));
              if (_shouldCancel(token)) {
                completer.complete(false);
                return;
              }
              await _nearbyService!.startAdvertisingPeer();
            }
            
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          } catch (e) {
            Logger.d('Error during initialization: $e');
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
        }
      );
      
      // Set a timeout to prevent hanging
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          Logger.d('Init timeout reached');
          completer.complete(false);
        }
      });
      
      return await completer.future;
    } catch (e) {
      Logger.d('Error initializing NearbyService: $e');
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    } finally {
      _cleanupToken(token);
    }
  }

  /// Check if we should re-scan
  bool _shouldRescan() {
    if (_rescanAttempts >= maxReconnectionAttempts) {
      return false;
    }

    if (_devicesManager.devices.any((device) => device.isFinished || device.status == ConnectionStatus.connected)) {
      return false;
    }

    return true;
  }

  /// Delayed re-scan
  Future<void> _delayedRescan() async {
    _stagnationTimer?.cancel();
    final delay = _rescanBackoffSeconds;
   
    _stagnationTimer = Timer(Duration(seconds: delay), () {
      debugPrint('Rescan timer fired after $delay seconds');
      if (_shouldRescan()) {
        _rescanAttempts++;
        debugPrint('Rescan attempt $_rescanAttempts');
        final tempRescanAttempts = _rescanAttempts;
        init();
        _rescanAttempts = tempRescanAttempts;
      }
    });
  }

  /// Monitor device connection status with improved state tracking
  Future<void> monitorDevicesConnectionStatus({
    Future<void> Function(Device device)? deviceLostCallback,
    Future<void> Function(Device device)? deviceFoundCallback,
    Future<void> Function(Device device)? deviceConnectingCallback,
    Future<void> Function(Device device)? deviceConnectedCallback,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    // Don't proceed if the service is disposed
    if (_isDisposed) return; 
    if (_nearbyService == null) {
      debugPrint('NearbyService is not initialized');
      await init();
      if (_nearbyService == null) {
        debugPrint('NearbyService is still not initialized');
        return;
      }
    }
    
    final token = _createCancellationToken('monitor_devices');
  
    try {
      // Cancel any existing subscription
      await deviceMonitorSubscription?.cancel();
      
      final otherDeviceNames = _devicesManager.otherDevices
          .map((device) => getDeviceNameString(device.name))
          .toList();

      // Start rescan timer, will be cancelled if we get a device connection
      _delayedRescan();
      
      // Create a new subscription with improved state tracking
      deviceMonitorSubscription = _nearbyService!.stateChangedSubscription(callback: (devicesList) async {
      // Check if we've been cancelled
      if (_shouldCancel(token)) return;

      // Check if we should re-scan
      final shouldRescan = _shouldRescan();
      if (shouldRescan && _stagnationTimer?.isActive == false) {
        await _delayedRescan();
        return;
      } else if (!shouldRescan) {
        _stagnationTimer?.cancel();
        _rescanAttempts = 0;
      }
      
      final Map<String, Device> currentDevices = {};
      
      // First, process all devices in the new list and update their states
      for (var device in devicesList) {
        if (_shouldCancel(token)) return;
        
        // Skip if device not in target list
        if (!otherDeviceNames.contains(device.deviceName)) {
          continue; // Skip devices not in our target list
        }
        
          currentDevices[device.deviceId] = device;
          
          // Check if this is a new device or state has changed
          final existingDevice = _deviceStateMap[device.deviceId];
          final bool isNewDevice = existingDevice == null;
          final bool stateChanged = !isNewDevice && existingDevice.state != device.state;
          
          // Update our tracking map
          _deviceStateMap[device.deviceId] = device;

        final deviceName = getDeviceNameFromString(device.deviceName);
        final connectedDevice = _devicesManager.getDevice(deviceName);

        if (connectedDevice == null || connectedDevice.isFinished || connectedDevice.status == ConnectionStatus.error) {
          continue;
        }
        
          // Process different device states
          if (device.state == SessionState.notConnected) {
            // Handle device found state - new or state changed
            if (isNewDevice || stateChanged) {
              // Debounce the found callback to prevent UI flicker
              _debounceCallback(device.deviceId, () async {
                if (_shouldCancel(token)) return;
                // Update ConnectedDevice if available
                try {
                  if (connectedDevice.status != ConnectionStatus.found) {
                    connectedDevice.status = ConnectionStatus.found;
                  }
                } catch (e) {
                  // Silently handle invalid device names
                }
                if (deviceFoundCallback != null) {
                  await deviceFoundCallback(device);
                }
              });
            }
          } else if (device.state == SessionState.connecting) {
            if (_shouldCancel(token)) return;
              try {
                if (connectedDevice.status != ConnectionStatus.connecting) {
                  connectedDevice.status = ConnectionStatus.connecting;
                }
              } catch (e) {
                // Silently handle invalid device names
              }
            if (deviceConnectingCallback != null) {
              await deviceConnectingCallback(device);
            }
          } else if (device.state == SessionState.connected) {
            if ((isNewDevice || stateChanged) && !_shouldCancel(token)) {
              // Reset reconnection attempts on successful connection
              _reconnectionAttempts.remove(device.deviceId);

              try {
                if (connectedDevice.status != ConnectionStatus.connected) {
                  connectedDevice.status = ConnectionStatus.connected;
                }
              } catch (e) {
                // Silently handle invalid device names
              }
              
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
      Logger.d('Error monitoring device connections: $e');
    } finally {
      _cleanupToken(token);
    }
  }

  /// Invite a device to connect with improved error handling
  Future<bool> inviteDevice(Device device) async {
    // Don't proceed if the service is disposed
    if (_isDisposed || _nearbyService == null) return false;
    
    try {
      if (device.state == SessionState.notConnected) {
        await _nearbyService!.invitePeer(
          deviceID: device.deviceId, 
          deviceName: device.deviceName
        );
        return true;
      } else if (device.state == SessionState.connected) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      Logger.d('Error inviting device ${device.deviceName}: $e');
      return false;
    }
  }
  
  /// Attempt to reconnect to a device with exponential backoff
  Future<bool> attemptReconnection(Device device) async {
    if (_isDisposed || _nearbyService == null) return false;
    
    final deviceId = device.deviceId;
    
    // Reset attempt count if this is a new reconnection
    if (!_reconnectionAttempts.containsKey(deviceId)) {
      _reconnectionAttempts[deviceId] = 0;
    }
    
    // Check if we've reached max attempts
    if ((_reconnectionAttempts[deviceId] ?? 0) >= maxReconnectionAttempts) {
      _reconnectionAttempts.remove(deviceId);
      return false;
    }
    
    // Increment attempt count
    _reconnectionAttempts[deviceId] = (_reconnectionAttempts[deviceId] ?? 0) + 1;
    
    // Implement exponential backoff
    final delay = Duration(milliseconds: 500 * (1 << (_reconnectionAttempts[deviceId] ?? 0)));
    await Future.delayed(delay);
    
    // Attempt to reconnect
    return await inviteDevice(device);
  }

  /// Disconnect from a device with improved error handling
  Future<bool> disconnectDevice(Device device) async {
    // Don't proceed if the service is disposed
    if (_isDisposed || _nearbyService == null) return false;
    
    try {
      if (device.state != SessionState.connected) {
        Logger.d('Device not connected, cannot disconnect from ${device.deviceName}');
        return false;
      }
      
      await _nearbyService!.disconnectPeer(deviceID: device.deviceId);
      Logger.d('Disconnected from device ${device.deviceName}');
      return true;
    } catch (e) {
      Logger.d('Error disconnecting from device ${device.deviceName}: $e');
      return false;
    }
  }

  /// Send a message to a device with improved error handling and cancellation
  Future<bool> sendMessageToDevice(Device device, Package package) async {
    // Don't proceed if the service is disposed
    if (_isDisposed || _nearbyService == null) {
      Logger.d('Cannot send message - service inactive');
      return false;
    }

    if (device.state != SessionState.connected) {
      Logger.d('Device not connected - Cannot send message to ${device.deviceName}');
      return false;
    }
    
    final token = _createCancellationToken('send_message');
    
    try {
      Logger.d('Sending message to device ${device.deviceName}');
      
      // Check for cancellation
      if (_shouldCancel(token)) {
        Logger.d('Send message operation cancelled');
        return false;
      }
      
      await _nearbyService!.sendMessage(device.deviceId, package.toString());
      Logger.d('Message sent successfully to ${device.deviceName}');
      return true;
    } catch (e) {
      Logger.d('Error sending message to ${device.deviceName}: $e');
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
    if (_isDisposed || _nearbyService == null) {
      return '';
    }
    
    final token = _createCancellationToken('monitor_messages');
    Logger.d('Setting up message monitoring for device: ${device.deviceName}');

    // Store the callback for this specific device
    _messageCallbacks[device.deviceId] = (Map<String, dynamic>? data) async {
      // Check for cancellation
      if (_shouldCancel(token)) return;
      
      try {
        Logger.d('Raw data received: $data');
        if (data == null ||
            !data.containsKey('message') ||
            !data.containsKey('senderDeviceId')) {
          Logger.d('Received invalid data format: $data');
          return;
        }

        // Parse the message string into a Package object
        try {
          if (_shouldCancel(token)) return;
          
          Logger.d('Attempting to parse message: ${data['message']}');
          final String packageString = data['message'];

          final package = Package.fromString(packageString);
          Logger.d('Successfully parsed package: ${package.type}');
          
          if (!_shouldCancel(token)) {
            await messageReceivedCallback(package, data['senderDeviceId']);
          }
        } catch (e) {
          Logger.d('Error parsing package: $e');
        }
      } catch (e) {
        Logger.d('Error processing received data: $e');
      }
    };

    // Only set up the subscription once
    if (receivedDataSubscription == null) {
      Logger.d('Creating new data subscription');
      receivedDataSubscription =
          _nearbyService!.dataReceivedSubscription(callback: (data) async {
        // Check for cancellation
        if (_shouldCancel(token)) return;
            
        Logger.d('Data received in subscription: $data');
        try {
          final callback = _messageCallbacks[data['senderDeviceId']];
          if (callback != null) {
            await callback(data.cast<String, dynamic>());
          } else {
            Logger.d(
                'No callback found for device ID: ${data['senderDeviceId']}');
          }
        } catch (e) {
          Logger.d('Error in data received subscription: $e');
        }
      });
    } else {
      Logger.d('Using existing data subscription');
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
    
    // Clean up stagnation detection
    _stagnationTimer?.cancel();
    _stagnationTimer = null;
    
    // Disconnect from all devices in the state map
    final devicesCopy = _deviceStateMap.values.toList();
    for (var device in devicesCopy) {
      disconnectDevice(device);
    }
    _deviceStateMap.clear();
    
    // Cancel all debounce timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    
    // Clear reconnection attempts
    _reconnectionAttempts.clear();

    _rescanAttempts = 0;


    for (var token in _cancellationCompleters.keys) {
      _cancelOperation(token);
    }

    _cancellationCompleters.clear();
    
    // Stop advertising and browsing
    _nearbyService?.stopBrowsingForPeers();
    _nearbyService?.stopAdvertisingPeer();
  }

  /// Fully dispose the service and all resources
  void dispose() {
    if (_isDisposed) return;
    
    Logger.d('Disposing DeviceConnectionService');
    _isDisposed = true;
    
    
    
    // Clean up resources
    _cleanupResources();
    
    // Clear all state
    _nearbyService = null;
  }

  /// Creates a device manager for the specified device name and type
  static DevicesManager createDevices(
      DeviceName deviceName, DeviceType deviceType,
      {String? data}) {
    return DevicesManager(deviceName, deviceType, data: data);
  }
}
