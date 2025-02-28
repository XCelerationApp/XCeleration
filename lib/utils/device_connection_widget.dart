import 'package:flutter/material.dart';
import 'connection_components.dart';
import 'enums.dart';
import 'dart:async';

Widget deviceConnectionWidget(DeviceName deviceName, DeviceType deviceType, Map<DeviceName, Map<String, dynamic>> otherDevices) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Replace ListView.builder with Column of SearchableButtons
      ...otherDevices.keys.map((deviceKey) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ConnectionButton(
            deviceName: deviceKey,
            connectionStatus: otherDevices[deviceKey]!['status'],
          ),
        );
      }),
      const SizedBox(height: 16),
      const Text(
        'or',
        style: TextStyle(
          fontSize: 16,
          color: Colors.black54,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 24),
      ConnectionButton(
        deviceName: deviceName,
        deviceType: deviceType,
        icon: Icons.qr_code,
        connectionStatus: otherDevices.values.first['status'],
        isQrCode: true,
      ),
    ],
  );
}

Future<void> waitForDataTransferCompletion( Map<DeviceName, Map<String, dynamic>> otherDevices) async {
  Completer<void> completer = Completer<void>();
  Future.wait(otherDevices.keys.map((deviceName) async {
    while (otherDevices[deviceName]!['status'] != ConnectionStatus.finished) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  })).then((_) async {
    completer.complete();
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