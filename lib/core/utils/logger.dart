import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xceleration/core/components/dialog_utils.dart';

class Logger {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void e(String message,
      {BuildContext? context, Object? error, StackTrace? stackTrace}) {
    Logger.d('[ERROR] $message');
    if (error != null) Logger.d('Error: $error');
    if (stackTrace != null) Logger.d('StackTrace: $stackTrace');
    if (context != null && context.mounted) {
      DialogUtils.showErrorDialog(context, message: 'Error: $message');
    }
  }
}
