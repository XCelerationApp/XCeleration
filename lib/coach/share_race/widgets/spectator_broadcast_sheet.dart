import 'package:flutter/material.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/enums.dart';

class SpectatorBroadcastSheet extends StatefulWidget {
  final DevicesManager devices;

  const SpectatorBroadcastSheet({super.key, required this.devices});

  @override
  State<SpectatorBroadcastSheet> createState() =>
      _SpectatorBroadcastSheetState();
}

class _SpectatorBroadcastSheetState extends State<SpectatorBroadcastSheet> {
  final Set<ConnectedDevice> _finished = {};
  final _finishedCount = ValueNotifier<int>(0);
  final Map<ConnectedDevice, VoidCallback> _listeners = {};

  @override
  void initState() {
    super.initState();
    for (final d in widget.devices.otherDevices) {
      void listener() => _onDeviceChanged(d);
      _listeners[d] = listener;
      d.addListener(listener);
    }
  }

  void _onDeviceChanged(ConnectedDevice device) {
    if (!mounted) return;
    if (device.status == ConnectionStatus.finished && _finished.add(device)) {
      _finishedCount.value = _finished.length;
    }
  }

  @override
  void dispose() {
    for (final entry in _listeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _finishedCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(color: AppColors.lightColor, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _finishedCount,
                  builder: (context, count, _) => Text(
                    'Sent to $count device${count == 1 ? '' : 's'}',
                    style: AppTypography.bodySemibold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop'),
              )
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Underlying wireless connection UI modeled after coach↔assistant
        DeviceConnectionWidget(devices: widget.devices),
      ],
    );
  }
}
