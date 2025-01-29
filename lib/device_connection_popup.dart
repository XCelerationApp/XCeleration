import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'dart:convert';
import 'dart:async';
// import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
// import '../constants.dart';
import 'device_connection_service.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';

Future<void> showDeviceConnectionPopup(BuildContext context, { required DeviceType deviceType, required Function() backUpShareFunction, Function(String data)? onDatatransferComplete, String? dataToTransfer }) async {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return DeviceConnectionPopupContent(deviceType: deviceType, backUpShareFunction: backUpShareFunction, onDataTransferComplete: onDatatransferComplete, dataToTransfer: dataToTransfer);
    }
  );
}


enum ConnectionStatus { connected, found, connecting, searching, finished, error, sending, receiving, timeout }

class DeviceConnectionPopupContent extends StatefulWidget {
  final DeviceType deviceType;
  final Function() backUpShareFunction;
  final Function(String result)? onDataTransferComplete;
  final String? dataToTransfer;
  const DeviceConnectionPopupContent({
    super.key,
    required this.deviceType,
    required this.backUpShareFunction,
    this.onDataTransferComplete,
    this.dataToTransfer,
  });
  @override
  State<DeviceConnectionPopupContent> createState() => _DeviceConnectionPopupState();
}

class _DeviceConnectionPopupState extends State<DeviceConnectionPopupContent> {
  late ConnectionStatus _connectionStatus;
  late Function() _backUpShareFunction;
  late Function(String result)? _onDataTransferComplete;
  late AudioPlayer _audioPlayer;
  bool _isAudioPlayerReady = false;
  late DeviceType _deviceType;
  late String? _dataToTransfer;

