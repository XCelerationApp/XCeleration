import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'device_connection_service.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'data_protocol.dart';
import 'utils/dialog_utils.dart';
import 'utils/sheet_utils.dart';

Future<void> showDeviceConnectionPopup(BuildContext context, { required DeviceType deviceType, required DeviceName deviceName, required Map<DeviceName, Map<String, dynamic>> otherDevices}) async {
  // Create a completer to track when we're actually done
  final completer = Completer<void>();

  sheet(
    context: context,
    showHeader: false,
    title: deviceType == DeviceType.advertiserDevice ? 'Wireless Sharing' : 'Wireless Receiving',
    body: DeviceConnectionPopupContent(
      deviceName: deviceName,
      deviceType: deviceType,
      otherDevices: otherDevices,
      onComplete: () {
        completer.complete();
      },
    ),
  );
  
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

enum ConnectionStatus { connected, found, connecting, searching, finished, error, sending, receiving, timeout }
enum DeviceName { coach, bibRecorder, raceTimer}
enum PopupScreen { main, qr }

class DeviceConnectionPopupContent extends StatefulWidget {
  final DeviceName deviceName;
  final DeviceType deviceType;
  final Map<DeviceName, Map<String, dynamic>> otherDevices;
  final VoidCallback onComplete;
  const DeviceConnectionPopupContent({
    super.key,
    required this.deviceName,
    required this.deviceType,
    required this.otherDevices,
    required this.onComplete,
  });

  @override
  State<DeviceConnectionPopupContent> createState() => _DeviceConnectionPopupContentState();
}

class _DeviceConnectionPopupContentState extends State<DeviceConnectionPopupContent> with SingleTickerProviderStateMixin {
  PopupScreen _popupScreen = PopupScreen.main;
  late AnimationController _animationController;
  late DeviceName _oppositeDeviceName;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    Future.wait(widget.otherDevices.keys.map((deviceName) async {
      while (widget.otherDevices[deviceName]!['status'] != ConnectionStatus.finished) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    })).then((_) async {
      if (!mounted) return;
      try {
        await _audioPlayer.play(AssetSource('sounds/completed_ding.mp3'));
      } catch (e) {
        debugPrint('Error playing completion sound: $e');
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;  
        Navigator.of(context).pop();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    widget.onComplete();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _handleScreenTransition(PopupScreen newScreen, {DeviceName? oppositeDeviceName}) async {
    if (oppositeDeviceName != null) {
      _oppositeDeviceName = oppositeDeviceName;
    } else {
      if (newScreen == PopupScreen.qr) {
        throw Exception('Opposite device name must be provided for qr screen');
      }
    }
    if (newScreen == PopupScreen.main) {
      await _animationController.reverse();
      if (mounted) {
        setState(() {
          _popupScreen = newScreen;
        });
      }
    } else {
      setState(() {
        _popupScreen = newScreen;
      });
      await _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: child,
          );
        },
        child: _popupScreen == PopupScreen.main
            ? _buildMainScreen()
            : Container(
                key: ValueKey(_popupScreen),
                child: _buildSecondaryScreen(),
              ),
      ),
    );
  }

  Widget _buildMainScreen() {
    return Container(
      width: double.maxFinite,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      // child:
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          //   child: Text(
          //     widget.deviceType == DeviceType.advertiserDevice ? 'Wireless Sharing' : 'Wireless Receiving',
          //     style: TextStyle(
          //       fontSize: 30,
          //       color: Colors.deepOrangeAccent,
          //       fontWeight: FontWeight.bold
          //     ),
          //   ),
          // ),
          createSheetHeader(
            widget.deviceType == DeviceType.advertiserDevice ? 'Wireless Sharing' : 'Wireless Receiving',
            context: context,
          ),
          WirelessConnectionPopupContent(
            deviceName: widget.deviceName,
            deviceType: widget.deviceType,
            otherDevices: widget.otherDevices,
            showQRCode: (DeviceName oppositeDeviceName) async { 
              _handleScreenTransition(PopupScreen.qr, oppositeDeviceName: oppositeDeviceName);
            },
          ),
          // SizedBox(height: 20), // Add some bottom padding
        ],
      ),
    );
  }

  Widget _buildSecondaryScreen() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          createSheetHeader(
            'QR Connection',
            context: context,
            backArrow: true,
            onBack: () => _handleScreenTransition(PopupScreen.main),
          ),
          // SizedBox(height: 10),
          // Row(
          //   children: [
          //     SizedBox(width: 10),
          //     _buildBackButton(),
          //     Expanded(
          //       child: Center(
          //         child: Text(
          //           'QR Connection',
          //           style: TextStyle(
          //             fontSize: 20,
          //             color: Colors.deepOrangeAccent,
          //             fontWeight: FontWeight.bold
          //           ),
          //         ),
          //       ),
          //     ),
          //     SizedBox(width: 20),
          //   ],
          // ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: QRConnectionPopupContent(
              data: widget.otherDevices[_oppositeDeviceName]!['data'],
              deviceName: widget.deviceName,
              oppositeDeviceName: _oppositeDeviceName,
            ),
          ),
        ],
      ),
    );
  }
}

