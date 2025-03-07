import 'package:flutter/material.dart';
import 'connection_components.dart';
import '../../utils/enums.dart';
import 'dart:async';

Widget deviceConnectionWidget(
  DeviceName deviceName, 
  DeviceType deviceType, 
  Map<DeviceName, Map<String, dynamic>> otherDevices, 
  {Function? callback}
) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
        WirelessConnectionWidget(
          deviceName: deviceName,
          deviceType: deviceType,
          otherDevices: otherDevices,
          callback: callback,
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
          deviceName: deviceName,
          deviceType: deviceType,
          otherDevices: otherDevices,
          callback: callback,
        ),
    ],
  );
}