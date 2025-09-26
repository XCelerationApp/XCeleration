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

  // Cache UI chunks to preserve controller state across rebuilds
  List<UIChunk>? _cachedUIChunks;
  bool _needsUIRebuild = true;

  /// Force UI rebuild (used by UIChunk when records change)
  void invalidateUICache() {
    _needsUIRebuild = true;
  }

  MergeConflictsController({
    required this.masterRace,
    required this.timingChunks,
    required this.raceRunners,
  });

  void setContext(BuildContext context) {
    _context = context;
  }

  List<UIChunk> get uiChunks {
    // Cache the UI chunks to preserve controller state across rebuilds
    if (_cachedUIChunks == null ||
        _cachedUIChunks!.length != timingChunks.length ||
        _needsUIRebuild) {
      _cachedUIChunks = TimingDataConverter.convertToUIChunks(
          timingChunks, raceRunners, this);
      _needsUIRebuild = false;
    }
    return _cachedUIChunks!;
  }

  BuildContext get context {
    assert(_context != null,
        'Context not set in MergeConflictsController. Call setContext() first.');
    return _context!;
  }

  void initState() {
    consolidateConfirmedTimes();
  }

  Future<void> removeExtraTime(String chunkId, int recordIndex) async {
    final chunkIndex = timingChunks.indexWhere((c) => c.id == chunkId);
    if (chunkIndex == -1) {
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
    if (recordIndex >= 0 && recordIndex < chunk.timingData.length) {
      final timeToRemove = chunk.timingData[recordIndex].time;
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Confirm Deletion',
        content: 'Are you sure you want to delete the time $timeToRemove?',
      );

      if (!confirmed) return;

      chunk.timingData.removeAt(recordIndex);

      // Update the conflict's offBy count
      final conflict = chunk.conflictRecord!.conflict!;
      if (conflict.offBy > 0) {
        conflict.offBy--;

        // Note: Don't auto-convert to confirmRunner when offBy reaches 0
        // User should explicitly click "Resolve Conflict" to resolve extra time conflicts
      }

      // Only notify listeners if context is still mounted
      if (context.mounted) {
        _needsUIRebuild = true;
        notifyListeners();
      }
    }
  }

  void notifyRegisteredListeners() {
    if (context.mounted) {
      super.notifyListeners();
    }
  }

  /// Manually resolve an extra time conflict for a specific chunk
  Future<void> resolveExtraTimeConflict(int chunkIndex) async {
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

    // Resolution is now checked in UI based on local state

    // Convert to confirmRunner conflict
    chunk.conflictRecord = TimingDatum(
      time: chunk.conflictRecord!.time,
      conflict: Conflict(type: ConflictType.confirmRunner, offBy: 0),
    );

    // Invalidate UI cache since conflict type changed
    _needsUIRebuild = true;

    // Consolidate adjacent confirmRunner chunks after resolving the conflict
    await consolidateConfirmedTimes();
  }

  /// Manually resolve a missing time conflict for a specific chunk
  Future<void> resolveMissingTimeConflict(int chunkIndex) async {
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

    // Resolution is now checked in UI based on local state

    // Convert to confirmRunner conflict
    chunk.conflictRecord = TimingDatum(
      time: chunk.conflictRecord!.time,
      conflict: Conflict(type: ConflictType.confirmRunner, offBy: 0),
    );

    // Invalidate UI cache since conflict type changed
    _needsUIRebuild = true;

    // Consolidate adjacent confirmRunner chunks after resolving the conflict
    await consolidateConfirmedTimes();
  }

  /// Sync UIChunk records to backend and check for chunk resolution
  Future<void> syncChunkToBackendAndCheckResolution(UIChunk uiChunk) async {
    final chunkIndex = timingChunks.indexWhere((c) => c.id == uiChunk.chunkId);
    if (chunkIndex == -1) {
      return;
    }
    final chunk = timingChunks[chunkIndex];

    // Sync UI record times to backend - replace all timing data
    chunk.timingData.clear();
    chunk.timingData.addAll(
        uiChunk.records.map((record) => TimingDatum(time: record.time)));

    // Update conflict count for missing time conflicts
    if (chunk.hasConflict &&
        chunk.conflictRecord?.conflict?.type == ConflictType.missingTime) {
      final conflict = chunk.conflictRecord!.conflict!;
      // Recalculate offBy based on current TBD count
      final tbdCount = uiChunk.records.where((r) => r.time == 'TBD').length;
      conflict.offBy = tbdCount;

      // Check if this chunk is now fully resolved
      if (conflict.offBy == 0) {
        Logger.d(
            'MergeConflictsController: Chunk ${uiChunk.chunkId} synced and is now fully resolved, consolidating confirmed times');

        // Consolidate confirmed times (merge adjacent confirmRunner chunks)
        await consolidateConfirmedTimes();
        _needsUIRebuild = true;
      }
    }

    // Notify listeners for UI update
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

      // Check if this chunk is now fully resolved
      if (chunk.hasConflict &&
          chunk.conflictRecord?.conflict?.type == ConflictType.missingTime &&
          chunk.conflictRecord!.conflict!.offBy == 0) {
        // Consolidate confirmed times (merge adjacent confirmRunner chunks)
        consolidateConfirmedTimes();

        // Check if we now have one consolidated confirmed chunk and auto-close if so
        if (!hasConflicts) {
          returnMergedData();
          return; // Don't notify listeners since we're closing
        }
      }

      // Only notify listeners if context is still mounted
      if (context.mounted) {
        notifyListeners();
      }
    }
  }

  bool get hasConflicts {
    if (timingChunks.length != 1) return true;
    final chunk = timingChunks.first;
    if (!chunk.hasConflict) return false;
    // ConfirmRunner conflicts are resolved and mergeable
    return chunk.conflictRecord!.conflict!.type != ConflictType.confirmRunner;
  }

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
    Navigator.of(context).pop(null);
  }

  /// Consolidates adjacent confirmRunner chunks into a single chunk,
  /// preserving all runnerTime records and keeping only the last confirmRunner record.
  Future<void> consolidateConfirmedTimes() async {
    // Process chunks to consolidate adjacent confirmRunner chunks
    _consolidateConfirmedChunks();

    // Check for auto-close after consolidation
    _checkForAutoClose();

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

  /// Check if we should auto-close the conflict resolution screen
  void _checkForAutoClose() {
    if (allConflictsResolved && hasValidTimeOrder && timingChunks.length == 1) {
      // Schedule auto-close for next frame to avoid dispose issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          returnMergedData();
        }
      });
    } else {}
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

    // For merged chunks, keep a confirmRunner conflict record so they remain visible
    // Only remove conflict record if there are no conflicts at all
    final hasAnyConflicts = consecutiveChunks.any((chunk) => chunk.hasConflict);

    return TimingChunk(
      id: 'merged-${consecutiveChunks.map((c) => c.id).join('-')}',
      conflictRecord: hasAnyConflicts
          ? TimingDatum(
              time: consecutiveChunks.last.conflictRecord!.time,
              conflict: Conflict(type: ConflictType.confirmRunner))
          : null,
      timingData: consecutiveChunks.expand((data) => data.timingData).toList(),
    );
  }

  Future<TimingChunk?> createNewResolvedChunk(List<String> times) async {
    if (!_validateUserTimes(times)) {
      _showError('All time fields must be filled with valid times');
      return null;
    }
    return TimingChunk(
        id: 'resolved-${DateTime.now().millisecondsSinceEpoch}',
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
