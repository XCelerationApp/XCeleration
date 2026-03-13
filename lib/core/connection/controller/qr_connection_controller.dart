import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/barcode_scanner_interface.dart';
import 'package:xceleration/core/utils/connection_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/utils/platform_checker.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';

class QRConnectionController extends ChangeNotifier {
  final DevicesManager _devices;
  final PlatformCheckerInterface _platformChecker;
  final BarcodeScannerInterface _barcodeScanner;
  final Function _callback;

  AppError? _error;

  bool get hasError => _error != null;
  AppError? get error => _error;

  QRConnectionController({
    required DevicesManager devices,
    required PlatformCheckerInterface platformChecker,
    required Function callback,
    BarcodeScannerInterface barcodeScanner = const DefaultBarcodeScanner(),
  })  : _devices = devices,
        _platformChecker = platformChecker,
        _barcodeScanner = barcodeScanner,
        _callback = callback;

  Future<void> handleTap(BuildContext context) async {
    _clearError();
    if (_devices.currentDeviceType == DeviceType.advertiserDevice) {
      await _showQR(context, _devices.otherDevices.first.name);
    } else {
      await _scanQRCodes();
    }
  }

  Future<void> _showQR(BuildContext context, DeviceName device) async {
    final String rawData = _devices.getDevice(device)!.data!;
    Logger.d('Raw data: $rawData');
    final String qrData =
        '${getDeviceNameString(_devices.currentDeviceName)}:$rawData';

    await sheet(
      context: context,
      title: 'QR Code',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 250.0,
          ),
        ],
      ),
    );
  }

  Future<void> _scanQRCodes() async {
    if (!_platformChecker.isIOS && !_platformChecker.isAndroid) {
      _setError(const AppError(
        userMessage:
            'QR scanner is not available on this device. Please use a mobile device.',
      ));
      return;
    }

    try {
      final result = await _barcodeScanner.scan();

      if (result.type == ResultType.Barcode) {
        final parts = result.rawContent.split(':');

        DeviceName? scannedDeviceName;
        try {
          scannedDeviceName =
              _devices.getDevice(getDeviceNameFromString(parts[0]))?.name;
        } catch (_) {
          // No match found, scannedDeviceName remains null
        }

        if (parts.isEmpty || scannedDeviceName == null) {
          _setError(const AppError(userMessage: 'Incorrect QR Code Scanned'));
          return;
        }

        _devices.getDevice(scannedDeviceName)!.status =
            ConnectionStatus.finished;
        _devices.getDevice(scannedDeviceName)!.data =
            parts.sublist(1).join(':');
        Logger.d(
            'Data received: ${_devices.getDevice(scannedDeviceName)!.data}');

        if (_devices.allDevicesFinished()) {
          _callback();
        }
      }
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_NOT_GRANTED') {
        _setError(const AppError(
          userMessage: 'Camera permission is required to scan QR codes.',
        ));
      } else if (e.code == 'MissingPluginException') {
        _setError(const AppError(
          userMessage:
              'QR scanner is not available on this device. Please use a different connection method.',
        ));
      } else {
        Logger.e('[QRConnectionController] PlatformException: ${e.message}');
        _setError(const AppError(userMessage: 'Error scanning QR code'));
      }
    } catch (e) {
      Logger.e('[QRConnectionController] $e');
      _setError(const AppError(
        userMessage:
            'An error occurred while scanning the QR code. Please try again.',
      ));
    }
  }

  void _setError(AppError error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
