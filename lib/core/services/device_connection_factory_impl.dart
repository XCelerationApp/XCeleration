import 'device_connection_service.dart';
import 'i_device_connection_factory.dart';
import '../utils/enums.dart';

/// Concrete implementation of [IDeviceConnectionFactory] that delegates to
/// [DeviceConnectionService.createDevices].
class DeviceConnectionFactoryImpl implements IDeviceConnectionFactory {
  const DeviceConnectionFactoryImpl();

  @override
  DevicesManager createDevices(
    DeviceName deviceName,
    DeviceType deviceType, {
    String? data,
    bool toSpectator = false,
  }) =>
      DeviceConnectionService.createDevices(
        deviceName,
        deviceType,
        data: data,
        toSpectator: toSpectator,
      );
}
