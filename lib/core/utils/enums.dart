/// Enums used throughout the application
/// Consolidated from various enum files across the app
library;

enum ConnectionStatus {
  connected,
  connecting,
  finished,
  error,
  sending,
  receiving,
  timeout,
  searching,
  found,
  disconnected,
  failed,
}

enum WirelessConnectionError {
  unavailable,
  unknown,
  timeout,
}

enum PopupScreen {
  main,
  qr,
}

enum DeviceName {
  coach,
  bibRecorder,
  raceTimer,
  assistant,
}

enum DeviceType {
  advertiserDevice,
  browserDevice,
  assistantDevice,
  coachDevice,
}

enum RecordType {
  runnerTime,
  confirmRunner,
  missingTime,
  extraTime,
  manualTime,
}

enum ConflictType {
  confirmRunner,
  missingTime,
  extraTime,
}

enum RaceScreenPage {
  main,
  results,
}

enum ResultFormat {
  plainText,
  googleSheet,
  pdf,
}

enum FlowType {
  preRace,
  postRace,
}

enum RunnerRecordFlags {
  duplicateBibNumber,
  notInDatabase,
  lowConfidenceScore,
}

/// Represents the different roles in the application
enum Role {
  coach,
  assistant,
}

/// Event types for the event bus system
enum EventTypes {
  raceFlowStateChanged,
  deviceConnectionChanged,
  dataReceived,
  dataTransferComplete,
}
