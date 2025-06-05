import 'package:flutter/material.dart';
import 'package:xceleration/coach/merge_conflicts/model/timing_data.dart';
import 'package:xceleration/core/utils/logger.dart';

import '../assistant/race_timer/model/timing_record.dart';
import '../coach/race_screen/widgets/runner_record.dart';
import '../core/components/dialog_utils.dart';
import '../utils/enums.dart';
import 'database_helper.dart';
import 'time_formatter.dart';
import 'runner_time_functions.dart';

/// Decodes a string of race times into TimingData
Future<TimingData> decodeRaceTimesString(String encodedData) async {
  final condensedRecords = encodedData.split(',');
  List<TimingRecord> records = [];
  int place = 0;
  
  for (var recordString in condensedRecords) {
    if (_isRunnerTime(recordString)) {
      place++;
      records.add(TimingRecord(
        elapsedTime: recordString,
        type: RecordType.runnerTime,
        place: place,
      ));
      Logger.d('Added runner time record at place $place: $recordString');
    } else if (recordString.startsWith('RecordType.')) {
      final conflict = _parseConflict(recordString);
      if (conflict != null) {
        records = _handleConflict(conflict, records, place);
        place = records.last.place!;
      }
    }
  }
  
  _validatePlaces(records);
  
  return TimingData(
    endTime: records.last.elapsedTime, 
    records: records, 
    startTime: null
  );
}

/// Processes encoded timing data and validates it
Future<TimingData?> processEncodedTimingData(
    String data, BuildContext context) async {
  try {
    final TimingData timingData = await decodeRaceTimesString(data);
    Logger.d(timingData.toString());
    Logger.d(
        'Has conflicts: ${timingData.records.any((record) => record.conflict != null)}');
    for (var record in timingData.records) {
      Logger.d(record.toString());
    }
    if (!context.mounted) return null;
    if (isValidTimingData(timingData)) {
      return timingData;
    } else {
      DialogUtils.showErrorDialog(context,
          message: 'Error: Invalid Timing Data');
      return null;
    }
  } catch (e) {
    DialogUtils.showErrorDialog(context, message: 'Error processing data: $e');
    rethrow;
  }
}

/// Decodes bib records from a string
Future<List<RunnerRecord>> decodeBibRecordsString(
    String encodedBibRecords, int raceId) async {
  final List<String> bibNumbers = encodedBibRecords.split(',');
  List<RunnerRecord> bibRecords = [];
  for (var bibNumber in bibNumbers) {
    if (bibNumber.isNotEmpty) {
      final runner =
          await DatabaseHelper.instance.getRaceRunnerByBib(raceId, bibNumber);
      if (runner == null) {
        bibRecords.add(RunnerRecord(
            runnerId: -1,
            raceId: -1,
            bib: bibNumber,
            name: 'Unknown',
            grade: 0,
            school: 'Unknown',
            error: 'Runner not found'));
      } else {
        bibRecords.add(runner);
      }
    }
  }
  return bibRecords;
}

/// Processes encoded bib record data and validates it
Future<List<RunnerRecord>> processEncodedBibRecordsData(
    String data, BuildContext context, int raceId) async {
  try {
    final bibData = await decodeBibRecordsString(data, raceId);
    Logger.d(bibData.toString());
    for (var bibRecord in bibData) {
      Logger.d(bibRecord.toString());
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

/// Decodes encoded runner data
Future<List<RunnerRecord>?> decodeEncodedRunners(
    String data, BuildContext context) async {
  try {
    final List<String> encodedRunners = data.split(' ');
    List<RunnerRecord> decodedRunners = [];
    for (var runner in encodedRunners) {
      if (runner.isNotEmpty) {
        List<String> runnerValues = runner.split(',');
        if (runnerValues.length == 4) {
          decodedRunners.add(RunnerRecord(
            raceId: -1,
            bib: Uri.decodeComponent(runnerValues[0]),
            name: Uri.decodeComponent(runnerValues[1]),
            school: Uri.decodeComponent(runnerValues[2]),
            grade: int.parse(Uri.decodeComponent(runnerValues[3])),
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

// Helper methods
bool _isRunnerTime(String recordString) {
  return recordString == 'TBD' || TimeFormatter.loadDurationFromString(recordString) != null;
}

ConflictInfo? _parseConflict(String recordString) {
  final parts = recordString.split(' ');
  if (parts.length < 3) return null;
  
  final typeString = parts[0];
  final offBy = int.tryParse(parts[1]);
  final finishTime = parts[2];
  
  final typeMap = {
    RecordType.confirmRunner.toString(): RecordType.confirmRunner,
    RecordType.missingRunner.toString(): RecordType.missingRunner,
    RecordType.extraRunner.toString(): RecordType.extraRunner,
  };
  
  final type = typeMap[typeString];
  
  return (type != null && offBy != null) 
    ? ConflictInfo(type: type, offBy: offBy, finishTime: finishTime)
    : null;
}

List<TimingRecord> _handleConflict(ConflictInfo conflict, List<TimingRecord> records, int place) {
  switch (conflict.type) {
    case RecordType.missingRunner:
      return missingRunnerTime(conflict.offBy, records, place, conflict.finishTime, addMissingRunner: false);
    case RecordType.extraRunner:
      return extraRunnerTime(conflict.offBy, records, place, conflict.finishTime);
    case RecordType.confirmRunner:
      return confirmRunnerNumber(records, place, conflict.finishTime);
    default:
      return records;
  }
}

void _validatePlaces(List<TimingRecord> records) {
  final recordPlaces = records.map((r) => r.place).whereType<int>().toList();
  if (recordPlaces.isEmpty) return;
  
  final maxPlace = recordPlaces.reduce((a, b) => a > b ? a : b);
  final expectedPlaces = Set<int>.from(List.generate(maxPlace, (i) => i + 1));
  final actualPlaces = Set<int>.from(recordPlaces);
  final missingPlaces = expectedPlaces.difference(actualPlaces);
  
  if (missingPlaces.isNotEmpty) {
    Logger.e('decodeRaceTimesString: Missing places after decoding: $missingPlaces');
    Logger.e('decodeRaceTimesString: All decoded record places: $recordPlaces');
  }
}

/// Helper class for conflict parsing
class ConflictInfo {
  final RecordType type;
  final int offBy;
  final String finishTime;
  
  ConflictInfo({required this.type, required this.offBy, required this.finishTime});
}

/// Validates timing data
bool isValidTimingData(TimingData data) {
  return data.records.isNotEmpty && data.endTime != '';
}

/// Validates bib data
bool isValidBibData(RunnerRecord data) {
  return data.error == 'Runner not found' ||
      data.bib.isNotEmpty &&
          data.name.isNotEmpty &&
          data.grade > 0 &&
          data.school.isNotEmpty;
}
