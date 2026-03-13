import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../services/device_connection_service.dart';
import '../utils/enums.dart';
import '../connection/controller/wireless_connection_controller.dart';
import 'wireless_connection_button.dart';

class WirelessConnectionWidget extends StatefulWidget {
  final WirelessConnectionController controller;

  const WirelessConnectionWidget({
    super.key,
    required this.controller,
  });

  @override
  State<WirelessConnectionWidget> createState() => _WirelessConnectionState();
}

class _WirelessConnectionState extends State<WirelessConnectionWidget> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    widget.controller.initialize();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    if (controller.wirelessConnectionError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: WirelessConnectionButton(
              device: ConnectedDevice(DeviceName.coach),
            ).error(
              error: controller.wirelessConnectionError!,
              retryAction: controller.retry,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var device in controller.devices.otherDevices)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: controller.isLoading
                ? WirelessConnectionButton(device: device).skeleton
                : WirelessConnectionButton(device: device),
          ),
      ],
    );
  }
}
