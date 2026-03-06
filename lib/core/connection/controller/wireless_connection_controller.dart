import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/connection_utils.dart';
import 'package:xceleration/core/utils/data_protocol.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/result.dart';

class WirelessConnectionController extends ChangeNotifier {
  final DeviceConnectionService _deviceConnectionService;
  final Protocol _protocol;
  final DevicesManager _devices;
  final Function _callback;

  bool _isLoading = true;
  WirelessConnectionError? _wirelessConnectionError;
  String? _messageMonitorToken;
  Completer<void> _connectionCompleter = Completer<void>()..complete();
  bool _isDisposed = false;

  bool get isLoading => _isLoading;
  WirelessConnectionError? get wirelessConnectionError => _wirelessConnectionError;
  bool get hasError => _wirelessConnectionError != null;
  DevicesManager get devices => _devices;

  WirelessConnectionController({
    required DeviceConnectionService deviceConnectionService,
    required Protocol protocol,
    required DevicesManager devices,
    required Function callback,
  })  : _deviceConnectionService = deviceConnectionService,
        _protocol = protocol,
        _devices = devices,
        _callback = callback;

  Future<void> initialize() async {
    if (_isDisposed) return;
    _connectionCompleter = Completer<void>();

    try {
      final checkResult =
          await _deviceConnectionService.checkIfNearbyConnectionsWorks();
      final isServiceAvailable = switch (checkResult) {
        Success(:final value) => value,
        Failure() => false,
      };

      if (_isDisposed) return;

      if (!isServiceAvailable) {
        _wirelessConnectionError = WirelessConnectionError.unavailable;
        _isLoading = false;
        notifyListeners();
        return;
      }

      try {
        final initResult = await _deviceConnectionService.init();
        final initSuccess = switch (initResult) {
          Success(:final value) => value,
          Failure() => false,
        };

        if (_isDisposed) return;

        if (!initSuccess) {
          _wirelessConnectionError = WirelessConnectionError.unknown;
          _isLoading = false;
          notifyListeners();
          return;
        }

        _isLoading = false;
        notifyListeners();

        _startConnectionProcess();
      } catch (e) {
        if (_isDisposed) return;
        Logger.d('Error initializing connection service: $e');
        _wirelessConnectionError = WirelessConnectionError.unknown;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      if (_isDisposed) return;
      _wirelessConnectionError = WirelessConnectionError.unknown;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retry() async {
    _wirelessConnectionError = null;
    _isLoading = true;
    notifyListeners();
    await initialize();
  }

  void _startConnectionProcess() {
    // Don't proceed if we've been disposed
    if (_isDisposed || !_deviceConnectionService.isActive) return;

    // Start device monitoring process asynchronously
    _monitorDevices();
  }

  Future<void> _monitorDevices() async {
    try {
      await _deviceConnectionService.monitorDevicesConnectionStatus(
        deviceFoundCallback: _deviceFoundCallback,
        deviceConnectingCallback: _deviceConnectingCallback,
        deviceConnectedCallback: _deviceConnectedCallback,
        timeout: const Duration(seconds: 60),
        timeoutCallback: () async {
          if (_isDisposed) return;
          if (_devices.allDevicesFinished()) return;
          _wirelessConnectionError = WirelessConnectionError.timeout;
          _deviceConnectionService.dispose();
          _protocol.dispose();
          if (!_connectionCompleter.isCompleted) {
            _connectionCompleter.complete();
          }
          notifyListeners();
        },
      );
    } catch (e) {
      Logger.d('Error monitoring devices: $e');
    } finally {
      // Ensure we mark connection as complete when monitoring ends
      if (!_connectionCompleter.isCompleted) {
        _connectionCompleter.complete();
      }
    }
  }

  Future<void> _deviceFoundCallback(Device device) async {
    // Skip if we're disposed or the connection is complete
    if (_isDisposed || _connectionCompleter.isCompleted) return;

    final deviceName = getDeviceNameFromString(device.deviceName);
    if (!_devices.hasDevice(deviceName) ||
        _devices.getDevice(deviceName)!.isFinished) {
      return;
    }

    // Skip invite if we're an advertiser
    if (_devices.currentDeviceType == DeviceType.advertiserDevice) return;

    // Try to invite the device
    if (!_connectionCompleter.isCompleted) {
      await _deviceConnectionService.inviteDevice(device);
    }
  }

  Future<void> _deviceConnectingCallback(Device device) async {
    // Skip if we're disposed or the connection is complete
    if (_isDisposed || _connectionCompleter.isCompleted) return;

    final deviceName = getDeviceNameFromString(device.deviceName);
    if (!_devices.hasDevice(deviceName) ||
        _devices.getDevice(deviceName)!.isFinished) {
      return;
    }
    // No action needed for connecting state
  }

  Future<void> _deviceConnectedCallback(Device device) async {
    // Skip if we're disposed or the connection is complete
    if (_isDisposed || _connectionCompleter.isCompleted) return;

    final deviceName = getDeviceNameFromString(device.deviceName);
    if (!_devices.hasDevice(deviceName) ||
        _devices.getDevice(deviceName)!.isFinished) {
      return;
    }

    try {
      _protocol.addDevice(device);

      // Monitor messages with proper tracking for cleanup
      _messageMonitorToken =
          await _deviceConnectionService.monitorMessageReceives(
        device,
        messageReceivedCallback: (package, senderId) async {
          // Skip if we're disposed or the connection is complete
          if (_isDisposed || _connectionCompleter.isCompleted) return;
          await _protocol.handleMessage(package, senderId);
        },
      );

      // Get device reference once to avoid repetition
      final connectedDevice = _devices.getDevice(deviceName);
      if (connectedDevice == null) {
        Logger.d('Device not found in connected devices list');
        return;
      }

      // Determine if this is a browser device (receiving) or advertiser (sending)
      final isBrowserDevice =
          _devices.currentDeviceType == DeviceType.browserDevice;

      // Set initial status
      connectedDevice.status = isBrowserDevice
          ? ConnectionStatus.receiving
          : ConnectionStatus.sending;

      // For advertiser device, check if we have data to send
      if (!isBrowserDevice && connectedDevice.data == null) {
        Logger.d('No data for advertiser device to send');
        connectedDevice.status = ConnectionStatus.error;
        return;
      }

      final transferResult = await _protocol.handleDataTransfer(
        deviceId: device.deviceId,
        // If browser device, we're receiving; otherwise we're sending the device's data
        isReceiving: isBrowserDevice,
        dataToSend: isBrowserDevice ? null : connectedDevice.data,
        // Check if we should continue the transfer based on device status
        shouldContinueTransfer: () {
          // Only continue if the device's status is still in receiving/sending state
          if (_isDisposed) return false;
          final deviceStatus = _devices.getDevice(deviceName)?.status;
          final expectedStatus = isBrowserDevice
              ? ConnectionStatus.receiving
              : ConnectionStatus.sending;
          bool shouldContinue = deviceStatus == expectedStatus;
          if (!shouldContinue) {
            Logger.d('Device status changed: $deviceStatus != $expectedStatus');
          }
          return shouldContinue;
        },
      );

      // Skip updating UI if we're disposed
      if (_isDisposed || _connectionCompleter.isCompleted) return;

      switch (transferResult) {
        case Success(:final value):
          // Update device status and data if we're a browser device (and received data)
          if (isBrowserDevice && value != null) {
            connectedDevice.data = value;
          }
          connectedDevice.status = ConnectionStatus.finished;

          // In spectator broadcast mode (advertiser), briefly show Done then return to Searching
          if (!isBrowserDevice && _devices.toSpectator) {
            Timer(const Duration(seconds: 2), () {
              if (_isDisposed) return;
              connectedDevice.status = ConnectionStatus.searching;
            });
          }

          // Check if all devices have finished loading data
          bool allDevicesFinished = _devices.allDevicesFinished();

          // Call the callback if all devices are finished
          if (allDevicesFinished) {
            // Complete the connection to stop monitoring
            if (!_connectionCompleter.isCompleted) {
              _connectionCompleter.complete();
              _deviceConnectionService.dispose();
              _protocol.dispose();
            }
            _callback();
          }

          // For advertiser devices, disconnect after sending
          if (!isBrowserDevice) {
            Timer(const Duration(seconds: 1), () {
              if (!_isDisposed) {
                _deviceConnectionService.disconnectDevice(device);
              }
            });
          }

        case Failure(:final error):
          Logger.e('[WirelessConnectionController] ${error.originalException}');
          connectedDevice.status = ConnectionStatus.error;
      }

      // Clean up device from protocol
      _protocol.removeDevice(device.deviceId);
    } catch (e) {
      Logger.d('Error in connection: $e');
      _protocol.removeDevice(device.deviceId);
      _devices.getDevice(deviceName)?.status = ConnectionStatus.error;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_messageMonitorToken != null) {
      _deviceConnectionService.stopMessageMonitoring(_messageMonitorToken!);
    }
    if (!_connectionCompleter.isCompleted) {
      _connectionCompleter.complete();
    }
    _deviceConnectionService.dispose();
    _protocol.dispose();
    super.dispose();
  }
}
