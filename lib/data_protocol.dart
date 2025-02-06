import 'dart:async';
import 'device_connection_service.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'data_package.dart';
import 'dart:math';

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

class Protocol {
  static const int maxSendAttempts = 3;
  static const int retryTimeoutSeconds = 5;
  static const int chunkSize = 1000;
  static const int maxConcurrentTransmissions = 5;
  
  final DeviceConnectionService deviceConnectionService;
  final Map<String, Device> connectedDevices = {};  // Map of device IDs to devices
  
  final Map<String, Map<int, Package>> _receivedPackages = {};  // Map of device ID to their packages
  final Map<int, _TransmissionState> _pendingTransmissions = {};
  final StreamController<void> _terminationController = StreamController<void>();
  
  int _sequenceNumber = 0;
  bool _isFinished = false;
  bool _isTerminated = false;
  int _finishSequenceNumber = 0;
  
  final _transmissionSemaphore = StreamController<void>.broadcast();
  int _currentTransmissions = 0;

  Protocol({
    required this.deviceConnectionService,
  }) {
    for (var i = 0; i < maxConcurrentTransmissions; i++) {
      _transmissionSemaphore.add(null);
    }
  }

  void addDevice(Device device) {
    connectedDevices[device.deviceId] = device;
    _receivedPackages[device.deviceId] = {};
  }

  void removeDevice(String deviceId) {
    if (!connectedDevices.containsKey(deviceId)) return;
    connectedDevices.remove(deviceId);
    _receivedPackages.remove(deviceId);
  }

  Future<void> terminate() async {
    _isTerminated = true;
    
    for (var state in _pendingTransmissions.values) {
      state.isCancelled = true;
      state.retryTimer?.cancel();
      if (!state.completer.isCompleted) {
        state.completer.complete();
      }
    }
    
    _terminationController.add(null);
    clear();
  }

  Future<void> _handleAcknowledgment(Package package, String senderId) async {
    if (_isTerminated) return;
    
    if (package.number == _finishSequenceNumber) {
      _isFinished = true;
    }
    
    final state = _pendingTransmissions.remove(package.number);
    if (state != null) {
      state.retryTimer?.cancel();
      if (!state.completer.isCompleted) {
        state.completer.complete();
      }
    }
  }

  Future<void> _processIncomingPackage(Package package, String senderId) async {
    if (_isTerminated) return;
    
    final devicePackages = _receivedPackages[senderId];
    if (devicePackages != null && !devicePackages.containsKey(package.number)) {
      devicePackages[package.number] = package;
      
      try {
        final device = connectedDevices[senderId];
        if (device != null) {
          await deviceConnectionService.sendMessageToDevice(
            device,
            Package(number: package.number, type: 'ACK'),
          );
        }
      } catch (e) {
        if (!_isTerminated) {
          print('Failed to send acknowledgment for package ${package.number} to device $senderId: $e');
        }
      }
    }
  }

  Future<void> handleMessage(Package package, String senderId) async {
    if (_isTerminated) return;
    
    try {
      switch(package.type) {
        case 'FIN':
          await _processIncomingPackage(package, senderId);
          break;
          
        case 'ACK':
          await _handleAcknowledgment(package, senderId);
          break;
          
        case 'DATA':
          if (package.data == null || !package.checksumsMatch()) {
            if (!_isTerminated) {
              print('Invalid package from $senderId: ${package.data == null ? 'data is null' : 'checksums do not match'}');
            }
            return;
          }
          
          await _processIncomingPackage(package, senderId);
          break;
          
        default:
          if (!_isTerminated) {
            print('Unknown package type from $senderId: ${package.type}');
          }
      }
    } catch (e) {
      if (!_isTerminated) {
        print('Error handling message from $senderId: $e');
      }
    }
  }

  Future<bool> _isDeviceConnected(String senderId) async {
    final device = connectedDevices[senderId];
    return device != null;
  }

