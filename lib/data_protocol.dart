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
  static const int maxConcurrentTransmissions = 5; // Control concurrent sends
  
  final DeviceConnectionService deviceConnectionService;
  final Device device;
  
  final Map<int, Package> _receivedPackages = {};
  final Map<int, _TransmissionState> _pendingTransmissions = {};
  final StreamController<void> _terminationController = StreamController<void>();
  
  int _sequenceNumber = 0;
  bool _isFinished = false;
  bool _isTerminated = false;
  late final int _finishSequenceNumber;
  
  // Semaphore for controlling concurrent transmissions
  final _transmissionSemaphore = StreamController<void>();
  int _currentTransmissions = 0;

  Protocol({
    required this.deviceConnectionService,
    required this.device,
  }) {
    // Initialize semaphore
    for (var i = 0; i < maxConcurrentTransmissions; i++) {
      _transmissionSemaphore.add(null);
    }
  }

  Future<void> terminate() async {
    _isTerminated = true;
    
    // Cancel all pending transmissions
    for (var state in _pendingTransmissions.values) {
      state.isCancelled = true;
      state.retryTimer?.cancel();
      if (!state.completer.isCompleted) {
        state.completer.complete(); // Complete normally for graceful shutdown
      }
    }
    
    _terminationController.add(null);
    clear();
  }

  Future<void> _handleAcknowledgment(Package package) async {
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

  Future<void> _processIncomingPackage(Package package) async {
    if (_isTerminated) return;
    
    if (!_receivedPackages.containsKey(package.number)) {
      _receivedPackages[package.number] = package;
      
      try {
        await deviceConnectionService.sendMessageToDevice(
          device,
          Package(number: package.number, type: 'ACK'),
        );
      } catch (e) {
        if (!_isTerminated) {
          print('Failed to send acknowledgment for package ${package.number}: $e');
        }
      }
    }
  }

  Future<void> handleMessage(Package package) async {
    if (_isTerminated) return;
    
    if (_isFinished) {
      print('Protocol finished - ignoring incoming message');
      return;
    }

    try {
      switch(package.type) {
        case 'FIN':
          await _processIncomingPackage(package);
          if (!_isTerminated) _isFinished = true;
          break;
          
        case 'ACK':
          await _handleAcknowledgment(package);
          break;
          
        case 'DATA':
          if (package.data == null || !package.checksumsMatch()) {
            if (!_isTerminated) {
              print('Invalid package: ${package.data == null ? 'data is null' : 'checksums do not match'}');
            }
            return;
          }
          
          await _processIncomingPackage(package);
          break;
          
        default:
          if (!_isTerminated) {
            print('Unknown package type: ${package.type}');
          }
      }
    } catch (e) {
      if (!_isTerminated) {
        print('Error handling message: $e');
      }
    }
  }

  Future<void> _sendPackageWithRetry(Package package) async {
    if (_isTerminated) {
      throw ProtocolTerminatedException('Cannot send package - protocol is terminated');
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
        if (!state.isCancelled) {
          await deviceConnectionService.sendMessageToDevice(device, package);
        }
      } catch (e) {
        print('Failed to send package ${package.number}: $e');
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

    await attemptSend();
    scheduleRetry();
    _sequenceNumber++;

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

  Future<void> _sendMessage(String message) async {
    if (_isTerminated) {
      throw ProtocolTerminatedException('Cannot send message - protocol is terminated');
    }

    final package = Package(
      number: _sequenceNumber + 1,
      type: 'DATA',
      data: message,
    );
    
    try {
      await _sendPackageWithRetry(package);
    } catch (e) {
      if (_isTerminated) {
        throw ProtocolTerminatedException('Message transmission interrupted by termination');
      }
      print('Failed to send message: $e');
      rethrow;
    }
  }

  Future<void> sendData(String data) async {
    if (_isTerminated) {
      throw ProtocolTerminatedException('Cannot send data - protocol is terminated');
    }

    final chunks = <String>[];
    for (var i = 0; i < data.length; i += chunkSize) {
      chunks.add(data.substring(i, min(i + chunkSize, data.length)));
    }

    try {
      final futures = <Future<void>>[];
      
      for (var i = 0; i < chunks.length; i++) {
        if (_isTerminated) {
          throw ProtocolTerminatedException('Data transmission interrupted during sending chunks');
        }
        final future = _sendMessage(chunks[i]);
        futures.add(future);
      }

      await Future.wait(futures);

      if (_isTerminated) {
        throw ProtocolTerminatedException('Data transmission interrupted before completion');
      }

      _finishSequenceNumber = _sequenceNumber + 1;
      await _sendPackageWithRetry(
        Package(number: _finishSequenceNumber, type: 'FIN')
      );
    } catch (e) {
      if (_isTerminated) {
        rethrow;
      }
      print('Data transmission failed: $e');
      rethrow;
    }
  }

  Future<String> receiveData() async {
    if (_isTerminated) {
      throw ProtocolTerminatedException('Cannot receive data - protocol is terminated');
    }

    try {
      await Future.any([
        Future.doWhile(() async {
          if (_isFinished || _isTerminated) return false;
          await Future.delayed(Duration(milliseconds: 500));
          return true;
        }),
        _terminationController.stream.first
      ]);

      if (_isTerminated) {
        throw ProtocolTerminatedException('Data reception interrupted by termination');
      }

      if (!_isFinished) {
        throw StateError('Protocol terminated without finishing');
      }

      final packages = _receivedPackages.values.toList()
        ..sort((a, b) => a.number.compareTo(b.number));

      return packages
        .where((package) => package.data != null)
        .map((package) => package.data!)
        .join();
    } catch (e) {
      if (e is ProtocolTerminatedException) {
        rethrow;
      }
      print('Error during data reception: $e');
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