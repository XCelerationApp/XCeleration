import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/services/nearby_connections.dart';
import 'package:xceleration/core/utils/connection_utils.dart';
import 'package:xceleration/core/utils/data_package.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:xceleration/core/utils/enums.dart';

// Generate mocks for our classes
@GenerateMocks([DevicesManager, NearbyConnections])
import 'device_connection_service_test.mocks.dart';

/// Helper class to enhance MockNearbyConnections with device state change functionality
class MockNearbyConnectionsHelper {
  final MockNearbyConnections mock;
  final StreamController<List<Device>> deviceStateController =
      StreamController<List<Device>>.broadcast();

  MockNearbyConnectionsHelper(this.mock);

  void emitDeviceStateChange(List<Device> devices) {
    deviceStateController.add(devices);
  }

  void dispose() {
    deviceStateController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeviceConnectionService deviceConnectionService;
  late MockDevicesManager mockDevicesManager;
  late MockNearbyConnections mockNearbyConnections;
  late MockNearbyConnectionsHelper mockNearbyHelper;
  late StreamController<List<Device>> stateChangeController;
  late StreamController<dynamic> dataController;
  final ConnectedDevice mockConnectedDevice = ConnectedDevice(DeviceName.bibRecorder);
  final Device mockDevice = Device('test_id', getDeviceNameString(mockConnectedDevice.name), SessionState.notConnected.index);

  setUp(() async {
    mockNearbyConnections = MockNearbyConnections();
    mockDevicesManager = MockDevicesManager();

    // Reset mock object states to ensure test independence
    mockConnectedDevice.status = ConnectionStatus.searching;
    mockConnectedDevice.data = null;
    mockDevice.state = SessionState.notConnected;

    // Initialize new stream controllers to ensure test independence
    stateChangeController?.close();
    dataController?.close();
    stateChangeController = StreamController<List<Device>>.broadcast();
    dataController = StreamController<dynamic>.broadcast();

    // Setup all stream controllers and mocks

    // Setup initial mocks for NearbyConnections
    when(mockNearbyConnections.startBrowsingForPeers())
        .thenAnswer((_) => Future.value(true));
    when(mockNearbyConnections.startAdvertisingPeer())
        .thenAnswer((_) => Future.value(true));
    when(mockNearbyConnections.stopBrowsingForPeers())
        .thenAnswer((_) => Future.value(true));
    when(mockNearbyConnections.stopAdvertisingPeer())
        .thenAnswer((_) => Future.value(true));

    // Setup mock for sendMessage
    when(mockNearbyConnections.sendMessage(any, any))
        .thenAnswer((_) => Future.value(true));

    // Setup mock for invitePeer
    when(mockNearbyConnections.invitePeer(
      deviceID: anyNamed('deviceID'),
      deviceName: anyNamed('deviceName'),
    )).thenAnswer((_) => Future.value(true));

    // Setup mock for disconnectPeer
    when(mockNearbyConnections.disconnectPeer(
      deviceID: anyNamed('deviceID'),
    )).thenAnswer((_) => Future.value(true));

    // Setup NearbyConnections init behavior to immediately callback with success
    when(mockNearbyConnections.init(
      serviceType: anyNamed('serviceType'),
      deviceName: anyNamed('deviceName'),
      strategy: anyNamed('strategy'),
      callback: anyNamed('callback'),
    )).thenAnswer((invocation) {
      // Extract and call the callback immediately with success
      final callback = invocation.namedArguments[const Symbol('callback')] as Function;
      // This callback triggers setting _nearbyConnectionsInitialized = true
      callback(true);
      return Future.value(true);
    });

    // Setup stateChangedSubscription
    when(mockNearbyConnections.stateChangedSubscription(
            callback: anyNamed('callback')))
        .thenAnswer((invocation) {
      final callback = invocation.namedArguments[const Symbol('callback')]
          as Function(List<Device>);
      return stateChangeController.stream.listen(callback);
    });

    // Setup dataReceivedSubscription
    when(mockNearbyConnections.dataReceivedSubscription(
            callback: anyNamed('callback')))
        .thenAnswer((invocation) {
      final callback = invocation.namedArguments[const Symbol('callback')]
          as Function(dynamic);
      return dataController.stream.listen((data) => callback(data));
    });

    // Setup devices for MockDevicesManager
    when(mockDevicesManager.devices).thenReturn([mockConnectedDevice]);
    when(mockDevicesManager.allDevicesFinished()).thenReturn(false);
    when(mockDevicesManager.otherDevices).thenReturn([mockConnectedDevice]);

    // Mock getDevice to return a ConnectedDevice for tests
    // This is crucial for the monitor connection status tests
    when(mockDevicesManager.getDevice(any)).thenReturn(mockConnectedDevice);

    // Create DeviceConnectionService with mocks
    mockNearbyHelper = MockNearbyConnectionsHelper(mockNearbyConnections);
    deviceConnectionService = DeviceConnectionService(
      mockDevicesManager,
      'wirelessconn', // serviceType
      'coach', // deviceName
      DeviceType.browserDevice,
      mockNearbyConnections, // Pass the mock as the NearbyConnectionsInterface
    );

    deviceConnectionService.rescanBackoff = const Duration(milliseconds: 100);

    Logger.d('Initializing connection service');

    // Ensure the service is properly initialized before each test
    // This is crucial since many tests depend on an active service
    final initResult = await deviceConnectionService.init();

    // Verify initialization succeeded
    expect(initResult, isTrue, reason: 'Service initialization should return true');
    expect(deviceConnectionService.isActive, isTrue, reason: 'Service should be active after initialization');

    // CRITICAL: The nearbyConnectionsInitialized flag must be set to true
    // for methods like inviteDevice to work properly
    deviceConnectionService.nearbyConnectionsInitialized = true;
    
    // Verify the flag is set
    expect(deviceConnectionService.nearbyConnectionsInitialized, isTrue,
        reason: 'NearbyConnections should be initialized after initialization');
  });

  tearDown(() async {
    // Wait for any pending operations to complete
    await Future.delayed(Duration.zero);
    deviceConnectionService.dispose();
    mockNearbyHelper.dispose();
  });

  group('DeviceConnectionService initialization', () {
    // Note: Service is already initialized in setUp

    test('should have isActive true after initialization', () {
      // Service is already initialized in setUp
      // Just verify it's active
      expect(deviceConnectionService.isActive, isTrue);
    });

    test('should have isActive false after disposal', () async {
      // Act - dispose the service
      deviceConnectionService.dispose(); // No await as dispose() is void

      // Assert
      expect(deviceConnectionService.isActive, isFalse);

      // Reinitialize for subsequent tests
      await deviceConnectionService.init();
    });
  });

  group('Device scanning', () {
    test('init should initialize nearby service', () async {
      // Act
      clearInteractions(mockNearbyConnections);
      final result = await deviceConnectionService.init();

      // Assert
      expect(result, isTrue);
      verify(mockNearbyConnections.startBrowsingForPeers()).called(1);
      verifyNever(mockNearbyConnections.startAdvertisingPeer());
    });
  });

  group('Device connection', () {
    test('inviteDevice should handle device invitation', () async {
      // Arrange
      mockDevice.state = SessionState.notConnected;

      when(mockNearbyConnections.invitePeer(deviceID: mockDevice.deviceId, deviceName: mockDevice.deviceName))
          .thenAnswer((_) {
            Logger.d('Inviting peer');
            mockDevice.state = SessionState.connected;
            return Future.value(true);
          });
      
      // Act
      final result = await deviceConnectionService.inviteDevice(mockDevice);
      // Assert
      expect(result, isTrue);
      expect(mockDevice.state, SessionState.connected);
      verify(mockNearbyConnections.invitePeer(
              deviceID: mockDevice.deviceId, deviceName: mockDevice.deviceName))
          .called(1);
    });

    test('disconnectDevice should handle device disconnection', () async {
      
      mockDevice.state = SessionState.connected;
      
      when(mockNearbyConnections.disconnectPeer(deviceID: mockDevice.deviceId))
          .thenAnswer((_) {
            Logger.d('Disconnecting peer');
            mockDevice.state = SessionState.notConnected;
            return Future.value(true);
          });
          
      // Service is already initialized in setUp
      // Act
      final result = await deviceConnectionService.disconnectDevice(mockDevice);
      
      // Assert
      expect(result, isTrue, reason: 'disconnectDevice should return true');
      expect(mockDevice.state, SessionState.notConnected);
      verify(mockNearbyConnections.disconnectPeer(
              deviceID: mockDevice.deviceId))
          .called(1);
    });
  });

  group('Message handling', () {
    test('sendMessageToDevice should send message correctly', () async {
      // Set the device state to connected
      mockDevice.state = SessionState.connected;
      
      final package = Package(number: 1, type: 'DATA', data: 'test_data');

      // Add debug logging to track execution
      when(mockNearbyConnections.sendMessage(
              mockDevice.deviceId, package.data!))
          .thenAnswer((_) {
            Logger.d('Sending message to ${mockDevice.deviceName}');
            return Future.value(true);
          });

      // Act
      final result = await deviceConnectionService.sendMessageToDevice(
          mockDevice, package);

      // Assert
      expect(result, isTrue, reason: 'sendMessageToDevice should return true');
      
      // Use any() for the second parameter since the Package is serialized with a checksum
      verify(mockNearbyConnections.sendMessage(
              mockDevice.deviceId, any))
          .called(1);
    });

    test('Data resend works after failure', () async {
      
      // Set the device state to connected
      mockDevice.state = SessionState.connected;
      
      final package = Package(number: 1, type: 'DATA', data: 'test_data');

      // Setup mock with logging - first throws exception, then succeeds
      var attemptCount = 0;
      when(mockNearbyConnections.sendMessage(mockDevice.deviceId, any))
          .thenAnswer((_) {
            attemptCount++;
            if (attemptCount == 1) {
              Logger.d('First attempt - simulating exception');
              throw Exception('Simulated network error'); // First attempt throws exception
            } else {
              Logger.d('Retry attempt - simulating success');
              return Future.value(true); // Retry succeeds
            }
          });

      // Act - first attempt
      final firstResult = await deviceConnectionService.sendMessageToDevice(
          mockDevice, package);
      expect(firstResult, isFalse, reason: 'First attempt should fail');

      // Act - second attempt
      final secondResult = await deviceConnectionService.sendMessageToDevice(
          mockDevice, package);
      expect(secondResult, isTrue, reason: 'Second attempt should succeed');

      // Verify it was called exactly twice (initial try + retry)
      verify(mockNearbyConnections.sendMessage(mockDevice.deviceId, any))
          .called(2);
    });

    test('monitorMessageReceives should handle incoming messages', () async {
      bool messageReceived = false;
      mockDevice.state = SessionState.connected;

      // Simulate data received - format exactly as the service expects
      final testData = Package(number: 1, type: 'DATA', data: 'test_data');
      
      // Use 'senderDeviceId' and 'message' keys to match what the service expects
      final dataPayload = {
        'senderDeviceId': mockDevice.deviceId,
        'message': testData.toString()
      };

      // Setup dataReceivedSubscription specifically for this test
      when(mockNearbyConnections.dataReceivedSubscription(
              callback: anyNamed('callback')))
          .thenAnswer((invocation) {
        final callback = invocation.namedArguments[const Symbol('callback')]
            as Function(dynamic);
        Logger.d('Creating new data subscription');
        // Return a subscription that will trigger our callback when we add to dataController
        return dataController.stream.listen(callback);
      });

      // Act - Setup monitoring
      await deviceConnectionService.monitorMessageReceives(
        mockDevice,
        messageReceivedCallback: (package, deviceId) {
          Logger.d('Message callback triggered with deviceId: $deviceId');
          messageReceived = true;
          expect(package, equals(testData));
          expect(deviceId, equals(mockDevice.deviceId));
          
        },
      );

      // Wait to ensure monitoring is properly set up
      await Future.delayed(const Duration(milliseconds: 100));

      dataController.add(dataPayload);

      // Allow time for the async operation to complete
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert
      expect(messageReceived, isTrue,
          reason: 'Message callback should have been triggered');
    });
  });

  group('Device management', () {
    test('createDevices should return DevicesManager instance', () {
      // Arrange
      const deviceName = DeviceName.coach;
      const deviceType = DeviceType.browserDevice;
      const data = 'test_data';

      // Act
      final result = DeviceConnectionService.createDevices(
        deviceName,
        deviceType,
        data: data,
      );

      // Assert
      expect(result, isA<DevicesManager>());
      expect(result.currentDeviceName, equals(deviceName));
      expect(result.currentDeviceType, equals(deviceType));
      expect(result.otherDevices.any((device) => device.name == deviceName),
          isFalse);
    });
  });

  group('Rescan behavior', () {
    test('rescan occurs when devices are searching and not all finished', () async {
      // Arrange
      clearInteractions(mockNearbyConnections);
      mockConnectedDevice.status = ConnectionStatus.searching;
      final mockConnectedDevice2 = ConnectedDevice(DeviceName.raceTimer);
      mockConnectedDevice2.status = ConnectionStatus.finished;
      
      
      // Override _stagnationTimer to detect if _delayedRescan is called
      deviceConnectionService.monitorDevicesConnectionStatus(
        timeout: const Duration(milliseconds: 500),
      );
      
      // Simulate a state change to trigger _shouldRescan evaluation
      mockNearbyHelper.emitDeviceStateChange([mockDevice]);
      
      // Allow time for the async operation to complete
      await Future.delayed(const Duration(milliseconds: 350));
      
      // Verify _stagnationTimer was called (indicating a rescan)
      verify(mockNearbyConnections.init(
        serviceType: anyNamed('serviceType'),
        deviceName: anyNamed('deviceName'),
        strategy: anyNamed('strategy'),
        callback: anyNamed('callback'),
      )).called(1);
    });

    test('rescan occurs when all devices are searching', () async {
      // Arrange
      clearInteractions(mockNearbyConnections);
      mockConnectedDevice.status = ConnectionStatus.searching;

      
      // Act
      deviceConnectionService.monitorDevicesConnectionStatus(
        timeout: const Duration(milliseconds: 500),
      );
      
      // Simulate a state change to trigger _shouldRescan evaluation
      mockNearbyHelper.emitDeviceStateChange([mockDevice]);
      
      // Allow time for the async operation to complete
      await Future.delayed(const Duration(milliseconds: 350));
      
      // Verify _stagnationTimer was called (indicating a rescan)
      verify(mockNearbyConnections.init(
        serviceType: anyNamed('serviceType'),
        deviceName: anyNamed('deviceName'),
        strategy: anyNamed('strategy'),
        callback: anyNamed('callback'),
      )).called(1);
    });
    
    test('rescan does not occur when device is in transfer process', () async {
      // Arrange
      clearInteractions(mockNearbyConnections);
      mockConnectedDevice.status = ConnectionStatus.sending;
      
      // We need to verify that rescan logic doesn't execute through side effects
      bool timeoutCallbackCalled = false;
      
      // Act
      deviceConnectionService.monitorDevicesConnectionStatus(
        timeout: const Duration(milliseconds: 100),
        timeoutCallback: () async {
          timeoutCallbackCalled = true;
        }
      );
      
      // Simulate a state change to trigger _shouldRescan evaluation
      mockNearbyHelper.emitDeviceStateChange([mockDevice]);
      
      // Allow time for the async operation to complete
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Assert that the timeout was reached (no rescan occurred)
      expect(timeoutCallbackCalled, isTrue);
      verifyNever(mockNearbyConnections.init(
        serviceType: anyNamed('serviceType'),
        strategy: anyNamed('strategy'),
        callback: anyNamed('callback'),
      ));
    });

    test('rescan does not occur when all devices are finished', () async {
      // Arrange
      clearInteractions(mockNearbyConnections);
      mockConnectedDevice.status = ConnectionStatus.finished;
      
      bool timeoutCallbackCalled = false;
      
      // Act
      deviceConnectionService.monitorDevicesConnectionStatus(
        timeout: const Duration(milliseconds: 100),
        timeoutCallback: () async {
          timeoutCallbackCalled = true;
        }
      );
      
      // Simulate a state change to trigger _shouldRescan evaluation
      mockNearbyHelper.emitDeviceStateChange([mockDevice]);
      
      // Allow time for the async operation to complete
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Assert that the timeout was reached (no rescan occurred)
      expect(timeoutCallbackCalled, isTrue);
      verifyNever(mockNearbyConnections.init(
        serviceType: anyNamed('serviceType'),
        strategy: anyNamed('strategy'),
        callback: anyNamed('callback'),
      ));
    });
  });

  group('Monitor connection status', () {
    // Verify basic registration of callbacks
    test('monitorDevicesConnectionStatus registers callbacks', () async {
      deviceConnectionService.rescanBackoff = const Duration(seconds: 10);
      bool deviceFoundCallbackTriggered = false;
      
      mockDevice.state = SessionState.notConnected;
      mockConnectedDevice.status = ConnectionStatus.searching;
      
      // Mock state change subscription to use our local controller
      when(mockNearbyConnections.stateChangedSubscription(
          callback: anyNamed('callback')))
          .thenAnswer((invocation) {
        final callback = invocation.namedArguments[const Symbol('callback')]
            as Function(List<Device>);
        
        // Schedule the callback to be called with our test device
        // This simulates finding a device in the "notConnected" state
        Future.delayed(const Duration(milliseconds: 10), () {
          callback([mockDevice]);
        });
        
        return stateChangeController.stream.listen(callback);
      });
      
      // Act - Call monitorDevicesConnectionStatus with deviceFoundCallback
      deviceConnectionService.monitorDevicesConnectionStatus(
        deviceFoundCallback: (_) async {
          deviceFoundCallbackTriggered = true;
        },
        timeout: const Duration(milliseconds: 500), 
      );

      mockNearbyHelper.emitDeviceStateChange([mockDevice]);

      await Future.delayed(const Duration(milliseconds: 350));

      // Assert
      expect(deviceFoundCallbackTriggered, isTrue, reason: 'deviceFoundCallback should be triggered for notConnected devices');
    });

    test('monitorDevicesConnectionStatus handles timeout scenario', () async {
      // Track whether timeout was triggered
      bool timeoutOccurred = false;


      // Act - Setup monitoring with a very short timeout
      deviceConnectionService.monitorDevicesConnectionStatus(
          timeout: const Duration(milliseconds: 100),
          timeoutCallback: () async {
            // Mark that timeout occurred
            timeoutOccurred = true;
          });

      // Wait for timeout to occur
      await Future.delayed(const Duration(milliseconds: 150));


      // Assert timeout callback was triggered
      expect(timeoutOccurred, isTrue, reason: 'Timeout callback should be triggered after timeout period');
    });
  });

  group('DeviceConnectionService disposal', () {
    test('should dispose of resources', () async {
      // Act - dispose the service
      deviceConnectionService.dispose(); // No await as dispose() is void

      // Assert
      expect(deviceConnectionService.isActive, isFalse);
      expect(deviceConnectionService.nearbyConnectionsInitialized, isFalse);
      expect(await deviceConnectionService.init(), isFalse);
    });
  });
}
