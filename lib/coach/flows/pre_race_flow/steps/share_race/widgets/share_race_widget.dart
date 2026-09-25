import 'package:flutter/material.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/theme/app_spacing.dart';

class ShareRaceWidget extends StatelessWidget {
  final DevicesManager devices;
  const ShareRaceWidget({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Center(
          child: DeviceConnectionWidget(devices: devices, inSheet: false)),
    );
  }
}
