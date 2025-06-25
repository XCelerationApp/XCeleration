import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart'
    show RunnerRecord;
import 'dart:math';
import '../core/theme/app_colors.dart';
import '../core/components/dialog_utils.dart';
import 'enums.dart';
import '../assistant/race_timer/model/timing_record.dart';

List<TimeRecord> updateTextColor(Color? color, List<TimeRecord> records,
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

List<TimeRecord> confirmTimes(
    List<TimeRecord> records, int numTimes, String finishTime) {
  final color = Colors.green;
  records = updateTextColor(color, records, confirmed: true);

  records = deleteConfirmedRecordsBeforeIndexUntilConflict(
      records, records.length - 1);

  records.add(TimeRecord(
    elapsedTime: finishTime,
    type: RecordType.confirmRunner,
    textColor: color,
    place: numTimes,
  ));

  return records;
}

List<TimeRecord> deleteConfirmedRecordsBeforeIndexUntilConflict(
    List<TimeRecord> records, int recordIndex) {
  Logger.d(recordIndex.toString());
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

List<TimeRecord> removeExtraTime(
    int offBy, List<TimeRecord> records, int numTimes, String finishTime) {
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
      conflict: ConflictDetails(type: RecordType.extraTime, isResolved: false),
      confirmed: true);

  records.add(TimeRecord(
    elapsedTime: finishTime,
    type: RecordType.extraTime,
    textColor: color,
    place: correcttedNumTimes,
    conflict: ConflictDetails(
      type: RecordType.extraTime,
      isResolved: false,
      data: {
        'offBy': offBy,
        'numTimes': correcttedNumTimes,
      },
    ),
  ));
  return records;
}

List<TimeRecord> addMissingTime(
    int offBy, List<TimeRecord> records, int numTimes, String finishTime,
    {bool addMissingRecords = true}) {
  int correcttedNumTimes =
      numTimes + offBy; // Placeholder for actual length input

  final color = AppColors.redColor;
  records = updateTextColor(color, records,
      conflict:
          ConflictDetails(type: RecordType.missingTime, isResolved: false),
      confirmed: true);

  if (addMissingRecords) {
    for (int i = 1; i <= offBy; i++) {
      records.add(TimeRecord(
        elapsedTime: 'TBD',
        type: RecordType.runnerTime,
        textColor: color,
        place: numTimes + i,
        conflict: ConflictDetails(
          type: RecordType.missingTime,
          isResolved: false,
        ),
      ));
    }
  } else {
    correcttedNumTimes -= offBy;
  }

  records.add(TimeRecord(
    elapsedTime: finishTime,
    type: RecordType.missingTime,
    textColor: color,
    place: correcttedNumTimes,
    conflict: ConflictDetails(
      type: RecordType.missingTime,
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
  List<TimeRecord> records,
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
Future<List<TimeRecord>> syncBibData(int runnerRecordsLength,
    List<TimeRecord> records, String finishTime, BuildContext context) async {
  final numberOfRunnerTimes = getNumberOfTimes(records);
  Logger.d('Number of runner times: $numberOfRunnerTimes');
  if (numberOfRunnerTimes != runnerRecordsLength) {
    Logger.d(
        'Runner records length: $runnerRecordsLength, Number of runner times: $numberOfRunnerTimes');
    await _handleTimingDiscrepancy(
        runnerRecordsLength, records, numberOfRunnerTimes, finishTime, context);
  } else {
    Logger.d(
        'Runner records length: $runnerRecordsLength, Number of runner times: $numberOfRunnerTimes');
    records = confirmTimes(records, numberOfRunnerTimes, finishTime);
  }
  Logger.d('');
  Logger.d(records.toString());
  Logger.d('');
  return records;
}

Future<void> _handleTimingDiscrepancy(
    int runnerRecordsLength,
    List<TimeRecord> records,
    int numberOfRunnerTimes,
    String finishTime,
    BuildContext context) async {
  final difference = runnerRecordsLength - numberOfRunnerTimes;
  if (difference > 0) {
    addMissingTime(difference, records, numberOfRunnerTimes, finishTime);
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
    removeExtraTime(-difference, records, numberOfRunnerTimes, finishTime);
  }
}

// Timing Utilities
int getNumberOfTimes(List<TimeRecord> records) {
  return max(
      0,
      records.fold<int>(0, (int count, record) {
        if (record.type == RecordType.runnerTime) return count + 1;
        if (record.type == RecordType.extraTime) {
          return count - record.conflict!.data!['offBy'] as int;
        }
        return count;
      }));
}
