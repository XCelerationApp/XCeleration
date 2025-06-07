import 'dart:async';
import 'dart:math';
import '../services/device_connection_service.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'data_package.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'connection_interfaces.dart';



class _TransmissionState {
  final Completer<void> completer;
  Timer? retryTimer;
  int retryCount = 0;
  bool isCancelled = false;

  _TransmissionState() : completer = Completer<void>();
}

class ProtocolTerminatedException implements Exception {
  final String message;
  ProtocolTerminatedException([this.message = 'Protocol was terminated']);

  @override
  String toString() => 'ProtocolTerminatedException: $message';
}

class Protocol implements ProtocolInterface {
  static const int maxSendAttempts = 4;
  static const int retryTimeoutSeconds = 5;
  static const int chunkSize = 1000;

  final DeviceConnectionService deviceConnectionService;
  final Map<String, Device> connectedDevices =
      {}; // Map of device IDs to devices

  final Map<String, Map<int, Package>> _receivedPackages =
      {}; // Map of device ID to their packages
  final Map<int, _TransmissionState> _pendingTransmissions = {};
  final StreamController<void> _terminationController =
      StreamController<void>.broadcast();

  int _sequenceNumber = 0;
  final List<String> _finishedDevices = [];
  bool _isTerminated = false;
  final Map<String, int> _finishSequenceNumbers = {};

  Protocol({required this.deviceConnectionService});

  @override
  void addDevice(Device device) {
    // Check if this is a reconnection of a previously known device
    final isReconnection = connectedDevices.containsKey(device.deviceId);

    if (isReconnection) {
      // Device is reconnecting, reset its state
      resetDeviceState(device.deviceId);
      Logger.d('Device ${device.deviceId} reconnected - reset transfer state');
    }

    connectedDevices[device.deviceId] = device;
    _receivedPackages[device.deviceId] = {};
    _finishSequenceNumbers[device.deviceId] = 0;
  }

  @override
  void removeDevice(String deviceId) {
    if (!connectedDevices.containsKey(deviceId)) return;
    connectedDevices.remove(deviceId);
    _receivedPackages.remove(deviceId);
    _finishSequenceNumbers.remove(deviceId);
  }

  @override
  Future<void> terminate() async {
    if (!_isTerminated) {
      _isTerminated = true;
      _terminationController.add(null);
      Logger.d('Protocol terminated');
    }
  }

  Future<void> _handleAcknowledgment(Package package, String senderId) async {
    if (_isTerminated) return;

    if (package.number == _finishSequenceNumbers[senderId]) {
      _finishedDevices.add(senderId);
    }

    Logger.d(
        'Received acknowledgment for package ${package.number} from device $senderId');

    final state = _pendingTransmissions[package.number];
    if (state != null && !state.completer.isCompleted) {
      state.completer.complete();
    }
  }

  @override
  Future<void> handleMessage(Package package, String senderId) async {
    Logger.d('Handling message from $senderId: ${package.type}');
    if (_isTerminated) return;
    if (package.type != 'ACK' &&
        package.type != 'DATA' &&
        package.type != 'FIN') {
      throw Exception('Invalid package type: ${package.type}');
    }
    Logger.d(
        '[${DateTime.now()}] Received ${package.type} package ${package.number} from $senderId');

    if (package.type == 'ACK') {
      await _handleAcknowledgment(package, senderId);
      return;
    }

    if (package.type == 'DATA' &&
        (package.data == null || !package.checksumsMatch())) {
      Logger.e('Invalid package (${package.number}) from device $senderId');
      return;
    }

    // Store the package if it's a DATA or FIN package
    if (!_receivedPackages.containsKey(senderId)) {
      _receivedPackages[senderId] = {};
    }
    _receivedPackages[senderId]![package.number] = package;

    // Send acknowledgment
    try {
      if (!_isDeviceConnected(senderId)) {
        Logger.d(
            'Cannot send acknowledgment - device $senderId not connected');
        return;
      }

      // For FIN package, mark this device as finished after sending ACK
      if (package.type == 'FIN') {
        Logger.d('[${DateTime.now()}] Received FIN package from $senderId');
        _finishSequenceNumbers[senderId] = package.number;
      }

      await deviceConnectionService.sendMessageToDevice(
        connectedDevices[senderId]!,
        Package(number: package.number, type: 'ACK'),
      );

      if (package.type == 'FIN') {
        Logger.d('[${DateTime.now()}] Marking device $senderId as finished');
        _finishedDevices.add(senderId);
      }
    } catch (e) {
      if (!_isTerminated) {
        Logger.e('Error sending acknowledgment to device $senderId: $e');
        rethrow;
      }
    }
  }

