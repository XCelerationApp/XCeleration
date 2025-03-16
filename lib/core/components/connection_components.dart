import 'package:flutter/material.dart';
import '../utils/connection_utils.dart';
import '../../utils/enums.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import '../services/device_connection_service.dart';
import '../utils/data_protocol.dart';
import 'dialog_utils.dart';
import '../../utils/sheet_utils.dart';
import '../../utils/enums.dart' show DeviceName, DeviceType, ConnectionStatus, WirelessConnectionError;

class WirelessConnectionButton extends StatefulWidget {
  final DeviceName deviceName;
  final IconData? icon;
  final ConnectionStatus connectionStatus;
  final Function()? onRetry;
  final String? errorMessage;
  final bool isLoading;

  const WirelessConnectionButton({
    super.key,
    required this.deviceName,
    this.icon = Icons.person,
    required this.connectionStatus,
    this.onRetry,
    this.errorMessage,
    this.isLoading = false,
  });

  WirelessConnectionButton get skeleton => WirelessConnectionButton(
    deviceName: deviceName,
    icon: icon,
    connectionStatus: connectionStatus,
    isLoading: true,
  );

  WirelessConnectionButton error(String message, {Function()? retryAction}) => WirelessConnectionButton(
    deviceName: deviceName,
    icon: Icons.error_outline,
    connectionStatus: ConnectionStatus.error,
    errorMessage: message,
    onRetry: retryAction,
  );

  @override
  State<WirelessConnectionButton> createState() => _WirelessConnectionButtonState();
}

class _WirelessConnectionButtonState extends State<WirelessConnectionButton> {
  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 120,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            Container(
              width: 80,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.connectionStatus == ConnectionStatus.error && widget.errorMessage != null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[400],
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Connection unavailable',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.errorMessage ?? 'An error occurred',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onRetry != null)
              TextButton(
                onPressed: widget.onRetry,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }

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
      ),
    );
  }
}


class QRConnectionButton extends StatefulWidget {
  final DeviceName deviceName;
  final DeviceType deviceType;
  final ConnectionStatus connectionStatus;
  final Function()? onRetry;
  final String? errorMessage;
  final bool isLoading;

  const QRConnectionButton({
    super.key,
    required this.deviceName,
    required this.deviceType,
    required this.connectionStatus,
    this.onRetry,
    this.errorMessage,
    this.isLoading = false,
  });

  @override
  State<QRConnectionButton> createState() => _QRConnectionButtonState();
}

class _QRConnectionButtonState extends State<QRConnectionButton> {
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
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code,
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
                  )
                ],    
              ),
            ),
          )
        ],
      ),
    );
  }
}


class QRConnectionWidget extends StatefulWidget {
  final DevicesManager devices;
  final Function callback;

  const QRConnectionWidget({
    super.key,
    required this.devices,
    required this.callback,
  });

  @override
  State<QRConnectionWidget> createState() => _QRConnectionState();
}

class _QRConnectionState extends State<QRConnectionWidget> {

  @override
  void initState() {
    super.initState();
  }

