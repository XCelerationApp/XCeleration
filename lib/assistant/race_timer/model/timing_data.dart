import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../utils/enums.dart';
import 'timing_record.dart';

class TimingData with ChangeNotifier {
  List<TimingRecord> _records = [];
  DateTime? _startTime;
  Duration? _endTime;
  bool _raceStopped = true;

  List<TimingRecord> get records => _records;
  set records(List<TimingRecord> value) {
    _records = value;
    notifyListeners();
  }

  DateTime? get startTime => _startTime;
  Duration? get endTime => _endTime;
  bool get raceStopped => _raceStopped;
  set raceStopped(bool value) {
    _raceStopped = value;
    notifyListeners();
  }

  void addRecord(String elapsedTime,
      {String? runnerNumber,
      bool isConfirmed = false,
      ConflictDetails? conflict,
      RecordType type = RecordType.runnerTime,
      int place = 0,
      Color? textColor}) {
    _records.add(TimingRecord(
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

  void updateRecord(int runnerId,
      {String? runnerNumber,
      bool? isConfirmed,
      ConflictDetails? conflict,
      RecordType? type,
      int? place,
      int? previousPlace,
      Color? textColor}) {
    final index = _records.indexWhere((record) => record.runnerId == runnerId);
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

  void removeRecord(int runnerId) {
    _records.removeWhere((record) => record.runnerId == runnerId);
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
    List<String> recordMaps = _records
        .map((record) => (record.type == RecordType.runnerTime)
            ? record.elapsedTime
            : (record.type == RecordType.confirmRunner)
                ? '${record.type.toString()} ${record.place} ${record.elapsedTime}'
                : '${record.type.toString()} ${record.conflict?.data?["offBy"]} ${record.elapsedTime}')
        .toList();
    return recordMaps.join(',');
  }

  void decode(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);

    if (data.containsKey('records') && data['records'] is List) {
      _records = (data['records'] as List)
          .map((recordMap) => TimingRecord.fromMap(recordMap))
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
