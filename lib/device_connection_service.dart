import 'dart:async';
import 'dart:convert';
// import 'dart:io';
// import 'package:device_info/device_info.dart';
// import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';

enum DeviceType { bibNumberDevice, raceTimerDevice }


class DeviceConnectionService {
  late NearbyService nearbyService;

  late StreamSubscription deviceMonitorSubscription;
  late StreamSubscription? receivedDataSubscription;
  Completer<Device?>? _findDeviceCompleter;
  Completer<String?>? _receiveMessageCompleter;
  Device? _connectedDevice;

  Future<void> init(String serviceType, String deviceName, DeviceType deviceType) async {
    nearbyService = NearbyService();
    receivedDataSubscription = null;
    await nearbyService.init(
        serviceType: serviceType, //'wirelessconn'
        deviceName: deviceName,
        strategy: Strategy.P2P_POINT_TO_POINT,
        callback: (isRunning) async {
          if (isRunning) {
            if (deviceType == DeviceType.bibNumberDevice) {
              await nearbyService.stopBrowsingForPeers();
              await Future.delayed(Duration(microseconds: 200));
              await nearbyService.startBrowsingForPeers();
            } else {
              await nearbyService.stopAdvertisingPeer();
              await Future.delayed(Duration(microseconds: 200));
              await nearbyService.startAdvertisingPeer();
            }
          }
        });
  }

