import 'device_connection_service.dart';
import '../utils/enums.dart';

abstract interface class IDeviceConnectionFactory {
  DevicesManager createDevices(
    DeviceName deviceName,
    DeviceType deviceType, {
    String? data,
    bool toSpectator,
  });
}
