import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../utils/enums.dart';

import '../utils/time_formatter.dart';
import '../assistant/race_timer/timing_screen/model/runner_record.dart';

class TimingData with ChangeNotifier {
  List<RunnerRecord> _records = [];
  DateTime? _startTime;
  Duration? _endTime;
  final _uuid = const Uuid();

  List<RunnerRecord> get records => _records;
  set records(List<RunnerRecord> value) {
    _records = value;
    notifyListeners();
  }
  DateTime? get startTime => _startTime;
  Duration? get endTime => _endTime;

  void addRecord(String elapsedTime, {int? runnerNumber, bool isConfirmed = false, ConflictDetails? conflict, RecordType type = RecordType.runnerTime, int place = 0, Color? textColor}) {
    _records.add(RunnerRecord(
      id: _uuid.v4(),
      elapsedTime: elapsedTime,
      runnerNumber: runnerNumber,
      isConfirmed: isConfirmed,
      conflict: conflict,
      type: type,
      place: place,
      textColor: textColor,
    ));
    notifyListeners();
  }

  void updateRecord(String id, {int? runnerNumber, bool? isConfirmed, ConflictDetails? conflict, RecordType? type, int? place, int? previousPlace, Color? textColor}) {
    final index = _records.indexWhere((record) => record.id == id);
    if (index >= 0) {
      _records[index] = _records[index].copyWith(
        runnerNumber: runnerNumber,
        isConfirmed: isConfirmed,
        conflict: conflict,
        type: type,
        place: place,
        previousPlace: previousPlace,
        textColor: textColor,
      );
      notifyListeners();
    }
  }

  void removeRecord(String id) {
    _records.removeWhere((record) => record.id == id);
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
    List<Map<String, dynamic>> recordMaps = _records.map((record) => record.toMap()).toList();
    return jsonEncode({
      'records': recordMaps,
      'end_time': _endTime?.inMilliseconds,
    });
  }

  void decode(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    
    if (data.containsKey('records') && data['records'] is List) {
      _records = (data['records'] as List)
          .map((recordMap) => RunnerRecord.fromMap(recordMap))
          .toList();
    }
    
    if (data.containsKey('end_time') && data['end_time'] != null) {
      _endTime = Duration(milliseconds: data['end_time']);
    }
    
    notifyListeners();
  }

  // Helper methods
  int getNumberOfConfirmedTimes() {
    return _records.where((record) => record.isConfirmed).length;
  }
  
  int getNumberOfTimes() {
    return _records.length;
  }

  void clearRecords() {
    _records.clear();
    _startTime = null;
    _endTime = null;
    notifyListeners();
  }
}