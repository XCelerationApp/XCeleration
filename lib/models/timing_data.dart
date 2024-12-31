import 'package:flutter/material.dart';

class TimingData with ChangeNotifier {
  final Map<int, List<Map<String, dynamic>>> _records = {};
  final Map<int, List<TextEditingController>> _controllers = {};
  Map<int, DateTime?> _startTimes = {};

  //  List<TextEditingController> controllers = [];

  // TimingData() {
  //   records = _records; // Initialize in constructor
  //   startTime = _startTime; // Initialize in constructor
  //   controllers = _controllers; // Initialize in constructor
  // }


  // set startTime(DateTime? value) {
  //   _startTime = value;
  // }

  Map<int, List<Map<String, dynamic>>> get records => _records;
  Map<int, DateTime?> get startTime => _startTimes;
  Map<int, List<TextEditingController>> get controllers => _controllers;
  // List<Map<String, dynamic>> records; // Add this line
  // DateTime? startTime; // Add this line
  // List<TextEditingController> controllers; // Add this line

  void addRecord(Map<String, dynamic> record, int raceId) {
    if (_records[raceId] == null) {
      _records[raceId] = [];
    }
    _records[raceId]?.add(record);
    notifyListeners();
  }
  
  void addController(TextEditingController controller, int raceId) {
    if (_controllers[raceId] == null) {
      _controllers[raceId] = [];
    }
    _controllers[raceId]?.add(controller);
    notifyListeners();
  }

  void changeStartTime(DateTime? time, int raceId) {
    _startTimes[raceId] = time;
    notifyListeners();
  }

  void clearRecords(int raceId) {
    _records[raceId]?.clear();
    _controllers[raceId]?.clear();
    _startTimes[raceId] = null;
    notifyListeners();
  }
}