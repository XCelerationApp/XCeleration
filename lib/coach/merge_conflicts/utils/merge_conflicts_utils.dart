import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

/// Validates a single time entry against all other times in a chunk.
/// Returns an error message string, or null if valid.
/// [contextTimes] is the full list of times with [recordIndex] already updated to [endTime].
String? validateTimeInContext(
    List<String> contextTimes, int recordIndex, String endTime) {
  final currentTime = contextTimes[recordIndex];
  if (currentTime == 'TBD') return null;
  final currentDuration = TimeFormatter.loadDurationFromString(currentTime);
  if (currentDuration == null) return null;

  for (int i = 0; i < contextTimes.length; i++) {
    if (i != recordIndex && contextTimes[i] != 'TBD') {
      final other = TimeFormatter.loadDurationFromString(contextTimes[i]);
      if (other != null && currentDuration == other) return 'Invalid Time';
    }
  }

  final prevIndex = getPreviousValidTimeIndex(contextTimes, recordIndex);
  if (prevIndex != null) {
    final prev =
        TimeFormatter.loadDurationFromString(contextTimes[prevIndex]);
    if (prev != null && currentDuration <= prev) return 'Invalid Time';
  }

  final nextIndex = getNextValidTimeIndex(contextTimes, recordIndex);
  if (nextIndex != null) {
    final next =
        TimeFormatter.loadDurationFromString(contextTimes[nextIndex]);
    if (next != null && currentDuration >= next) return 'Invalid Time';
  }

  final endDuration = TimeFormatter.loadDurationFromString(endTime);
  if (endDuration != null && currentDuration > endDuration) {
    return 'Invalid Time';
  }

  return null;
}

/// Returns the index of the previous non-TBD time before [recordIndex], or null.
int? getPreviousValidTimeIndex(List<String> contextTimes, int recordIndex) {
  for (int i = recordIndex - 1; i >= 0; i--) {
    if (contextTimes[i] != 'TBD') return i;
  }
  return null;
}

/// Returns the index of the next non-TBD time after [recordIndex], or null.
int? getNextValidTimeIndex(List<String> contextTimes, int recordIndex) {
  for (int i = recordIndex + 1; i < contextTimes.length; i++) {
    if (contextTimes[i] != 'TBD') return i;
  }
  return null;
}

bool validateRunnerInfo(List<RunnerRecord> records) {
  return records.every((runner) =>
      runner.bib.isNotEmpty &&
      runner.name.isNotEmpty &&
      runner.grade > 0 &&
      runner.team.isNotEmpty &&
      runner.teamAbbreviation.isNotEmpty);
}

String? validateTimes(
  List<String> times,
  List<RunnerRecord> runners,
  TimingDatum lastConfirmed,
  TimingDatum conflictRecord,
) {
  if (times.any((time) => time.trim().isEmpty)) {
    return 'All time fields must be filled in';
  }
  for (var i = 0; i < times.length; i++) {
    final String time = times[i].trim();
    final runner = i < runners.length ? runners[i] : runners.last;
    final bool validFormat =
        RegExp(r'^\d+:\d+\.\d+|^\d+\.\d+$').hasMatch(time);
    if (!validFormat) {
      return 'Invalid time format for runner with bib ${runner.bib}. Use MM:SS.ms or SS.ms';
    }
  }
  Duration lastConfirmedTime = lastConfirmed.time.trim().isEmpty
      ? Duration.zero
      : TimeFormatter.loadDurationFromString(lastConfirmed.time) ??
          Duration.zero;
  Duration? conflictTime =
      TimeFormatter.loadDurationFromString(conflictRecord.time);
  for (var i = 0; i < times.length; i++) {
    final time = TimeFormatter.loadDurationFromString(times[i]);
    final runner = i < runners.length ? runners[i] : runners.last;
    if (time == null) {
      return 'Enter a valid time for runner with bib ${runner.bib}';
    }
    if (time <= lastConfirmedTime || time >= (conflictTime ?? Duration.zero)) {
      return 'Time for ${runner.name} must be after ${lastConfirmed.time} and before ${conflictRecord.time}';
    }
  }
  if (!isAscendingOrder(times
      .map(
          (time) => TimeFormatter.loadDurationFromString(time) ?? Duration.zero)
      .toList())) {
    return 'Times must be in ascending order';
  }
  return null;
}

bool isAscendingOrder(List<Duration> times) {
  for (var i = 0; i < times.length - 1; i++) {
    if (times[i] >= times[i + 1]) return false;
  }
  return true;
}
