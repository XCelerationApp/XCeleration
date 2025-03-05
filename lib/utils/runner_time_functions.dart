import 'package:flutter/material.dart';
import 'dart:math';
import '../core/theme/app_colors.dart';
import '../core/components/dialog_utils.dart';
import 'enums.dart';
import '../assistant/race_timer/timing_screen/model/runner_record.dart';
import 'package:uuid/uuid.dart';

Uuid _uuid = Uuid();

List<RunnerRecord> updateTextColor(Color? color, List<RunnerRecord> records, {bool confirmed = false, ConflictDetails? conflict, endIndex}) {
  if (endIndex != null && endIndex < records.length && records.isNotEmpty) {
    records = records.sublist(0, endIndex);
  }
  for (int i = records.length - 1; i >= 0; i--) {
    if (records[i].type != RecordType.runnerTime) {
      break;
    }
    records[i].textColor = color;
    if (confirmed == true) {
      // records[i].isConfirmed = true;
      // records[i].conflict = conflict;
      records[i] = records[i].copyWith(conflict: conflict, isConfirmed: true, textColor: color);
    }
    else {
      records[i] = records[i].copyWith(conflict: null, isConfirmed: false, textColor: color);
    }
  }
  return records;
}

List<RunnerRecord> confirmRunnerNumber(records, numTimes, String finishTime) {
  final color = Colors.green;
  records = updateTextColor(color, records,confirmed: true);

  records = deleteConfirmedRecordsBeforeIndexUntilConflict(records, records.length - 1);

  records.add(RunnerRecord(
      id: _uuid.v4(),
      elapsedTime: finishTime,
      type: RecordType.confirmRunner,
      textColor: color,
      place: numTimes,
    ));

  return records;
}

List<RunnerRecord> deleteConfirmedRecordsBeforeIndexUntilConflict(List<RunnerRecord> records, int recordIndex) {
  debugPrint(recordIndex.toString());
  if (recordIndex < 0 || recordIndex >= records.length) {
    return [];
  }
  final trimmedRecords = records.sublist(0, recordIndex + 1);
  for (int i = trimmedRecords.length - 1; i >= 0; i--) {
    if (trimmedRecords[i].type != RecordType.runnerTime && trimmedRecords[i].type != RecordType.confirmRunner) {
      break;
    }
    if (trimmedRecords[i].type != RecordType.runnerTime && trimmedRecords[i].type == RecordType.confirmRunner) {
      records.removeAt(i);
    }
  }
  return records;
}

List<RunnerRecord> extraRunnerTime(int offBy, List<RunnerRecord> records, int numTimes, String finishTime) {
  if (offBy < 1) {
    offBy = 1;
  }
  int correcttedNumTimes = numTimes - offBy; // Placeholder for actual length input

  for (int i = 1; i <= offBy; i++) {
    final lastOffByRunner = records[records.length - i];
    if (lastOffByRunner.type == RecordType.runnerTime) {
      lastOffByRunner.previousPlace = lastOffByRunner.place;
      lastOffByRunner.place = null;
    }
  }

  final color = AppColors.redColor;
  records = updateTextColor(color, records, conflict: ConflictDetails(type: RecordType.extraRunner, isResolved: false), confirmed: true);

  records.add(RunnerRecord(
    id: _uuid.v4(),
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
  // records.add({
  //   'finish_time': finishTime,
  //   'type': RecordType.extraRunner.toString(),
  //   'text_color': color,
  //   'numTimes': correcttedNumTimes,
  //   'offBy': offBy,
  // });
  return records;
}

dynamic missingRunnerTime(offBy, records, numTimes, String finishTime) {
  int correcttedNumTimes = numTimes + offBy; // Placeholder for actual length input
  
  final color = AppColors.redColor;
  records = updateTextColor(color, records, conflict: ConflictDetails(type: RecordType.missingRunner, isResolved: false), confirmed: true);

    for (int i = 1; i <= offBy; i++) {
      records.add(RunnerRecord(
        id: _uuid.v4(),
        elapsedTime: 'TBD',
        type: RecordType.runnerTime,
        textColor: color,
        place: numTimes + i,
        conflict: ConflictDetails(
          type: RecordType.missingRunner,
          isResolved: false,
        ),
      ));
      // records.add({
      //   'finish_time': 'TBD',
      //   'bib_number': null,
      //   'type': RecordType.runnerTime.toString(),
      //   'is_confirmed': true,
      //   'conflict': 'missing_runner_time',
      //   'text_color': color,
      //   'place': numTimes + i,
      // });
    }

    // records.add({
    //   'finish_time': finishTime,
    //   'type': RecordType.missingRunner.toString(),
    //   'text_color': color,
    //   'numTimes': correcttedNumTimes,
    //   'offBy': offBy,
    // });
    records.add(RunnerRecord(
      id: _uuid.v4(),
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

List<dynamic> getConflictingRecords(
  List<dynamic> records,
  int conflictIndex,
) {
  final firstConflictIndex = records.sublist(0, conflictIndex).indexWhere(
      (record) => record['type'] == RecordType.runnerTime.toString() && record['conflict'] != null,
    );
  
  return firstConflictIndex == -1 ? [] : 
    records.sublist(firstConflictIndex, conflictIndex);
}

// Timing Operations
Future<List<RunnerRecord>> syncBibData(int runnerRecordsLength, List<RunnerRecord> records, String finishTime, BuildContext context) async {
  final numberOfRunnerTimes = getNumberOfTimes(records);
  debugPrint('Number of runner times: $numberOfRunnerTimes');
  if (numberOfRunnerTimes != runnerRecordsLength) {
    debugPrint('Runner records length: $runnerRecordsLength, Number of runner times: $numberOfRunnerTimes');
    await _handleTimingDiscrepancy(runnerRecordsLength, records, numberOfRunnerTimes, finishTime, context);
  } else {
    debugPrint('Runner records length: $runnerRecordsLength, Number of runner times: $numberOfRunnerTimes');
    records = confirmRunnerNumber(records, numberOfRunnerTimes, finishTime);
  }
  debugPrint('');
  debugPrint(records.toString());
  debugPrint('');
  return records;
}

Future<void> _handleTimingDiscrepancy(int runnerRecordsLength, List<RunnerRecord> records, int numberOfRunnerTimes, String finishTime, BuildContext context) async {
  final difference = runnerRecordsLength - numberOfRunnerTimes;
  if (difference > 0) {
    missingRunnerTime(difference, records, numberOfRunnerTimes, finishTime);
  } else {
    final numConfirmedRunners = records.where((r) => 
      r.type == RecordType.runnerTime && r.isConfirmed == true
    ).length;
    
    if (numConfirmedRunners > runnerRecordsLength) {
      DialogUtils.showErrorDialog(context, 
        message: 'Cannot load bib numbers: more confirmed runners than loaded bib numbers.');
      return;
    }
    extraRunnerTime(-difference, records, numberOfRunnerTimes, finishTime);
  }
}

// Timing Utilities
int getNumberOfTimes(records) {
  return max(0, records.fold<int>(0, (int count, record) {
    if (record.type == RecordType.runnerTime) return count + 1;
    if (record.type == RecordType.extraRunner) return count - 1;
    return count;
  }));
}