  late DeviceConnectionService _deviceConnectionService;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _deviceType = widget.deviceType;
    _backUpShareFunction = widget.backUpShareFunction;
    _onDataTransferComplete = widget.onDataTransferComplete;
    _dataToTransfer = widget.dataToTransfer;
    _deviceConnectionService = DeviceConnectionService();
    _connectionStatus = ConnectionStatus.searching;
    _connectAndTransferData();
  }

  Future<void> _connectAndTransferData() async {
    Future<void> foundDeviceCallback (Device device) async {
      setState(() {
        _connectionStatus = ConnectionStatus.found;
      });
    }
    Future<void> connectingToDeviceCallback (Device device) async {
      setState(() {
        _connectionStatus = ConnectionStatus.connecting;
      });
    }

    try {
      await _deviceConnectionService.init('wirelessconn', _getDeviceTypeString(), _deviceType);
      if (_deviceType == DeviceType.bibNumberDevice) {
        Device? device = await _deviceConnectionService.connectToDevice(
          _getOppositeDeviceTypeString(),
          foundDeviceCallback: foundDeviceCallback,
          connectingToDeviceCallback: connectingToDeviceCallback,
        );
        if (device == null) {
          setState(() {
            _connectionStatus = ConnectionStatus.timeout;
          });
          closeWidget();
          return;
        }
        print("Connected to device: ${device.deviceName}");
        setState(() {
          _connectionStatus = ConnectionStatus.connected;
        });
        String? message = await _deviceConnectionService.receiveMessageFromDevice(device);
        if (message == null) {
          setState(() {
            _connectionStatus = ConnectionStatus.timeout;
          });
          closeWidget();
          return;
        }
        if (message != 'Start') {
          setState(() {
            _connectionStatus = ConnectionStatus.error;
          });
          closeWidget();
          return;
        }
        await _deviceConnectionService.sendMessageToDevice(device, 'received start');
        setState(() {
          _connectionStatus = ConnectionStatus.receiving;
        });
        message = '';
        String data = '';
        while (message != 'Stop') {
          if (message == null) {
            setState(() {
              _connectionStatus = ConnectionStatus.timeout;
            });
            closeWidget();
            return;
          }
          data += message;
          message = await _deviceConnectionService.receiveMessageFromDevice(device);
          await _deviceConnectionService.sendMessageToDevice(device, 'received data');
        }
        await _deviceConnectionService.sendMessageToDevice(device, 'received stop');
        print("received data from Race Timer Device: $data");
        if (_onDataTransferComplete != null) {
          await _onDataTransferComplete!(data);    
        }   
        setState(() {
          _connectionStatus = ConnectionStatus.finished;
        });
        if (_isAudioPlayerReady) {
          try {
            await _audioPlayer.stop(); // Stop any currently playing sound
            await _audioPlayer.play(AssetSource('sounds/completed_ding.mp3'));
          } catch (e) {
            print('Error playing sound: $e');
            // Reinitialize audio player if it failed
            _initAudioPlayer();
          }
        }
        closeWidget();
      }
      else {
        if (_dataToTransfer == null) {
          setState(() {
            _connectionStatus = ConnectionStatus.error;
          });
          closeWidget();
          return;
        }
        Device? device = await _deviceConnectionService.monitorDeviceConnectionStatus(
          _getOppositeDeviceTypeString(),
          foundDeviceCallback: foundDeviceCallback,
          connectingToDeviceCallback: connectingToDeviceCallback,
        );
        if (device == null) {
          setState(() {
            _connectionStatus = ConnectionStatus.timeout;
          });
          closeWidget();
          return;
        }
        print("Connected to device: ${device.deviceName}");
        await _deviceConnectionService.sendMessageToDevice(device, 'Start');
        String? start_message = await _deviceConnectionService.receiveMessageFromDevice(device);
        if (start_message != 'received start') {
          setState(() {
            _connectionStatus = ConnectionStatus.error;
          });
          closeWidget();
          return;
        }

        setState(() {
          _connectionStatus = ConnectionStatus.sending;
        });
        await _deviceConnectionService.sendMessageToDevice(device, _dataToTransfer!);
        String? data_message = await _deviceConnectionService.receiveMessageFromDevice(device);
        if (data_message != 'received data') {
          setState(() {
            _connectionStatus = ConnectionStatus.error;
          });
          closeWidget();
          return;
        }
        await _deviceConnectionService.sendMessageToDevice(device, 'Stop');
        String? stop_message = await _deviceConnectionService.receiveMessageFromDevice(device);
        if (stop_message != 'received stop') {
          setState(() {
            _connectionStatus = ConnectionStatus.error;
          });
          closeWidget();
          return;
        }

        setState(() {
          _connectionStatus = ConnectionStatus.finished;
        });
        closeWidget();
      }
    } catch (e) {
      setState(() {
        print('Error with device connection service: $e');
        _connectionStatus = ConnectionStatus.error;
      });
      closeWidget();
    }
  }

  String _getDeviceTypeString() {
    return _deviceType == DeviceType.bibNumberDevice ? 'bibNumberDevice' : 'raceTimerDevice';
  }

  String _getOppositeDeviceTypeString() {
    return _deviceType == DeviceType.bibNumberDevice ? 'raceTimerDevice' : 'bibNumberDevice';
  }

  void closeWidget({Duration delay = const Duration(seconds: 2)}) {
    Future.delayed(delay, () {
      if (mounted) {
        // Remove the widget from the navigation stack
        Navigator.pop(context);
      }
    });
  }

  Future<void> _initAudioPlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      // Pre-load the audio file
      await _audioPlayer.setSource(AssetSource('sounds/completed_ding.mp3'));
      setState(() {
        _isAudioPlayerReady = true;
      });
    } catch (e) {
      print('Error initializing device connection audio player: $e');
      // Try to recreate the audio player if it failed
      if (!_isAudioPlayerReady) {
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          _initAudioPlayer();
        }
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _deviceConnectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_connectionStatus != ConnectionStatus.error && _connectionStatus != ConnectionStatus.finished && _connectionStatus != ConnectionStatus.timeout) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 5),
            ],
            Text(
              _connectionStatus == ConnectionStatus.searching ? 'Searching for device...' :
              _connectionStatus == ConnectionStatus.found ? 'Found device, trying to connect...' :
              _connectionStatus == ConnectionStatus.connecting ? 'Connecting to device...' :
              _connectionStatus == ConnectionStatus.connected ? 'Connected to device...' :
              _connectionStatus == ConnectionStatus.sending ? 'Sending data...' :
              _connectionStatus == ConnectionStatus.receiving ? 'Receiving data...' :
              _connectionStatus == ConnectionStatus.finished ? 'Done!' :
              _connectionStatus == ConnectionStatus.timeout ? 'Connection timed out' :
              'Error'
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [ 
                ElevatedButton(
                  child: const Text('Use QR Codes Instead'),
                  onPressed: () => {
                    Navigator.pop(context), _backUpShareFunction()
                  }
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
              ]
            )
          ],
        ),
      )
    );
  }
}
