import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:xceleration/core/utils/data_protocol.dart';
import 'package:xceleration/core/utils/data_package.dart';
import 'package:xceleration/core/utils/connection_interfaces.dart';
import 'package:xceleration/core/result.dart';

@GenerateMocks([DeviceConnectionServiceInterface])
import 'data_protocol_test.mocks.dart';

// Fast timing values so tests don't wait on real timers.
const _retryTimeout = Duration(milliseconds: 50);
const _sendStabilizationDelay = Duration.zero;
const _transferAbortTimeout = Duration(milliseconds: 150);

void main() {
  late Protocol protocol;
  late MockDeviceConnectionServiceInterface mockConnectionService;
  final mockDevice =
      Device('test_id', 'test_device', SessionState.connected.index);

  setUp(() {
    mockConnectionService = MockDeviceConnectionServiceInterface();
    protocol = Protocol(
      deviceConnectionService: mockConnectionService,
      retryTimeout: _retryTimeout,
      sendStabilizationDelay: _sendStabilizationDelay,
      transferAbortTimeout: _transferAbortTimeout,
    );
    protocol.addDevice(mockDevice);

    when(mockConnectionService.sendMessageToDevice(any, any))
        .thenAnswer((_) async => true);
  });

  tearDown(() {
    protocol.dispose();
  });

  /// Configures the mock to ACK every DATA/FIN package immediately.
  void setupAutoAck() {
    when(mockConnectionService.sendMessageToDevice(any, any))
        .thenAnswer((invocation) async {
      final package = invocation.positionalArguments[1] as Package;
      if (package.type == 'DATA' || package.type == 'FIN') {
        await protocol.handleMessage(
            Package(number: package.number, type: 'ACK'), mockDevice.deviceId);
      }
      return true;
    });
  }

  group('Protocol basics', () {
    test('protocol initializes correctly', () {
      expect(protocol, isNotNull);
    });

    test('adding and removing devices', () {
      expect(protocol.connectedDevices, contains(mockDevice.deviceId));
      protocol.removeDevice(mockDevice.deviceId);
      expect(protocol.connectedDevices, isNot(contains(mockDevice.deviceId)));
    });

    test('protocol can be terminated', () async {
      await protocol.terminate();
      final result = await protocol.sendData('test', 'deviceId');
      expect(result, isA<Failure<void>>());
    });
  });

  group('addDevice() / removeDevice()', () {
    test('reconnection resets in-progress transfer state', () async {
      await protocol.handleMessage(
          Package(number: 1, type: 'FIN'), mockDevice.deviceId);
      expect(protocol.isFinished(mockDevice.deviceId), isTrue);

      // Re-adding the same device simulates a reconnection.
      protocol.addDevice(mockDevice);

      expect(protocol.isFinished(mockDevice.deviceId), isFalse);
    });

    test('removing an unknown device is a no-op', () {
      expect(() => protocol.removeDevice('unknown_device_id'), returnsNormally);
    });
  });

  group('isFinished()', () {
    test('returns false before FIN is received', () {
      expect(protocol.isFinished(mockDevice.deviceId), isFalse);
    });

    test('returns true after FIN package is received and acknowledged',
        () async {
      await protocol.handleMessage(
          Package(number: 1, type: 'FIN'), mockDevice.deviceId);
      expect(protocol.isFinished(mockDevice.deviceId), isTrue);
    });
  });

  group('terminate() / dispose()', () {
    test('terminate() is idempotent', () async {
      await protocol.terminate();
      expect(protocol.isTerminated, isTrue);
      // Second call must not throw.
      await expectLater(() => protocol.terminate(), returnsNormally);
      expect(protocol.isTerminated, isTrue);
    });

    test('dispose() completes pending transmissions with Failure', () async {
      // Use a fresh protocol so tearDown does not double-dispose.
      final freshProtocol = Protocol(
        deviceConnectionService: mockConnectionService,
        retryTimeout: _retryTimeout,
        sendStabilizationDelay: _sendStabilizationDelay,
        transferAbortTimeout: _transferAbortTimeout,
      );
      final freshDevice =
          Device('fresh_id', 'fresh_device', SessionState.connected.index);
      freshProtocol.addDevice(freshDevice);

      // Never ACK — keep transmissions pending.
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((_) async => true);

      Result<void>? result;
      final sendFuture = freshProtocol
          .sendData('test', freshDevice.deviceId)
          .then((r) => result = r);

      // Allow sendData to reach the completer.future await.
      await Future.delayed(const Duration(milliseconds: 10));

      freshProtocol.dispose();
      await sendFuture;

      expect(result, isA<Failure<void>>());
    });
  });

  group('handleMessage()', () {
    test('throws for invalid package type', () async {
      await expectLater(
        protocol.handleMessage(
            Package(number: 1, type: 'INVALID'), mockDevice.deviceId),
        throwsA(isA<Exception>()),
      );
    });

    test('does nothing when protocol is terminated', () async {
      await protocol.terminate();
      await protocol.handleMessage(
          Package(number: 1, type: 'DATA', data: 'data'), mockDevice.deviceId);
      verifyNever(mockConnectionService.sendMessageToDevice(any, any));
    });

    test('sends ACK for received DATA package', () async {
      await protocol.handleMessage(
          Package(number: 1, type: 'DATA', data: 'test_data'),
          mockDevice.deviceId);

      verify(mockConnectionService.sendMessageToDevice(
              any,
              argThat(
                  predicate((Package p) => p.type == 'ACK' && p.number == 1))))
          .called(1);
    });

    test('handles duplicate DATA packages without error', () async {
      final package = Package(number: 1, type: 'DATA', data: 'test_data');
      await protocol.handleMessage(package, mockDevice.deviceId);
      await protocol.handleMessage(package, mockDevice.deviceId);

      verify(mockConnectionService.sendMessageToDevice(
              any,
              argThat(
                  predicate((Package p) => p.type == 'ACK' && p.number == 1))))
          .called(2);
    });

    test('ACK unblocks pending sender', () async {
      setupAutoAck();
      final result = await protocol.sendData('hello', mockDevice.deviceId);
      expect(result, isA<Success<void>>());
    });

    test('marks device finished after receiving FIN package', () async {
      await protocol.handleMessage(
          Package(number: 1, type: 'FIN'), mockDevice.deviceId);

      verify(mockConnectionService.sendMessageToDevice(
              any,
              argThat(
                  predicate((Package p) => p.type == 'ACK' && p.number == 1))))
          .called(1);
      expect(protocol.isFinished(mockDevice.deviceId), isTrue);
    });
  });

  group('sendData()', () {
    test('returns Failure for null data', () async {
      final result = await protocol.sendData(null, mockDevice.deviceId);
      expect(result, isA<Failure<void>>());
    });

    test('returns Failure for empty data', () async {
      final result = await protocol.sendData('', mockDevice.deviceId);
      expect(result, isA<Failure<void>>());
    });

    test('returns Failure when protocol is terminated', () async {
      await protocol.terminate();
      final result = await protocol.sendData('hello', mockDevice.deviceId);
      expect(result, isA<Failure<void>>());
    });

    test('returns Failure when device is not connected', () async {
      final result =
          await protocol.sendData('hello', 'unconnected_device_id');
      expect(result, isA<Failure<void>>());
    });

    test('sends a single DATA chunk and FIN for small data', () async {
      setupAutoAck();
      final result = await protocol.sendData('hello', mockDevice.deviceId);

      expect(result, isA<Success<void>>());
      verify(mockConnectionService.sendMessageToDevice(
              any, argThat(predicate((Package p) => p.type == 'DATA'))))
          .called(1);
      verify(mockConnectionService.sendMessageToDevice(
              any, argThat(predicate((Package p) => p.type == 'FIN'))))
          .called(1);
    });

    test('sends multiple DATA chunks for data exceeding chunk size', () async {
      setupAutoAck();
      // chunkSize == 1000; 2500 chars → 3 chunks
      final result =
          await protocol.sendData('x' * 2500, mockDevice.deviceId);

      expect(result, isA<Success<void>>());
      verify(mockConnectionService.sendMessageToDevice(
              any, argThat(predicate((Package p) => p.type == 'DATA'))))
          .called(3);
      verify(mockConnectionService.sendMessageToDevice(
              any, argThat(predicate((Package p) => p.type == 'FIN'))))
          .called(1);
    });

    test('returns Failure when retry attempts are exhausted', () async {
      // Never ACK — force all maxSendAttempts retries to expire.
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((_) async => true);

      // With retryTimeout = 50 ms and maxSendAttempts = 4, this resolves
      // after ~200 ms without needing fakeAsync.
      final result = await protocol.sendData('test', mockDevice.deviceId);

      expect(result, isA<Failure<void>>());
    });

    test('sends data in chunks with FIN package at the end', () async {
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((args) async {
        final package = args.positionalArguments[1] as Package;
        await protocol.handleMessage(
            Package(number: package.number, type: 'ACK'), mockDevice.deviceId);
        return true;
      });

      final result = await protocol.sendData('test_data', mockDevice.deviceId);
      expect(result, isA<Success<void>>());
      verify(mockConnectionService.sendMessageToDevice(
              any, argThat(predicate((Package p) => p.type == 'DATA'))))
          .called(greaterThan(0));
      verify(mockConnectionService.sendMessageToDevice(
          any, argThat(predicate((Package p) => p.type == 'FIN')))).called(1);
    });
  });

  group('handleDataTransfer()', () {
    test('returns Failure when protocol is terminated', () async {
      await protocol.terminate();
      final result = await protocol.handleDataTransfer(
          deviceId: mockDevice.deviceId,
          isReceiving: true,
          shouldContinueTransfer: () => true);
      expect(result, isA<Failure<String?>>());
    });

    test('returns Failure when device is not connected', () async {
      final result = await protocol.handleDataTransfer(
          deviceId: 'unconnected_device_id',
          isReceiving: true,
          shouldContinueTransfer: () => true);
      expect(result, isA<Failure<String?>>());
    });

    test('assembles received chunks correctly for receiver', () async {
      // Schedule incoming messages so they arrive while handleDataTransfer
      // is polling (after the first Future.delayed yields control).
      Future.microtask(() async {
        await protocol.handleMessage(
            Package(number: 1, type: 'DATA', data: 'hello '),
            mockDevice.deviceId);
        await protocol.handleMessage(
            Package(number: 2, type: 'DATA', data: 'world'),
            mockDevice.deviceId);
        await protocol.handleMessage(
            Package(number: 3, type: 'FIN'), mockDevice.deviceId);
      });

      final result = await protocol.handleDataTransfer(
          deviceId: mockDevice.deviceId,
          isReceiving: true,
          shouldContinueTransfer: () => true);

      expect(result, isA<Success<String?>>());
      expect((result as Success<String?>).value, 'hello world');
    });

    test('returns Failure when packets are missing from sequence', () async {
      Future.microtask(() async {
        await protocol.handleMessage(
            Package(number: 1, type: 'DATA', data: 'chunk1'),
            mockDevice.deviceId);
        // packet 2 intentionally omitted
        await protocol.handleMessage(
            Package(number: 3, type: 'DATA', data: 'chunk3'),
            mockDevice.deviceId);
        await protocol.handleMessage(
            Package(number: 4, type: 'FIN'), mockDevice.deviceId);
      });

      final result = await protocol.handleDataTransfer(
          deviceId: mockDevice.deviceId,
          isReceiving: true,
          shouldContinueTransfer: () => true);

      expect(result, isA<Failure<String?>>());
    });

    test('returns Failure when shouldContinueTransfer is persistently false',
        () async {
      // With transferAbortTimeout = 150 ms this resolves quickly.
      final result = await protocol.handleDataTransfer(
          deviceId: mockDevice.deviceId,
          isReceiving: true,
          shouldContinueTransfer: () => false);

      expect(result, isA<Failure<String?>>());
    });

    test('sends data and returns Success(null) for sender', () async {
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((args) async {
        final package = args.positionalArguments[1] as Package;
        await protocol.handleMessage(
            Package(number: package.number, type: 'ACK'), mockDevice.deviceId);
        return true;
      });

      final result = await protocol.handleDataTransfer(
          deviceId: mockDevice.deviceId,
          dataToSend: 'test_data',
          isReceiving: false,
          shouldContinueTransfer: () => true);

      expect(result, isA<Success<String?>>());
      expect((result as Success<String?>).value, isNull);
      verify(mockConnectionService.sendMessageToDevice(
              any, argThat(predicate((Package p) => p.type == 'DATA'))))
          .called(greaterThan(0));
      verify(mockConnectionService.sendMessageToDevice(
          any, argThat(predicate((Package p) => p.type == 'FIN')))).called(1);
    });

    test('returns Failure if shouldContinueTransfer becomes false', () async {
      bool shouldContinue = true;
      Future.delayed(const Duration(milliseconds: 50), () {
        shouldContinue = false;
      });

      final result = await protocol.handleDataTransfer(
          deviceId: mockDevice.deviceId,
          isReceiving: true,
          shouldContinueTransfer: () => shouldContinue);

      expect(result, isA<Failure<String?>>());
    });
  });

  // Retained from original test file for regression coverage.
  group('Package handling', () {
    test('should send acknowledgment for received packages', () async {
      final package = Package(number: 1, type: 'DATA', data: 'test_data');
      await protocol.handleMessage(package, mockDevice.deviceId);

      verify(mockConnectionService.sendMessageToDevice(
              any,
              argThat(
                  predicate((Package p) => p.type == 'ACK' && p.number == 1))))
          .called(1);
    });

    test('should mark device as finished after receiving FIN package',
        () async {
      final finPackage = Package(number: 1, type: 'FIN');
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((_) async => true);

      await protocol.handleMessage(finPackage, mockDevice.deviceId);

      verify(mockConnectionService.sendMessageToDevice(
              any,
              argThat(
                  predicate((Package p) => p.type == 'ACK' && p.number == 1))))
          .called(1);
      expect(protocol.isFinished(mockDevice.deviceId), true);
    });
  });

  // Retained from original test file for regression coverage.
  group('Data sending', () {
    test('sends data in chunks with FIN package at the end', () async {
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((args) async {
        final package = args.positionalArguments[1] as Package;
        await protocol.handleMessage(
            Package(number: package.number, type: 'ACK'), mockDevice.deviceId);
        return true;
      });

      final result = await protocol.sendData('test_data', mockDevice.deviceId);
      expect(result, isA<Success<void>>());
      verify(mockConnectionService.sendMessageToDevice(
              any, argThat(predicate((Package p) => p.type == 'DATA'))))
          .called(greaterThan(0));
      verify(mockConnectionService.sendMessageToDevice(
          any, argThat(predicate((Package p) => p.type == 'FIN')))).called(1);
    });

    test('returns Failure when sending empty data', () async {
      final result = await protocol.sendData('', mockDevice.deviceId);
      expect(result, isA<Failure<void>>());
    });
  });

  // Retained from original test file for regression coverage.
  group('Data transfer handling', () {
    test('handleDataTransfer sends data and returns Success(null) for sender',
        () async {
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((args) async {
        final package = args.positionalArguments[1] as Package;
        await protocol.handleMessage(
            Package(number: package.number, type: 'ACK'), mockDevice.deviceId);
        return true;
      });

      final result = await protocol.handleDataTransfer(
          deviceId: mockDevice.deviceId,
          dataToSend: 'test_data',
          isReceiving: false,
          shouldContinueTransfer: () => true);

      expect(result, isA<Success<String?>>());
      expect((result as Success<String?>).value, null);
      verify(mockConnectionService.sendMessageToDevice(
              any, argThat(predicate((Package p) => p.type == 'DATA'))))
          .called(greaterThan(0));
      verify(mockConnectionService.sendMessageToDevice(
          any, argThat(predicate((Package p) => p.type == 'FIN')))).called(1);
    });

    test(
        'handleDataTransfer returns Failure if shouldContinueTransfer returns false',
        () async {
      bool shouldContinue = true;

      Future.delayed(const Duration(milliseconds: 50), () {
        shouldContinue = false;
      });

      final result = await protocol.handleDataTransfer(
          deviceId: mockDevice.deviceId,
          isReceiving: true,
          shouldContinueTransfer: () => shouldContinue);

      expect(result, isA<Failure<String?>>());
    });
  });
}
