import 'package:flutter/material.dart';
import 'connection_components.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart' as audio;
import '../services/device_connection_service.dart';

Widget deviceConnectionWidget(BuildContext context, DevicesManager devices,
    {Function? callback, bool inSheet = true}) {
  void handleCallback() async {
    if (callback != null) {
      await callback();
    }
    try {
      final player = audio.AudioPlayer();
      await player.play(audio.AssetSource('sounds/completed_ding.mp3'));
    } catch (e) {
      debugPrint('Error playing completion sound: $e');
    }
    if (inSheet) {
      Future.delayed(const Duration(seconds: 1), () {
        // Check if the context is still valid before using Navigator
        if (context.mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      WirelessConnectionWidget(
        devices: devices,
        callback: handleCallback,
      ),

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
        callback: handleCallback,
      ),
    ],
  );
}
