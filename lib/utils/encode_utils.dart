import 'dart:convert';
import 'package:xcelerate/coach/merge_conflicts_screen/model/timing_data.dart';

import '../coach/race_screen/widgets/runner_record.dart';
import 'time_formatter.dart';
import '../core/components/dialog_utils.dart';
import 'runner_time_functions.dart';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import '../assistant/race_timer/timing_screen/model/timing_record.dart';
import '../utils/enums.dart';
import 'package:uuid/uuid.dart';

Uuid _uuid = Uuid();

decodeRaceTimesString(String encodedData) async {
  final decodedData = json.decode(encodedData);
  final startTime = null;
  final endTime = decodedData[1];
  final condensedRecords = decodedData[0];
  List<TimingRecord> records = [];
  int place = 0;
  Uuid uuid = Uuid();
  for (var recordString in condensedRecords) {
    if (loadDurationFromString(recordString) != null) {
      place++;
      records.add(TimingRecord(
        id: uuid.v4(),
        elapsedTime: recordString,
        type: RecordType.runnerTime,
        place: place
      ));
      // records.add({
      //   'finish_time': recordString,
      //   'type': 'runner_time',
      //   'is_confirmed': false,
      //   'place': place
      // });
    }
    else {
      final [type, offByString, finishTime] = recordString.split(' ');

      int? offBy = int.tryParse(offByString);
      if (offBy == null) {
        debugPrint('Failed to parse offBy: $offByString');
        continue;
      }

      if (type == 'confirm_runner_number'){
        records = confirmRunnerNumber(records, place - 1, finishTime);
      }
      else if (type == 'missing_runner_time'){
        records = await missingRunnerTime(offBy, records, place, finishTime);
        place += offBy;
      }
      else if (type == 'extra_runner_time'){
        records = extraRunnerTime(offBy, records, place, finishTime);
        place -= offBy;
      }
      else {
        debugPrint('Unknown type: $type, string: $recordString');
      }
    }
  }
  return TimingData(
    endTime: endTime,
    records: records,
    startTime: startTime
  );
}

Future<TimingData?> processEncodedTimingData(String data, BuildContext context) async {
  try {
    final timingData = await decodeRaceTimesString(data);
    debugPrint(timingData);
    for (var record in timingData['records']) {
      debugPrint(record);
    }
    if (!context.mounted) return null;
    if (isValidTimingData(timingData)) {
      return timingData;
    } else {
      DialogUtils.showErrorDialog(context, message: 'Error: Invalid Timing Data');
      return null;
    }
  } catch (e) {
    DialogUtils.showErrorDialog(context, message: 'Error processing data: $e');
    rethrow;
  }
}

bool isValidTimingData(TimingData data) {
  return data.records.isNotEmpty &&
    data.endTime != '';
}

Future<List<RunnerRecord>> decodeBibRecordsString(String encodedBibRecords, int raceId) async {
  final List<String> bibNumbers = encodedBibRecords.split(' ');
  List<RunnerRecord> bibRecords = [];
  for (var bibNumber in bibNumbers) {
    if (bibNumber.isNotEmpty) {
      final runner = await DatabaseHelper.instance.getRaceRunnerByBib(raceId, bibNumber);
      if (runner == null) {
        bibRecords.add(RunnerRecord(
          runnerId: -1,
          raceId: -1,
          bib: bibNumber,
          name: 'Unknown',
          grade: 0,
          school: 'Unknown',
          error: 'Runner not found'
        ));
      }
      else {
        bibRecords.add(runner);
      }
    }
  }
  return bibRecords;
}

Future<List<RunnerRecord>> processEncodedBibRecordsData(String data, BuildContext context, int raceId) async {
  try {
    final bibData = await decodeBibRecordsString(data, raceId);
    debugPrint(bibData.toString());
    for (var bibRecord in bibData) {
      debugPrint(bibRecord.toString());
    }
    if (!context.mounted) return [];
    if (bibData.every((bibData) => isValidBibData(bibData))) {
      return bibData;
    } else {
      DialogUtils.showErrorDialog(context, message: 'Error: Invalid Bib Data');
      return [];
    }
  } catch (e) {
    DialogUtils.showErrorDialog(context, message: 'Error processing data: $e');
    rethrow;
  }
}

bool isValidBibData(RunnerRecord data) {
  return data.bib.isNotEmpty &&
    data.name.isNotEmpty &&
    data.grade > 0 &&
    data.school.isNotEmpty;
}