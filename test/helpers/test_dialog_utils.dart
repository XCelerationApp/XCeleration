import 'package:flutter/material.dart';

/// Mock version of DialogUtils for testing
/// Prevents UI errors in tests by capturing dialog calls without showing UI
class TestDialogUtils {
  // Captured error messages for verification
  static List<String> errorMessages = [];

  // Captured success messages for verification
  static List<String> successMessages = [];

  // Whether the mock has been set up
  static bool _isConfigured = false;

  /// Set up the dialog utils mock for testing
  /// Call this in your test setUp method
  static void setUp() {
    if (_isConfigured) return;
    _isConfigured = true;

    // Clear previous captures
    errorMessages = [];
    successMessages = [];

    print('[TEST SETUP] Dialog utils mock configured for testing');
  }

  /// Non-UI version of showErrorDialog for testing
  static void showErrorDialog(BuildContext context, {required String message, String? title}) {
    // Just capture the message without showing UI
    errorMessages.add(message);
    print('[TEST ERROR DIALOG] $message');
  }

  /// Non-UI version of showSuccessDialog for testing
  static void showSuccessDialog(BuildContext context, {required String message, String? title}) {
    // Just capture the message without showing UI
    successMessages.add(message);
    print('[TEST SUCCESS DIALOG] $message');
  }

  /// Non-UI version of showOverlayNotification for testing
  static void showOverlayNotification(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color backgroundColor = Colors.white,
    Color textColor = Colors.black,
    Color iconColor = Colors.black,
    Duration duration = const Duration(seconds: 2),
  }) {
    // Just log without showing UI
    print('[TEST NOTIFICATION] $message');
  }

  /// Reset captured messages (call between tests if needed)
  static void reset() {
    errorMessages = [];
    successMessages = [];
  }
}
