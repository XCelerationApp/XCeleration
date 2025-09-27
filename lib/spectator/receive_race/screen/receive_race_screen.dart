import 'package:flutter/material.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/components/connection_components.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/spectator/receive_race/services/race_share_decoder.dart';
import 'receive_race_preview_screen.dart';

class ReceiveRaceScreen extends StatefulWidget {
  const ReceiveRaceScreen({super.key});

  @override
  State<ReceiveRaceScreen> createState() => _ReceiveRaceScreenState();
}

class _ReceiveRaceScreenState extends State<ReceiveRaceScreen> {
  late DevicesManager devices;

  @override
  void initState() {
    super.initState();
    devices = DeviceConnectionService.createDevices(
      DeviceName.spectator,
      DeviceType.browserDevice,
    );
  }

  Future<void> _onComplete() async {
    // On browser, data will be placed on the coach ConnectedDevice in DevicesManager
    final data = devices.coach?.data;
    if (data == null || data.isEmpty) {
      if (!mounted) return;
      DialogUtils.showErrorDialog(context, message: 'No data received');
      return;
    }
    try {
      final decoded = RaceShareDecoder.decodeToResultsData(data);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReceiveRacePreviewScreen(data: decoded.results),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showErrorDialog(context, message: 'Import failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show as a sheet-style page content
    return Material(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Searching for nearby coaches...\nThis will automatically connect and receive a race.',
            ),
            const SizedBox(height: 16),
            WirelessConnectionWidget(
              devices: devices,
              callback: _onComplete,
            )
          ],
        ),
      ),
    );
  }
}
