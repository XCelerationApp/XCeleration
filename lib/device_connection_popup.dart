import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'device_connection_service.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'data_protocol.dart';

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
  late Protocol? _protocol;

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
    _protocol = null;
    _init();
  }

  Future<void> _init() async {
    try {
      final bool isServiceAvailable = await _deviceConnectionService.checkIfNearbyConnectionsWorks();
      if (!isServiceAvailable) {
        print('Device connection service is not available on this platform');
        setState(() {
          _connectionStatus = ConnectionStatus.error;
        });
        closeWidget();
        return;
      }

      try {
        await _deviceConnectionService.init('wirelessconn', _getDeviceTypeString(), _deviceType);
      } catch (e) {
        print('Error initializing device connection service: $e');
        rethrow;
      }
      try {
        _connectAndTransferData();
      } catch (e) {
        print('Error connecting and transferring data: $e');
        rethrow;
      }
    } catch (e) {
      print('Error in device connection popup: $e');
      setState(() {
        _connectionStatus = ConnectionStatus.error;
      });
      closeWidget();
    }
  }

  Future<void> _connectAndTransferData() async {
    Future<void> notConnectedDeviceCallback (Device device) async {
      if (_connectionStatus == ConnectionStatus.finished) {
        return;
      }
      _protocol?.dispose();
      _protocol = null;
      setState(() {
        _connectionStatus = ConnectionStatus.found;
      });
      if (_deviceType == DeviceType.bibNumberDevice) {
        await _deviceConnectionService.inviteDevice(device);
      }
    }
    Future<void> connectingToDeviceCallback (Device device) async {
      if (_connectionStatus == ConnectionStatus.finished) {
        return;
      }
      _protocol?.dispose();
      _protocol = null;
      setState(() {
        _connectionStatus = ConnectionStatus.connecting;
      });
    }
    Future<void> connectedToDeviceCallback (Device device) async {
      setState(() {
        _connectionStatus = ConnectionStatus.connected;
      });
      try {
        _protocol = Protocol(deviceConnectionService: _deviceConnectionService, device: device);
        _deviceConnectionService.monitorMessageReceives(device, messageReceivedCallback: _protocol!.handleMessage);
        if (_deviceType == DeviceType.bibNumberDevice) {
          setState(() {
            _connectionStatus = ConnectionStatus.receiving;
          });
          final String receivedData = await _protocol!.receiveData();
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
          _onDataTransferComplete?.call(receivedData);
          closeWidget();
        }
        else if (_deviceType == DeviceType.raceTimerDevice) {
          if (_dataToTransfer == null) {
            setState(() {
              _connectionStatus = ConnectionStatus.error;
            });
            print('No data to transfer');
            return;
          }
          setState(() {
            _connectionStatus = ConnectionStatus.sending;
          });
          await _protocol!.sendData(_dataToTransfer!);
          setState(() {
            _connectionStatus = ConnectionStatus.finished;
          });
          closeWidget();
        }
      } catch (e) {
        if (e is ProtocolTerminatedException) {
          print('Protocol terminated during data transfer: $e');
          return;
        }
        print('Error transferring data: $e');
        rethrow;
      }
    }
    try {
      await _deviceConnectionService.monitorDeviceConnectionStatus(
        _getOppositeDeviceTypeString(),
        notConnectedCallback: notConnectedDeviceCallback,
        connectingToDeviceCallback: connectingToDeviceCallback,
        connectedToDeviceCallback: connectedToDeviceCallback,
      );
    } catch (e) {
      setState(() {
        print('Error connecting and transferring data: $e');
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
    _protocol?.dispose();
    _protocol = null;
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
