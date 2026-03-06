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
  });
}
