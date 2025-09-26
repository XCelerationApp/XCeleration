/// Application-wide constants
class AppConstants {
  // Prevent instantiation
  AppConstants._();

  // App Information
  static const String appName = 'XCeleration';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'races.db';
  static const int databaseVersion = 4;

  // UI Dimensions
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double buttonHeight = 48.0;
  static const double iconSize = 24.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);

  // Network & Connection
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration deviceScanTimeout = Duration(seconds: 60);
  static const int maxRetryAttempts = 3;

  // Data Transfer
  static const int dataChunkSize = 1000;
  static const int maxSendAttempts = 4;
  static const Duration retryTimeout = Duration(seconds: 5);

  // File Paths
  static const String assetsPath = 'assets/';
  static const String iconsPath = '${assetsPath}icon/';
  static const String soundsPath = '${assetsPath}sounds/';
  static const String fontsPath = '${assetsPath}fonts/';

  // Sound Files
  static const String clickSound = '${soundsPath}click.mp3';
  static const String completedSound = '${soundsPath}completed_ding.mp3';

  // Validation
  static const int maxBibNumber = 99999;
  static const int minBibNumber = 1;
  static const int maxRunnerNameLength = 30;
  static const int maxTeamNameLength = 50;
  static const int maxRaceNameLength = 50;

  // Error Messages
  static const String genericError =
      'An unexpected error occurred. Please try again.';
  static const String networkError =
      'Network connection failed. Please check your internet connection.';
  static const String connectionError =
      'Failed to connect to device. Please try again.';
  static const String dataError =
      'Failed to process data. Please check your input.';

  // Success Messages
  static const String dataSaved = 'Data saved successfully';
  static const String raceCreated = 'Race created successfully';
  static const String deviceConnected = 'Device connected successfully';
}

/// Event type constants for the EventBus
class EventTypes {
  EventTypes._();

  static const String raceCreated = 'race_created';
  static const String raceUpdated = 'race_updated';
  static const String raceDeleted = 'race_deleted';
  static const String raceFlowStateChanged = 'race_flow_state_changed';
  static const String runnersAdded = 'runners_added';
  static const String runnerRemoved = 'runner_removed';
  static const String deviceConnected = 'device_connected';
  static const String deviceDisconnected = 'device_disconnected';
  static const String dataReceived = 'data_received';
  static const String timingStarted = 'timing_started';
  static const String timingStopped = 'timing_stopped';
  static const String resultsUpdated = 'results_updated';
  static const String errorOccurred = 'error_occurred';
}

/// Regular expressions for validation
class ValidationPatterns {
  ValidationPatterns._();

  static final RegExp bibNumber = RegExp(r'^\d{1,5}$');
  static final RegExp time = RegExp(r'^\d{1,2}:\d{2}:\d{2}$');
  static final RegExp name = RegExp(r'^[a-zA-Z .-]{1,50}$');
  static final RegExp email =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
}
