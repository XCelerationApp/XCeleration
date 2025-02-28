import 'package:flutter/material.dart';
import 'connection_utils.dart';
import 'enums.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'device_connection_service.dart';
import 'data_protocol.dart';
import 'dialog_utils.dart';
import 'sheet_utils.dart';
import 'enums.dart' show DeviceName, DeviceType, ConnectionStatus, WirelessConnectionError;


class ConnectionButton extends StatefulWidget {
  final DeviceName deviceName;
  final DeviceType? deviceType;
  final IconData? icon;
  final ConnectionStatus connectionStatus;
  final bool isQrCode;

  const ConnectionButton({
    super.key,
    required this.deviceName,
    this.deviceType,
    this.icon = Icons.person,
    required this.connectionStatus,
    this.isQrCode = false,
  });

  @override
  State<ConnectionButton> createState() => _ConnectionButtonState();
}

class _ConnectionButtonState extends State<ConnectionButton> {
  @override
  void initState() {
    super.initState();
    if (widget.isQrCode && widget.deviceType == null) {
      throw Exception('Cannot show QR code for device type null');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isQrCode) ...[
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon ?? Icons.person,
                      color: Colors.black54,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      widget.deviceType == DeviceType.advertiserDevice ? 'Show QR Code' : 'Scan QR Code',
                      style: const TextStyle(
                      fontSize: 17,
                      color: Colors.black87,
                    ),
                  ),    
                  ]
                ),
              ),
            )
          ] else ...[
            Icon(
              widget.icon ?? Icons.person,
              color: Colors.black54,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              getDeviceNameString(widget.deviceName),
              style: const TextStyle(
                fontSize: 17,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.connectionStatus == ConnectionStatus.finished) ...[
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Searching',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}


class QRConnectionWidget extends StatefulWidget {
  final Widget child;
  final DeviceName deviceName;
  final DeviceType deviceType;
  final Map<DeviceName, Map<String, dynamic>> otherDevices;
  const QRConnectionWidget({
    super.key,
    required this.child,
    required this.deviceName,
    required this.deviceType,
    required this.otherDevices,
  });

  @override
  State<QRConnectionWidget> createState() => _QRConnectionState();
}

class _QRConnectionState extends State<QRConnectionWidget> {

  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    if (widget.deviceType == DeviceType.advertiserDevice && widget.otherDevices.length != 1) {
      throw Exception('Can only show data for one device');
    }
    _audioPlayer = AudioPlayer();
  }

  void _showQR(BuildContext context, DeviceName device) {
    sheet(
      context: context,
      title: 'QR Code',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: widget.otherDevices[device]!['data'],
            version: QrVersions.auto,
            size: 250.0,
          ),
        ],
      ),
    );
  }

  Future<void> _scanQRCodes() async {
    try {
      final result = await BarcodeScanner.scan();
      if (!mounted) return;

      if (result.type == ResultType.Barcode) {
        final parts = result.rawContent.split(':');
        
        DeviceName? scannedDeviceName;
        try {
          scannedDeviceName = widget.otherDevices.keys.firstWhere(
            (element) => getDeviceNameString(element) == parts[0]
          );
        } catch (e) {
          // No match found, scanDeviceName remains null
        }
        
        if (parts.isEmpty || scannedDeviceName == null) {
          DialogUtils.showErrorDialog(context, message: 'Incorrect QR Code Scanned');
          return;
        }
        try {
          await _audioPlayer.play(AssetSource('sounds/completed_ding.mp3'));
        } catch (e) {
          debugPrint('Error playing completion sound: $e');
        }
        setState(() {
          widget.otherDevices[scannedDeviceName]!['status'] = ConnectionStatus.finished;
          widget.otherDevices[scannedDeviceName]!['data'] = parts.sublist(1).join(':');
        });
      }
    } on MissingPluginException {
      DialogUtils.showErrorDialog(context, message: 'The QR code scanner is not available on this device.');
    } catch (e) {
      DialogUtils.showErrorDialog(context, message: 'An unknown error occurred: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.deviceType == DeviceType.advertiserDevice) {
          _showQR(context, widget.otherDevices.keys.elementAt(0));
        }
        else {
          _scanQRCodes();
        }
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class WirelessConnectionWidget extends StatefulWidget {
  final Widget child;
  final DeviceName deviceName;
  final DeviceType deviceType;
  final Map<DeviceName, Map<String, dynamic>> otherDevices;
  final Future<void> Function(DeviceName deviceName) showQRCode;
  const WirelessConnectionWidget({
    super.key,
    required this.child,
    required this.deviceName,
    required this.deviceType,
    required this.otherDevices,
    required this.showQRCode,
  });
  @override
  State<WirelessConnectionWidget> createState() => _WirelessConnectionState();
}

class _WirelessConnectionState extends State<WirelessConnectionWidget> {
  late DeviceConnectionService _deviceConnectionService;
  late Protocol _protocol;
  WirelessConnectionError? _wirelessConnectionError;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _deviceConnectionService = DeviceConnectionService();
    _protocol = Protocol(deviceConnectionService: _deviceConnectionService);

    try {
      final isServiceAvailable = await _deviceConnectionService.checkIfNearbyConnectionsWorks();
      if (!isServiceAvailable) {
        debugPrint('Device connection service is not available on this platform');
        setState(() {
          _wirelessConnectionError = WirelessConnectionError.unavailable;
        });
        return;
      }
      _audioPlayer = AudioPlayer();

      try {
        await _deviceConnectionService.init(
          'wirelessconn',
          getDeviceNameString(widget.deviceName),
          widget.deviceType,
        );
      } catch (e) {
        debugPrint('Error initializing device connection service: $e');
        rethrow;
      }
      try {
        _connectAndTransferData();
      } catch (e) {
        debugPrint('Error connecting and transferring data: $e');
        rethrow;
      }
    } catch (e) {
      debugPrint('Error in device connection popup: $e');
      setState(() {
        _wirelessConnectionError = WirelessConnectionError.unknown;
      });
      for (var deviceName in widget.otherDevices.keys) {
        if (widget.otherDevices[deviceName]!['status'] != ConnectionStatus.finished) {
          widget.otherDevices[deviceName]!['status'] = ConnectionStatus.searching;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          DialogUtils.showErrorDialog(
            context,
            title: 'Error',
            message: 'An error occurred while trying to connect. Please try again.',
          );
        }
      });
    }
  }

  Future<void> _connectAndTransferData() async {
    Future<void> deviceFoundCallback (device) async {
      final deviceName = getDeviceNameFromString(device.deviceName);
      if (!widget.otherDevices.containsKey(deviceName) || 
          widget.otherDevices[deviceName]!['status'] == ConnectionStatus.finished) {
        debugPrint('Ignoring device because it is not in the list of other devices or finished: ${device.deviceName}');
        return;
      }
      debugPrint('Found device: ${device.deviceName}');
      setState(() {
        widget.otherDevices[deviceName]!['status'] = ConnectionStatus.found;
      });
      if (widget.deviceType == DeviceType.advertiserDevice) return;
      await _deviceConnectionService.inviteDevice(device);
    }
    Future<void> deviceLostCallback (device) async {
      debugPrint('Lost device: ${device.deviceName}');
      return;
    }
    Future<void> deviceConnectingCallback (device) async {
      if (widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['status'] == ConnectionStatus.finished) return;
      setState(() {
        widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.connecting;
      });
    }
    Future<void> deviceConnectedCallback (Device device) async {
      if (widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['status'] == ConnectionStatus.finished) return;
      debugPrint('Connected to device: ${device.deviceName}');
      setState(() {
        widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.connected;
      });

      try {
        debugPrint('Adding device to protocol');
        _protocol.addDevice(device);
        
        debugPrint('Setting up message monitoring');
        _deviceConnectionService.monitorMessageReceives(
          device,
          messageReceivedCallback: (package, senderId) async {
            debugPrint('Received package from $senderId: ${package.type}');
            await _protocol.handleMessage(package, senderId);
          },
        );

        if (widget.deviceType == DeviceType.browserDevice) {
          debugPrint('Browser device: preparing to receive data');
          setState(() {
            widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.receiving;
          });
          
          try {
            debugPrint('Starting to receive data');
            final results = await _protocol.receiveDataFromDevice(device.deviceId);
            debugPrint('Received data: $results');
            try {
              await _audioPlayer.play(AssetSource('sounds/completed_ding.mp3'));
            } catch (e) {
              debugPrint('Error playing completion sound: $e');
            }
            widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['data'] = results;
            setState(() {
              widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.finished;
            });
          } catch (e) {
            debugPrint('Error receiving data for device ${device.deviceName}: $e');
            rethrow;
          }
        } else {
          if (widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['data'] != null) {
            debugPrint('Advertiser device: preparing to send data');
            setState(() {
              widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.sending;
            });
            
            try {
              final data = widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['data']!;
              debugPrint('Starting to send data: $data');
              await _protocol.sendData(data, device.deviceId);
              debugPrint('Data sent successfully');
              setState(() {
                widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.finished;
              });
              _deviceConnectionService.disconnectDevice(device);
            } catch (e) {
              debugPrint('Error sending data for device ${device.deviceName}: $e');
              rethrow;
            }
          } else {
            debugPrint('No data available for advertiser device to send');
            throw Exception('No data for advertiser device ${device.deviceName} to send');
          }
        }
        _protocol.removeDevice(device.deviceId);
      } catch (e) {
        debugPrint('Error in connection callback for device ${device.deviceName}: $e');
        _protocol.removeDevice(device.deviceId);
        widget.otherDevices[getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.error;
        rethrow;
      }
    }

    _deviceConnectionService.monitorDevicesConnectionStatus(
      deviceNames: widget.otherDevices.keys
          .where((deviceName) =>
              widget.otherDevices[deviceName]!['status'] != ConnectionStatus.finished)
          .map((deviceName) => getDeviceNameString(deviceName)).toList(),
      deviceFoundCallback: deviceFoundCallback,
      deviceLostCallback: deviceLostCallback,
      deviceConnectingCallback: deviceConnectingCallback,
      deviceConnectedCallback: deviceConnectedCallback,
    );
    debugPrint('Finished setting up device monitoring');
  }

  @override
  void dispose() {
    _deviceConnectionService.dispose();
    _protocol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_wirelessConnectionError == WirelessConnectionError.unavailable || _wirelessConnectionError == WirelessConnectionError.unknown) {
      return Text('Wireless connection is unavailable');
    }
    return widget.child;
  }
}