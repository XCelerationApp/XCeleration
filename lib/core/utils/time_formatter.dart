import 'package:xceleration/core/utils/logger.dart';

/// A utility class for formatting and parsing time durations.
class TimeFormatter {
  /// Formats a duration into a string with conditional formatting:
  /// - For durations with hours: "h:mm:ss.xx"
  /// - For durations with minutes (no hours): "m:ss.xx"
  /// - For durations with seconds only: "ss.xx"
  static String formatDuration(Duration duration) {
    final (hours, minutes, seconds) = _parts(duration);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.padLeft(5, '0')}';
    } else if (minutes > 0) {
      return '$minutes:${seconds.padLeft(5, '0')}';
    } else {
      return seconds;
    }
  }

  /// Hours, minutes and seconds (to exactly 2 decimals) of [duration].
  /// Rounds to hundredths first: rounding only the seconds turned 15:59.996
  /// into "15:60.00".
  static (int, int, String) _parts(Duration duration) {
    final centis = (duration.inMilliseconds / 10).round();
    final hours = centis ~/ 360000;
    final minutes = (centis ~/ 6000) % 60;
    final seconds = ((centis % 6000) / 100).toStringAsFixed(2);
    return (hours, minutes, seconds);
  }

  /// Formats a duration into a string with consistent "hh:mm:ss.xx" format,
  /// always including hours and using leading zeros.
  static String formatDurationWithZeros(Duration duration) {
    final (hours, minutes, seconds) = _parts(duration);
    final hoursString = hours.toString().padLeft(2, '0');
    final minutesString = minutes.toString().padLeft(2, '0');
    final secondsString = seconds.padLeft(5, '0');

    return '$hoursString:$minutesString:$secondsString';
  }

  /// Parses a time string into a Duration object.
  ///
  /// Supports various formats:
  /// - "ss.xx" (seconds only)
  /// - "mm:ss.xx" (minutes and seconds)
  /// - "hh:mm:ss.xx" (hours, minutes, and seconds)
  ///
  /// Returns null if the string is empty, 'manual', or not in a valid format.
  static Duration? loadDurationFromString(String input) {
    try {
      if (input.isEmpty || input == '' || input == 'manual') return null;

      final parts = input.split(':');
      final timeString = switch (parts.length) {
        1 => '00:00:$input',
        2 => '00:$input',
        3 => input,
        _ => null
      };

      if (timeString == null) return null;

      final millisecondParts = timeString.split('.');
      if (millisecondParts.length > 2) return null;

      // Only the first three digits are milliseconds: "34.560000" (how a
      // Dart Duration prints) is 560 ms, not 560,000.
      final millisString = millisecondParts.length > 1
          ? millisecondParts[1].padRight(3, '0').substring(0, 3)
          : '0';

      final timeParts = timeString.split(':');

      final hours = int.parse(timeParts[0]);
      final minutes = int.parse(timeParts[1]);
      final seconds = int.parse(timeParts[2].split('.')[0]);
      final milliseconds = int.parse(millisString);

      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    } catch (e) {
      Logger.d('Error parsing duration string: $e');
      return null;
    }
  }

  static bool isDuration(String input) {
    return loadDurationFromString(input) != null;
  }
}
