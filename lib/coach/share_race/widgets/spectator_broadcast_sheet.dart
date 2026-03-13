import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/theme/app_colors.dart';
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
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    // Listen for device status changes to compute sent count
    for (final d in widget.devices.otherDevices) {
      d.addListener(_onDeviceChanged);
    }
    // Auto-timeout after 2 minutes
    _timeoutTimer = Timer(const Duration(minutes: 2), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void _onDeviceChanged() {
    if (!mounted) return;
    setState(() {
      for (final d in widget.devices.otherDevices) {
        if (d.status == ConnectionStatus.finished) {
          _finished.add(d);
        }
      }
    });
  }

  @override
  void dispose() {
    for (final d in widget.devices.otherDevices) {
      d.removeListener(_onDeviceChanged);
    }
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightColor, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Sent to ${_finished.length} device${_finished.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
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
        const SizedBox(height: 12),
        // Underlying wireless connection UI modeled after coach↔assistant
        DeviceConnectionWidget(devices: widget.devices),
      ],
    );
  }
}
