import 'package:flutter/material.dart';
import 'connection_components.dart';
import 'enums.dart';
import 'dart:async';

Widget deviceConnectionWidget(DeviceName deviceName, DeviceType deviceType, Map<DeviceName, Map<String, dynamic>> otherDevices) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
        WirelessConnectionWidget(
          deviceName: deviceName,
          deviceType: deviceType,
          otherDevices: otherDevices,
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
        ),
    ],
  );
}

Future<bool> waitForDataTransferCompletion(Map<DeviceName, Map<String, dynamic>> otherDevices) async {
  final completer = Completer<bool>();
  
  Timer.periodic(const Duration(milliseconds: 100), (timer) {
    final allFinished = otherDevices.values
        .every((device) => device['status'] == ConnectionStatus.finished);
    if (allFinished) {
      timer.cancel();
      completer.complete(true);
    }
  });
  
  return completer.future;
}

Map<DeviceName, Map<String, dynamic>> createOtherDeviceList(DeviceName deviceName, DeviceType deviceType, {String? data}) {
  Map<DeviceName, Map<String, dynamic>> devices = {}; 
  if (deviceType == DeviceType.advertiserDevice) {
    if (data == null) {
      throw Exception('Data to transfer must be provided for advertiser devices');
    }
    if (deviceName == DeviceName.coach) {
      devices[DeviceName.bibRecorder] = {
        'status': ConnectionStatus.searching,
        'data': data,
      };
    }
    else {
      devices[DeviceName.coach] = {
        'status': ConnectionStatus.searching,
        'data': data,
      };
    }
  }
  else {
    if (deviceName == DeviceName.coach) {
      devices[DeviceName.bibRecorder] = {
        'status': ConnectionStatus.searching,
      };
      devices[DeviceName.raceTimer] = {
        'status': ConnectionStatus.searching,
      };
    }
    else {
      devices[DeviceName.coach] = {
        'status': ConnectionStatus.searching,
      };
    }
  }
  return devices;
}