  bool _isDeviceConnected(String senderId) {
    final device = connectedDevices[senderId];
    return device != null;
  }

  Future<void> _sendPackageWithRetry(Package package, String senderId) async {
    final startTime = DateTime.now();
    Logger.d(
        '[${startTime.toString()}] Starting _sendPackageWithRetry for package ${package.number} with data ${package.data}');

    if (_isTerminated) {
      Logger.d('Protocol terminated, cannot send package');
      throw ProtocolTerminatedException(
          'Cannot send package - protocol is terminated');
    }

    final state = _TransmissionState();
    _pendingTransmissions[package.number] = state;

    Future<void> attemptSend() async {
      try {
        if (!state.isCancelled && _isDeviceConnected(senderId)) {
          final attemptTime = DateTime.now();
          Logger.d(
              '[${attemptTime.toString()}] Attempt ${state.retryCount + 1}/$maxSendAttempts to send package ${package.number} with data ${package.data}');
          await deviceConnectionService.sendMessageToDevice(
              connectedDevices[senderId]!, package);
        } else if (!state.isCancelled && !_isDeviceConnected(senderId)) {
          state.completer
              .completeError('Device disconnected during transmission');
          throw Exception('Device disconnected during transmission');
        }
      } catch (e) {
        Logger.e(
            'Failed to send package ${package.number} to device $senderId: $e');
        rethrow;
      }
    }

    void scheduleRetry() {
      state.retryTimer = Timer(
        Duration(seconds: retryTimeoutSeconds),
        () async {
          if (state.isCancelled || state.completer.isCompleted) return;

          if (state.retryCount < maxSendAttempts - 1) {
            state.retryCount++;
            final retryTime = DateTime.now();
            Logger.d(
                '[${retryTime.toString()}] Retrying package ${package.number} (attempt ${state.retryCount + 1})');
            await attemptSend();
            scheduleRetry();
          } else {
            final failTime = DateTime.now();
            Logger.e(
                '[${failTime.toString()}] Failed to send package after ${state.retryCount + 1} attempts');
            state.completer.completeError(
                'Failed to send package after ${state.retryCount + 1} attempts');
          }
        },
      );
    }

    void cleanup() {
      state.retryTimer?.cancel();
      _pendingTransmissions.remove(package.number);
    }

    Logger.d(
        '[${DateTime.now().toString()}] Starting package send attempt for ${package.type} (seq: ${package.number})');

    try {
      await attemptSend();
      scheduleRetry();

      // Wait for acknowledgment or failure
      try {
        await state.completer.future;
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        Logger.d(
            '[${endTime.toString()}] Package ${package.number} successfully sent and acknowledged after ${duration.inMilliseconds}ms');
      } catch (e) {
        final errorTime = DateTime.now();
        final duration = errorTime.difference(startTime);
        Logger.e(
            '[${errorTime.toString()}] Failed to send package ${package.number} after ${duration.inMilliseconds}ms: $e');
        rethrow;
      } finally {
        cleanup();
      }
    } catch (e) {
      cleanup();
      throw Exception('Failed to send package: $e');
    }
  }

