import 'package:xceleration/coach/merge_conflicts/models/ui_record.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

class UIChunk {
  final int timingChunkHash;
  final int startingPlace;
  final int chunkId;
  final String startTime;
  final String endTime;
  final Conflict conflict;

  // UI records as the single source of truth for this chunk
  final List<UIRecord> records;

  bool get hasConflict => true; // UIChunk always has a conflict record

  int? lastInsertedIndex;

  factory UIChunk({
    required int timingChunkHash,
    required List<String> times,
    required List<RaceRunner> allRunners,
    required TimingDatum conflictRecord,
    required List<TimingDatum> originalTimingData,
    required int startingPlace,
    required int chunkId,
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
  });

  void reset() {
    lastInsertedIndex = null;
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

  /// Check if all times in this chunk are in valid order (no validation errors)
  bool get hasValidTimeOrder {
    for (final record in records) {
      if (record.validationError != null) {
        return false;
      }
    }
    return true;
  }
}
