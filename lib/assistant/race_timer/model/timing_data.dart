import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

class TimingData with ChangeNotifier {
  List<TimingDatum> _records = [];
  DateTime? _startTime;
  Duration? _endTime;
  bool _raceStopped = true;

  List<TimingDatum> get records => _records;
  set records(List<TimingDatum> value) {
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

  void addRecord(TimingDatum record) {
    _records.add(record);
    notifyListeners();
  }

  void updateRecord(TimingDatum record, int index) {
    if (index >= 0) {
      _records[index] = record;
      notifyListeners();
    }
  }

  void removeRecord(int index) {
    _records.removeAt(index);
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

  // Helper methods
  int getNumberOfConfirmedTimes() {
    return _records.where((record) => record.conflict?.type == ConflictType.confirmRunner).length;
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
