import 'package:flutter/material.dart';
// import 'package:race_timing_app/utils/time_formatter.dart';
import 'dart:convert';

import 'package:race_timing_app/utils/time_formatter.dart';

class TimingData with ChangeNotifier {
  List<Map<String, dynamic>> _records = [];
  // List<String> _bibs = [];
  List<TextEditingController> _controllers = [];
  DateTime? _startTime;
  Duration? _endTime;

  //  List<TextEditingController> controllers = [];

  // TimingData() {
  //   records = _records; // Initialize in constructor
  //   startTime = _startTime; // Initialize in constructor
  //   controllers = _controllers; // Initialize in constructor
  // }


  // set startTime(DateTime? value) {
  //   _startTime = value;
  // }

  List<Map<String, dynamic>> get records => _records;
  DateTime? get startTime => _startTime;
  Duration? get endTime => _endTime;
  // List<String> get bibs => _bibs;
  List<TextEditingController> get controllers => _controllers;
  // List<Map<String, dynamic>> records; // Add this line
  // DateTime? startTime; // Add this line
  // List<TextEditingController> controllers; // Add this line

  void addRecord(Map<String, dynamic> record) {
    _records.add(record);
    notifyListeners();
  }
  
  void addController(TextEditingController controller) {
    _controllers.add(controller);
    notifyListeners();
  }

  void insertRecord(int index, Map<String, dynamic> record) {
    _records.insert(index, record);
    notifyListeners();
  }

  void insertController(int index, TextEditingController controller) {
    _controllers.insert(index, controller);
    notifyListeners();
  }

  void changeStartTime(DateTime? time) {
    _startTime = time;
    notifyListeners();
  }

  // void setBibs(List<String> bibs) {
  //   _bibs = bibs;
  //   notifyListeners();
  // }

  void changeEndTime(Duration? time) {
    _endTime = time;
    notifyListeners();
  }

  String QREncode() {
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
    _controllers.clear();
    _startTime = null;
    _endTime = null;
    // _bibs.clear();
    notifyListeners();
  }
}