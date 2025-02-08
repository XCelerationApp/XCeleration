import 'dart:convert';
import 'time_formatter.dart';
import 'dialog_utils.dart';
import '../runner_time_functions.dart';
import 'package:flutter/material.dart';
import '../database_helper.dart';

decodeRaceTimesString(String encodedData) async {
  final decodedData = json.decode(encodedData);
  final startTime = null;
  final endTime = loadDurationFromString(decodedData[1]);
  final condensedRecords = decodedData[0];
  List<Map<String, dynamic>> records = [];
  int place = 0;
  for (var recordString in condensedRecords) {
    if (loadDurationFromString(recordString) != null) {
      place++;
      records.add({'finish_time': recordString, 'type': 'runner_time', 'is_confirmed': false, 'text_color': null, 'place': place});
    }
    else {
      final [type, offBy, finish_time] = recordString.split(' ');
      if (type == 'confirm_runner_number'){
        records = confirmRunnerNumber(records, place - 1, finish_time);
      }
      else if (type == 'missing_runner_time'){
        records = await missingRunnerTime(int.tryParse(offBy), records, place, finish_time);
        place += int.tryParse(offBy)!;
      }
      else if (type == 'extra_runner_time'){
        records = await extraRunnerTime(int.tryParse(offBy), records, place, finish_time);
        place -= int.tryParse(offBy)!;
      }
      else {
        print("Unknown type: $type, string: $recordString");
      }
    }
  }
  return {'endTime': endTime, 'records': records, 'startTime': startTime};
}

Future<Map<String, dynamic>?> processEncodedTimingData(String data, BuildContext context) async {
  try {
    final timingData = await decodeRaceTimesString(data);
    print(timingData);
    for (var record in timingData['records']) {
      print(record);
    }
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

bool isValidTimingData(Map<String, dynamic> data) {
  return data.isNotEmpty &&
          data.containsKey('records') &&
          data.containsKey('endTime') &&
          data['records'].isNotEmpty &&
          data['endTime'] != null;
}

Future<List<Map<String, dynamic>>> decodeBibRecordsString(String encodedData, int raceId) async {
  final condensedBibRecords = json.decode(encodedData);
  final List<String> bibNumbers = condensedBibRecords.split(' ');
  List<Map<String, dynamic>> bibRecords = [];
  for (var bibNumber in bibNumbers) {
    if (bibNumber.isNotEmpty) {
      final runner = await DatabaseHelper.instance.getRaceRunnerByBib(raceId, bibNumber);
      if (runner == null) {
        bibRecords.add({'bib_number': bibNumber, 'name': 'Unknown', 'grade': 'Unknown', 'school': 'Unknown', 'error': 'Runner not found'});
      }
      else {
        bibRecords.add({'bib_number': bibNumber, 'name': runner['full_name'], 'grade': runner['grade'], 'school': runner['school'], 'error': null});
      }
    }
  }
  return bibRecords;
}

Future<List<Map<String, dynamic>>> processEncodedBibRecordsData(String data, BuildContext context, int raceId) async {
  try {
    final bibData = await decodeBibRecordsString(data, raceId);
    print(bibData);
    for (var bibRecord in bibData) {
      print(bibRecord);
    }
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

bool isValidBibData(Map<String, dynamic> data) {
  return data.isNotEmpty &&
          data.containsKey('bib_number') &&
          data.containsKey('name') &&
          data.containsKey('grade') &&
          data.containsKey('school') &&
          data['bib_number'] != null &&
          data['bib_number'].isNotEmpty &&
          data['name'] != null &&
          data['name'].isNotEmpty &&
          data['grade'] != null &&
          data['grade'].isNotEmpty &&
          data['school'] != null &&
          data['school'].isNotEmpty;
}