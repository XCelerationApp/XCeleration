import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/enums.dart';

void main() {
  group('DevicesManager spectator behavior', () {
    test('spectator advertiser targets spectator with payload', () {
      final devices = DeviceConnectionService.createDevices(
        DeviceName.spectator,
        DeviceType.advertiserDevice,
        data: 'payload',
        toSpectator: true,
      );

      // Should advertise to spectator only
      expect(devices.spectator, isNotNull);
      expect(devices.coach, isNull);
      expect(devices.otherDevices.length, 1);
      expect(devices.otherDevices.first.name, DeviceName.spectator);
      expect(devices.otherDevices.first.data, 'payload');
    });

    test('spectator browser receiving from coach only when toSpectator=false',
        () {
      final devices = DeviceConnectionService.createDevices(
        DeviceName.spectator,
        DeviceType.browserDevice,
        toSpectator: false,
      );

      expect(devices.coach, isNotNull);
      expect(devices.spectator, isNull);
      final names = devices.otherDevices.map((d) => d.name).toList();
      expect(names.contains(DeviceName.coach), isTrue);
      expect(names.contains(DeviceName.spectator), isFalse);
    });

    test(
        'spectator browser receiving from spectator only when toSpectator=true',
        () {
      final devices = DeviceConnectionService.createDevices(
        DeviceName.spectator,
        DeviceType.browserDevice,
        toSpectator: true,
      );

      expect(devices.spectator, isNotNull);
      expect(devices.coach, isNull);
      final names = devices.otherDevices.map((d) => d.name).toList();
      expect(names.contains(DeviceName.spectator), isTrue);
      expect(names.contains(DeviceName.coach), isFalse);
    });
  });
}
