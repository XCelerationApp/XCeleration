import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import '../../../shared/models/time_record.dart';
import 'package:xceleration/core/utils/time_formatter.dart';

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
  TimeRecord lastConfirmed,
  TimeRecord conflictRecord,
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
  Duration lastConfirmedTime = lastConfirmed.elapsedTime.trim().isEmpty
      ? Duration.zero
      : TimeFormatter.loadDurationFromString(lastConfirmed.elapsedTime) ??
          Duration.zero;
  Duration? conflictTime =
      TimeFormatter.loadDurationFromString(conflictRecord.elapsedTime);
  for (var i = 0; i < times.length; i++) {
    final time = TimeFormatter.loadDurationFromString(times[i]);
    final runner = i < runners.length ? runners[i] : runners.last;
    if (time == null) {
      return 'Enter a valid time for runner with bib ${runner.bib}';
    }
    if (time <= lastConfirmedTime || time >= (conflictTime ?? Duration.zero)) {
      return 'Time for ${runner.name} must be after ${lastConfirmed.elapsedTime} and before ${conflictRecord.elapsedTime}';
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
