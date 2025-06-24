class AppConfig {
  final String appName;
  final String bundleId;
  final String flavor;

  AppConfig({
    required this.appName,
    required this.bundleId,
    required this.flavor,
  });

  // Helper method to easily identify dev builds in the UI if needed
  bool get isDevBuild => flavor == 'development';

  // Factory method to create a config from dart-define parameters
  factory AppConfig.fromEnvironment() {
    // Get bundleId from --dart-define or use the default value
    const bundleId = String.fromEnvironment(
      'BUNDLE_ID',
      defaultValue: 'com.owendonnelley.xceleration',
    );

    // Get app name from --dart-define or use the default value
    const appName = String.fromEnvironment(
      'APP_NAME',
      defaultValue: 'XCeleration',
    );

    // Determine flavor based on bundle ID
    final flavor = bundleId.contains('.dev') ? 'development' : 'production';

    return AppConfig(
      appName: appName,
      bundleId: bundleId,
      flavor: flavor,
    );
  }
}
