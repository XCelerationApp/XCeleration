import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:xceleration/core/components/dialog_utils.dart';

class Logger {
  static bool silent = false;

  static void d(String message) {
    if (kDebugMode && !silent) {
      debugPrint(message);
    }
  }

  /// Logs an error the app caught and carried on from. Outside debug builds
  /// it also goes to Sentry: only uncaught errors reached it before, so a
  /// coach's failed save or load was never seen.
  static void e(String message,
      {BuildContext? context, Object? error, StackTrace? stackTrace}) {
    Logger.d('[ERROR] $message');
    if (error != null) Logger.d('Error: $error');
    if (stackTrace != null) Logger.d('StackTrace: $stackTrace');
    if (!kDebugMode) _report(message, error, stackTrace);
    if (context != null && context.mounted) {
      DialogUtils.showErrorDialog(context, message: 'Error: $message');
    }
  }

  static void _report(String message, Object? error, StackTrace? stackTrace) {
    if (error == null) {
      Sentry.captureMessage(message, level: SentryLevel.error);
      return;
    }
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) => scope.setContexts('log', {'message': message}),
    );
  }
}
