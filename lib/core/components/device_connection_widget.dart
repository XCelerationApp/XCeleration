import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/utils/connection_utils.dart';
import 'connection_components.dart';
import 'package:audioplayers/audioplayers.dart' as audio;
import '../services/device_connection_service.dart';
import '../services/nearby_connections.dart';
import '../utils/data_protocol.dart';
import '../connection/controller/wireless_connection_controller.dart';

/// A widget that renders both wireless and QR connection options.
///
/// It makes the wireless connection once and keeps it. Made in build, a new
/// one was made at every redraw of the screen around it, and the list kept
/// showing the first while the new one was never started.
class DeviceConnectionWidget extends StatefulWidget {
  final DevicesManager devices;
  final Function? callback;
  final bool inSheet;

  const DeviceConnectionWidget({
    super.key,
    required this.devices,
    this.callback,
    this.inSheet = true,
  });

  @override
  State<DeviceConnectionWidget> createState() => _DeviceConnectionWidgetState();
}

class _DeviceConnectionWidgetState extends State<DeviceConnectionWidget> {
  late final WirelessConnectionController _wireless = () {
    final devices = widget.devices;
    final svc = DeviceConnectionService(
      devices,
      'wirelessconn',
      getDeviceWireName(devices.currentDeviceName),
      devices.currentDeviceType,
      NearbyConnections(),
    );
    return WirelessConnectionController(
      deviceConnectionService: svc,
      protocol: Protocol(deviceConnectionService: svc),
      devices: devices,
      callback: () => _handleCallback(context),
    );
  }();

  DevicesManager get devices => widget.devices;
  bool get inSheet => widget.inSheet;

  void _handleCallback(BuildContext context) async {
    final callback = widget.callback;
    if (callback != null) {
      await callback();
    }
    try {
      final player = audio.AudioPlayer();
      await player.play(audio.AssetSource('sounds/completed_ding.mp3'));
    } catch (e) {
      Logger.d('Error playing completion sound: $e');
    }
    if (inSheet) {
      Future.delayed(const Duration(seconds: 1), () {
        if (context.mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WirelessConnectionWidget(controller: _wireless),

        // Separator
        const SizedBox(height: 16),
        const Text(
          'or',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black54,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 16),

        // QR connection button
        QRConnectionWidget(
          devices: devices,
          callback: () => _handleCallback(context),
          inSheet: inSheet,
        ),
      ],
    );
  }
}
