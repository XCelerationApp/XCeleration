import 'package:flutter/foundation.dart';

class Logger {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    Logger.d('[ERROR] $message');
    if (error != null) Logger.d('Error: $error');
    if (stackTrace != null) Logger.d('StackTrace: $stackTrace');
  }
} 