  @override
  Future<void> sendData(String? data, String senderId) async {
    if (_isTerminated) {
      throw ProtocolTerminatedException(
          'Cannot send data - protocol is terminated');
    }

    if (!connectedDevices.containsKey(senderId)) {
      throw Exception('Device $senderId not connected');
    }

    // Check if we have data to send
    if (data == null || data.isEmpty) {
      Logger.d('Warning: No data to send to device $senderId, sending empty data placeholder');
      // Send a single empty DATA package to avoid protocol errors
      _sequenceNumber++;
      final emptyPackage = Package(
        number: _sequenceNumber,
        type: 'DATA',
        data: '', // Empty data
      );
      await _sendPackageWithRetry(emptyPackage, senderId);
      return;
    }

    try {
      Logger.d('Starting to send data to device $senderId (length: ${data.length})');
      // Split data into chunks
      final chunks = <String>[];
      for (var i = 0; i < data.length; i += chunkSize) {
        chunks.add(data.substring(i, min(i + chunkSize, data.length)));
      }
      Logger.d('Split data into ${chunks.length} chunks');

      // Send each chunk as a DATA package
      for (var i = 0; i < chunks.length; i++) {
        _sequenceNumber++;
        final package = Package(
          number: _sequenceNumber,
          type: 'DATA',
          data: chunks[i],
        );
        Logger.d('Sending chunk ${i + 1}/${chunks.length}');
        await _sendPackageWithRetry(package, senderId);
      }

      // Send FIN package to mark end of transmission
      _finishSequenceNumbers[senderId] = _sequenceNumber + 1;
      final finPackage = Package(
        number: _finishSequenceNumbers[senderId]!,
        type: 'FIN',
      );
      Logger.d('Sending FIN package');
      await _sendPackageWithRetry(finPackage, senderId);

      Logger.d(
          'Successfully sent ${chunks.length} chunks to device $senderId');
    } catch (e) {
      if (_isTerminated) {
        rethrow;
      }
      Logger.e('Error sending data to device $senderId: $e');
      rethrow;
    }
  }

  /// Comprehensive method to handle a complete data transfer with a device
  /// This method handles both sending and receiving, with automatic reconnection support
  /// Returns received data if this device is receiving, or null if this device is sending
  ///
  /// The statusChecker parameter allows the caller to abort the transfer if device status changes
  @override
  Future<String?> handleDataTransfer({
    required String deviceId,
    String? dataToSend,
    bool isReceiving = false,
    required bool Function() shouldContinueTransfer,
  }) async {
    if (_isTerminated) {
      throw ProtocolTerminatedException('Protocol is terminated');
    }

    if (!connectedDevices.containsKey(deviceId)) {
      throw Exception('Device $deviceId not connected');
    }

    // Variables to track state changes and timer
    bool lastKnownState = true;
    Timer? stateChangeTimer;
    final stateChangeTimeout = const Duration(seconds: 3);

    // Helper function to check if we should abort the transfer
    bool shouldAbort() {
      try {
        bool currentState = shouldContinueTransfer();
        
        // If protocol is terminated, abort immediately
        if (_isTerminated) {
          Logger.d('Aborting transfer because protocol is terminated');
          stateChangeTimer?.cancel();
          return true;
        }
        
        // If state hasn't changed and it's good, we're fine
        if (currentState == lastKnownState && currentState) {
          return false;
        }
        
        // If state changes
        if (currentState != lastKnownState) {
          Logger.d('Transfer state changed: $lastKnownState -> $currentState');
          
          // If changed to good state, cancel any pending timer
          if (currentState) {
            Logger.d('State recovered, cancelling abort timer');
            stateChangeTimer?.cancel();
            stateChangeTimer = null;
            lastKnownState = currentState;
            return false;
          } 
          // If changed to bad state, start the timer if not already running
          else if (stateChangeTimer == null) {
            Logger.d('State degraded, starting 3-second abort timer');
            stateChangeTimer = Timer(stateChangeTimeout, () {
              Logger.d('Abort timer triggered after ${stateChangeTimeout.inSeconds} seconds of bad state');
              // Timer trigger doesn't actually do anything - it will be checked in the next call to shouldAbort
            });
          }
          
          lastKnownState = currentState;
        }
        
        // If we have an active timer that has completed, abort
        if (stateChangeTimer != null && !stateChangeTimer!.isActive) {
          Logger.d('Aborting transfer: state remained bad for ${stateChangeTimeout.inSeconds} seconds');
          return true;
        }
        
        return false;
      } catch (e) {
        Logger.e('Error in shouldContinueTransfer: $e');
        // Start timer on error if not already running
        stateChangeTimer ??= Timer(stateChangeTimeout, () {
          Logger.d('Abort timer triggered after error condition persisted');
        });
        return false; // Don't abort immediately on error
      }
    }

    // Reset device state to ensure a clean transfer
    resetDeviceState(deviceId);
    Logger.d('Starting fresh data transfer with device $deviceId');

    try {
      // Handle sending data if we have data to send
      if (dataToSend != null && !isReceiving) {
        // Before starting to send, check if we should proceed
        await sendData(dataToSend, deviceId);
        // Add a small delay to allow state stabilization after sending data
        await Future.delayed(Duration(milliseconds: 500));
      }

      if (shouldAbort()) {
        throw ProtocolTerminatedException('Transfer aborted: device status changed');
      }

      // Wait for either completion or termination with resilience to transient state changes
      await Future.any([
        Future.doWhile(() async {
          // Check if we've finished or should terminate
          if (_finishedDevices.contains(deviceId) || _isTerminated) {
            return false;
          }
          
          // Use our robust state checker
          if (shouldAbort()) {
            // State has been bad for 3 seconds - shouldAbort will handle logging
            return false;
          }

          await Future.delayed(Duration(milliseconds: 100));
          return true;
        }),
        _terminationController.stream.first,
      ]);
      
      // Check again with our timer-based state checker
      if (shouldAbort()) {
        throw ProtocolTerminatedException('Transfer aborted: persistent device status change');
      }

      if (_isTerminated) {
        Logger.d('Data reception terminated');
        throw ProtocolTerminatedException('Data reception interrupted');
      }
      Logger.d('Data transfer complete');

      
      // Handle receiving data
      if (isReceiving) {
        // Process received packages
        Map<int, Package> packages = _receivedPackages[deviceId] ?? {};
        if (packages.isEmpty) {
          throw Exception('No packages received from $deviceId');
        }
        
        final List<Package> sortedPackages = packages.values.toList()
          ..sort((a, b) => a.number.compareTo(b.number));

        // Filter only DATA packages and verify sequence
        final List<Package> dataPackages =
            sortedPackages.where((p) => p.type == 'DATA').toList();

        if (dataPackages.isEmpty) {
          throw Exception('No DATA packages received from $deviceId');
        }

        // Verify we have all packages in sequence
        bool hasAllPackages = true;
        for (var i = 0; i < dataPackages.length; i++) {
          if (dataPackages[i].number != i + 1) {
            hasAllPackages = false;
            break;
          }
        }

        if (!hasAllPackages) {
          throw Exception('Missing packages in sequence from $deviceId');
        }

        // Combine data chunks
        final dataChunks = dataPackages
            .where((p) => p.data != null)
            .map((p) => p.data!)
            .toList();

        if (dataChunks.isEmpty) {
          throw Exception('No valid DATA packages received from $deviceId');
        }
        return dataChunks.join();
      }
      
      return null;
    } catch (e) {
      if (_isTerminated) {
        rethrow;
      }
      Logger.e('Error in data transfer with device $deviceId: $e');
      rethrow;
    } finally {
      // Always clean up the timer resource regardless of success or failure
      stateChangeTimer?.cancel();
    }
  }


