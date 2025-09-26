import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../controller/merge_conflicts_controller.dart';

/// Represents the UI state for a single time entry in a conflict resolution UI
class ConflictTime {
  final String time;
  final bool isOriginallyTBD;
  final String? validationError;

  const ConflictTime({
    required this.time,
    required this.isOriginallyTBD,
    this.validationError,
  });

  ConflictTime copyWith({
    String? time,
    bool? isOriginallyTBD,
    String? validationError,
  }) {
    return ConflictTime(
      time: time ?? this.time,
      isOriginallyTBD: isOriginallyTBD ?? this.isOriginallyTBD,
      validationError: validationError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictTime &&
          runtimeType == other.runtimeType &&
          time == other.time &&
          isOriginallyTBD == other.isOriginallyTBD &&
          validationError == other.validationError;

  @override
  int get hashCode => Object.hash(time, isOriginallyTBD, validationError);
}

class TimingDataConverter {
  static List<UIChunk> convertToUIChunks(List<TimingChunk> timingChunks,
      List<RaceRunner> runners, MergeConflictsController? controller) {
    final runnersCopy = List<RaceRunner>.from(runners);
    final uiChunks = <UIChunk>[];
    int startingPlace = 1;
    for (int i = 0; i < timingChunks.length; i++) {
      final chunk = timingChunks[i];
      // Skip chunks without conflicts or chunks with conflicts but no timing data
      if (!chunk.hasConflict ||
          chunk.conflictRecord == null ||
          chunk.timingData.isEmpty) {
        continue;
      }

      final times = chunk.timingData.map((e) => e.time).toList();
      if (times.isEmpty) {
        continue; // Skip if no times (shouldn't happen due to earlier check)
      }

      final uiChunk = UIChunk(
        timingChunkHash: chunk.hashCode,
        times: times,
        allRunners: runnersCopy,
        conflictRecord: chunk.conflictRecord!,
        originalTimingData: chunk.timingData,
        startingPlace: startingPlace,
        controller: controller,
        chunkId: chunk.id,
      );
      uiChunks.add(uiChunk);
      startingPlace += uiChunk.records.length;
    }
    return uiChunks;
  }
}

class UIChunk {
  final int timingChunkHash;
  final int startingPlace;
  final String chunkId;
  final String startTime;
  final String endTime;
  final Conflict conflict;

  // UI records as the single source of truth for this chunk
  final List<UIRecord> records;

  // Reference to controller for updating underlying data
  final MergeConflictsController? controller;

  bool get hasConflict => true; // UIChunk always has a conflict record

  int? lastInsertedIndex;

  factory UIChunk({
    required int timingChunkHash,
    required List<String> times,
    required List<RaceRunner> allRunners,
    required TimingDatum conflictRecord,
    required List<TimingDatum> originalTimingData,
    required int startingPlace,
    MergeConflictsController? controller,
    required String chunkId,
  }) {
    if (times.isEmpty) {
      throw Exception('Times list cannot be empty');
    }

    final conflictType = conflictRecord.conflict!.type;
    final offBy = conflictRecord.conflict!.offBy;

    // Build records based on conflict type
    final records = <UIRecord>[];

    if (conflictType == ConflictType.extraTime) {
      // For extra time conflicts: match runners with times, extra times show "Extra Time"
      final runnersCount = times.length - offBy;

      for (int i = 0; i < times.length; i++) {
        final isExtra = i >= runnersCount;
        final runner = isExtra ? null : allRunners.removeAt(0);
        final place = isExtra ? null : i + startingPlace;

        records.add(UIRecord(
          place: place,
          runner: runner,
          initialTime: times[i],
          isOriginallyTBD: false, // Extra times are never originally TBD
          validationError: null,
        ));
      }
    } else if (conflictType == ConflictType.missingTime) {
      // For missing time conflicts: all positions have runners, some times are TBD
      final tbdCount = times.where((t) => t == 'TBD').length;

      // If no TBDs present, add them
      if (tbdCount == 0) {
        for (int i = 0; i < offBy; i++) {
          times.add('TBD');
        }
      }

      for (int i = 0; i < times.length; i++) {
        final runner = i < allRunners.length ? allRunners.removeAt(0) : null;
        final place = i < allRunners.length ? i + startingPlace : null;
        final isOriginallyTBD = i < originalTimingData.length
            ? originalTimingData[i].time == 'TBD'
            : true; // Added TBDs are originally TBD

        records.add(UIRecord(
          place: place,
          runner: runner,
          initialTime: times[i],
          isOriginallyTBD: isOriginallyTBD,
          validationError: null,
        ));
      }
    } else if (conflictType == ConflictType.confirmRunner) {
      // For confirm runner conflicts: all positions have runners and times
      for (int i = 0; i < times.length; i++) {
        final runner = allRunners.removeAt(0);
        final place = i + startingPlace;

        records.add(UIRecord(
          place: place,
          runner: runner,
          initialTime: times[i],
          isOriginallyTBD: false, // Confirm runners are never TBD
          validationError: null,
        ));
      }
    }

    // Initialize conflict data
    final conflict = conflictRecord.conflict!;
    final startTime =
        records.isNotEmpty && records.first.timeController.text.isNotEmpty
            ? records.first.timeController.text
            : '0.0';
    final parsedEndTime =
        TimeFormatter.loadDurationFromString(conflictRecord.time);
    final endTime = parsedEndTime != null
        ? TimeFormatter.formatDuration(parsedEndTime)
        : conflictRecord.time;

    return UIChunk._(
      timingChunkHash: timingChunkHash,
      records: records,
      startingPlace: startingPlace,
      chunkId: chunkId,
      controller: controller,
      startTime: startTime,
      endTime: endTime,
      conflict: conflict,
    );
  }

  UIChunk._({
    required this.timingChunkHash,
    required this.records,
    required this.startingPlace,
    required this.chunkId,
    required this.startTime,
    required this.endTime,
    required this.conflict,
    this.controller,
  });

  void reset() {
    lastInsertedIndex = null;
  }

  void onRemoveExtraTime(int recordIndex) async {
    if (conflict.type != ConflictType.extraTime) {
      throw Exception('Cannot remove time for non-extra time conflict');
    }

    // Remove the record directly from the UIChunk
    records.removeAt(recordIndex);

    // Update the backend data
    if (controller != null) {
      controller!.removeExtraTime(chunkId, recordIndex);
    }

    // UI cache invalidation and notifications are handled by the controller
  }

  Future<void> onMissingTimeSubmitted(
      BuildContext context, int chunkIndex, String newValue) async {
    UIRecord record = records[chunkIndex];

    // Validation already happened in real-time during typing
    // Just ensure the record is up to date and check for resolution
    record.updateConflictTime(ConflictTime(
      time: newValue,
      isOriginallyTBD: record.isOriginallyTBD,
      validationError:
          record.validationError, // Preserve current validation state
    ));

    // Check if chunk is now fully resolved (no TBDs left and no validation errors)
    if (isResolvedLocally) {
      if (controller != null) {
        controller!.syncChunkToBackendAndCheckResolution(this);
      }
    } else {
      if (controller != null) {
        controller!.notifyRegisteredListeners();
      }
    }
  }

  void onMissingTimeChanged(
      BuildContext context, int chunkIndex, String newValue) {
    UIRecord record = records[chunkIndex];

    // Update the controller text
    record.timeController.text = newValue;

    // Run validation in real-time as user types
    String? validationError;

    // Validate the input format
    if (newValue.isNotEmpty &&
        newValue != 'TBD' &&
        TimeFormatter.loadDurationFromString(newValue) == null) {
      validationError = 'Invalid Time';
    } else {
      // Validate time ordering if format is valid
      final allCurrentTimes =
          records.map((r) => r.timeController.text).toList();
      allCurrentTimes[chunkIndex] = newValue;
      validationError = _validateTimesInContext(allCurrentTimes, chunkIndex);
    }

    // Update the record with the validation result
    record.updateConflictTime(ConflictTime(
      time: newValue,
      isOriginallyTBD: record.isOriginallyTBD,
      validationError: validationError,
    ));

    // Notify UI to update resolve button state
    if (controller != null) {
      controller!.notifyRegisteredListeners();
    }
  }

  /// Insert a TBD time at the specified position by moving the first available TBD
  void insertTimeAt(int recordIndex) {
    // For confirmRunner conflicts, always allow inserting new TBDs
    if (conflict.type == ConflictType.confirmRunner) {
      // Create a new TBD record
      final newRecord = UIRecord(
        place: null,
        runner: null,
        initialTime: 'TBD',
        isOriginallyTBD: true,
        validationError: null,
      );

      // Insert it at the specified position
      records.insert(recordIndex, newRecord);

      // Notify UI to rebuild after records list changed
      if (controller != null) {
        controller!.notifyRegisteredListeners();
      }
      return;
    }

    // For missing time conflicts, move existing TBDs
    // Find the first record where controller.text == 'TBD' (unused TBD)
    int? tbdRecordIndex;
    for (int i = 0; i < records.length; i++) {
      if (records[i].timeController.text == 'TBD') {
        tbdRecordIndex = i;
        break;
      }
    }

    if (tbdRecordIndex == null) {
      return; // No TBD to move
    }

    // Remove the TBD record and insert it at the new position
    final tbdRecord = records.removeAt(tbdRecordIndex);
    records.insert(recordIndex, tbdRecord);

    // Notify UI to rebuild after records list changed
    if (controller != null) {
      controller!.notifyRegisteredListeners();
    }
  }

  /// Check if there are TBDs available after the given index for insertion
  bool hasTbdAfter(int recordIndex) {
    for (int i = recordIndex + 1; i < records.length; i++) {
      if (records[i].time == 'TBD') {
        return true;
      }
    }
    return false;
  }

  /// Check if the current position should show a plus button
  bool shouldShowPlusButton(int recordIndex) {
    // Show plus button if:
    // 1. This position didn't originally start as TBD (confirmed times can have plus buttons)
    // 2. There are still unused TBDs available (time == 'TBD')
    return !records[recordIndex].isOriginallyTBD &&
        records.any((record) => record.time == 'TBD');
  }

  /// Get the number of times removed for extra time conflicts
  int get removedCount {
    if (conflict.type != ConflictType.extraTime) return 0;
    // For extra time conflicts, removedCount = original length - current length
    return (conflict.offBy + records.length) - records.length;
  }

  /// Get the number of times entered for missing time conflicts
  int get enteredCount {
    if (conflict.type != ConflictType.missingTime) return 0;
    // For missing time conflicts, enteredCount = original TBDs - remaining TBDs
    final remainingTBDs = records.where((r) => r.time == 'TBD').length;
    return conflict.offBy - remainingTBDs;
  }

  /// Get times from records (for backward compatibility with tests)
  List<String> get times => records.map((r) => r.time).toList();

  /// Check if the conflict is resolved based on local UI state
  bool get isResolvedLocally {
    switch (conflict.type) {
      case ConflictType.extraTime:
        // Extra time conflict is resolved when all extra times have been removed
        // All remaining records should have runners (not null)
        return records.every((record) => record.runner != null);
      case ConflictType.missingTime:
        // Missing time conflict is resolved when all positions have valid non-TBD times
        return records.every((record) =>
            record.time.isNotEmpty &&
            record.time != 'TBD' &&
            record.validationError == null);
      case ConflictType.confirmRunner:
        // ConfirmRunner conflicts are already resolved
        return true;
    }
  }

  /// Validate time ordering for a specific record index
  String? validateTimeOrder(int recordIndex) {
    // Only return persistent validation errors set during submission
    if (records[recordIndex].validationError != null) {
      return records[recordIndex].validationError;
    }

    return null; // No persistent validation error
  }

  Duration? _parseTimeToDuration(String time) {
    return TimeFormatter.loadDurationFromString(time);
  }

  /// Check if all times in this chunk are in valid order (no validation errors)
  bool get hasValidTimeOrder {
    for (final record in records) {
      if (record.validationError != null) {
        return false;
      }
    }
    return true;
  }

  /// Validate times in context using controller values
  String? _validateTimesInContext(List<String> contextTimes, int recordIndex) {
    final currentTime = contextTimes[recordIndex];
    if (currentTime == 'TBD') return null; // TBD is always valid

    final currentDuration = _parseTimeToDuration(currentTime);
    if (currentDuration == null) {
      return null; // Invalid format will be caught elsewhere
    }

    // Check for exact duplicates first (skip TBDs)
    for (int i = 0; i < contextTimes.length; i++) {
      if (i != recordIndex && contextTimes[i] != 'TBD') {
        final otherDuration = _parseTimeToDuration(contextTimes[i]);
        if (otherDuration != null && currentDuration == otherDuration) {
          return 'Invalid Time';
        }
      }
    }

    // Check against previous valid time (must be strictly greater than)
    final previousIndex = _getPreviousValidTimeIndex(contextTimes, recordIndex);
    if (previousIndex != null) {
      final previousDuration =
          _parseTimeToDuration(contextTimes[previousIndex]);
      if (previousDuration != null && currentDuration <= previousDuration) {
        return 'Invalid Time';
      }
    }

    // Check against next valid time (must be strictly less)
    final nextIndex = _getNextValidTimeIndex(contextTimes, recordIndex);
    if (nextIndex != null) {
      final nextDuration = _parseTimeToDuration(contextTimes[nextIndex]);
      if (nextDuration != null && currentDuration >= nextDuration) {
        return 'Invalid Time';
      }
    }

    // Check against chunk's end time (times should not exceed the chunk's expected end time)
    final endDuration = _parseTimeToDuration(endTime);
    if (endDuration != null && currentDuration > endDuration) {
      return 'Invalid Time';
    }

    return null; // Valid
  }

  int? _getPreviousValidTimeIndex(List<String> contextTimes, int recordIndex) {
    for (int i = recordIndex - 1; i >= 0; i--) {
      if (contextTimes[i] != 'TBD') {
        return i;
      }
    }
    return null;
  }

  int? _getNextValidTimeIndex(List<String> contextTimes, int recordIndex) {
    for (int i = recordIndex + 1; i < contextTimes.length; i++) {
      if (contextTimes[i] != 'TBD') {
        return i;
      }
    }
    return null;
  }
}

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
