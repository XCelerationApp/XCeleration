import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../controller/merge_conflicts_controller.dart';

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

      // Calculate required runners for this chunk
      int requiredRunners = times.length;
      if (chunk.conflictRecord!.conflict!.type == ConflictType.extraTime) {
        requiredRunners -= chunk.conflictRecord!.conflict!.offBy;
      }

      // Skip if not enough runners available
      if (runnersCopy.length < requiredRunners) {
        continue;
      }

      final uiChunk = UIChunk(
          timingChunkHash: chunk.hashCode,
          times: times,
          allRunners: runnersCopy,
          conflictRecord: chunk.conflictRecord!,
          startingPlace: startingPlace,
          controller: controller,
          chunkIndex: i);
      uiChunks.add(uiChunk);
      startingPlace += uiChunk.records.length;
    }
    return uiChunks;
  }
}

class UIChunk {
  final int timingChunkHash;
  late final List<String> initialTimes;
  List<String> times;
  final int startingPlace;

  late final String startTime;
  late final String endTime;
  late final Conflict conflict;
  late final List<RaceRunner> runners;

  // Reference to controller for updating underlying data
  final MergeConflictsController? controller;
  final int chunkIndex;

  List<UIRecord> get records {
    final records = <UIRecord>[];
    for (int i = 0; i < times.length; i++) {
      if (i < runners.length) {
        records.add(UIRecord(
            initialTime: times[i],
            place: i + startingPlace,
            runner: runners[i]));
      } else {
        // For extra time conflicts, show the actual time. For missing time conflicts, show TBD.
        final displayTime =
            conflict.type == ConflictType.extraTime ? times[i] : 'TBD';
        records
            .add(UIRecord(initialTime: displayTime, place: null, runner: null));
      }
    }
    return records;
  }

  late final int originalTimingDataLength;
  int? lastInsertedIndex;

  UIChunk(
      {required this.timingChunkHash,
      required this.times,
      required List<RaceRunner> allRunners,
      required TimingDatum conflictRecord,
      required this.startingPlace,
      this.controller,
      this.chunkIndex = 0}) {
    if (times.isEmpty) {
      throw Exception('Times list cannot be empty');
    }

    // Store the original timingData length before adding constructor TBDs
    originalTimingDataLength = times.length;

    int runnersLength = times.length;
    if (conflictRecord.conflict!.type == ConflictType.extraTime) {
      runnersLength -= conflictRecord.conflict!.offBy;
    }

    // Check if we have enough runners available
    if (allRunners.length < runnersLength) {
      throw Exception('Not enough runners available for timing data');
    }

    runners =
        List<RaceRunner>.generate(runnersLength, (_) => allRunners.removeAt(0));
    startTime = times.first;
    conflict = conflictRecord.conflict!;
    endTime = conflictRecord.time;
    if (conflict.type == ConflictType.missingTime) {
      // Check if we have enough runners for the missing times
      if (allRunners.length < conflict.offBy) {
        throw Exception(
            'Not enough runners available for missing time conflict');
      }

      for (int i = 0; i < conflict.offBy; i++) {
        times.add('TBD');
        runners.add(allRunners.removeAt(0));
      }
    }

    initialTimes = times;
  }

  void reset() {
    times = initialTimes;
    lastInsertedIndex = null;
  }

  void onRemoveExtraTime(int timeIndex) async {
    if (controller == null) {
      // Fallback to local modification if no controller
      if (conflict.type != ConflictType.extraTime) {
        throw Exception('Cannot remove time for non-extra time conflict');
      }
      times.removeAt(timeIndex);
    } else {
      // Use controller to update underlying data
      await controller!.removeExtraTime(chunkIndex, timeIndex);
    }
  }

