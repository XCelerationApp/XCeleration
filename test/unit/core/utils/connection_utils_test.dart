import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/connection_utils.dart';
import 'package:xceleration/core/utils/enums.dart';

// Phones find each other by name. A name one phone sends that the other does
// not read back is ignored, and the connection never finishes.

// The devices that connect to another phone.
const connecting = [
  DeviceName.coach,
  DeviceName.raceTimer,
  DeviceName.bibRecorder,
  DeviceName.spectator,
];

void main() {
  test('every device reads back from the name it sends', () {
    for (final device in connecting) {
      expect(getDeviceNameFromString(getDeviceWireName(device)), device);
    }
  });

  test('every device reads back from the name on screen', () {
    for (final device in connecting) {
      expect(getDeviceNameFromString(getDeviceNameString(device)), device);
    }
  });

  test('the Timer still sends Race Timer, which phones on 1.1.0 know', () {
    expect(getDeviceWireName(DeviceName.raceTimer), 'Race Timer');
    expect(getDeviceNameString(DeviceName.raceTimer), 'Timer');
  });

  test('a Timer on 1.1.1, which sends Timer, is still read', () {
    expect(getDeviceNameFromString('Timer'), DeviceName.raceTimer);
    expect(getDeviceNameFromString('Race Timer'), DeviceName.raceTimer);
  });

  test('a name from another app is not a device', () {
    expect(tryDeviceNameFromString("Sam's iPhone"), isNull);
    expect(() => getDeviceNameFromString("Sam's iPhone"), throwsArgumentError);
  });
}