Map<DeviceName, String> _deviceNameStrings = {
  DeviceName.coach: 'Coach',
  DeviceName.bibRecorder: 'Bib Recorder',
  DeviceName.raceTimer: 'Race Timer',
};

String _getDeviceNameString(DeviceName deviceName) {
  return _deviceNameStrings[deviceName]!;
}

DeviceName _getDeviceNameFromString(String deviceName) {
  return _deviceNameStrings.keys.firstWhere((name) => _getDeviceNameString(name) == deviceName);
}


class QRConnectionPopupContent extends StatefulWidget {
  final String data;
  final DeviceName deviceName;
  final DeviceName oppositeDeviceName;
  const QRConnectionPopupContent({
    super.key,
    required this.data,
    required this.deviceName,
    required this.oppositeDeviceName,
  });
  @override
  State<QRConnectionPopupContent> createState() => _QRCodePopupContentState();
}

class _QRCodePopupContentState extends State<QRConnectionPopupContent> {

  @override
  void initState() {
    super.initState();
  } 

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  'Show this QR code to ${_getDeviceNameString(widget.oppositeDeviceName)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.deepOrangeAccent,
                  ),
                ),
              ),
              SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth * 0.7;
                  return Center(
                    child: SizedBox(
                      height: size,
                      width: size,
                      child: QrImageView(
                        data: '${_getDeviceNameString(widget.deviceName)}:${widget.data}',
                        version: QrVersions.auto,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        size: size,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
            ],
          );
        }
      )
    );
  }
}

enum WirelessConnectionError { unavailable, unknown }

class WirelessConnectionPopupContent extends StatefulWidget {
  final DeviceName deviceName;
  final DeviceType deviceType;
  final Map<DeviceName, Map<String, dynamic>> otherDevices;
  final Future<void> Function(DeviceName deviceName) showQRCode;
  const WirelessConnectionPopupContent({
    super.key,
    required this.deviceName,
    required this.deviceType,
    required this.otherDevices,
    required this.showQRCode,
  });
  @override
  State<WirelessConnectionPopupContent> createState() => _WirelessConnectionPopupState();
}

class _WirelessConnectionPopupState extends State<WirelessConnectionPopupContent> {
  late DeviceConnectionService _deviceConnectionService;
  late Protocol _protocol;
  WirelessConnectionError? _wirelessConnectionError;

  @override
  void initState() {
    super.initState();
    _deviceConnectionService = DeviceConnectionService();
    _protocol = Protocol(deviceConnectionService: _deviceConnectionService);
    _init();
  }