  void onMissingTimeSubmitted(
      BuildContext context, int chunkIndex, String newValue) {
    UIRecord record = records[chunkIndex];

    // Validate the input format
    if (newValue.isNotEmpty &&
        newValue != 'TBD' &&
        TimeFormatter.loadDurationFromString(newValue) == null) {
      // Invalid time format - show inline error
      // Temporarily update to show validation error, then revert
      times[chunkIndex] = 'INVALID_FORMAT';
      // Revert after a brief moment to show the error
      Future.delayed(const Duration(milliseconds: 100), () {
        times[chunkIndex] = record.initialTime;
        record.timeController.text = record.initialTime;
      });
      return;
    }

    // Validate time ordering
    final tempTimes = List<String>.from(times);
    tempTimes[chunkIndex] = newValue;
    final validationError = _validateTimeInContext(tempTimes, chunkIndex);
    if (validationError != null) {
      // Invalid time ordering - show inline error
      // Temporarily update to show validation error, then revert
      times[chunkIndex] = 'INVALID_ORDER';
      // Revert after a brief moment to show the error
      Future.delayed(const Duration(milliseconds: 100), () {
        times[chunkIndex] = record.initialTime;
        record.timeController.text = record.initialTime;
      });
      return;
    }

    // Update the time directly
    times[chunkIndex] = newValue;
    // Update the controller text to reflect the change immediately
    record.timeController.text = newValue;

    // Update controller if available
    if (controller != null) {
      controller!.submitMissingTime(chunkIndex, chunkIndex, newValue);
    }
  }

  void onMissingTimeChanged(
      BuildContext context, int chunkIndex, String newValue) {
    UIRecord record = records[chunkIndex];

    // For typing, just update the local controller text
    // Don't try to validate or update the backend data during typing
    record.timeController.text = newValue;
  }

  /// Insert a new TBD time at the specified position
  void insertTimeAt(int recordIndex) {
    // Find the first TBD after the insertion point
    int? tbdToRemove;
    for (int i = recordIndex + 1; i < times.length; i++) {
      if (times[i] == 'TBD') {
        tbdToRemove = i;
        break;
      }
    }

    if (tbdToRemove == null) {
      return; // No TBD to move, cannot insert
    }

    // Insert TBD at the specified position
    times.insert(recordIndex, 'TBD');

    // Remove the TBD that we found (adjusted for the insertion)
    final adjustedRemoveIndex =
        tbdToRemove + 1; // +1 because we inserted before it
    times.removeAt(adjustedRemoveIndex);
  }

  /// Check if there are TBDs available after the given index for insertion
  bool hasTbdAfter(int recordIndex) {
    for (int i = recordIndex + 1; i < times.length; i++) {
      if (times[i] == 'TBD') {
        return true;
      }
    }
    return false;
  }

  /// Check if the current position should show a plus button
  bool shouldShowPlusButton(int recordIndex) {
    final time = times[recordIndex];
    // Show plus button if:
    // 1. Current time is not TBD (filled in or empty)
    // 2. There are TBDs after this position
    return time != 'TBD' && hasTbdAfter(recordIndex);
  }

  /// Validate time ordering for a specific record index
  String? validateTimeOrder(int recordIndex) {
    final currentTime = times[recordIndex];
    if (currentTime == 'TBD') return null; // TBD is always valid

    // Handle special error display cases
    if (currentTime == 'INVALID_FORMAT') {
      return 'Invalid time format. Use MM:SS.ms or SS.ms';
    }
    if (currentTime == 'INVALID_ORDER') {
      // Get the bounds for the error message
      final tempTimes = List<String>.from(times);
      tempTimes[recordIndex] = records[recordIndex].timeController.text;
      final bounds = _getTimeBounds(recordIndex);
      if (bounds['min'] != null && bounds['max'] != null) {
        return 'Time must be between ${TimeFormatter.formatDuration(bounds['min']!)} and ${TimeFormatter.formatDuration(bounds['max']!)}';
      } else if (bounds['min'] != null) {
        return 'Time must be after ${TimeFormatter.formatDuration(bounds['min']!)}';
      } else if (bounds['max'] != null) {
        return 'Time must be before ${TimeFormatter.formatDuration(bounds['max']!)}';
      }
      return 'Invalid time order';
    }

    final currentDuration = _parseTimeToDuration(currentTime);
    if (currentDuration == null) {
      return null; // Invalid format will be caught elsewhere
    }

    // Check against previous valid time
    final previousDuration = _getPreviousValidTime(recordIndex);
    if (previousDuration != null && currentDuration <= previousDuration) {
      return 'Must be after ${TimeFormatter.formatDuration(previousDuration)}';
    }

    // Check against next valid time
    final nextDuration = _getNextValidTime(recordIndex);
    if (nextDuration != null && currentDuration >= nextDuration) {
      return 'Must be before ${TimeFormatter.formatDuration(nextDuration)}';
    }

    return null; // Valid
  }

