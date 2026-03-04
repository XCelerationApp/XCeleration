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

void main() {
  late Protocol protocol;
  late MockDeviceConnectionServiceInterface mockConnectionService;
  final mockDevice =
      Device('test_id', 'test_device', SessionState.connected.index);

  setUp(() {
    mockConnectionService = MockDeviceConnectionServiceInterface();
    protocol = Protocol(deviceConnectionService: mockConnectionService);
    protocol.addDevice(mockDevice);

    // Set up default behavior for the mock
    when(mockConnectionService.sendMessageToDevice(any, any))
        .thenAnswer((_) async => true);
  });

  tearDown(() {
    protocol.dispose();
  });

  group('Protocol basics', () {
    test('protocol initializes correctly', () {
      expect(protocol, isNotNull);
    });

    test('adding and removing devices', () {
      expect(protocol.connectedDevices, contains(mockDevice.deviceId));
      // Try to remove it
      protocol.removeDevice(mockDevice.deviceId);

      expect(protocol.connectedDevices, isNot(contains(mockDevice.deviceId)));
    });

    test('protocol can be terminated', () async {
      await protocol.terminate();
      // Should be marked as terminated
      final result = await protocol.sendData('test', 'deviceId');
      expect(result, isA<Failure<void>>());
    });
  });

  group('Package handling', () {
    test('should send acknowledgment for received packages', () async {
      // Create a test package
      final package = Package(number: 1, type: 'DATA', data: 'test_data');

      // Handle the package
      await protocol.handleMessage(package, mockDevice.deviceId);

      // Verify an ACK was sent
      verify(mockConnectionService.sendMessageToDevice(
              any,
              argThat(
                  predicate((Package p) => p.type == 'ACK' && p.number == 1))))
          .called(1);
    });

    test('should mark device as finished after receiving FIN package',
        () async {
      // Create a test FIN package
      final finPackage = Package(number: 1, type: 'FIN');

      // Set up the mock to "receive" acknowledgments
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((_) async => true);

      // Handle the package
      await protocol.handleMessage(finPackage, mockDevice.deviceId);

      // Verify FIN was acknowledged
      verify(mockConnectionService.sendMessageToDevice(
              any,
              argThat(
                  predicate((Package p) => p.type == 'ACK' && p.number == 1))))
          .called(1);

      expect(protocol.isFinished(mockDevice.deviceId), true);
    });
  });

  group('Data sending', () {
    test('sends data in chunks with FIN package at the end', () async {
      // Set up the mock to "receive" acknowledgments
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((args) async {
        // Simulate receiving ACK for any sent package
        final package = args.positionalArguments[1] as Package;
        await protocol.handleMessage(
            Package(number: package.number, type: 'ACK'), mockDevice.deviceId);
        return true;
      });

      // Send test data
      final result = await protocol.sendData('test_data', mockDevice.deviceId);
      expect(result, isA<Success<void>>());

      // Verify appropriate packages were sent
      // Should send at least one DATA package and one FIN package
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

  group('Data transfer handling', () {
    test('handleDataTransfer sends data and returns Success(null) for sender',
        () async {
      // Set up the mock to "receive" acknowledgments
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((args) async {
        // Simulate receiving ACK for any sent package
        final package = args.positionalArguments[1] as Package;
        await protocol.handleMessage(
            Package(number: package.number, type: 'ACK'), mockDevice.deviceId);
        return true;
      });

      // Handle data transfer (as sender)
      final result = await protocol.handleDataTransfer(
          deviceId: mockDevice.deviceId,
          dataToSend: 'test_data',
          isReceiving: false,
          shouldContinueTransfer: () => true);

      // Sender gets Success(null)
      expect(result, isA<Success<String?>>());
      expect((result as Success<String?>).value, null);

      // Verify a DATA package and FIN package were sent
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

      // Set up a delayed status change
      Future.delayed(Duration(milliseconds: 50), () {
        shouldContinue = false;
      });

      // Handle data transfer with a status that will change
      final result = await protocol.handleDataTransfer(
          deviceId: mockDevice.deviceId,
          isReceiving: true,
          shouldContinueTransfer: () => shouldContinue);

      expect(result, isA<Failure<String?>>());
    });
  });
}
