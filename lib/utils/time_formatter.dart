String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = (duration.inMinutes % 60);
  // Format seconds with exactly 2 decimal places
  final seconds = ((duration.inMilliseconds / 1000) % 60).toStringAsFixed(2);

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.padLeft(5, '0')}';
  } else if (minutes > 0) {
    return '$minutes:${seconds.padLeft(5, '0')}';
  } else {
    return seconds;
  }
}

String formatDurationWithZeros(Duration duration) {
  final hours = duration.inHours;
  final hoursString = hours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60);

  final minutesString = minutes.toString().padLeft(2, '0');
  // Format seconds with exactly 2 decimal places
  final seconds = ((duration.inMilliseconds / 1000) % 60).toStringAsFixed(2);
  final secondsString = seconds.padLeft(5, '0');

  return '$hoursString:$minutesString:$secondsString';
}

// Duration? loadDurationFromString(String durationString) {
//   try {
//     List<String> parts = durationString.split(':');
//     int hours = parts.length == 3 ? int.parse(parts[0]) : 0; // First part is hours
//     int minutes = parts.length == 3 ? int.parse(parts[1]) : (parts.length == 2 ? int.parse(parts[0]) : 0); // Second part is minutes

//     // Handle milliseconds if present
//     int milliseconds = 0;
//     int seconds = 0;
//     if (parts.last.contains('.')) {
//         List<String> secondsParts = parts.last.split('.');
//         seconds = int.parse(secondsParts[0]);
//         milliseconds = (int.parse(secondsParts[1]) * (1000 ~/ 100)); // Convert to milliseconds
//     }
//     else {
//       seconds = int.parse(parts.last);
//     }

//     return Duration(
//         hours: hours,
//         minutes: minutes,
//         seconds: seconds,
//         milliseconds: milliseconds
//     );
//   } catch (e) {
//     print('Error parsing duration string: $e');
//     return null;
//   }
// }

Duration? loadDurationFromString(String input) {
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

    final millisString = millisecondParts.length > 1
        ? millisecondParts[1].padRight(3, '0')
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
    print('Error parsing duration string: $e');
    return null;
  }
}
