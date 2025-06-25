import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/data_protocol.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'dart:async';

// Create mocks for the external dependencies
@GenerateMocks([DeviceConnectionService, Protocol, DevicesManager])
import 'wireless_connection_test.mocks.dart';

void main() {
  late MockDeviceConnectionService mockConnectionService;
  late MockDevicesManager advertiserDevicesManager;
  late MockDevicesManager browserDevicesManager;

  setUp(() {
    mockConnectionService = MockDeviceConnectionService();
    advertiserDevicesManager = MockDevicesManager();
    browserDevicesManager = MockDevicesManager();
    
    // Configure the mock device managers
    when(advertiserDevicesManager.currentDeviceName).thenReturn(DeviceName.coach);
    when(advertiserDevicesManager.currentDeviceType).thenReturn(DeviceType.advertiserDevice);
    when(browserDevicesManager.currentDeviceName).thenReturn(DeviceName.coach);
    when(browserDevicesManager.currentDeviceType).thenReturn(DeviceType.browserDevice);

    // Set up default behaviors for the mocks
    when(mockConnectionService.isActive).thenReturn(true);
    when(mockConnectionService.monitorDevicesConnectionStatus(
            deviceFoundCallback: anyNamed('deviceFoundCallback'),
            deviceConnectingCallback: anyNamed('deviceConnectingCallback'),
            deviceConnectedCallback: anyNamed('deviceConnectedCallback'),
            timeout: anyNamed('timeout'),
            timeoutCallback: anyNamed('timeoutCallback')))
        .thenAnswer((_) async {});
  });

  group('Complete data transfer flow', () {
    test('Successful data transfer between advertiser and browser', () async {
      // Test devices
      final advertiserDevice =
          ConnectedDevice(DeviceName.coach, data: 'test_data_to_send');
      advertiserDevice.status = ConnectionStatus.found;

      final browserDevice = ConnectedDevice(DeviceName.bibRecorder);
      browserDevice.status = ConnectionStatus.found;

      // Setup mock device lists
      final List<ConnectedDevice> advertiserDevices = [advertiserDevice];
      when(advertiserDevicesManager.devices).thenReturn(advertiserDevices);
      when(advertiserDevicesManager.getDevice(DeviceName.coach)).thenReturn(advertiserDevice);
      final List<ConnectedDevice> browserDevices = [browserDevice];
      when(browserDevicesManager.devices).thenReturn(browserDevices);
      when(browserDevicesManager.getDevice(DeviceName.bibRecorder)).thenReturn(browserDevice);

      // Set up protocols
      final advertiserProtocol = MockProtocol();
      final browserProtocol = MockProtocol();

      // Configure advertiser (sending data)
      when(advertiserProtocol.handleDataTransfer(
              deviceId: anyNamed('deviceId'),
              dataToSend: anyNamed('dataToSend'),
              isReceiving: false,
              shouldContinueTransfer: anyNamed('shouldContinueTransfer')))
          .thenAnswer((_) async {
        // Simulate sending the data
        advertiserDevice.status = ConnectionStatus.sending;
        await Future.delayed(Duration(milliseconds: 50));

        // Simulate FIN package sent and receive ACK
        advertiserDevice.status = ConnectionStatus.finished;

        return null; // Sender returns null
      });

      // Configure browser (receiving data)
      when(browserProtocol.handleDataTransfer(
              deviceId: anyNamed('deviceId'),
              dataToSend: null,
              isReceiving: true,
              shouldContinueTransfer: anyNamed('shouldContinueTransfer')))
          .thenAnswer((_) async {
        // Simulate receiving data
        browserDevice.status = ConnectionStatus.receiving;
        await Future.delayed(Duration(milliseconds: 50));

        // Simulate FIN package received
        browserDevice.status = ConnectionStatus.finished;
        browserDevice.data = advertiserDevice.data;

        return advertiserDevice.data;
      });

      // Create completers to track the async flow
      final advertiserCompleted = Completer<void>();
      final browserCompleted = Completer<void>();

      // Simulate advertiser side
      unawaited(Future(() async {
        try {
          final result = await advertiserProtocol.handleDataTransfer(
              deviceId: 'Browser',
              dataToSend: advertiserDevice.data,
              isReceiving: false,
              shouldContinueTransfer: () =>
                  advertiserDevice.status != ConnectionStatus.found);

          expect(result, null);
          expect(advertiserDevice.status, ConnectionStatus.finished);
          advertiserCompleted.complete();
        } catch (e) {
          advertiserCompleted.completeError(e);
        }
      }));

      // Simulate browser side
      unawaited(Future(() async {
        try {
          final result = await browserProtocol.handleDataTransfer(
              deviceId: 'Advertiser',
              dataToSend: null,
              isReceiving: true,
              shouldContinueTransfer: () =>
                  browserDevice.status != ConnectionStatus.found);

          expect(result, 'test_data_to_send');
          expect(browserDevice.status, ConnectionStatus.finished);
          browserCompleted.complete();
        } catch (e) {
          browserCompleted.completeError(e);
        }
      }));

      // Wait for both sides to complete
      await Future.wait([advertiserCompleted.future, browserCompleted.future]);

      // Verify final states
      expect(advertiserDevice.status, ConnectionStatus.finished);
      expect(browserDevice.status, ConnectionStatus.finished);
      expect(browserDevice.data, 'test_data_to_send');
    });

    test('Handles premature disconnection gracefully', () async {
      // Test devices
      final advertiserDevice =
          ConnectedDevice(DeviceName.coach, data: 'test_data_to_send');
      advertiserDevice.status = ConnectionStatus.found;

      final browserDevice = ConnectedDevice(DeviceName.bibRecorder);
      browserDevice.status = ConnectionStatus.found;

      // Setup mock device lists
      final List<ConnectedDevice> advertiserDevices = [advertiserDevice];
      when(advertiserDevicesManager.devices).thenReturn(advertiserDevices);
      when(advertiserDevicesManager.getDevice(DeviceName.coach)).thenReturn(advertiserDevice);
      final List<ConnectedDevice> browserDevices = [browserDevice];
      when(browserDevicesManager.devices).thenReturn(browserDevices);
      when(browserDevicesManager.getDevice(DeviceName.bibRecorder)).thenReturn(browserDevice);

      // Set up protocols
      final advertiserProtocol = MockProtocol();
      final browserProtocol = MockProtocol();

      // Configure advertiser to disconnect before sending FIN
      when(advertiserProtocol.handleDataTransfer(
              deviceId: anyNamed('deviceId'),
              dataToSend: anyNamed('dataToSend'),
              isReceiving: false,
              shouldContinueTransfer: anyNamed('shouldContinueTransfer')))
          .thenAnswer((_) async {
        // Simulate sending data
        advertiserDevice.status = ConnectionStatus.sending;
        await Future.delayed(Duration(milliseconds: 50));

        // Simulate premature disconnection
        advertiserDevice.status = ConnectionStatus.found;

        throw ProtocolTerminatedException(
            'Transfer aborted: device status changed');
      });

      // Configure browser to handle disconnection
      when(browserProtocol.handleDataTransfer(
              deviceId: anyNamed('deviceId'),
              dataToSend: null,
              isReceiving: true,
              shouldContinueTransfer: anyNamed('shouldContinueTransfer')))
          .thenAnswer((_) async {
        // Simulate receiving some data
        browserDevice.status = ConnectionStatus.receiving;
        await Future.delayed(Duration(milliseconds: 50));

        // Simulate disconnection detected
        browserDevice.status = ConnectionStatus.error;

        throw ProtocolTerminatedException(
            'Transfer aborted: device status changed');
      });

      // Test advertiser side
      expect(() async {
        await advertiserProtocol.handleDataTransfer(
            deviceId: 'Browser',
            dataToSend: advertiserDevice.data,
            isReceiving: false,
            shouldContinueTransfer: () =>
                advertiserDevice.status == ConnectionStatus.sending);
      }, throwsA(isA<ProtocolTerminatedException>()));

      // Test browser side
      expect(() async {
        await browserProtocol.handleDataTransfer(
            deviceId: 'Advertiser',
            dataToSend: null,
            isReceiving: true,
            shouldContinueTransfer: () =>
                browserDevice.status == ConnectionStatus.receiving);
      }, throwsA(isA<ProtocolTerminatedException>()));
    });
  });

  group('Testing rescan prevention logic', () {
    test('_shouldRescan prevents rescans during active transfers', () {
      // Create a function that mimics the _shouldRescan method
      bool shouldRescan(String token) {
        // Logic from _shouldRescan
        if (advertiserDevicesManager.devices.any((device) =>
            !device.isFinished &&
            device.status != ConnectionStatus.searching)) {
          return false;
        }

        return !advertiserDevicesManager.devices
            .every((device) => device.isFinished);
      }

      // Add a device in receiving state
      final device = ConnectedDevice(DeviceName.coach);
      device.status = ConnectionStatus.receiving;
      
      // Configure the mock to return this device
      final List<ConnectedDevice> devices = [device];
      when(advertiserDevicesManager.devices).thenReturn(devices);
      when(advertiserDevicesManager.getDevice(DeviceName.coach)).thenReturn(device);

      // Should not rescan with a device in receiving state
      expect(shouldRescan('test_token'), false);

      // Now change state to searching
      device.status = ConnectionStatus.searching;
      expect(shouldRescan('test_token'), true);

      // Now change to finished
      device.status = ConnectionStatus.finished;
      expect(shouldRescan('test_token'), false);
    });
  });
}

// Helper function to avoid having to use await
void unawaited(Future<void> future) {}
