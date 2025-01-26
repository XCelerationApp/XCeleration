import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'dart:convert';
import 'dart:async';
// import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
// import '../constants.dart';
import 'device_connection_service.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';

Future<void> showDeviceConnectionPopup(BuildContext context, { required DeviceType deviceType, required Function() backUpShareFunction, Function(String result)? onDatatransferComplete }) async {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return DeviceConnectionPopupContent(deviceType: deviceType, backUpShareFunction: backUpShareFunction, onDataTransferComplete: onDatatransferComplete,);
    }
  );
}


enum ConnectionStatus { connected, found, connecting, searching, finished, error, sending, receiving, timeout }

class DeviceConnectionPopupContent extends StatefulWidget {
  final DeviceType deviceType;
  final Function() backUpShareFunction;
  final Function(String result)? onDataTransferComplete;
  const DeviceConnectionPopupContent({
    super.key,
    required this.deviceType,
    required this.backUpShareFunction,
    this.onDataTransferComplete,
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

  late DeviceConnectionService _deviceConnectionService;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _deviceType = widget.deviceType;
    _backUpShareFunction = widget.backUpShareFunction;
    _onDataTransferComplete = widget.onDataTransferComplete;
    _deviceConnectionService = DeviceConnectionService();
    _connectionStatus = ConnectionStatus.searching;
    _connectAndTransferData();
  }

  Future<void> _connectAndTransferData() async {
    Future<void> foundDeviceCallback (device) async {
      setState(() {
        _connectionStatus = ConnectionStatus.found;
      });
    }
    Future<void> connectingToDeviceCallback (device) async {
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
        final String? message = await _deviceConnectionService.receiveMessageFromDevice(device);
        if (message == null) {
          setState(() {
            _connectionStatus = ConnectionStatus.timeout;
          });
          closeWidget();
          return;
        }
        print("received message from Race Timer Device: $message");
        if (_onDataTransferComplete != null) {
          await _onDataTransferComplete!(message);    
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
        await _deviceConnectionService.sendMessageToDevice(device, 'Hello from Race Timer Device');
        if (_onDataTransferComplete != null) {
          await _onDataTransferComplete!('');    
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
            if (_connectionStatus != ConnectionStatus.error || _connectionStatus != ConnectionStatus.finished || _connectionStatus != ConnectionStatus.timeout) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 5),
            ],
            Text(
              _connectionStatus == ConnectionStatus.searching ? 'Searching for device...' :
              _connectionStatus == ConnectionStatus.found ? 'Found device, trying to connect...' :
              _connectionStatus == ConnectionStatus.connecting ? 'Connecting to device...' :
              _connectionStatus == ConnectionStatus.connected ? 'Connected to device' :
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