  Future<void> _showQR(BuildContext context, DeviceName device) async {
    // Get the data and handle the case where it might be a Future
    String rawData = widget.devices.getDevice(device)!.data!;
    String qrData = '${getDeviceNameString(device)}:$rawData';
    
    sheet(
      context: context,
      title: 'QR Code',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: qrData,
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
          scannedDeviceName = widget.devices.getDevice(getDeviceNameFromString(parts[0]))?.name;
        } catch (e) {
          // No match found, scannedDeviceName remains null
        }
        
        if (parts.isEmpty || scannedDeviceName == null) {
          DialogUtils.showErrorDialog(context, message: 'Incorrect QR Code Scanned');
          return;
        }
        
        widget.devices.getDevice(scannedDeviceName)!.status = ConnectionStatus.finished;
        widget.devices.getDevice(scannedDeviceName)!.data = parts.sublist(1).join(':');
        
        // Call the callback function if provided
        if (widget.devices.allDevicesFinished()) {
          widget.callback();
        }
      }
    } on MissingPluginException {
      if (!mounted) return;
      DialogUtils.showErrorDialog(context, message: 'The QR code scanner is not available on this device.');
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showErrorDialog(context, message: 'An unknown error occurred: $e');
    }
  }

  Future<void> _handleTap() async {
    if (widget.devices.currentDeviceType == DeviceType.advertiserDevice) {
      await _showQR(context, widget.devices.currentDeviceName);
    } else {
      _scanQRCodes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await _handleTap();
      },
      child: QRConnectionButton(
        deviceName: widget.devices.currentDeviceName,
        deviceType: widget.devices.currentDeviceType,
        connectionStatus: ConnectionStatus.searching,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class WirelessConnectionWidget extends StatefulWidget {
  final DevicesManager devices;
  final Function callback;

  const WirelessConnectionWidget({
    super.key,
    required this.devices,
    required this.callback,
  });

  @override
  State<WirelessConnectionWidget> createState() => _WirelessConnectionState();
}

class _WirelessConnectionState extends State<WirelessConnectionWidget> {
  late DeviceConnectionService _deviceConnectionService;
  late Protocol _protocol;
  WirelessConnectionError? _wirelessConnectionError;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _deviceConnectionService = DeviceConnectionService();
    _protocol = Protocol(deviceConnectionService: _deviceConnectionService);

    try {
      final isServiceAvailable = await _deviceConnectionService.checkIfNearbyConnectionsWorks();
      if (!isServiceAvailable) {
        setState(() {
          _wirelessConnectionError = WirelessConnectionError.unavailable;
          _isInitialized = true;
        });
        return;
      }

      try {
        await _deviceConnectionService.init(
          'wirelessconn',
          getDeviceNameString(widget.devices.currentDeviceName),
          widget.devices.currentDeviceType,
        );
        setState(() {
          _isInitialized = true;
        });
        
        _startConnectionProcess();
      } catch (e) {
        setState(() {
          debugPrint('Error initializing connection service.');
          _isInitialized = true;
        });
        rethrow;
      }
    } catch (e) {
      setState(() {
        _wirelessConnectionError = WirelessConnectionError.unknown;
        _isInitialized = true;
      });
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          DialogUtils.showErrorDialog(
            context,
            title: 'Error',
            message: 'An error occurred while trying to connect. Please try again.',
          );
        });
      }
    }
  }

  void _startConnectionProcess() {
    // Setup device monitoring here
    _deviceConnectionService.monitorDevicesConnectionStatus(
      deviceNames: widget.devices.otherDevices.map((device) => getDeviceNameString(device.name)).toList(),
      deviceFoundCallback: _deviceFoundCallback,
      deviceLostCallback: _deviceLostCallback,
      deviceConnectingCallback: _deviceConnectingCallback,
      deviceConnectedCallback: _deviceConnectedCallback,
    );
  }

  Future<void> _deviceFoundCallback(Device device) async {
    final deviceName = getDeviceNameFromString(device.deviceName);
    if (!widget.devices.hasDevice(deviceName) || widget.devices.getDevice(deviceName)!.isFinished) {
      return;
    }
    
    if (mounted) {
      setState(() {
        widget.devices.getDevice(deviceName)!.status = ConnectionStatus.found;
      });
    }
    
    if (widget.devices.currentDeviceType == DeviceType.advertiserDevice) return;
    await _deviceConnectionService.inviteDevice(device);
  }

  Future<void> _deviceLostCallback(Device device) async {
    // Handle device lost
    final deviceName = getDeviceNameFromString(device.deviceName);
    if (mounted && widget.devices.hasDevice(deviceName)) {
      setState(() {
        widget.devices.getDevice(deviceName)!.status = ConnectionStatus.error;
      });
    }
  }

  Future<void> _deviceConnectingCallback(Device device) async {
    final deviceName = getDeviceNameFromString(device.deviceName);
    if (widget.devices.getDevice(deviceName)!.isFinished) return;
    
    if (mounted) {
      setState(() {
        widget.devices.getDevice(deviceName)!.status = ConnectionStatus.connecting;
      });
    }
  }

  Future<void> _deviceConnectedCallback(Device device) async {
    final deviceName = getDeviceNameFromString(device.deviceName);
    if (widget.devices.getDevice(deviceName)!.isFinished) return;
    
    if (mounted) {
      setState(() {
        widget.devices.getDevice(deviceName)!.status = ConnectionStatus.connected;
      });
    }

    try {
      _protocol.addDevice(device);
      
      _deviceConnectionService.monitorMessageReceives(
        device,
        messageReceivedCallback: (package, senderId) async {
          await _protocol.handleMessage(package, senderId);
        },
      );

      if (widget.devices.currentDeviceType == DeviceType.browserDevice) {
        if (mounted) {
          setState(() {
            widget.devices.getDevice(deviceName)!.status = ConnectionStatus.receiving;
          });
        }
        
        try {
          final results = await _protocol.receiveDataFromDevice(device.deviceId);
          
          if (mounted) {
            setState(() {
              widget.devices.getDevice(deviceName)!.data = results;
              widget.devices.getDevice(deviceName)!.status = ConnectionStatus.finished;
            });
          }
          
          // Check if all devices have finished loading data
          bool allDevicesFinished = widget.devices.allDevicesFinished();
          
          // Call the callback if all devices are finished and callback is provided
          if (allDevicesFinished) {
            widget.callback();
          }
        } catch (e) {
          debugPrint('Error receiving data: $e');
          rethrow;
        }
      } else {
        if (widget.devices.getDevice(deviceName)!.data != null) {
          if (mounted) {
            setState(() {
              widget.devices.getDevice(deviceName)!.status = ConnectionStatus.sending;
            });
          }
          
          try {
            final data = widget.devices.getDevice(deviceName)!.data!;
            await _protocol.sendData(data, device.deviceId);
            if (mounted) {
              setState(() {
                widget.devices.getDevice(deviceName)!.status = ConnectionStatus.finished;
              });
            }
            
            // Check if all devices have finished loading data
            bool allDevicesFinished = widget.devices.allDevicesFinished();
            
            // Call the callback if all devices are finished
            if (allDevicesFinished) {
              widget.callback();
            }
            
            _deviceConnectionService.disconnectDevice(device);
          } catch (e) {
            debugPrint('Error sending data: $e');
            rethrow;
          }
        } else {
          throw Exception('No data for advertiser device to send');
        }
      }
      _protocol.removeDevice(device.deviceId);
    } catch (e) {
      debugPrint('Error in connection: $e');
      _protocol.removeDevice(device.deviceId);
      if (mounted) {
        setState(() {
          widget.devices.getDevice(deviceName)!.status = ConnectionStatus.error;
        });
      }
      rethrow;
    }
  }


  @override
  void dispose() {
    _deviceConnectionService.dispose();
    _protocol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_wirelessConnectionError != null) {
      // Show a single error button
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: WirelessConnectionButton(
              deviceName: widget.devices.currentDeviceName,
              connectionStatus: ConnectionStatus.error,
              errorMessage: _wirelessConnectionError == WirelessConnectionError.unavailable 
                  ? 'Wireless connection is not available on this device.'
                  : 'An unknown error occurred.',
              onRetry: () {
                setState(() {
                  _wirelessConnectionError = null;
                  _isInitialized = false;
                });
                _initialize();
              }
            )
          ),
        ],
      );
    } 

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var device in widget.devices.otherDevices)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: !_isInitialized 
              ? WirelessConnectionButton(
                  deviceName: device.name,
                  connectionStatus: ConnectionStatus.searching,
                ).skeleton
              : WirelessConnectionButton(
                  deviceName: device.name,
                  connectionStatus: device.status,
                ),
          ),
      ],
    );
  }
}