import 'package:flutter/material.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart'
    show RunnerRecord;
import 'dart:math';
import '../core/theme/app_colors.dart';
import '../core/components/dialog_utils.dart';
import 'enums.dart';
import '../assistant/race_timer/model/timing_record.dart';

List<TimingRecord> updateTextColor(Color? color, List<TimingRecord> records,
    {bool confirmed = false,
    ConflictDetails? conflict,
    int? endIndex,
    bool clearConflictColor = false}) {
  if (endIndex != null && endIndex < records.length && records.isNotEmpty) {
    records = records.sublist(0, endIndex);
  }
  for (int i = records.length - 1; i >= 0; i--) {
    if (records[i].type != RecordType.runnerTime) {
      break;
    }

    // Directly set the textColor field for immediate visual update
    records[i].textColor = color;

    // Determine if we need to clear the text color (when null is passed)
    bool shouldClearTextColor = color == null;

    bool shouldClearConflict = clearConflictColor && conflict == null;

    if (confirmed == true) {
      records[i] = records[i].copyWith(
        conflict: conflict,
        isConfirmed: true,
        textColor: color,
        clearTextColor: shouldClearTextColor,
        clearConflict: shouldClearConflict,
      );
    } else {
      records[i] = records[i].copyWith(
        conflict: null,
        isConfirmed: false,
        textColor: color,
        clearTextColor: shouldClearTextColor,
        clearConflict: shouldClearConflict,
      );
    }
  }
  return records;
}

List<TimingRecord> confirmRunnerNumber(
    List<TimingRecord> records, int numTimes, String finishTime) {
  final color = Colors.green;
  records = updateTextColor(color, records, confirmed: true);

  records = deleteConfirmedRecordsBeforeIndexUntilConflict(
      records, records.length - 1);

  records.add(TimingRecord(
    elapsedTime: finishTime,
    type: RecordType.confirmRunner,
    textColor: color,
    place: numTimes,
  ));

  return records;
}

List<TimingRecord> deleteConfirmedRecordsBeforeIndexUntilConflict(
    List<TimingRecord> records, int recordIndex) {
  debugPrint(recordIndex.toString());
  if (recordIndex < 0 || recordIndex >= records.length) {
    return [];
  }
  final trimmedRecords = records.sublist(0, recordIndex + 1);
  for (int i = trimmedRecords.length - 1; i >= 0; i--) {
    if (trimmedRecords[i].type != RecordType.runnerTime &&
        trimmedRecords[i].type != RecordType.confirmRunner) {
      break;
    }
    if (trimmedRecords[i].type != RecordType.runnerTime &&
        trimmedRecords[i].type == RecordType.confirmRunner) {
      records.removeAt(i);
    }
  }
  return trimmedRecords;
}

List<TimingRecord> extraRunnerTime(
    int offBy, List<TimingRecord> records, int numTimes, String finishTime) {
  if (offBy < 1) {
    offBy = 1;
  }
  int correcttedNumTimes =
      numTimes - offBy; // Placeholder for actual length input

  for (int i = 1; i <= offBy; i++) {
    final lastOffByRunner = records[records.length - i];
    if (lastOffByRunner.type == RecordType.runnerTime) {
      lastOffByRunner.previousPlace = lastOffByRunner.place;
      lastOffByRunner.place = null;
    }
  }

  final color = AppColors.redColor;
  records = updateTextColor(color, records,
      conflict:
          ConflictDetails(type: RecordType.extraRunner, isResolved: false),
      confirmed: true);

  records.add(TimingRecord(
    elapsedTime: finishTime,
    type: RecordType.extraRunner,
    textColor: color,
    place: correcttedNumTimes,
    conflict: ConflictDetails(
      type: RecordType.extraRunner,
      isResolved: false,
      data: {
        'offBy': offBy,
        'numTimes': correcttedNumTimes,
      },
    ),
  ));
  return records;
}

