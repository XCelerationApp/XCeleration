String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = (duration.inMinutes % 60);
  final seconds = ((duration.inMilliseconds / 1000) % 60).toStringAsFixed(2); // Round to 2 decimal places
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(5, '0')}';
  }
  else if (minutes > 0){
    return'$minutes:${seconds.toString().padLeft(5, '0')}';
  }
  else {
    return seconds;
  }
}

String formatDurationWithZeros(Duration duration) {
  final hours = duration.inHours;
  final hoursString = hours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60);
  
  final minutesString = minutes.toString().padLeft(2, '0');
  final seconds = ((duration.inMilliseconds / 1000) % 60).toStringAsFixed(2); // Round to 2 decimal places
  final secondsString = seconds.padLeft(5, '0');
  
  return '$hoursString:$minutesString:$secondsString';
}

Duration loadDurationFromString(String durationString) {
    List<String> parts = durationString.split(':');
    int hours = parts.length == 3 ? int.parse(parts[0]) : 0; // First part is hours
    int minutes = parts.length == 3 ? int.parse(parts[1]) : (parts.length == 2 ? int.parse(parts[0]) : 0); // Second part is minutes

    // Handle milliseconds if present
    int milliseconds = 0;
    int seconds = 0;
    if (parts.last.contains('.')) {
        List<String> secondsParts = parts.last.split('.');
        seconds = int.parse(secondsParts[0]);
        milliseconds = (int.parse(secondsParts[1]) * (1000 ~/ 100)); // Convert to milliseconds
    }
    else {
      seconds = int.parse(parts.last);
    }

    return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds
    );
}