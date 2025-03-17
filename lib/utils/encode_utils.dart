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

Future<TimingData> decodeRaceTimesString(String encodedData) async {
  // final decodedData = encodedData.split(',');
  // final startTime = null;
  // final endTime = decodedData[1];
  final condensedRecords = encodedData.split(',');
  List<TimingRecord> records = [];
  int place = 0;
  for (var recordString in condensedRecords) {
    if (loadDurationFromString(recordString) != null || recordString == 'TBD') {
      place++;
      records.add(TimingRecord(
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

      if (type == RecordType.confirmRunner.toString()){
        records = confirmRunnerNumber(records, place - 1, finishTime);
      }
      else if (type == RecordType.missingRunner.toString()){
        records = missingRunnerTime(offBy, records, place, finishTime);
        place += offBy;
      }
      else if (type == RecordType.extraRunner.toString()){
        records = extraRunnerTime(offBy, records, place, finishTime);
        place -= offBy;
      }
      else {
        debugPrint('Unknown type: $type, string: $recordString');
      }
    }
  }
  return TimingData(
    endTime: records.last.elapsedTime,
    records: records,
    startTime: null
  );
}

Future<TimingData?> processEncodedTimingData(String data, BuildContext context) async {
  try {
    final TimingData timingData = await decodeRaceTimesString(data);
    debugPrint(timingData.toString());
    debugPrint('Has conflicts: ${timingData.records.any((record) => record.conflict != null)}');
    for (var record in timingData.records) {
      debugPrint(record.toString());
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

// Future<TimingData> combineRunnerRecordsWithTimingData(TimingData timingData, List<RunnerRecord> runnerRecords) async {
//   for (var runnerRecord in runnerRecords) {
//     timingData.mergeRunnerData(
//       runnerRecord,
      
//     );
//   }
//   return timingData;
// }

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
  print(data.toMap());
  return data.error == 'Runner not found' ||
    data.bib.isNotEmpty &&
    data.name.isNotEmpty &&
    data.grade > 0 &&
    data.school.isNotEmpty;
}

Future<List<RunnerRecord>?> decodeEncodedRunners(String data, BuildContext context) async {
  try {
    final List<String> encodedRunners = data.split(' ');
    List<RunnerRecord> decodedRunners = [];
    for (var runner in encodedRunners) {
      if (runner.isNotEmpty) {
        List<String> runnerValues = runner.split(',');
        if (runnerValues.length == 4) {
          decodedRunners.add(RunnerRecord(
            raceId: -1,
            bib: runnerValues[0],
            name: runnerValues[1],
            grade: int.parse(runnerValues[3]),
            school: runnerValues[2],
          ));
        }
      }
    }
    return decodedRunners;
  } catch (e) {
    DialogUtils.showErrorDialog(context, message: 'Error processing data: $e');
    return null;
  }
}