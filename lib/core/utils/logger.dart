import 'package:flutter/foundation.dart';

class Logger {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message');
    if (error != null) debugPrint('Error: $error');
    if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
  }
} 