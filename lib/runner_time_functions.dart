import 'package:flutter/material.dart';
import 'dart:math';
import 'utils/app_colors.dart';
import 'utils/dialog_utils.dart';

dynamic updateTextColor(Color? color, records, {bool confirmed = false, String? conflict, endIndex}) {
  if (endIndex != null && endIndex < records.length && records.isNotEmpty) {
    records = records.sublist(0, endIndex);
  }
  for (int i = records.length - 1; i >= 0; i--) {
    if (records[i]['type'] != 'runner_time') {
      break;
    }
    records[i]['text_color'] = color;
    if (confirmed == true) {
      records[i]['is_confirmed'] = true;
      records[i]['conflict'] = conflict;
    }
    else {
      records[i]['is_confirmed'] = false;
      records[i]['conflict'] = null;
    }
  }
  return records;
}

dynamic confirmRunnerNumber(records, numTimes, String finishTime) {
  final color = Colors.green;
  records = updateTextColor(color, records,confirmed: true);

  records = deleteConfirmedRecordsBeforeIndexUntilConflict(records, records.length - 1);

  records.add({
      'finish_time': finishTime,
      'type': 'confirm_runner_number',
      'text_color': color,
      'numTimes': numTimes,
    });
  return records;
}

dynamic deleteConfirmedRecordsBeforeIndexUntilConflict(records, int recordIndex) {
  print(recordIndex);
  if (recordIndex < 0 || recordIndex >= records.length) {
    return;
  }
  final trimmedRecords = records.sublist(0, recordIndex + 1);
  for (int i = trimmedRecords.length - 1; i >= 0; i--) {
    if (trimmedRecords[i]['type'] != 'runner_time' && trimmedRecords[i]['type'] != 'confirm_runner_number') {
      break;
    }
    if (trimmedRecords[i]['type'] != 'runner_time' && trimmedRecords[i]['type'] == 'confirm_runner_number') {
      records.removeAt(i);
    }
  }
  return records;
}

dynamic extraRunnerTime(offBy, records, numTimes, String finishTime) {
  if (offBy < 1) {
    offBy = 1;
  }
  int correcttedNumTimes = numTimes - offBy; // Placeholder for actual length input

  for (int i = 1; i <= offBy; i++) {
    final lastOffByRunner = records[records.length - i];
    if (lastOffByRunner['type'] == 'runner_time') {
      lastOffByRunner['previous_place'] = lastOffByRunner['place'];
      lastOffByRunner['place'] = '';
    }
  }

  final color = AppColors.redColor;
  records = updateTextColor(color, records, conflict: 'extra_runner_time', confirmed: false);

  records.add({
    'finish_time': finishTime,
    'type': 'extra_runner_time',
    'text_color': color,
    'numTimes': correcttedNumTimes,
    'offBy': offBy,
  });
  return records;
}

dynamic missingRunnerTime(offBy, records, numTimes, String finishTime) {
  int correcttedNumTimes = numTimes + offBy; // Placeholder for actual length input
  
  final color = AppColors.redColor;
  records = updateTextColor(color, records, conflict: 'missing_runner_time', confirmed: false);

    for (int i = 1; i <= offBy; i++) {
      records.add({
        'finish_time': 'TBD',
        'bib_number': null,
        'type': 'runner_time',
        'is_confirmed': false,
        'conflict': 'missing_runner_time',
        'text_color': color,
        'place': numTimes + i,
      });
    }

    records.add({
      'finish_time': finishTime,
      'type': 'missing_runner_time',
      'text_color': color,
      'numTimes': correcttedNumTimes,
      'offBy': offBy,
    });
  return records;
}

List<dynamic> getConflictingRecords(
  List<dynamic> records,
  int conflictIndex,
) {
  final firstConflictIndex = records.sublist(0, conflictIndex).indexWhere(
      (record) => record['type'] == 'runner_time' && record['is_confirmed'] == false,
    );
  
  return firstConflictIndex == -1 ? [] : 
    records.sublist(firstConflictIndex, conflictIndex);
}

// Timing Operations
Future<List<Map<String, dynamic>>> syncBibData(int runnerRecordsLength, List<Map<String, dynamic>> records, String finishTime, BuildContext context) async {
  final numberOfRunnerTimes = getNumberOfTimes(records);
  print('Number of runner times: $numberOfRunnerTimes');
  if (numberOfRunnerTimes != runnerRecordsLength) {
    print('Runner records length: $runnerRecordsLength, Number of runner times: $numberOfRunnerTimes');
    await _handleTimingDiscrepancy(runnerRecordsLength, records, numberOfRunnerTimes, finishTime, context);
  } else {
    print('Runner records length: $runnerRecordsLength, Number of runner times: $numberOfRunnerTimes');
    records = await confirmRunnerNumber(records, numberOfRunnerTimes, finishTime);
  }
  print('');
  print(records);
  print('');
  return records;
}

Future<void> _handleTimingDiscrepancy(int runnerRecordsLength, List<Map<String, dynamic>> records, int numberOfRunnerTimes, String finishTime, BuildContext context) async {
  final difference = runnerRecordsLength - numberOfRunnerTimes;
  if (difference > 0) {
    missingRunnerTime(difference, records, numberOfRunnerTimes, finishTime);
  } else {
    final numConfirmedRunners = records.where((r) => 
      r['type'] == 'runner_time' && r['is_confirmed'] == true
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
  return max(0, records.fold<int>(0, (int count, Map<String, dynamic> record) {
    if (record['type'] == 'runner_time') return count + 1;
    if (record['type'] == 'extra_runner_time') return count - 1;
    return count;
  }));
}