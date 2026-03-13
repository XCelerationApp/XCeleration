import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/coach/merge_conflicts/models/conflict_time.dart';

/// Complete UI state for a single timing record
class UIRecord with ChangeNotifier {
  final int? place;
  final RaceRunner? runner;
  final TextEditingController timeController;
  final bool
      isOriginallyTBD; // True if this position started as TBD (always editable)
  ConflictTime _conflictTime;

  String get time => timeController.text;
  ConflictTime get conflictTime => _conflictTime;
  String? get validationError => _conflictTime.validationError;

  set validationError(String? value) {
    if (_conflictTime.validationError != value) {
      _conflictTime = _conflictTime.copyWith(validationError: value);
      notifyListeners();
    }
  }

  UIRecord({
    required this.place,
    this.runner,
    required String initialTime,
    required this.isOriginallyTBD,
    String? validationError,
  })  : timeController = TextEditingController(text: initialTime),
        _conflictTime = ConflictTime(
          time: initialTime,
          isOriginallyTBD: isOriginallyTBD,
          validationError: validationError,
        );

  /// Update the conflict time state
  void updateConflictTime(ConflictTime newConflictTime) {
    _conflictTime = newConflictTime;
    timeController.text = newConflictTime.time;
    notifyListeners();
  }
}
