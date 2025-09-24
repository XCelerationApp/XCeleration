import 'package:xceleration/coach/merge_conflicts/utils/timing_data_converter.dart';
import 'package:xceleration/core/utils/index.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

import '../../../core/utils/enums.dart';
import '../../../core/components/dialog_utils.dart';
import 'package:flutter/material.dart';

class MergeConflictsController with ChangeNotifier {
  late final MasterRace masterRace;
  late final List<TimingChunk> timingChunks;
  late List<RaceRunner> raceRunners;
  Map<int, dynamic> selectedTimes = {};
  BuildContext? _context;

  MergeConflictsController({
    required this.masterRace,
    required this.timingChunks,
    required this.raceRunners,
  });

  void setContext(BuildContext context) {
    _context = context;
  }

  List<UIChunk> get uiChunks =>
      TimingDataConverter.convertToUIChunks(timingChunks, raceRunners, this);

  BuildContext get context {
    assert(_context != null,
        'Context not set in MergeConflictsController. Call setContext() first.');
    return _context!;
  }

  void initState() {
    consolidateConfirmedTimes();
  }

  Future<void> removeExtraTime(int chunkIndex, int timeIndex) async {
    if (chunkIndex < 0 || chunkIndex >= timingChunks.length) {
      return;
    }

    final chunk = timingChunks[chunkIndex];
    if (!chunk.hasConflict ||
        chunk.conflictRecord == null ||
        chunk.conflictRecord!.conflict == null ||
        chunk.conflictRecord!.conflict!.type != ConflictType.extraTime) {
      return;
    }

    // Show confirmation dialog before removing
    if (timeIndex >= 0 && timeIndex < chunk.timingData.length) {
      final timeToRemove = chunk.timingData[timeIndex].time;
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Confirm Deletion',
        content: 'Are you sure you want to delete the time $timeToRemove?',
      );

      if (!confirmed) return;

      chunk.timingData.removeAt(timeIndex);

      // Update the conflict's offBy count
      final conflict = chunk.conflictRecord!.conflict!;
      if (conflict.offBy > 0) {
        conflict.offBy--;
      }

      // Only notify listeners if context is still mounted
      if (context.mounted) {
        notifyListeners();
      }
    }
  }

  /// Manually resolve an extra time conflict for a specific chunk
  void resolveExtraTimeConflict(int chunkIndex) {
    if (chunkIndex < 0 || chunkIndex >= timingChunks.length) {
      return;
    }

    final chunk = timingChunks[chunkIndex];
    if (!chunk.hasConflict ||
        chunk.conflictRecord == null ||
        chunk.conflictRecord!.conflict == null ||
        chunk.conflictRecord!.conflict!.type != ConflictType.extraTime) {
      return;
    }

    final conflict = chunk.conflictRecord!.conflict!;

    // Only allow resolution if extra times have been removed (offBy is 0)
    if (conflict.offBy > 0) {
      return;
    }

    // Convert to confirmRunner conflict
    chunk.conflictRecord = TimingDatum(
      time: chunk.conflictRecord!.time,
      conflict: Conflict(type: ConflictType.confirmRunner, offBy: 0),
    );

    // Consolidate adjacent confirmRunner chunks after resolving the conflict
    consolidateConfirmedTimes();

    // Only notify listeners if context is still mounted
    if (context.mounted) {
      notifyListeners();
    }
  }

  /// Manually resolve a missing time conflict for a specific chunk
  void resolveMissingTimeConflict(int chunkIndex) {
    if (chunkIndex < 0 || chunkIndex >= timingChunks.length) {
      return;
    }

    final chunk = timingChunks[chunkIndex];
    if (!chunk.hasConflict ||
        chunk.conflictRecord == null ||
        chunk.conflictRecord!.conflict == null ||
        chunk.conflictRecord!.conflict!.type != ConflictType.missingTime) {
      return;
    }

    final conflict = chunk.conflictRecord!.conflict!;

    // Only allow resolution if missing times have been filled (offBy is 0)
    if (conflict.offBy > 0) {
      return;
    }

    // Convert to confirmRunner conflict
    chunk.conflictRecord = TimingDatum(
      time: chunk.conflictRecord!.time,
      conflict: Conflict(type: ConflictType.confirmRunner, offBy: 0),
    );

    // Consolidate adjacent confirmRunner chunks after resolving the conflict
    consolidateConfirmedTimes();

    // Only notify listeners if context is still mounted
    if (context.mounted) {
      notifyListeners();
    }
  }

  void submitMissingTime(int chunkIndex, int timeIndex, String newValue) {
    if (chunkIndex < 0 || chunkIndex >= timingChunks.length) {
      return;
    }

    final chunk = timingChunks[chunkIndex];
    if (timeIndex >= 0 && timeIndex <= chunk.timingData.length) {
      final isNewEntry = timeIndex == chunk.timingData.length;
      final oldTime = isNewEntry ? 'TBD' : chunk.timingData[timeIndex].time;

      if (isNewEntry) {
        // Add new entry
        chunk.timingData.add(TimingDatum(time: newValue));
      } else {
        // Update existing entry
        chunk.timingData[timeIndex] = TimingDatum(time: newValue);
      }

      // Update conflict count for missing time conflicts
      if (chunk.hasConflict &&
          chunk.conflictRecord?.conflict?.type == ConflictType.missingTime) {
        final conflict = chunk.conflictRecord!.conflict!;
        if (oldTime == 'TBD' && newValue != 'TBD') {
          // Filled a missing time
          conflict.offBy--;
        } else if (oldTime != 'TBD' && newValue == 'TBD') {
          // Created a new missing time
          conflict.offBy++;
        }
      }

      // Only notify listeners if context is still mounted
      if (context.mounted) {
        notifyListeners();
      }
    }
  }

  bool get hasConflicts =>
      (timingChunks.length != 1 || timingChunks.first.hasConflict);

  bool get allConflictsResolved {
    // Check if any timing chunks still have TBD values
    return timingChunks.every((chunk) =>
        chunk.timingData.every((timingDatum) => timingDatum.time != 'TBD'));
  }

  bool get hasValidTimeOrder {
    // Check if all UI chunks have valid time ordering
    return uiChunks.every((chunk) => chunk.hasValidTimeOrder);
  }

  Future<void> returnMergedData() async {
    if (hasConflicts) {
      DialogUtils.showErrorDialog(context,
          message: 'All conflicts must be resolved before proceeding.');
      return;
    }
    Navigator.of(context).pop(timingChunks[0].timingData);
  }

  /// Consolidates adjacent confirmRunner chunks into a single chunk,
  /// preserving all runnerTime records and keeping only the last confirmRunner record.
  Future<void> consolidateConfirmedTimes() async {
    // Process chunks to consolidate adjacent confirmRunner chunks
    _consolidateConfirmedChunks();
    notifyListeners();
  }

  /// Process all chunks to find and consolidate adjacent confirmRunner chunks
  void _consolidateConfirmedChunks() {
    if (timingChunks.isEmpty) return;

    final consolidatedChunks = <TimingChunk>[];
    int i = 0;

    while (i < timingChunks.length) {
      final currentChunk = timingChunks[i];

      // Check if this is a confirmRunner chunk by looking at its records
      if (_isConfirmRunnerChunk(currentChunk)) {
        // Find all consecutive confirmRunner chunks
        final consecutiveChunks = <TimingChunk>[currentChunk];
        int j = i + 1;

        // Collect consecutive confirmRunner chunks
        while (
            j < timingChunks.length && _isConfirmRunnerChunk(timingChunks[j])) {
          consecutiveChunks.add(timingChunks[j]);
          j++;
        }

        if (consecutiveChunks.length > 1) {
          // Merge multiple consecutive chunks
          final mergedChunk = _mergeConsecutiveTimingChunks(consecutiveChunks);
          consolidatedChunks.add(mergedChunk);
          Logger.d(
              'Consolidated ${consecutiveChunks.length} consecutive confirmRunner chunks');
        } else {
          // Single chunk, keep as is
          consolidatedChunks.add(currentChunk);
        }

        // Skip all processed chunks
        i = j;
      } else {
        // Not a confirmRunner chunk, keep as is
        consolidatedChunks.add(currentChunk);
        i++;
      }
    }

    // Replace timingChunks with consolidated version
    timingChunks.clear();
    timingChunks.addAll(consolidatedChunks);
  }

  /// Check if a TimingChunk contains confirmRunner records
  bool _isConfirmRunnerChunk(TimingChunk chunk) {
    return chunk.conflictRecord?.conflict?.type == ConflictType.confirmRunner;
  }

  /// Merge consecutive confirmRunner chunks efficiently
  TimingChunk _mergeConsecutiveTimingChunks(
      List<TimingChunk> consecutiveChunks) {
    if (consecutiveChunks.isEmpty) {
      throw ArgumentError('Cannot merge empty chunk list');
    }

    if (consecutiveChunks.length == 1) {
      return consecutiveChunks.first;
    }

    return TimingChunk(
      conflictRecord: consecutiveChunks.last.conflictRecord,
      timingData: consecutiveChunks.expand((data) => data.timingData).toList(),
    );
  }

  Future<TimingChunk?> createNewResolvedChunk(List<String> times) async {
    if (!_validateUserTimes(times)) {
      _showError('All time fields must be filled with valid times');
      return null;
    }
    return TimingChunk(
        timingData: times.map((time) => TimingDatum(time: time)).toList(),
        conflictRecord: TimingDatum(
            time: times.last,
            conflict: Conflict(type: ConflictType.confirmRunner)));
  }

  /// Validate that all user-provided times are non-empty and valid
  bool _validateUserTimes(List<String> times) {
    return times.isNotEmpty &&
        times.every((time) =>
            time.isNotEmpty && time != 'TBD' && TimeFormatter.isDuration(time));
  }

  void showSuccessMessage() {
    DialogUtils.showSuccessDialog(context,
        message: 'Successfully resolved conflict');
  }

  void updateSelectedTime(
      int conflictIndex, String newValue, String? previousValue) {
    if (selectedTimes[conflictIndex] == null) {
      selectedTimes[conflictIndex] = <String>[];
    }

    selectedTimes[conflictIndex].add(newValue);

    if (previousValue != null &&
        previousValue.isNotEmpty &&
        previousValue != newValue) {
      selectedTimes[conflictIndex].remove(previousValue);
    }

    notifyListeners();
  }

  /// Helper method to show error dialogs consistently
  void _showError(String message) {
    Logger.e(message);
    if (context.mounted) {
      DialogUtils.showErrorDialog(context, message: message);
    }
  }

  /// Clear all data for testing purposes
  Future<void> clearAllData() async {
    try {
      Logger.d('Clearing all data');

      // Clear all data
      raceRunners.clear();
      timingChunks.clear();

      selectedTimes.clear();

      Logger.d('All data cleared successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.e('Error clearing data: $e',
          context: context.mounted ? context : null,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  void dispose() {
    _context = null;
    super.dispose();
  }
}
