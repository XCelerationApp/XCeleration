import 'package:flutter/material.dart';
import 'connection_components.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../services/device_connection_service.dart';

Widget deviceConnectionWidget(
  BuildContext context,
  DevicesManager devices,
  {Function? callback}
) {
  void handleCallback() async {
    if (callback != null) {
      await callback();
    }
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/completed_ding.mp3'));
    } catch (e) {
      debugPrint('Error playing completion sound: $e');
    }

    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context);
    });
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