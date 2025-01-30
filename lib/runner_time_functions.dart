import 'package:flutter/material.dart';
import '../constants.dart';

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

dynamic confirmRunnerNumber(records, numTimes, finishTime) {
  final color = AppColors.navBarTextColor;
  records = updateTextColor(AppColors.navBarTextColor, records,confirmed: true);

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

dynamic extraRunnerTime(offBy, records, numTimes, finishTime) {
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

dynamic missingRunnerTime(offBy, records, numTimes, finishTime) {
  int correcttedNumTimes = numTimes + offBy; // Placeholder for actual length input
  
  final color = AppColors.redColor;
  records = updateTextColor(color, records, conflict: 'missing_runner_time', confirmed: false);

    for (int i = 1; i <= offBy; i++) {
      records.add({
        'finish_time': 'TBD',
        'bib_number': null,
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