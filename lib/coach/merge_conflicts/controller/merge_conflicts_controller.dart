import 'package:xceleration/coach/merge_conflicts/utils/merge_conflicts_utils.dart';
import 'package:xceleration/coach/merge_conflicts/utils/timing_data_converter.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/utils/index.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

import '../../../core/utils/enums.dart';
import 'package:flutter/material.dart';

class MergeConflictsController with ChangeNotifier {
  late final MasterRace masterRace;
  late final List<TimingChunk> timingChunks;
  late List<RaceRunner> raceRunners;
  Map<int, dynamic> selectedTimes = {};

  /// Widget registers this to handle auto-close navigation.
  VoidCallback? onReadyToClose;

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

  List<UIChunk> get uiChunks {
    // Cache the UI chunks to preserve controller state across rebuilds
    if (_cachedUIChunks == null ||
        _cachedUIChunks!.length != timingChunks.length ||
        _needsUIRebuild) {
      _cachedUIChunks = TimingDataConverter.convertToUIChunks(
          timingChunks, raceRunners);
      _needsUIRebuild = false;
    }
    return _cachedUIChunks!;
  }

  void initState() {
    consolidateConfirmedTimes();
  }

  bool removeExtraTime(int chunkId, int recordIndex) {
    final chunkIndex = timingChunks.indexWhere((c) => c.id == chunkId);
    if (chunkIndex == -1) {
      return false;
    }
    final chunk = timingChunks[chunkIndex];
    if (!chunk.hasConflict ||
        chunk.conflictRecord == null ||
        chunk.conflictRecord!.conflict == null ||
        chunk.conflictRecord!.conflict!.type != ConflictType.extraTime) {
      return false;
    }

    if (recordIndex >= 0 && recordIndex < chunk.timingData.length) {
      chunk.timingData.removeAt(recordIndex);

      // Update the conflict's offBy count
      final conflict = chunk.conflictRecord!.conflict!;
      if (conflict.offBy > 0) {
        conflict.offBy--;

        // Note: Don't auto-convert to confirmRunner when offBy reaches 0
        // User should explicitly click "Resolve Conflict" to resolve extra time conflicts
      }

      _needsUIRebuild = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void notifyRegisteredListeners() {
    super.notifyListeners();
  }

  /// Called by widget when user removes an extra time record from a UIChunk.
  void removeExtraTimeRecord(int chunkId, int recordIndex) {
    final uiChunk = _getUIChunk(chunkId);
    if (uiChunk == null) return;
    if (uiChunk.conflict.type != ConflictType.extraTime) return;
    uiChunk.records.removeAt(recordIndex);
    removeExtraTime(chunkId, recordIndex);
  }

  /// Called by widget when user submits a missing time.
  Future<void> submitMissingTimeRecord(
      int chunkId, int recordIndex, String newValue) async {
    final uiChunk = _getUIChunk(chunkId);
    if (uiChunk == null) return;
    final record = uiChunk.records[recordIndex];
    record.updateConflictTime(ConflictTime(
      time: newValue,
      isOriginallyTBD: record.isOriginallyTBD,
      validationError: record.validationError,
    ));
    if (uiChunk.isResolvedLocally) {
      await syncChunkToBackendAndCheckResolution(uiChunk);
    } else {
      notifyListeners();
    }
  }

  /// Called by widget on text change in a missing time field.
  void updateMissingTimeRecord(
      int chunkId, int recordIndex, String newValue) {
    final uiChunk = _getUIChunk(chunkId);
    if (uiChunk == null) return;
    final record = uiChunk.records[recordIndex];
    record.timeController.text = newValue;
    final validationError = _validateTimeInChunk(uiChunk, recordIndex, newValue);
    record.updateConflictTime(ConflictTime(
      time: newValue,
      isOriginallyTBD: record.isOriginallyTBD,
      validationError: validationError,
    ));
    notifyListeners();
  }

  /// Called by widget when user taps the insert TBD button.
  void insertTbdAt(int chunkId, int recordIndex) {
    final uiChunk = _getUIChunk(chunkId);
    if (uiChunk == null) return;
    if (uiChunk.conflict.type == ConflictType.confirmRunner) {
      uiChunk.records.insert(
        recordIndex,
        UIRecord(
          place: null,
          runner: null,
          initialTime: 'TBD',
          isOriginallyTBD: true,
          validationError: null,
        ),
      );
      notifyListeners();
      return;
    }
    // For missing time conflicts, move the first existing TBD to the target position
    int? tbdIndex;
    for (int i = 0; i < uiChunk.records.length; i++) {
      if (uiChunk.records[i].timeController.text == 'TBD') {
        tbdIndex = i;
        break;
      }
    }
    if (tbdIndex == null) return;
    final tbdRecord = uiChunk.records.removeAt(tbdIndex);
    uiChunk.records.insert(recordIndex, tbdRecord);
    notifyListeners();
  }

  UIChunk? _getUIChunk(int chunkId) {
    try {
      return uiChunks.firstWhere((c) => c.chunkId == chunkId);
    } catch (_) {
      return null;
    }
  }

  String? _validateTimeInChunk(
      UIChunk uiChunk, int recordIndex, String newValue) {
    if (newValue.isNotEmpty &&
        newValue != 'TBD' &&
        TimeFormatter.loadDurationFromString(newValue) == null) {
      return 'Invalid Time';
    }
    final contextTimes =
        uiChunk.records.map((r) => r.timeController.text).toList();
    contextTimes[recordIndex] = newValue;
    return validateTimeInContext(contextTimes, recordIndex, uiChunk.endTime);
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

    notifyListeners();
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onReadyToClose?.call();
          });
          return; // Don't notify listeners since we're closing
        }
      }

      notifyListeners();
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

  /// Returns an error if conflicts remain, or null if safe to close.
  /// The widget is responsible for showing the error and handling navigation.
  AppError? canClose() {
    if (hasConflicts) {
      return const AppError(
          userMessage: 'All conflicts must be resolved before proceeding.');
    }
    return null;
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
        onReadyToClose?.call();
      });
    }
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
      id: -1,
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
      Logger.e('All time fields must be filled with valid times');
      return null;
    }
    return TimingChunk(
        id: -1,
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
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  void dispose() {
    onReadyToClose = null;
    super.dispose();
  }
}
