import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:race_timing_app/utils/time_formatter.dart';

class TimingData with ChangeNotifier {
  List<Map<String, dynamic>> _records = [];
  DateTime? _startTime;
  Duration? _endTime;

  List<Map<String, dynamic>> get records => _records;
  set records(List<Map<String, dynamic>> value) {
    _records = value;
    notifyListeners();
  }
  DateTime? get startTime => _startTime;
  Duration? get endTime => _endTime;

  void addRecord(Map<String, dynamic> record) {
    _records.add(record);
    notifyListeners();
  }

  void insertRecord(int index, Map<String, dynamic> record) {
    _records.insert(index, record);
    notifyListeners();
  }

  void changeStartTime(DateTime? time) {
    _startTime = time;
    notifyListeners();
  }

  void changeEndTime(Duration? time) {
    _endTime = time;
    notifyListeners();
  }

  String encode() {
    List<String> condensedRecords = [];
    for (var record in _records) {
      if (record['is_runner'] == true) {
        final time = record['finish_time'];
        condensedRecords.add('$time');
      } else {
        final offBy = record['type'] == 'confirm_runner_number' ? 'null' : record['offBy'].toString();
        condensedRecords.add('${record['type']} $offBy ${record['finish_time']}');
      }
    }
    return jsonEncode([condensedRecords, formatDuration(_endTime!)]);
  }

  void clearRecords() {
    _records.clear();
    _startTime = null;
    _endTime = null;
    notifyListeners();
  }
}