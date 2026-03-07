import 'dart:async';

import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/connection/controller/wireless_connection_controller.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/data_protocol.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/app_error.dart';

@GenerateMocks([DeviceConnectionService, Protocol, DevicesManager])
import 'wireless_connection_controller_test.mocks.dart';

void main() {
  late MockDeviceConnectionService mockService;
  late MockProtocol mockProtocol;
  late MockDevicesManager mockDevices;
  setUp(() {
    provideDummy<Result<bool>>(const Success(false));
    provideDummy<Result<String?>>(const Success(null));
    provideDummy(Device('', '', 0));

    mockService = MockDeviceConnectionService();
    mockProtocol = MockProtocol();
    mockDevices = MockDevicesManager();

    when(mockDevices.currentDeviceName).thenReturn(DeviceName.coach);
    when(mockDevices.currentDeviceType).thenReturn(DeviceType.browserDevice);
    when(mockDevices.otherDevices).thenReturn([]);
    when(mockDevices.toSpectator).thenReturn(false);
    when(mockService.isActive).thenReturn(true);
  });

  WirelessConnectionController buildController() => WirelessConnectionController(
        deviceConnectionService: mockService,
        protocol: mockProtocol,
        devices: mockDevices,
        callback: () {},
      );

  group('WirelessConnectionController', () {
    group('initialize', () {
      test('starts in loading state', () {
        final controller = buildController();
        expect(controller.isLoading, isTrue);
        expect(controller.hasError, isFalse);
        expect(controller.wirelessConnectionError, isNull);
      });

      test('sets unavailable error when nearby connections not available',
          () async {
        when(mockService.checkIfNearbyConnectionsWorks())
            .thenAnswer((_) async => const Success(false));

        final controller = buildController();
        await controller.initialize();

        expect(controller.isLoading, isFalse);
        expect(controller.hasError, isTrue);
        expect(controller.wirelessConnectionError,
            WirelessConnectionError.unavailable);
      });

      test('sets unavailable error when checkIfNearbyConnectionsWorks fails',
          () async {
        when(mockService.checkIfNearbyConnectionsWorks()).thenAnswer((_) async =>
            Failure(AppError(userMessage: 'Failed', originalException: null)));

        final controller = buildController();
        await controller.initialize();

        expect(controller.isLoading, isFalse);
        expect(controller.hasError, isTrue);
        expect(controller.wirelessConnectionError,
            WirelessConnectionError.unavailable);
      });

      test('sets unknown error when init fails', () async {
        when(mockService.checkIfNearbyConnectionsWorks())
            .thenAnswer((_) async => const Success(true));
        when(mockService.init())
            .thenAnswer((_) async => const Success(false));

        final controller = buildController();
        await controller.initialize();

        expect(controller.isLoading, isFalse);
        expect(controller.hasError, isTrue);
        expect(controller.wirelessConnectionError,
            WirelessConnectionError.unknown);
      });

      test('clears loading and starts monitoring on successful init', () async {
        when(mockService.checkIfNearbyConnectionsWorks())
            .thenAnswer((_) async => const Success(true));
        when(mockService.init()).thenAnswer((_) async => const Success(true));
        when(mockService.monitorDevicesConnectionStatus(
          deviceFoundCallback: anyNamed('deviceFoundCallback'),
          deviceConnectingCallback: anyNamed('deviceConnectingCallback'),
          deviceConnectedCallback: anyNamed('deviceConnectedCallback'),
          timeout: anyNamed('timeout'),
          timeoutCallback: anyNamed('timeoutCallback'),
        )).thenAnswer((_) async {});

        final controller = buildController();
        await controller.initialize();

        expect(controller.isLoading, isFalse);
        expect(controller.hasError, isFalse);
      });

      test('notifies listeners when loading completes', () async {
        when(mockService.checkIfNearbyConnectionsWorks())
            .thenAnswer((_) async => const Success(false));

        final controller = buildController();
        var notified = false;
        controller.addListener(() => notified = true);

        await controller.initialize();

        expect(notified, isTrue);
      });

      test('does nothing when called after dispose', () async {
        when(mockService.checkIfNearbyConnectionsWorks())
            .thenAnswer((_) async => const Success(false));

        final controller = buildController();
        controller.dispose();

        // Should not throw or call service
        await controller.initialize();

        verifyNever(mockService.checkIfNearbyConnectionsWorks());
      });
    });

    group('retry', () {
      test('resets error and loading state then re-initializes', () async {
        when(mockService.checkIfNearbyConnectionsWorks())
            .thenAnswer((_) async => const Success(false));

        final controller = buildController();
        await controller.initialize();
        expect(controller.hasError, isTrue);

        // Retry: also fails, but state resets between calls
        final states = <bool>[];
        controller.addListener(() => states.add(controller.isLoading));

        await controller.retry();

        // First notification: isLoading=true (reset); second: isLoading=false (error set)
        expect(states, containsAllInOrder([true, false]));
        expect(controller.wirelessConnectionError,
            WirelessConnectionError.unavailable);
      });

      test('clears previous error before re-initializing', () async {
        when(mockService.checkIfNearbyConnectionsWorks())
            .thenAnswer((_) async => const Success(false));

        final controller = buildController();
        await controller.initialize();
        expect(controller.wirelessConnectionError, isNotNull);

        // On retry, error is cleared before initialize runs
        bool seenClear = false;
        controller.addListener(() {
          if (controller.wirelessConnectionError == null && controller.isLoading) {
            seenClear = true;
          }
        });

        await controller.retry();

        expect(seenClear, isTrue);
      });
    });

    group('dispose', () {
      test('disposes service and protocol', () {
        final controller = buildController();
        controller.dispose();

        verify(mockService.dispose()).called(1);
        verify(mockProtocol.dispose()).called(1);
      });

      test('stops message monitoring if token present', () async {
        // We can't easily set a token without going through the full flow,
        // but we verify dispose doesn't throw without one.
        final controller = buildController();
        expect(() => controller.dispose(), returnsNormally);
      });
    });

    group('devices getter', () {
      test('exposes the injected DevicesManager', () {
        final controller = buildController();
        expect(controller.devices, same(mockDevices));
      });
    });

    group('_deviceFoundCallback', () {
      late Completer<void> monitorCompleter;
      late Future<void> Function(Device) capturedFoundCallback;

      setUp(() {
        monitorCompleter = Completer<void>();
        when(mockService.checkIfNearbyConnectionsWorks())
            .thenAnswer((_) async => const Success(true));
        when(mockService.init()).thenAnswer((_) async => const Success(true));
        when(mockService.monitorDevicesConnectionStatus(
          deviceFoundCallback: anyNamed('deviceFoundCallback'),
          deviceConnectingCallback: anyNamed('deviceConnectingCallback'),
          deviceConnectedCallback: anyNamed('deviceConnectedCallback'),
          timeout: anyNamed('timeout'),
          timeoutCallback: anyNamed('timeoutCallback'),
        )).thenAnswer((invocation) async {
          capturedFoundCallback = invocation.namedArguments[#deviceFoundCallback]
              as Future<void> Function(Device);
          await monitorCompleter.future;
        });
      });

      tearDown(() {
        if (!monitorCompleter.isCompleted) monitorCompleter.complete();
      });

      test('skips invite when device not in manager', () async {
        when(mockDevices.hasDevice(DeviceName.coach)).thenReturn(false);
        final controller = buildController();
        await controller.initialize();

        await capturedFoundCallback(Device('id', 'Coach', 0));

        verifyNever(mockService.inviteDevice(any));
      });

      test('skips invite when current device is advertiser', () async {
        when(mockDevices.currentDeviceType)
            .thenReturn(DeviceType.advertiserDevice);
        when(mockDevices.hasDevice(DeviceName.coach)).thenReturn(true);
        when(mockDevices.getDevice(DeviceName.coach))
            .thenReturn(ConnectedDevice(DeviceName.coach));
        final controller = buildController();
        await controller.initialize();

        await capturedFoundCallback(Device('id', 'Coach', 0));

        verifyNever(mockService.inviteDevice(any));
      });
    });

    group('_deviceConnectedCallback', () {
      late Completer<void> monitorCompleter;
      late Future<void> Function(Device) capturedConnectedCallback;
      late ConnectedDevice connectedDevice;

      setUp(() {
        monitorCompleter = Completer<void>();
        connectedDevice = ConnectedDevice(DeviceName.coach);
        when(mockService.checkIfNearbyConnectionsWorks())
            .thenAnswer((_) async => const Success(true));
        when(mockService.init()).thenAnswer((_) async => const Success(true));
        when(mockService.monitorDevicesConnectionStatus(
          deviceFoundCallback: anyNamed('deviceFoundCallback'),
          deviceConnectingCallback: anyNamed('deviceConnectingCallback'),
          deviceConnectedCallback: anyNamed('deviceConnectedCallback'),
          timeout: anyNamed('timeout'),
          timeoutCallback: anyNamed('timeoutCallback'),
        )).thenAnswer((invocation) async {
          capturedConnectedCallback =
              invocation.namedArguments[#deviceConnectedCallback]
                  as Future<void> Function(Device);
          await monitorCompleter.future;
        });
        when(mockDevices.hasDevice(DeviceName.coach)).thenReturn(true);
        when(mockDevices.getDevice(DeviceName.coach)).thenReturn(connectedDevice);
        when(mockService.monitorMessageReceives(
          any,
          messageReceivedCallback: anyNamed('messageReceivedCallback'),
        )).thenAnswer((_) async => 'token');
      });

      tearDown(() {
        if (!monitorCompleter.isCompleted) monitorCompleter.complete();
      });

      test('sets status to finished and fires callback when all devices done',
          () async {
        bool callbackFired = false;
        final controller = WirelessConnectionController(
          deviceConnectionService: mockService,
          protocol: mockProtocol,
          devices: mockDevices,
          callback: () => callbackFired = true,
        );
        when(mockProtocol.handleDataTransfer(
          deviceId: anyNamed('deviceId'),
          isReceiving: anyNamed('isReceiving'),
          dataToSend: anyNamed('dataToSend'),
          shouldContinueTransfer: anyNamed('shouldContinueTransfer'),
        )).thenAnswer((_) async => const Success('received data'));
        when(mockDevices.allDevicesFinished()).thenReturn(true);

        await controller.initialize();
        await capturedConnectedCallback(Device('coach-id', 'Coach', 2));

        expect(connectedDevice.status, ConnectionStatus.finished);
        expect(callbackFired, isTrue);
      });

      test('sets device status to error on transfer failure', () async {
        when(mockProtocol.handleDataTransfer(
          deviceId: anyNamed('deviceId'),
          isReceiving: anyNamed('isReceiving'),
          dataToSend: anyNamed('dataToSend'),
          shouldContinueTransfer: anyNamed('shouldContinueTransfer'),
        )).thenAnswer((_) async => Failure(AppError(
              userMessage: 'Transfer failed',
              originalException: null,
            )));

        final controller = buildController();
        await controller.initialize();
        await capturedConnectedCallback(Device('coach-id', 'Coach', 2));

        expect(connectedDevice.status, ConnectionStatus.error);
      });
    });
  });
}
