import 'dart:async';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:xceleration/core/services/nearby_connections.dart';
import '../utils/enums.dart';
import '../utils/data_package.dart';
import 'package:flutter/foundation.dart';
import '../utils/connection_utils.dart';
import '../utils/connection_interfaces.dart';
import '../utils/platform_checker.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/app_error.dart';

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
  final bool _toSpectator;

  ConnectedDevice? _coach;
  ConnectedDevice? _bibRecorder;
  ConnectedDevice? _raceTimer;
  ConnectedDevice? _spectator;

  /// Creates a device manager for the current device name and type
  ///
  /// If the device is an advertiser, data must be provided
  DevicesManager(this._currentDeviceName, this._currentDeviceType,
      {String? data, bool toSpectator = false})
      : _data = data,
        _toSpectator = toSpectator {
    _initializeDevices();
  }

  void _initializeDevices() {
    if (_currentDeviceType == DeviceType.advertiserDevice) {
      if (_data == null) {
        throw Exception(
            'Data to transfer must be provided for advertiser devices');
      }

      if (_currentDeviceName == DeviceName.coach && !_toSpectator) {
        _coach = ConnectedDevice(DeviceName.coach);

        final List<String> parts = _data!.split('  ');
        late String bibData;
        late String timerData;
        if (parts.length != 2) {
          bibData = '';
          timerData = '';
        } else {
          bibData = parts[0];
          timerData = parts[1];
        }
        _bibRecorder = ConnectedDevice(DeviceName.bibRecorder, data: bibData);
        _raceTimer = ConnectedDevice(DeviceName.raceTimer, data: timerData);
      } else if (_currentDeviceName == DeviceName.coach && _toSpectator) {
        _coach = ConnectedDevice(DeviceName.coach);
        _spectator = ConnectedDevice(DeviceName.spectator, data: _data);
      } else if (_currentDeviceName == DeviceName.bibRecorder) {
        _bibRecorder = ConnectedDevice(DeviceName.bibRecorder);
        _coach = ConnectedDevice(DeviceName.coach, data: _data);
      } else if (_currentDeviceName == DeviceName.raceTimer) {
        _raceTimer = ConnectedDevice(DeviceName.raceTimer);
        _coach = ConnectedDevice(DeviceName.coach, data: _data);
      } else if (_currentDeviceName == DeviceName.spectator && !_toSpectator) {
        _spectator = ConnectedDevice(DeviceName.spectator);
        _coach = ConnectedDevice(DeviceName.coach, data: _data);
      } else if (_currentDeviceName == DeviceName.spectator && _toSpectator) {
        _spectator = ConnectedDevice(DeviceName.spectator, data: _data);
      }
    } else {
      if (_currentDeviceName == DeviceName.coach) {
        _coach = ConnectedDevice(DeviceName.coach);
        _bibRecorder = ConnectedDevice(DeviceName.bibRecorder);
        _raceTimer = ConnectedDevice(DeviceName.raceTimer);
      } else if (_currentDeviceName == DeviceName.spectator) {
        // Spectator receiving: choose either Coach or Spectator based on flag
        if (_toSpectator) {
          _spectator = ConnectedDevice(DeviceName.spectator);
        } else {
          _coach = ConnectedDevice(DeviceName.coach);
        }
      } else if (_currentDeviceName == DeviceName.bibRecorder) {
        _bibRecorder = ConnectedDevice(DeviceName.bibRecorder);
        _coach = ConnectedDevice(DeviceName.coach);
      } else if (_currentDeviceName == DeviceName.raceTimer) {
        _raceTimer = ConnectedDevice(DeviceName.raceTimer);
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

  /// Get the spectator device if available
  ConnectedDevice? get spectator => _spectator;

  /// Whether coach is targeting spectator broadcast mode
  bool get toSpectator => _toSpectator;

  /// Get all connected devices (non-null only)
  List<ConnectedDevice> get devices => [
        ?_coach,
        ?_bibRecorder,
        ?_raceTimer,
        ?_spectator,
      ];

  List<ConnectedDevice> get otherDevices {
    // Spectator flows can target another spectator. In those cases, include
    // same-role devices instead of filtering them out.
    final isSpectator = _currentDeviceName == DeviceName.spectator;
    final isBrowser = _currentDeviceType == DeviceType.browserDevice;
    final isAdvertiserToSpectator =
        _currentDeviceType == DeviceType.advertiserDevice && _toSpectator;

    if (isSpectator && (isBrowser || isAdvertiserToSpectator)) {
      return devices;
    }

    return devices
        .where((device) => device.name != _currentDeviceName)
        .toList();
  }

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
    return DevicesManager(_currentDeviceName, _currentDeviceType,
        data: _data, toSpectator: _toSpectator);
  }
}

/// Service to manage device connections
class DeviceConnectionService implements DeviceConnectionServiceInterface {
  // Permanent settings
  final int maxReconnectionAttempts = 8;
  Duration rescanBackoff = const Duration(seconds: 7);

  // External service for nearby connections
  final NearbyConnectionsInterface _nearbyConnections;
  final PlatformCheckerInterface _platformChecker;
  final NearbyConnectionsInterface Function() _nearbyConnectionsFactory;
  bool nearbyConnectionsInitialized = false;

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

  // Device status callbacks
  Future<void> Function(Device device)? _deviceFoundCallback;
  Future<void> Function(Device device)? _deviceConnectingCallback;
  Future<void> Function(Device device)? _deviceConnectedCallback;
  Duration _monitorTimeout = const Duration(seconds: 60);
  Future<void> Function()? _timeoutCallback;

  DeviceConnectionService(
    this._devicesManager,
    this._serviceType,
    this._deviceName,
    this._deviceType,
    this._nearbyConnections, {
    PlatformCheckerInterface? platformChecker,
    NearbyConnectionsInterface Function()? nearbyConnectionsFactory,
  })  : _platformChecker = platformChecker ?? const PlatformChecker(),
        _nearbyConnectionsFactory =
            nearbyConnectionsFactory ?? NearbyConnections.new;

  @override
  bool get isActive => !_isDisposed;

  /// Creates a cancellation token for an operation that can be cancelled
  String _createCancellationToken(String operationName) {
    final token = '${operationName}_${DateTime.now().millisecondsSinceEpoch}';
    _cancellationCompleters[token] = Completer<void>();
    return token;
  }

  /// Checks if an operation with the given token should be cancelled
  bool _shouldCancel(String token) {
    return _isDisposed ||
        (_cancellationCompleters[token]?.isCompleted ?? false);
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
  void _debounceCallback(String deviceId, Function callback,
      {Duration duration = const Duration(milliseconds: 300)}) {
    if (_debounceTimers.containsKey(deviceId)) {
      _debounceTimers[deviceId]?.cancel();
    }

    _debounceTimers[deviceId] = Timer(duration, () {
      callback();
      _debounceTimers.remove(deviceId);
    });
  }

  /// Check if nearby connections functionality works on this device
  @override
  Future<Result<bool>> checkIfNearbyConnectionsWorks(
      {Duration timeout = const Duration(seconds: 5)}) async {
    // Don't proceed if the service is disposed
    if (_isDisposed) return const Success(false);

    final token = _createCancellationToken('check_nearby');
    final completer = Completer<bool>();

    try {
      if (_platformChecker.isAndroid || _platformChecker.isIOS) {
        // Create timeout timer
        final timer = Timer(timeout, () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        });

        try {
          // Try to initialize NearbyConnections - this will fail if permissions are denied
          final testService = _nearbyConnectionsFactory();
          await testService.init(
            serviceType: 'test',
            deviceName: 'test',
            strategy: Strategy.P2P_STAR,
            callback: (isRunning) {
              if (!completer.isCompleted) {
                nearbyConnectionsInitialized = true;
                completer.complete(isRunning as bool);
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

          return Success(await completer.future);
        } catch (e) {
          Logger.e('Failed to initialize NearbyConnections: $e');
          timer.cancel();
          return Failure(AppError(
            userMessage: 'Failed to check nearby connections availability.',
            originalException: e,
          ));
        }
      } else {
        return const Success(false);
      }
    } finally {
      _cleanupToken(token);
    }
  }

  /// Initialize the connection service
  @override
  Future<Result<bool>> init() async {
    // Don't proceed if the service is disposed
    if (_isDisposed) return const Success(false);

    Logger.d('Initializing connection service');

    // Clean up any existing resources first
    _cleanupResources();

    final token = _createCancellationToken('init');
    final completer = Completer<bool>();

    try {
      await _nearbyConnections.init(
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
                await _nearbyConnections.stopBrowsingForPeers();
                await Future.delayed(const Duration(milliseconds: 200));
                if (_shouldCancel(token)) {
                  completer.complete(false);
                  return;
                }
                await _nearbyConnections.startBrowsingForPeers();
              } else {
                await _nearbyConnections.stopAdvertisingPeer();
                await Future.delayed(const Duration(milliseconds: 200));
                if (_shouldCancel(token)) {
                  completer.complete(false);
                  return;
                }
                await _nearbyConnections.startAdvertisingPeer();
              }

              nearbyConnectionsInitialized = true;
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            } catch (e) {
              Logger.e('Error during initialization: $e');
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            }
          });

      // Set a timeout to prevent hanging
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          Logger.d('Init timeout reached');
          completer.complete(false);
        }
      });

      return Success(await completer.future);
    } catch (e) {
      Logger.e('Error initializing NearbyConnections: $e');
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return Failure(AppError(
        userMessage: 'Failed to initialize connection service.',
        originalException: e,
      ));
    } finally {
      _cleanupToken(token);
    }
  }

  /// Whether to start looking again from scratch. Only a phone that browses
  /// does this, and only while it has found none of the phones it wants.
  /// Restarting while a phone was found broke the invitation in progress,
  /// and an advertiser restarting made every browser lose it.
  bool _shouldRescan(String token) {
    if (_shouldCancel(token)) return false;
    if (_deviceType != DeviceType.browserDevice) return false;
    if (_rescanAttempts >= maxReconnectionAttempts) return false;
    // A wanted phone is in sight, perhaps about to be invited.
    if (_deviceStateMap.isNotEmpty) return false;
    for (final device in _devicesManager.otherDevices) {
      if (device.isFinished) continue;
      if (device.status != ConnectionStatus.searching) return false;
    }
    return !_devicesManager.allDevicesFinished();
  }

  /// Looks again from scratch after [rescanBackoff], if nothing was found.
  void _delayedRescan(String token) {
    _stagnationTimer?.cancel();
    _stagnationTimer = Timer(rescanBackoff, () async {
      if (!_shouldRescan(token)) return;
      _rescanAttempts++;
      Logger.d('Rescan attempt $_rescanAttempts');
      final attempts = _rescanAttempts;
      await init();
      _rescanAttempts = attempts;
      if (_isDisposed || _sessionDone.isCompleted) return;
      await _monitor();
    });
  }

  /// Completes when this search ends: it timed out, or was stopped or
  /// disposed. A rescan does not end it.
  Completer<void> _sessionDone = Completer<void>()..complete();
  Timer? _sessionTimer;

  /// How long a search may go on while a transfer is still running when the
  /// time is up, before it is checked again.
  static const _transferGrace = Duration(seconds: 30);

  void _startSessionTimer(Duration after) {
    _sessionTimer?.cancel();
    if (after <= Duration.zero) return;
    _sessionTimer = Timer(after, () {
      if (_isDisposed || _sessionDone.isCompleted) return;
      // Never cut off a transfer that is under way.
      final busy = _devicesManager.otherDevices.any((d) =>
          d.status == ConnectionStatus.connecting ||
          d.status == ConnectionStatus.connected ||
          d.status == ConnectionStatus.sending ||
          d.status == ConnectionStatus.receiving);
      if (busy) {
        _startSessionTimer(_transferGrace);
        return;
      }
      _endSession();
      _timeoutCallback?.call();
    });
  }

  void _endSession() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _stagnationTimer?.cancel();
    for (final token in _cancellationCompleters.keys.toList()) {
      if (token.startsWith('monitor_devices')) _cancelOperation(token);
    }
    if (!_sessionDone.isCompleted) _sessionDone.complete();
  }

  /// Watches for the other phones until the search ends: [timeout] passes
  /// (then [timeoutCallback] is called), or the service is stopped or
  /// disposed. It does not return at a rescan: it used to, and the caller
  /// took that as the end and ignored every phone found afterwards.
  @override
  Future<void> monitorDevicesConnectionStatus({
    Future<void> Function(Device device)? deviceFoundCallback,
    Future<void> Function(Device device)? deviceConnectingCallback,
    Future<void> Function(Device device)? deviceConnectedCallback,
    Duration timeout = const Duration(seconds: 60),
    Future<void> Function()? timeoutCallback,
  }) async {
    if (deviceFoundCallback != null) _deviceFoundCallback = deviceFoundCallback;
    if (deviceConnectingCallback != null) {
      _deviceConnectingCallback = deviceConnectingCallback;
    }
    if (deviceConnectedCallback != null) {
      _deviceConnectedCallback = deviceConnectedCallback;
    }
    _monitorTimeout = timeout;
    if (timeoutCallback != null) _timeoutCallback = timeoutCallback;
    if (_isDisposed) return;

    _sessionDone = Completer<void>();
    _startSessionTimer(_monitorTimeout);
    unawaited(_monitor());
    await _sessionDone.future;
  }

  /// One stretch of watching, until a rescan or the end of the search.
  Future<void> _monitor() async {
    if (_isDisposed || _sessionDone.isCompleted) return;
    if (!nearbyConnectionsInitialized) {
      Logger.d('NearbyConnections is not initialized');
      await init();
      if (!nearbyConnectionsInitialized) {
        Logger.d('NearbyConnections is still not initialized');
        return;
      }
    }

    final token = _createCancellationToken('monitor_devices');
    _monitorToken = token;

    try {
      // One subscription for the whole search, kept through rescans: a phone
      // reported while a rescan was starting up used to be missed.
      deviceMonitorSubscription ??=
          _nearbyConnections.stateChangedSubscription(callback: (devicesList) {
        _lastDevices = devicesList;
        final current = _monitorToken;
        if (current != null) return _handleDevices(devicesList, current);
      });

      // Look again from scratch if nothing turns up.
      _delayedRescan(token);

      // The latest list, in case it came while no stretch was watching.
      if (_lastDevices.isNotEmpty) {
        await _handleDevices(_lastDevices, token);
      }

      while (!_shouldCancel(token)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      Logger.e('Error monitoring device connections: $e');
    } finally {
      if (_monitorToken == token) _monitorToken = null;
      _cleanupToken(token);
    }
  }

  /// The stretch of watching now running, whose token new lists are
  /// handled under.
  String? _monitorToken;

  /// The last list of phones reported.
  List<Device> _lastDevices = const [];

  /// Updates each wanted phone's status from [devicesList], and invites or
  /// sends through the callbacks.
  Future<void> _handleDevices(List<Device> devicesList, String token) async {
    final otherDeviceNames =
        _devicesManager.otherDevices.map((device) => device.name).toSet();
    if (_shouldCancel(token)) return;

    // Every list is handled, even one that starts a rescan: a phone
    // found in a skipped list was never invited.
    if (_shouldRescan(token)) {
      if (_stagnationTimer?.isActive != true) _delayedRescan(token);
    } else if (_devicesManager.otherDevices
        .any((d) => d.status != ConnectionStatus.searching)) {
      _stagnationTimer?.cancel();
      _rescanAttempts = 0;
    }

    final Map<String, Device> currentDevices = {};

    for (var device in devicesList) {
      if (_shouldCancel(token)) return;

      // Skip devices not in our target list. The name is read the same
      // way it is below, so a phone that passes here is always matched.
      final deviceName = tryDeviceNameFromString(device.deviceName);
      if (deviceName == null || !otherDeviceNames.contains(deviceName)) {
        continue;
      }

      currentDevices[device.deviceId] = device;

      final existingDevice = _deviceStateMap[device.deviceId];
      final bool isNewDevice = existingDevice == null;
      final bool stateChanged =
          !isNewDevice && existingDevice.state != device.state;

      _deviceStateMap[device.deviceId] = device;

      final connectedDevice = _devicesManager.getDevice(deviceName);

      if (connectedDevice == null ||
          connectedDevice.isFinished ||
          connectedDevice.status == ConnectionStatus.error) {
        continue;
      }

      if (device.state == SessionState.notConnected) {
        if (isNewDevice || stateChanged) {
          // Debounced so a quick flicker does not show in the list.
          _debounceCallback(device.deviceId, () async {
            if (_shouldCancel(token)) return;
            // It may have started connecting in the meantime: acting
            // on the old state set it back to found mid-connection.
            if (_deviceStateMap[device.deviceId]?.state !=
                SessionState.notConnected) {
              return;
            }
            if (connectedDevice.isFinished ||
                connectedDevice.status == ConnectionStatus.error) {
              return;
            }
            connectedDevice.status = ConnectionStatus.found;
            if (_deviceFoundCallback != null) {
              await _deviceFoundCallback!(device);
            }
          });
        }
      } else if (device.state == SessionState.connecting) {
        if (connectedDevice.status != ConnectionStatus.connecting) {
          connectedDevice.status = ConnectionStatus.connecting;
        }
        if (_deviceConnectingCallback != null) {
          await _deviceConnectingCallback!(device);
        }
      } else if (device.state == SessionState.connected) {
        if ((isNewDevice || stateChanged) && !_shouldCancel(token)) {
          _reconnectionAttempts.remove(device.deviceId);
          if (connectedDevice.status != ConnectionStatus.connected) {
            connectedDevice.status = ConnectionStatus.connected;
          }
          if (_deviceConnectedCallback != null) {
            await _deviceConnectedCallback!(device);
          }
        }
      }
    }

    // A phone that dropped out of the list is looked for again. Kept
    // in the map, it was not "new" when it came back, so it was never
    // invited again.
    for (final id in _deviceStateMap.keys.toList()) {
      if (currentDevices.containsKey(id)) continue;
      final gone = _deviceStateMap.remove(id)!;
      _debounceTimers.remove(id)?.cancel();
      final name = tryDeviceNameFromString(gone.deviceName);
      final connectedDevice =
          name == null ? null : _devicesManager.getDevice(name);
      if (connectedDevice == null ||
          connectedDevice.isFinished ||
          connectedDevice.status == ConnectionStatus.error) {
        continue;
      }
      connectedDevice.status = ConnectionStatus.searching;
    }
  }

  /// Ends the search without disposing the service, so it can be started
  /// again, as Try again does after a time-out.
  void stop() {
    _endSession();
    _stopWatching();
    _cleanupResources();
    nearbyConnectionsInitialized = false;
  }

  /// Stops listening for the list of phones. A rescan keeps listening.
  void _stopWatching() {
    deviceMonitorSubscription?.cancel();
    deviceMonitorSubscription = null;
    _monitorToken = null;
    _lastDevices = const [];
  }

  /// Invite a device to connect with improved error handling
  @override
  Future<bool> inviteDevice(Device device) async {
    // Don't proceed if the service is disposed
    if (_isDisposed || !nearbyConnectionsInitialized) return false;

    try {
      if (device.state == SessionState.notConnected) {
        Logger.d('Inviting device ${device.deviceName}');
        await _nearbyConnections.invitePeer(
            deviceID: device.deviceId, deviceName: device.deviceName);
        return true;
      } else if (device.state == SessionState.connected) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      Logger.e('Error inviting device ${device.deviceName}: $e');
      return false;
    }
  }

  /// Attempt to reconnect to a device with exponential backoff
  Future<bool> attemptReconnection(Device device) async {
    if (_isDisposed || !nearbyConnectionsInitialized) return false;

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
    _reconnectionAttempts[deviceId] =
        (_reconnectionAttempts[deviceId] ?? 0) + 1;

    // Implement exponential backoff
    final delay = Duration(
        milliseconds: 500 * (1 << (_reconnectionAttempts[deviceId] ?? 0)));
    await Future.delayed(delay);

    // Attempt to reconnect
    return await inviteDevice(device);
  }

  /// Disconnect from a device with improved error handling
  Future<bool> disconnectDevice(Device device) async {
    // Don't proceed if the service is disposed
    if (_isDisposed || !nearbyConnectionsInitialized) return false;

    try {
      if (device.state != SessionState.connected) {
        Logger.d(
            'Device not connected, cannot disconnect from ${device.deviceName}');
        return false;
      }

      await _nearbyConnections.disconnectPeer(deviceID: device.deviceId);
      Logger.d('Disconnected from device ${device.deviceName}');
      return true;
    } catch (e) {
      Logger.e('Error disconnecting from device ${device.deviceName}: $e');
      return false;
    }
  }

  /// Send a message to a device with improved error handling and cancellation
  @override
  Future<bool> sendMessageToDevice(Device device, Package package) async {
    // Don't proceed if the service is disposed
    if (_isDisposed || !nearbyConnectionsInitialized) {
      Logger.d('Cannot send message - service inactive');
      return false;
    }

    if (device.state != SessionState.connected) {
      Logger.d(
          'Device not connected - Cannot send message to ${device.deviceName}');
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

      final sent = await _nearbyConnections.sendMessage(
          device.deviceId, package.toString());
      if (sent == false) {
        Logger.d('Could not send to ${device.deviceName}: not connected');
        return false;
      }
      Logger.d('Message sent successfully to ${device.deviceName}');
      return true;
    } catch (e) {
      Logger.e('Error sending message to ${device.deviceName}: $e');
      return false;
    } finally {
      _cleanupToken(token);
    }
  }

  /// Monitor messages received from a device with improved error handling and cancellation
  @override
  Future<String?> monitorMessageReceives(Device device,
      {required Function(Package, String) messageReceivedCallback}) async {
    // Don't proceed if the service is disposed
    if (_isDisposed || !nearbyConnectionsInitialized) {
      return null;
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
          Logger.e('Error parsing package: $e');
        }
      } catch (e) {
        Logger.e('Error processing received data: $e');
      }
    };

    // Only set up the subscription once
    if (receivedDataSubscription == null) {
      Logger.d('Creating new data subscription');
      receivedDataSubscription =
          _nearbyConnections.dataReceivedSubscription(callback: (data) async {
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
          Logger.e('Error in data received subscription: $e');
        }
      });
    } else {
      Logger.d('Using existing data subscription');
    }

    return token;
  }

  /// Stop monitoring messages for a specific operation
  @override
  void stopMessageMonitoring(String token) {
    if (token.isNotEmpty) {
      _cancelOperation(token);
    }
  }

  /// Clean up resources without fully disposing the service
  void _cleanupResources() {
    receivedDataSubscription?.cancel();
    receivedDataSubscription = null;
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
    _nearbyConnections.stopBrowsingForPeers();
    _nearbyConnections.stopAdvertisingPeer();
  }

  /// Fully dispose the service and all resources
  @override
  void dispose() {
    if (_isDisposed) return;

    Logger.d('Disposing DeviceConnectionService');
    _isDisposed = true;

    _endSession();
    _stopWatching();
    _cleanupResources();

    // Clear all state
    nearbyConnectionsInitialized = false;
  }

  /// Creates a device manager for the specified device name and type
  /// Renamed to avoid conflict with the interface method
  static DevicesManager createDevices(
      DeviceName deviceName, DeviceType deviceType,
      {String? data, bool toSpectator = false}) {
    return DevicesManager(deviceName, deviceType,
        data: data, toSpectator: toSpectator);
  }
}
