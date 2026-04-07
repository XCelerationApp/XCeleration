import 'package:flutter/material.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/device_connection_factory_impl.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';

/// Shows the "Load a new race from Coach" sheet and feeds the received data
/// to [onData]. Displays an error snackbar on failure.
///
/// Shared across finish-line role screens (BibRecorderV2, Verifier, Fixer).
Future<void> getFromCoach({
  required BuildContext context,
  required DeviceName deviceName,
  required Future<Result<void>> Function(String data) onData,
}) async {
  final devices = const DeviceConnectionFactoryImpl().createDevices(
    deviceName,
    DeviceType.browserDevice,
  );
  await sheet(
    context: context,
    title: 'Load a new race from Coach',
    body: DeviceConnectionWidget(devices: devices),
  );
  final data = devices.coach?.data;
  if (data == null || !context.mounted) return;
  final result = await onData(data);
  if (!context.mounted) return;
  if (result case Failure(:final error)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.userMessage)),
    );
  }
}
