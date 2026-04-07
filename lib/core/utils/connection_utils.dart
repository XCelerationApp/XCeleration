import 'enums.dart';

const Map<DeviceName, String> _deviceNameStrings = {
  DeviceName.coach: 'Coach',
  DeviceName.bibRecorder: 'Bib Recorder',
  DeviceName.raceTimer: 'Race Timer',
  DeviceName.spectator: 'Spectator',
  DeviceName.bibRecorderV2: 'Bib Recorder V2',
  DeviceName.verifier: 'Verifier',
  DeviceName.fixer: 'Fixer',
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
    case 'bib recorder v2':
      return DeviceName.bibRecorderV2;
    case 'verifier':
      return DeviceName.verifier;
    case 'fixer':
      return DeviceName.fixer;
    default:
      throw ArgumentError('Invalid device name: $deviceName');
  }
}