  /// Resets the state for a specific device, clearing any in-progress transfers
  void resetDeviceState(String deviceId) {
    // Remove from finished devices if present
    _finishedDevices.remove(deviceId);
    
    // Clear received packages for this device
    _receivedPackages[deviceId]?.clear();
    
    // Reset finish sequence number
    _finishSequenceNumbers[deviceId] = 0;
    
    // Cancel any pending transmissions related to this device
    // This is a simplification as we don't track which transmissions are for which device
    // In a more sophisticated implementation, we would track device-specific transmissions
  }

  void clear() {
    for (var state in _pendingTransmissions.values) {
      state.retryTimer?.cancel();
    }

    _pendingTransmissions.clear();
    _receivedPackages.clear();
    _sequenceNumber = 0;
    _finishedDevices.clear();
    _finishSequenceNumbers.clear();
  }

  @override
  void dispose() {
    try {
      terminate();
      _terminationController.close();
      for (final state in _pendingTransmissions.values) {
        state.retryTimer?.cancel();
        if (!state.completer.isCompleted) {
          state.completer.completeError(
              ProtocolTerminatedException('Protocol disposed'));
        }
      }
      _pendingTransmissions.clear();
    } catch (e) {
      if (e is ProtocolTerminatedException) {
        return;
      }
      Logger.e('Error terminating protocol: $e');
      rethrow;
    }
  }
  
  /// Check if a device has finished its transfer
  @override
  bool isFinished(String deviceId) {
    return _finishedDevices.contains(deviceId);
  }
  
  /// Check if the protocol is terminated
  @override
  bool get isTerminated => _isTerminated;
}