  Future<void> _init() async {
    try {
      final bool isServiceAvailable = await _deviceConnectionService.checkIfNearbyConnectionsWorks();
      if (!isServiceAvailable) {
        debugPrint('Device connection service is not available on this platform');
        setState(() {
          _wirelessConnectionError = WirelessConnectionError.unavailable;
        });
        return;
      }

      try {
        await _deviceConnectionService.init('wirelessconn', _getDeviceNameString(widget.deviceName), widget.deviceType);
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
          DialogUtils.showErrorDialog(context, message: 'An error occurred in the wireless connection process. Use QR codes instead');
        }
      });
    }
  }

  Future<void> _connectAndTransferData() async {
    Future<void> deviceFoundCallback (device) async {
      final deviceName = _getDeviceNameFromString(device.deviceName);
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
      if (widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['status'] == ConnectionStatus.finished) return;
      setState(() {
        widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.connecting;
      });
    }
    Future<void> deviceConnectedCallback (Device device) async {
      if (widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['status'] == ConnectionStatus.finished) return;
      debugPrint('Connected to device: ${device.deviceName}');
      setState(() {
        widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.connected;
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
            widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.receiving;
          });
          
          try {
            debugPrint('Starting to receive data');
            final results = await _protocol.receiveDataFromDevice(device.deviceId);
            debugPrint('Received data: $results');
            widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['data'] = results;
            setState(() {
              widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.finished;
            });
          } catch (e) {
            debugPrint('Error receiving data for device ${device.deviceName}: $e');
            rethrow;
          }
        } else {
          if (widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['data'] != null) {
            debugPrint('Advertiser device: preparing to send data');
            setState(() {
              widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.sending;
            });
            
            try {
              final data = widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['data']!;
              debugPrint('Starting to send data: $data');
              await _protocol.sendData(data, device.deviceId);
              debugPrint('Data sent successfully');
              setState(() {
                widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.finished;
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
        widget.otherDevices[_getDeviceNameFromString(device.deviceName)]!['status'] = ConnectionStatus.error;
        rethrow;
      }
    }

    _deviceConnectionService.monitorDevicesConnectionStatus(
      deviceNames: widget.otherDevices.keys
          .where((deviceName) =>
              widget.otherDevices[deviceName]!['status'] != ConnectionStatus.finished)
          .map((deviceName) => _getDeviceNameString(deviceName)).toList(),
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

  Future<void> _scanQrCode(BuildContext context, DeviceName scanDeviceName) async {
    try {
      final result = await BarcodeScanner.scan();
      if (result.type == ResultType.Barcode) {
        final parts = result.rawContent.split(':');
        if (parts.isEmpty || parts[0] != _getDeviceNameString(scanDeviceName)) {
          if (!context.mounted) return;
          DialogUtils.showErrorDialog(context, message: 'Incorrect QR Code Scanned');
          return;
        }
        setState(() {
          widget.otherDevices[scanDeviceName]!['status'] = ConnectionStatus.finished;
          widget.otherDevices[scanDeviceName]!['data'] = parts.sublist(1).join(':');
        });
        _protocol.removeDevice(_getDeviceNameString(scanDeviceName));
      }
    } on MissingPluginException {
      if (!context.mounted) return;
      DialogUtils.showErrorDialog(context, message: 'The QR code scanner is not available on this device.');
    } catch (e) {
      if (!context.mounted) return;
      DialogUtils.showErrorDialog(context, message: 'An unknown error occurred: $e');
    }
  }

  Widget _buildDeviceConnectionTracker(DeviceName deviceName, ConnectionStatus status, VoidCallback onPressed) {
    String text = '';
    if (_wirelessConnectionError == WirelessConnectionError.unavailable || _wirelessConnectionError == WirelessConnectionError.unknown) {
      text = status == ConnectionStatus.finished ? 'Data Received' : 'Data not received';
    }
    else {
      text = switch(status) {
        ConnectionStatus.connected => 'Connected...',
        ConnectionStatus.connecting => 'Connecting...',
        ConnectionStatus.finished => widget.deviceType == DeviceType.browserDevice ? 'Data Received' : 'Data Sent',
        ConnectionStatus.error => 'Error',
        ConnectionStatus.sending => 'Sending...',
        ConnectionStatus.receiving => 'Receiving...',
        ConnectionStatus.timeout => 'Timed out',
        ConnectionStatus.searching => 'Searching...',
        ConnectionStatus.found => 'Found device...',
      };
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.deepOrangeAccent, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.person,
                color: Colors.deepOrange,
                size: 50,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    _getDeviceNameString(deviceName),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ),
                if (!(widget.deviceType == DeviceType.advertiserDevice && _wirelessConnectionError == WirelessConnectionError.unavailable))...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      if (status != ConnectionStatus.finished && status != ConnectionStatus.error && status != ConnectionStatus.timeout && _wirelessConnectionError != WirelessConnectionError.unavailable && _wirelessConnectionError != WirelessConnectionError.unknown)...[
                        SizedBox(
                          height: 15,
                          width: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.deepOrangeAccent,
                          ),
                        ),
                        SizedBox(width: 5),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.deepOrangeAccent,
                        ),
                      ),
                    ]
                  )
                ]
              ],
            ),
            Spacer(), // Add this to push the button to the right
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton(
                onPressed: onPressed,
                child: Text(
                  widget.deviceType == DeviceType.advertiserDevice ? 'Show QR' :
                  status == ConnectionStatus.finished ? 'Rescan QR' : 'Scan QR',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.deepOrangeAccent,
                  ),
                )
              ),
            )
          ]
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_wirelessConnectionError == WirelessConnectionError.unavailable || _wirelessConnectionError == WirelessConnectionError.unknown) {
      if (widget.deviceType == DeviceType.advertiserDevice && widget.otherDevices.length == 1) {
        return QRConnectionPopupContent(
          data: widget.otherDevices.values.elementAt(0)['data'],
          deviceName: widget.deviceName,
          oppositeDeviceName: widget.otherDevices.keys.elementAt(0),
        );
      }
    }
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.otherDevices.length,
              itemBuilder: (context, index) {
                DeviceName deviceName = widget.otherDevices.keys.elementAt(index);
                return _buildDeviceConnectionTracker(deviceName, widget.otherDevices[deviceName]!['status'], () {
                  if (widget.deviceType == DeviceType.advertiserDevice) {
                     widget.showQRCode(deviceName);
                  }
                  else {
                    _scanQrCode(context, deviceName);
                  }
                 }
                );
              },
            )
          ),
        ],
      ),
    );
  }
}