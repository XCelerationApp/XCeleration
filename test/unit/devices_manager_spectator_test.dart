import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/enums.dart';

void main() {
  group('DevicesManager finish-line role behavior', () {
    test('bibRecorderV2 in browserDevice mode connects to coach', () {
      final devices = DeviceConnectionService.createDevices(
        DeviceName.bibRecorderV2,
        DeviceType.browserDevice,
      );

      expect(devices.otherDevices.length, 1);
      expect(devices.otherDevices.first.name, DeviceName.coach);
    });

    test('bibRecorderV2 advertiser sets verifier and fixer as peers', () {
      final devices = DeviceConnectionService.createDevices(
        DeviceName.bibRecorderV2,
        DeviceType.advertiserDevice,
      );

      expect(devices.otherDevices.length, 2);
      final names = devices.otherDevices.map((d) => d.name).toSet();
      expect(names, {DeviceName.verifier, DeviceName.fixer});
    });

    test('verifier in browserDevice mode connects to coach', () {
      final devices = DeviceConnectionService.createDevices(
        DeviceName.verifier,
        DeviceType.browserDevice,
      );

      expect(devices.otherDevices.length, 1);
      expect(devices.otherDevices.first.name, DeviceName.coach);
    });

    test('fixer in browserDevice mode connects to coach', () {
      final devices = DeviceConnectionService.createDevices(
        DeviceName.fixer,
        DeviceType.browserDevice,
      );

      expect(devices.otherDevices.length, 1);
      expect(devices.otherDevices.first.name, DeviceName.coach);
    });

    test('finish-line roles do not require a data payload', () {
      expect(
        () => DeviceConnectionService.createDevices(
          DeviceName.bibRecorderV2,
          DeviceType.advertiserDevice,
        ),
        returnsNormally,
      );
      expect(
        () => DeviceConnectionService.createDevices(
          DeviceName.verifier,
          DeviceType.advertiserDevice,
        ),
        returnsNormally,
      );
      expect(
        () => DeviceConnectionService.createDevices(
          DeviceName.fixer,
          DeviceType.advertiserDevice,
        ),
        returnsNormally,
      );
    });
  });

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