  Future<void> _sendPackageWithRetry(Package package, String senderId) async {
    if (_isTerminated) {
      throw ProtocolTerminatedException('Cannot send package - protocol is terminated');
    }

    // Check device connection before attempting to send
    if (!await _isDeviceConnected(senderId)) {
      throw Exception('Device $senderId is not connected');
    }

    // Wait for available transmission slot
    await _transmissionSemaphore.stream.first;
    _currentTransmissions++;

    final state = _TransmissionState();
    _pendingTransmissions[package.number] = state;

    void releaseTransmissionSlot() {
      _currentTransmissions--;
      _transmissionSemaphore.add(null);
    }

    Future<void> attemptSend() async {
      try {
        // Check connection again before each send attempt
        if (!state.isCancelled && await _isDeviceConnected(senderId)) {
          await deviceConnectionService.sendMessageToDevice(connectedDevices[senderId]!, package);
        } else if (!state.isCancelled) {
          throw Exception('Device disconnected during transmission');
        }
      } catch (e) {
        print('Failed to send package ${package.number} to device $senderId: $e');
        rethrow;
      }
    }

    void scheduleRetry() {
      state.retryTimer = Timer(
        Duration(seconds: retryTimeoutSeconds),
        () async {
          if (state.isCancelled) {
            releaseTransmissionSlot();
            return;
          }

          // Check connection before retry
          if (!await _isDeviceConnected(senderId)) {
            _pendingTransmissions.remove(package.number);
            state.completer.completeError('Device disconnected during retry');
            releaseTransmissionSlot();
            return;
          }

          if (state.retryCount < maxSendAttempts && !state.completer.isCompleted) {
            state.retryCount++;
            print('Retrying package ${package.number} (attempt ${state.retryCount})');
            await attemptSend();
            scheduleRetry();
          } else if (!state.completer.isCompleted) {
            _pendingTransmissions.remove(package.number);
            state.completer.completeError(
              'Failed to send package ${package.number} after $maxSendAttempts attempts'
            );
            releaseTransmissionSlot();
          }
        },
      );
    }

    _sequenceNumber++;
    await attemptSend();
    scheduleRetry();

    try {
      await state.completer.future;
      state.retryTimer?.cancel();
      releaseTransmissionSlot();

      if (_isTerminated) {
        throw ProtocolTerminatedException('Package transmission interrupted by termination');
      }
      
      if (!state.isCancelled) {
        print('Package ${package.number} acknowledged');
      }
    } catch (e) {
      releaseTransmissionSlot();
      if (_isTerminated) {
        rethrow;
      }
      if (!state.isCancelled) {
        print('Package transmission failed: $e');
        rethrow;
      }
    }
  }

  Future<void> sendData(String data, String senderId) async {
    if (_isTerminated) {
      throw ProtocolTerminatedException('Cannot send data - protocol is terminated');
    }

    if (!connectedDevices.containsKey(senderId)) {
      throw Exception('Device $senderId not connected');
    }

    try {
      // Split data into chunks
      final chunks = <String>[];
      for (var i = 0; i < data.length; i += chunkSize) {
        chunks.add(data.substring(i, min(i + chunkSize, data.length)));
      }

      // Send each chunk as a DATA package
      for (var i = 0; i < chunks.length; i++) {
        final package = Package(
          number: _sequenceNumber + i + 1,
          type: 'DATA',
          data: chunks[i],
        );
        await _sendPackageWithRetry(package, senderId);
      }

      // Send FIN package to mark end of transmission
      _finishSequenceNumber = _sequenceNumber + chunks.length + 1;
      final finPackage = Package(
        number: _finishSequenceNumber,
        type: 'FIN',
      );
      await _sendPackageWithRetry(finPackage, senderId);
      
      print('Successfully sent ${chunks.length} chunks to device $senderId');
    } catch (e) {
      if (_isTerminated) {
        rethrow;
      }
      print('Error sending data to device $senderId: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> receiveData() async {
    if (_isTerminated) {
      throw ProtocolTerminatedException('Cannot receive data - protocol is terminated');
    }

    try {
      // Wait for either completion or termination
      await Future.any([
        Future.doWhile(() async {
          if (_isFinished || _isTerminated) return false;
          await Future.delayed(Duration(milliseconds: 100)); // Reduced delay for faster response
          return true;
        }),
        _terminationController.stream.first,
      ]);

      if (_isTerminated) {
        throw ProtocolTerminatedException('Data reception interrupted');
      }

      final results = <String, String>{};
      
      for (var entry in _receivedPackages.entries) {
        final deviceId = entry.key;
        final packages = entry.value.values.toList()
          ..sort((a, b) => a.number.compareTo(b.number));
        
        // Filter only DATA packages and verify sequence
        final dataPackages = packages.where((p) => p.type == 'DATA').toList();
        
        if (dataPackages.isEmpty) {
          results[deviceId] = '';
          continue;
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
          
        if (dataChunks.isNotEmpty) {
          results[deviceId] = dataChunks.join();
        } else {
          results[deviceId] = '';
        }
      }

      return results;
    } catch (e) {
      if (_isTerminated) {
        rethrow;
      }
      print('Error receiving data: $e');
      rethrow;
    }
  }

  void clear() {
    for (var state in _pendingTransmissions.values) {
      state.retryTimer?.cancel();
    }
    
    _pendingTransmissions.clear();
    _receivedPackages.clear();
    _sequenceNumber = 0;
    _isFinished = false;
    
    // Reset transmission semaphore
    while (_currentTransmissions > 0) {
      _transmissionSemaphore.add(null);
      _currentTransmissions--;
    }
  }
  
  void dispose() {
    try {
      terminate();
    } catch (e) {
      if (e is ProtocolTerminatedException) {
        return;
      }
      print('Error terminating protocol: $e');
      rethrow;
    }
  }
}