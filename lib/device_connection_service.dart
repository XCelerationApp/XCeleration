import 'dart:async';
import 'dart:convert';
// import 'dart:io';
// import 'package:device_info/device_info.dart';
// import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';

void main() {
  runApp(MyApp());
}

enum DeviceType { advertiser, browser }


class DeviceConnectionService {
  late NearbyService nearbyService;

  late StreamSubscription deviceSearchSubscription;
  late StreamSubscription receivedDataSubscription;
  Completer<Device>? _findDeviceCompleter;
  Completer<String>? _receiveMessageCompleter;

  bool isInit = false;

  Future<void> init(String serviceType, String deviceName, DeviceType deviceType) async {
    nearbyService = NearbyService();
    await nearbyService.init(
        serviceType: serviceType, //'wirelessconn'
        deviceName: deviceName,
        strategy: Strategy.P2P_POINT_TO_POINT,
        callback: (isRunning) async {
          if (isRunning) {
            if (deviceType == DeviceType.browser) {
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

  Future<Device?> findDevice(String deviceName) async {
    _findDeviceCompleter = Completer<Device>();

    deviceSearchSubscription = nearbyService.stateChangedSubscription(callback: (devicesList) {
      for (var device in devicesList) {
        if (device.deviceName == deviceName) {
          deviceSearchSubscription.cancel(); // Cancel the subscription
          _findDeviceCompleter!.complete(device); // Complete the completer with the found device
          return; // Exit the loop
        }
      }
    });
    if (_findDeviceCompleter?.isCompleted == true && _findDeviceCompleter!.future is Device) {
      print("Found device");
      return _findDeviceCompleter!.future;
    } else {
      print("Device not found");
      return null;
    }
  }

  Future<void> inviteDevice(Device device) async {
    await nearbyService.invitePeer(deviceID: device.deviceId, deviceName: device.deviceName);
    print("Invited to connect");
  }

  Future<void> disconnectDevice(Device device) async {
    if (device.state != SessionState.connected) {
      print("Device not connected");
      return;
    }
    await nearbyService.disconnectPeer(deviceID: device.deviceId);
    print("Disconnected from device");
  }


  Future<void> sendMessageToDevice(Device device, String message) async {
    if (device.state != SessionState.connected) {
      print("Device not connected - Cannot send message");
      return;
    }
    await nearbyService.sendMessage(device.deviceId, message);
  }

  Future<String?> receiveMessageFromDevice(Device device) async {
    if (device.state != SessionState.connected) {
      print("Device not connected - Cannot receive message");
      return null;
    }
    receivedDataSubscription = nearbyService.dataReceivedSubscription(callback: (data) {
      receivedDataSubscription.cancel();
      _receiveMessageCompleter!.complete(jsonEncode(data));
      print("dataReceivedSubscription: ${jsonEncode(data)}");
      return;
      // showToast(jsonEncode(data),
      //     context: context,
      //     axis: Axis.horizontal,
      //     alignment: Alignment.center,
      //     position: StyledToastPosition.bottom);
    });
    return _receiveMessageCompleter!.future;
  }

  void dispose() {
    nearbyService.stopBrowsingForPeers();
    nearbyService.stopAdvertisingPeer();
    deviceSearchSubscription.cancel();
    receivedDataSubscription.cancel();
    _findDeviceCompleter?.completeError('Device search cancelled');
    _findDeviceCompleter = null;
    _receiveMessageCompleter?.completeError('Message receiving cancelled');
    _receiveMessageCompleter = null;
  }
}


Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => Home());
    case 'browser':
      return MaterialPageRoute(
          builder: (_) => DevicesListScreen(deviceType: DeviceType.browser));
    case 'advertiser':
      return MaterialPageRoute(
          builder: (_) => DevicesListScreen(deviceType: DeviceType.advertiser));
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
    await deviceConnectionService.init('wirelessconn', deviceType == DeviceType.browser ? 'browser' : 'advertiser', deviceType);
    Device? device = await deviceConnectionService.findDevice(deviceType == DeviceType.browser ? 'advertiser' : 'browser');
    if (device != null) {
      if (deviceType == DeviceType.browser) {
        await deviceConnectionService.inviteDevice(device);
        while (device?.state != SessionState.connected) {
          await Future.delayed(const Duration(seconds: 1));
          device = await deviceConnectionService.findDevice('advertiser');
          if (device?.state == SessionState.connecting) {
            print("Connecting to device");
          }
        }
        if (device != null) {
          await deviceConnectionService.sendMessageToDevice(device, 'Hello from browser');
        }
      }
      else {
        while (device?.state != SessionState.connected) {
          await Future.delayed(const Duration(seconds: 1));
          device = await deviceConnectionService.findDevice('browser');
          if (device?.state == SessionState.connecting) {
            print("Connecting to device");
          }
        }
        if (device != null) {
          final String? message = await deviceConnectionService.receiveMessageFromDevice(device);
          if (message != null) {
            print("Advertiser received message from browser: $message");
          }
        }
      }
    }
      
  }
}