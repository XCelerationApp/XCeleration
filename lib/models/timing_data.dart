import 'package:flutter/material.dart';

class TimingData with ChangeNotifier {
  final Map<int, List<Map<String, dynamic>>> _records = {};
  final Map<int, List<String>> _bibs = {};
  final Map<int, List<TextEditingController>> _controllers = {};
  final Map<int, DateTime?> _startTimes = {};
  final Map<int, Duration?> _endTimes = {};

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
  Map<int, Duration?> get endTime => _endTimes;
  Map<int, List<String>> get bibs => _bibs;
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

  void insertRecord(int index, Map<String, dynamic> record, int raceId) {
    if (_records[raceId] == null) {
      _records[raceId] = [];
    }
    _records[raceId]?.insert(index, record);
    notifyListeners();
  }

  void insertController(int index, TextEditingController controller, int raceId) {
    if (_controllers[raceId] == null) {
      _controllers[raceId] = [];
    }
    _controllers[raceId]?.insert(index, controller);
    notifyListeners();
  }

  void changeStartTime(DateTime? time, int raceId) {
    _startTimes[raceId] = time;
    notifyListeners();
  }

  void setBibs(List<String> bibs, int raceId) {
    _bibs[raceId] = bibs;
    notifyListeners();
  }

  void changeEndTime(Duration? time, int raceId) {
    _endTimes[raceId] = time;
    notifyListeners();
  }

  void clearRecords(int raceId) {
    _records[raceId]?.clear();
    _controllers[raceId]?.clear();
    _startTimes[raceId] = null;
    _endTimes[raceId] = null;
    _bibs[raceId]?.clear();
    notifyListeners();
  }
}