  Duration? _parseTimeToDuration(String time) {
    return TimeFormatter.loadDurationFromString(time);
  }

  Duration? _getPreviousValidTime(int recordIndex) {
    for (int i = recordIndex - 1; i >= 0; i--) {
      final time = times[i];
      if (time != 'TBD') {
        return _parseTimeToDuration(time);
      }
    }
    return null;
  }

  Duration? _getNextValidTime(int recordIndex) {
    for (int i = recordIndex + 1; i < times.length; i++) {
      final time = times[i];
      if (time != 'TBD') {
        return _parseTimeToDuration(time);
      }
    }
    // If no valid time after, use the conflict end time
    if (controller != null &&
        controller!.timingChunks[chunkIndex].conflictRecord != null) {
      final endTime = controller!.timingChunks[chunkIndex].conflictRecord!.time;
      return _parseTimeToDuration(endTime);
    }
    return null;
  }

  /// Get the min and max time bounds for a given record index
  Map<String, Duration?> _getTimeBounds(int recordIndex) {
    final previousDuration = _getPreviousValidTime(recordIndex);
    final nextDuration = _getNextValidTime(recordIndex);
    return {
      'min': previousDuration,
      'max': nextDuration,
    };
  }

  /// Check if all times in this chunk are in valid order
  bool get hasValidTimeOrder {
    for (int i = 0; i < times.length; i++) {
      if (validateTimeOrder(i) != null) {
        return false;
      }
    }
    return true;
  }

  /// Validate a time in a given context (list of times)
  String? _validateTimeInContext(List<String> contextTimes, int recordIndex) {
    final currentTime = contextTimes[recordIndex];
    if (currentTime == 'TBD') return null; // TBD is always valid

    final currentDuration = _parseTimeToDuration(currentTime);
    if (currentDuration == null) {
      return null; // Invalid format will be caught elsewhere
    }

    // Check against previous valid time
    final previousDuration =
        _getPreviousValidTimeInContext(contextTimes, recordIndex);
    if (previousDuration != null && currentDuration < previousDuration) {
      return 'Time must be after ${TimeFormatter.formatDuration(previousDuration)}';
    }

    // Check against next valid time
    final nextDuration = _getNextValidTimeInContext(contextTimes, recordIndex);
    if (nextDuration != null && currentDuration > nextDuration) {
      return 'Time must be before ${TimeFormatter.formatDuration(nextDuration)}';
    }

    return null; // Valid
  }

  Duration? _getPreviousValidTimeInContext(
      List<String> contextTimes, int recordIndex) {
    for (int i = recordIndex - 1; i >= 0; i--) {
      final time = contextTimes[i];
      if (time != 'TBD') {
        return _parseTimeToDuration(time);
      }
    }
    return null;
  }

  Duration? _getNextValidTimeInContext(
      List<String> contextTimes, int recordIndex) {
    for (int i = recordIndex + 1; i < contextTimes.length; i++) {
      final time = contextTimes[i];
      if (time != 'TBD') {
        return _parseTimeToDuration(time);
      }
    }
    // If no valid time after, use the conflict end time
    if (controller != null &&
        controller!.timingChunks[chunkIndex].conflictRecord != null) {
      final endTime = controller!.timingChunks[chunkIndex].conflictRecord!.time;
      return _parseTimeToDuration(endTime);
    }
    return null;
  }
}

class UIRecord {
  final String initialTime;
  final int? place;
  final RaceRunner? runner;
  late final TextEditingController timeController;

  String get time => timeController.text;

  UIRecord({required this.initialTime, required this.place, this.runner}) {
    timeController = TextEditingController(text: initialTime);
  }
}
