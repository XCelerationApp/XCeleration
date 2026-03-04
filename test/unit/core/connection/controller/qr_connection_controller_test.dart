import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/connection/controller/qr_connection_controller.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/barcode_scanner_interface.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/platform_checker.dart';

@GenerateMocks(
    [DevicesManager, PlatformCheckerInterface, BarcodeScannerInterface])
import 'qr_connection_controller_test.mocks.dart';

void main() {
  late MockDevicesManager mockDevices;
  late MockPlatformCheckerInterface mockPlatformChecker;
  late MockBarcodeScannerInterface mockBarcodeScanner;
  late bool callbackInvoked;

  setUp(() {
    mockDevices = MockDevicesManager();
    mockPlatformChecker = MockPlatformCheckerInterface();
    mockBarcodeScanner = MockBarcodeScannerInterface();
    callbackInvoked = false;

    when(mockDevices.currentDeviceType).thenReturn(DeviceType.browserDevice);
    when(mockPlatformChecker.isAndroid).thenReturn(false);
    when(mockPlatformChecker.isIOS).thenReturn(false);
  });

  QRConnectionController buildController() => QRConnectionController(
        devices: mockDevices,
        platformChecker: mockPlatformChecker,
        barcodeScanner: mockBarcodeScanner,
        callback: () => callbackInvoked = true,
      );

  /// Pumps a minimal widget tree and returns a valid BuildContext.
  Future<BuildContext> pumpContext(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    return tester.element(find.byType(SizedBox));
  }

  group('QRConnectionController', () {
    group('handleTap — browser device on non-mobile platform', () {
      testWidgets('sets hasError with platform-unavailable message',
          (tester) async {
        final ctx = await pumpContext(tester);
        final controller = buildController();

        await controller.handleTap(ctx);

        expect(controller.hasError, isTrue);
        expect(
          controller.error!.userMessage,
          'QR scanner is not available on this device. Please use a mobile device.',
        );
      });

      testWidgets('notifies listeners when error is set', (tester) async {
        final ctx = await pumpContext(tester);
        final controller = buildController();
        var notified = false;
        controller.addListener(() => notified = true);

        await controller.handleTap(ctx);

        expect(notified, isTrue);
      });
    });

    group('handleTap — browser device with scan success', () {
      setUp(() {
        when(mockPlatformChecker.isAndroid).thenReturn(true);
        when(mockPlatformChecker.isIOS).thenReturn(false);
      });

      testWidgets('updates device status and data on valid QR scan',
          (tester) async {
        final ctx = await pumpContext(tester);
        final device = ConnectedDevice(DeviceName.coach);
        when(mockDevices.getDevice(DeviceName.coach)).thenReturn(device);
        when(mockDevices.allDevicesFinished()).thenReturn(false);
        when(mockBarcodeScanner.scan()).thenAnswer((_) async => ScanResult(
              type: ResultType.Barcode,
              rawContent: 'Coach:somedata:extra',
              format: BarcodeFormat.qr,
            ));

        final controller = buildController();
        await controller.handleTap(ctx);

        expect(controller.hasError, isFalse);
        expect(device.status, ConnectionStatus.finished);
        expect(device.data, 'somedata:extra');
      });

      testWidgets('invokes callback when all devices finished', (tester) async {
        final ctx = await pumpContext(tester);
        final device = ConnectedDevice(DeviceName.coach);
        when(mockDevices.getDevice(DeviceName.coach)).thenReturn(device);
        when(mockDevices.allDevicesFinished()).thenReturn(true);
        when(mockBarcodeScanner.scan()).thenAnswer((_) async => ScanResult(
              type: ResultType.Barcode,
              rawContent: 'Coach:payload',
              format: BarcodeFormat.qr,
            ));

        final controller = buildController();
        await controller.handleTap(ctx);

        expect(callbackInvoked, isTrue);
      });

      testWidgets('does not invoke callback when not all devices finished',
          (tester) async {
        final ctx = await pumpContext(tester);
        final device = ConnectedDevice(DeviceName.coach);
        when(mockDevices.getDevice(DeviceName.coach)).thenReturn(device);
        when(mockDevices.allDevicesFinished()).thenReturn(false);
        when(mockBarcodeScanner.scan()).thenAnswer((_) async => ScanResult(
              type: ResultType.Barcode,
              rawContent: 'Coach:payload',
              format: BarcodeFormat.qr,
            ));

        final controller = buildController();
        await controller.handleTap(ctx);

        expect(callbackInvoked, isFalse);
      });

      testWidgets('sets error when QR content has unrecognised device name',
          (tester) async {
        final ctx = await pumpContext(tester);
        when(mockBarcodeScanner.scan()).thenAnswer((_) async => ScanResult(
              type: ResultType.Barcode,
              rawContent: 'UnknownDevice:data',
              format: BarcodeFormat.qr,
            ));
        when(mockDevices.getDevice(any)).thenReturn(null);

        final controller = buildController();
        await controller.handleTap(ctx);

        expect(controller.hasError, isTrue);
        expect(controller.error!.userMessage, 'Incorrect QR Code Scanned');
      });

      testWidgets('sets camera-permission error on PERMISSION_NOT_GRANTED',
          (tester) async {
        final ctx = await pumpContext(tester);
        when(mockBarcodeScanner.scan())
            .thenThrow(PlatformException(code: 'PERMISSION_NOT_GRANTED'));

        final controller = buildController();
        await controller.handleTap(ctx);

        expect(controller.hasError, isTrue);
        expect(controller.error!.userMessage,
            'Camera permission is required to scan QR codes.');
      });

      testWidgets('sets plugin-unavailable error on MissingPluginException',
          (tester) async {
        final ctx = await pumpContext(tester);
        when(mockBarcodeScanner.scan())
            .thenThrow(PlatformException(code: 'MissingPluginException'));

        final controller = buildController();
        await controller.handleTap(ctx);

        expect(controller.hasError, isTrue);
        expect(
          controller.error!.userMessage,
          'QR scanner is not available on this device. Please use a different connection method.',
        );
      });

      testWidgets('sets generic error on unknown PlatformException',
          (tester) async {
        final ctx = await pumpContext(tester);
        when(mockBarcodeScanner.scan())
            .thenThrow(PlatformException(code: 'UNKNOWN'));

        final controller = buildController();
        await controller.handleTap(ctx);

        expect(controller.hasError, isTrue);
        expect(controller.error!.userMessage, 'Error scanning QR code');
      });

      testWidgets('sets generic error on unexpected exception', (tester) async {
        final ctx = await pumpContext(tester);
        when(mockBarcodeScanner.scan()).thenThrow(Exception('network failure'));

        final controller = buildController();
        await controller.handleTap(ctx);

        expect(controller.hasError, isTrue);
        expect(
          controller.error!.userMessage,
          'An error occurred while scanning the QR code. Please try again.',
        );
      });

      testWidgets('clears previous error on subsequent handleTap call',
          (tester) async {
        // First call on non-mobile → error
        when(mockPlatformChecker.isAndroid).thenReturn(false);
        when(mockPlatformChecker.isIOS).thenReturn(false);
        final ctx = await pumpContext(tester);
        final controller = buildController();
        await controller.handleTap(ctx);
        expect(controller.hasError, isTrue);

        // Second call on mobile → scan succeeds, error cleared
        when(mockPlatformChecker.isAndroid).thenReturn(true);
        final device = ConnectedDevice(DeviceName.coach);
        when(mockDevices.getDevice(DeviceName.coach)).thenReturn(device);
        when(mockDevices.allDevicesFinished()).thenReturn(false);
        when(mockBarcodeScanner.scan()).thenAnswer((_) async => ScanResult(
              type: ResultType.Barcode,
              rawContent: 'Coach:data',
              format: BarcodeFormat.qr,
            ));

        await controller.handleTap(ctx);

        expect(controller.hasError, isFalse);
      });
    });
  });
}
