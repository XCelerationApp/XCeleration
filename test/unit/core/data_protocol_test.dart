import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:xceleration/core/utils/data_protocol.dart';
import 'package:xceleration/core/utils/data_package.dart';
import 'package:xceleration/core/services/device_connection_service.dart';

@GenerateMocks([DeviceConnectionService])
import 'data_protocol_test.mocks.dart';

void main() {
  late Protocol protocol;
  late MockDeviceConnectionService mockConnectionService;

  setUp(() {
    mockConnectionService = MockDeviceConnectionService();
    protocol = Protocol(deviceConnectionService: mockConnectionService);
    
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
      final device = Device(
        'test_id',
        'test_device',
        SessionState.connected.index
      );  
      // Add device
      protocol.addDevice(device);
      
      // Try to remove it
      protocol.removeDevice('test_id');

      // Both operations should complete without errors
      expect(true, true);
    });

    test('protocol can be terminated', () {
      protocol.terminate();
      // Should be marked as terminated
      expect(() => protocol.sendData('test', 'deviceId'), 
          throwsA(isA<ProtocolTerminatedException>()));
    });
  });

  group('Package handling', () {
    test('should send acknowledgment for received packages', () async {
      // Set up the mock device
      final device = Device(
        'sender_id',
        'Sender',
        SessionState.connected.index
      );
      protocol.addDevice(device);
      
      // Create a test package
      final package = Package(number: 1, type: 'DATA', data: 'test_data');
      
      // Handle the package
      await protocol.handleMessage(package, 'sender_id');
      
      // Verify an ACK was sent
      verify(mockConnectionService.sendMessageToDevice(
          any, 
          argThat(predicate((Package p) => p.type == 'ACK' && p.number == 1))
      )).called(1);
    });

    test('should mark device as finished after receiving FIN package', () async {
      // Set up the mock device
      final device = Device(
        'sender_id',
        'Sender',
        SessionState.connected.index
      );
      protocol.addDevice(device);
      
      // Create a test FIN package
      final finPackage = Package(number: 1, type: 'FIN');

      // Set up the mock to "receive" acknowledgments
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((_) async => true);
      
      // Handle the package
      await protocol.handleMessage(finPackage, 'sender_id');
      
      // Verify FIN was acknowledged
      verify(mockConnectionService.sendMessageToDevice(
          any, 
          argThat(predicate((Package p) => p.type == 'ACK' && p.number == 1))
      )).called(1);

      expect(protocol.isFinished('sender_id'), true);
    });
  });

  group('Data sending', () {
    test('sends data in chunks with FIN package at the end', () async {
      // Set up the mock device
      final device = Device(
        'receiver_id',
        'Receiver',
        SessionState.connected.index
      );
      protocol.addDevice(device);
      
      // Set up the mock to "receive" acknowledgments
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((_) async {
            // Simulate receiving ACK for any sent package
            final package = _.positionalArguments[1] as Package;
            await protocol.handleMessage(
                Package(number: package.number, type: 'ACK'), 'receiver_id');
            return true;
          });
      
      // Send test data
      await protocol.sendData('test_data', 'receiver_id');
      
      // Verify appropriate packages were sent
      // Should send at least one DATA package and one FIN package
      verify(mockConnectionService.sendMessageToDevice(
          any,
          argThat(predicate((Package p) => p.type == 'DATA'))
      )).called(greaterThan(0));
      
      verify(mockConnectionService.sendMessageToDevice(
          any,
          argThat(predicate((Package p) => p.type == 'FIN'))
      )).called(1);
    });

    test('handles empty data gracefully', () async {
      // Set up the mock device
      final device = Device(
        'receiver_id',
        'Receiver',
        SessionState.connected.index
      );
      protocol.addDevice(device);
      
      // Set up the mock to "receive" acknowledgments
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((_) async {
            // Simulate receiving ACK for any sent package
            final package = _.positionalArguments[1] as Package;
            await protocol.handleMessage(
                Package(number: package.number, type: 'ACK'), 'receiver_id');
            return true;
          });
      
      // Send empty data
      await protocol.sendData('', 'receiver_id');
      
      // Should still send a package, but with empty data
      verify(mockConnectionService.sendMessageToDevice(
          any,
          argThat(predicate((Package p) => p.type == 'DATA' && p.data == ''))
      )).called(1);
    });
  });

  group('Data transfer handling', () {
    test('handleDataTransfer sends data and returns null for sender', () async {
      // Set up the mock device
      final device = Device(
        'receiver_id',
        'Receiver',
        SessionState.connected.index
      );
      protocol.addDevice(device);
      
      // Set up the mock to "receive" acknowledgments
      when(mockConnectionService.sendMessageToDevice(any, any))
          .thenAnswer((_) async {
            // Simulate receiving ACK for any sent package
            final package = _.positionalArguments[1] as Package;
            await protocol.handleMessage(
                Package(number: package.number, type: 'ACK'), 'receiver_id');
            return true;
          });
      
      // Handle data transfer (as sender)
      final result = await protocol.handleDataTransfer(
        deviceId: 'receiver_id',
        dataToSend: 'test_data',
        isReceiving: false,
        shouldContinueTransfer: () => true
      );
      
      // Sender doesn't receive data
      expect(result, null);
      
      // Verify a DATA package and FIN package were sent
      verify(mockConnectionService.sendMessageToDevice(
          any,
          argThat(predicate((Package p) => p.type == 'DATA'))
      )).called(greaterThan(0));
      
      verify(mockConnectionService.sendMessageToDevice(
          any,
          argThat(predicate((Package p) => p.type == 'FIN'))
      )).called(1);
    });

    test('handleDataTransfer aborts if shouldContinueTransfer returns false', () async {
      // Set up the mock device
      final device = Device(
        'receiver_id',
        'Receiver',
        SessionState.connected.index
      );
      protocol.addDevice(device);
      
      bool shouldContinue = true;
      
      // Set up a delayed status change
      Future.delayed(Duration(milliseconds: 50), () {
        shouldContinue = false;
      });
      
      // Handle data transfer with a status that will change
      expect(() => protocol.handleDataTransfer(
        deviceId: 'receiver_id',
        isReceiving: true,
        shouldContinueTransfer: () => shouldContinue
      ), throwsA(isA<ProtocolTerminatedException>()));
    });
  });
}
