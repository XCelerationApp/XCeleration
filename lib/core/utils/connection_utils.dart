import 'enums.dart';

const Map<DeviceName, String> _deviceNameStrings = {
  DeviceName.coach: 'Coach',
  DeviceName.bibRecorder: 'Bib Recorder',
  DeviceName.raceTimer: 'Race Timer',
  DeviceName.spectator: 'Spectator',
};

String getDeviceNameString(DeviceName deviceName) {
  return _deviceNameStrings[deviceName] ?? deviceName.toString();
}

DeviceName getDeviceNameFromString(String deviceName) {
  switch (deviceName.toLowerCase()) {
    case 'coach':
      return DeviceName.coach;
    case 'bib recorder':
      return DeviceName.bibRecorder;
    case 'race timer':
      return DeviceName.raceTimer;
    case 'spectator':
      return DeviceName.spectator;
    default:
      throw ArgumentError('Invalid device name: $deviceName');
  }
}
