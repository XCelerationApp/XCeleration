import 'enums.dart';

const Map<DeviceName, String> _deviceNameStrings = {
  DeviceName.coach: 'Coach',
  DeviceName.bibRecorder: 'Bib Recorder',
  DeviceName.raceTimer: 'Timer',
  DeviceName.spectator: 'Spectator',
};

/// The name a device goes by on screen.
String getDeviceNameString(DeviceName deviceName) {
  return _deviceNameStrings[deviceName] ?? deviceName.toString();
}

/// The name a phone announces itself by to other phones, and puts in front of
/// its QR code. The Timer is still 'Race Timer' here although it is 'Timer' on
/// screen: phones on 1.1.0 only know 'Race Timer', and a name they don't know
/// is ignored, so a coach's phone never answered a Timer on 1.1.1.
///
/// Part of what phones send each other: never change these names for
/// wording. See test/fixtures/wire/README.md.
String getDeviceWireName(DeviceName deviceName) {
  if (deviceName == DeviceName.raceTimer) return 'Race Timer';
  return getDeviceNameString(deviceName);
}

/// The device a name from another phone belongs to. Takes both the Timer's
/// names, since phones on 1.1.1 send 'Timer'.
DeviceName getDeviceNameFromString(String deviceName) {
  switch (deviceName.toLowerCase()) {
    case 'coach':
      return DeviceName.coach;
    case 'bib recorder':
      return DeviceName.bibRecorder;
    case 'race timer':
    case 'timer':
      return DeviceName.raceTimer;
    case 'spectator':
      return DeviceName.spectator;
    default:
      throw ArgumentError('Invalid device name: $deviceName');
  }
}

/// The device a name from another phone belongs to, or null for a name this
/// app does not know, such as another app's phone nearby.
DeviceName? tryDeviceNameFromString(String deviceName) {
  try {
    return getDeviceNameFromString(deviceName);
  } on ArgumentError {
    return null;
  }
}
