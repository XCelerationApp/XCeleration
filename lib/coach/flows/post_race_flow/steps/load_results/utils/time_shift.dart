import '../../../../../../core/utils/time_formatter.dart';
import '../../../../../../shared/models/timing_records/timing_chunk.dart';
import '../../../../../../shared/models/timing_records/timing_datum.dart';

/// Moves every recorded time in [chunks] by [by], in place.
///
/// For a Timer who pressed Start late or early: pressed 5 seconds after the
/// gun, every time is 5 seconds short, so [by] is +5 seconds. Placeholders
/// that are not times yet, such as a missing time still to be typed, are left
/// as they are.
///
/// Returns why nothing was moved, or null once every time has been: a shift
/// that would take any time below zero is refused as a whole, so the times
/// are never left half-moved.
String? shiftTimes(List<TimingChunk> chunks, Duration by) {
  final data = [
    for (final chunk in chunks) ...[
      ...chunk.timingData,
      ?chunk.conflictRecord,
    ],
  ];

  final moved = <TimingDatum, Duration>{};
  for (final datum in data) {
    final time = TimeFormatter.loadDurationFromString(datum.time);
    if (time == null) continue;
    final shifted = time + by;
    if (shifted.isNegative) {
      return 'That would put ${datum.time} below zero. Check the number of '
          'seconds.';
    }
    moved[datum] = shifted;
  }

  for (final MapEntry(key: datum, value: time) in moved.entries) {
    datum.time = TimeFormatter.formatDuration(time);
  }
  return null;
}

/// [time] moved by [by] and written the way the Timer writes times, or
/// [time] unchanged if it is not a time yet.
String shiftedTime(String time, Duration by) {
  final parsed = TimeFormatter.loadDurationFromString(time);
  return parsed == null ? time : TimeFormatter.formatDuration(parsed + by);
}