  Future<Device?> monitorDeviceConnectionStatus(String deviceName, {
    Future<void> Function(Device device)? foundDeviceCallback,
    Future<void> Function(Device device)? connectingToDeviceCallback,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    // Store the callbacks

    // Start monitoring
    // Initialize the completer
    _findDeviceCompleter = Completer<Device?>();

    // Subscribe to state changes
    deviceMonitorSubscription = nearbyService.stateChangedSubscription(callback: (devicesList) async {
      for (var device in devicesList) {
        if (device.deviceName == deviceName) {
          print("Found device");
          if (foundDeviceCallback != null) {
            await foundDeviceCallback(device);
          }
          if (device.state == SessionState.connecting) {
            if (connectingToDeviceCallback != null) {
              await connectingToDeviceCallback(device);
            }
          }
          else if (device.state == SessionState.connected) {
            _connectedDevice = device;
            await deviceMonitorSubscription.cancel(); // Cancel subscription
            _findDeviceCompleter!.complete(device); // Complete with the found device
            return; // Exit the loop
          }   
        }
      }
    });

    // Add a timeout to prevent indefinite waiting
    try {
      return await _findDeviceCompleter!.future.timeout(timeout, onTimeout: () {
        print("Device monitoring timed out");
        return null; // Return null if timeout occurs
      });
    } catch (e) {
      print("Error during device monitoring: $e");
      return null; // Handle any exceptions
    }
  }

  Future<Device?> connectToDevice(String deviceName, {
    Future<void> Function(Device device)? foundDeviceCallback,
    Future<void> Function(Device device)? connectingToDeviceCallback,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    Future<void> combinedFoundDeviceCallback(Device device) async {
      if (connectingToDeviceCallback != null) {
        connectingToDeviceCallback(device);
      }
      await inviteDevice(device);
    }

    return await monitorDeviceConnectionStatus(deviceName, foundDeviceCallback: combinedFoundDeviceCallback, connectingToDeviceCallback: connectingToDeviceCallback, timeout: timeout);
  }

  Future<void> inviteDevice(Device device) async {
    if (device.state == SessionState.notConnected) {
      print("Device found. Sending invite...");
      await nearbyService.invitePeer(deviceID: device.deviceId, deviceName: device.deviceName);
    } else if (device.state == SessionState.connected) {
      print("Device is already connected: ${device.deviceName}");
    } else {
      print("Device is connecting, not sending invite: ${device.state}");
    }
  }

  Future<void> disconnectDevice(Device device) async {
    if (device.state != SessionState.connected) {
      print("Device not connected");
      return;
    }
    await nearbyService.disconnectPeer(deviceID: device.deviceId);
    _connectedDevice = null;
    print("Disconnected from device");
  }


  Future<void> sendMessageToDevice(Device device, String message) async {
    if (device.state != SessionState.connected) {
      print("Device not connected - Cannot send message");
      return;
    }
    await nearbyService.sendMessage(device.deviceId, message);
  }

  Future<String?> receiveMessageFromDevice(Device device, {Duration timeout = const Duration(seconds: 60)}) async {
    if (device.state != SessionState.connected) {
      print("Device not connected - Cannot receive message");
      return null;
    }
    _receiveMessageCompleter = Completer<String?>();

    receivedDataSubscription = nearbyService.dataReceivedSubscription(callback: (data) async {
      await receivedDataSubscription?.cancel();
      _receiveMessageCompleter!.complete(jsonEncode(data.message));
      print("dataReceivedSubscription: ${jsonEncode(data.message)}");
      // print(data.message);
      return;
    });
    try {
    return await _receiveMessageCompleter!.future.timeout(timeout, onTimeout: () {
      print("Message receiving timed out");
      return null; // Return null if timeout occurs
    });
  } catch (e) {
    print("Error during message receiving: $e");
    return null; // Handle any exceptions
  }
  }

  void dispose() {
    nearbyService.stopBrowsingForPeers();
    nearbyService.stopAdvertisingPeer();
    deviceMonitorSubscription.cancel();
    receivedDataSubscription?.cancel();
    if (_findDeviceCompleter != null && !_findDeviceCompleter!.isCompleted) {
      _findDeviceCompleter!.completeError('Device search cancelled');
    }
    _findDeviceCompleter = null;
    if (_receiveMessageCompleter != null && !_receiveMessageCompleter!.isCompleted) {
      _receiveMessageCompleter!.completeError('Message receiving cancelled');
    }
    _receiveMessageCompleter = null;
    if (_connectedDevice != null) {
      disconnectDevice(_connectedDevice!);
    }
  }
}


Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => Home());
    case 'browser':
      return MaterialPageRoute(
          builder: (_) => DevicesListScreen(deviceType: DeviceType.bibNumberDevice));
    case 'advertiser':
      return MaterialPageRoute(
          builder: (_) => DevicesListScreen(deviceType: DeviceType.raceTimerDevice));
    default:
      return MaterialPageRoute(
          builder: (_) => Scaffold(
                body: Center(
                    child: Text('No route defined for ${settings.name}')),
              ));
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateRoute: generateRoute,
      initialRoute: '/',
    );
  }
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, 'browser');
              },
              child: Container(
                color: Colors.red,
                child: Center(
                    child: Text(
                  'BROWSER',
                  style: TextStyle(color: Colors.white, fontSize: 40),
                )),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, 'advertiser');
              },
              child: Container(
                color: Colors.green,
                child: Center(
                    child: Text(
                  'ADVERTISER',
                  style: TextStyle(color: Colors.white, fontSize: 40),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class DevicesListScreen extends StatefulWidget {
  const DevicesListScreen({required this.deviceType});

  final DeviceType deviceType;

  @override
  _DevicesListScreenState createState() => _DevicesListScreenState();
}

class _DevicesListScreenState extends State<DevicesListScreen> {
  List<Device> devices = [];
  List<Device> connectedDevices = [];
  late DeviceConnectionService deviceConnectionService;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    deviceConnectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.deviceType.toString().substring(11).toUpperCase()),
        ),
        backgroundColor: Colors.white,
        );
  }

  void init() async {
    deviceConnectionService = DeviceConnectionService();
    final deviceType = widget.deviceType;
    await deviceConnectionService.init('wirelessconn', deviceType == DeviceType.bibNumberDevice ? 'browser' : 'advertiser', deviceType);
    if (deviceType == DeviceType.bibNumberDevice) {
      Device? device = await deviceConnectionService.connectToDevice(deviceType == DeviceType.bibNumberDevice ? 'advertiser' : 'browser');
      if (device != null) {
        await deviceConnectionService.sendMessageToDevice(device, 'Hello from browser');
      }
    }
    else {
      Device? device = await deviceConnectionService.monitorDeviceConnectionStatus(deviceType == DeviceType.bibNumberDevice ? 'advertiser' : 'browser');
      if (device != null) {
        final String? message = await deviceConnectionService.receiveMessageFromDevice(device);
          if (message != null) {
            print("Advertiser received message from browser: $message");
          }
      }
    }  
  }
}