List<TimingRecord> missingRunnerTime(
    int offBy, List<TimingRecord> records, int numTimes, String finishTime,
    {bool addMissingRunner = true}) {
  int correcttedNumTimes =
      numTimes + offBy; // Placeholder for actual length input

  final color = AppColors.redColor;
  records = updateTextColor(color, records,
      conflict:
          ConflictDetails(type: RecordType.missingRunner, isResolved: false),
      confirmed: true);

  if (addMissingRunner) {
    for (int i = 1; i <= offBy; i++) {
      records.add(TimingRecord(
        elapsedTime: 'TBD',
        type: RecordType.runnerTime,
        textColor: color,
        place: numTimes + i,
        conflict: ConflictDetails(
          type: RecordType.missingRunner,
          isResolved: false,
        ),
      ));
    }
  } else {
    correcttedNumTimes -= offBy;
  }

  records.add(TimingRecord(
    elapsedTime: finishTime,
    type: RecordType.missingRunner,
    textColor: color,
    place: correcttedNumTimes,
    conflict: ConflictDetails(
      type: RecordType.missingRunner,
      isResolved: false,
      data: {
        'offBy': offBy,
        'numTimes': correcttedNumTimes,
      },
    ),
  ));
  return records;
}

List<RunnerRecord> getConflictingRecords(
  List<TimingRecord> records,
  List<RunnerRecord> runnerRecords,
) {
  int lastConfirmedIndexBeforeConflict = -1;
  for (int i = 0; i < records.length; i++) {
    final record = records[i];
    if ((record.type != RecordType.runnerTime && record.conflict == null) ||
        record.conflict != null) {
      lastConfirmedIndexBeforeConflict = i - 1;
      break;
    }
  }
  final lastConfirmedPlaceBeforeConflict =
      lastConfirmedIndexBeforeConflict == -1
          ? 0
          : records[lastConfirmedIndexBeforeConflict].place ?? 0;
  final lastConflict = records.lastWhere((record) => record.conflict != null,
      orElse: () => records.last);
  return runnerRecords.sublist(lastConfirmedPlaceBeforeConflict,
      lastConflict.conflict!.data!['numTimes'] - 1 ?? runnerRecords.length);
}

// Timing Operations
Future<List<TimingRecord>> syncBibData(int runnerRecordsLength,
    List<TimingRecord> records, String finishTime, BuildContext context) async {
  final numberOfRunnerTimes = getNumberOfTimes(records);
  debugPrint('Number of runner times: $numberOfRunnerTimes');
  if (numberOfRunnerTimes != runnerRecordsLength) {
    debugPrint(
        'Runner records length: $runnerRecordsLength, Number of runner times: $numberOfRunnerTimes');
    await _handleTimingDiscrepancy(
        runnerRecordsLength, records, numberOfRunnerTimes, finishTime, context);
  } else {
    debugPrint(
        'Runner records length: $runnerRecordsLength, Number of runner times: $numberOfRunnerTimes');
    records = confirmRunnerNumber(records, numberOfRunnerTimes, finishTime);
  }
  debugPrint('');
  debugPrint(records.toString());
  debugPrint('');
  return records;
}

Future<void> _handleTimingDiscrepancy(
    int runnerRecordsLength,
    List<TimingRecord> records,
    int numberOfRunnerTimes,
    String finishTime,
    BuildContext context) async {
  final difference = runnerRecordsLength - numberOfRunnerTimes;
  if (difference > 0) {
    missingRunnerTime(difference, records, numberOfRunnerTimes, finishTime);
  } else {
    final numConfirmedRunners = records
        .where((r) => r.type == RecordType.runnerTime && r.isConfirmed == true)
        .length;

    if (numConfirmedRunners > runnerRecordsLength) {
      DialogUtils.showErrorDialog(context,
          message:
              'Cannot load bib numbers: more confirmed runners than loaded bib numbers.');
      return;
    }
    extraRunnerTime(-difference, records, numberOfRunnerTimes, finishTime);
  }
}

// Timing Utilities
int getNumberOfTimes(records) {
  return max(
      0,
      records.fold<int>(0, (int count, record) {
        if (record.type == RecordType.runnerTime) return count + 1;
        if (record.type == RecordType.extraRunner) return count - 1;
        return count;
      }));
}
