import 'package:xceleration/coach/merge_conflicts/models/conflict_time.dart';
import 'package:xceleration/coach/merge_conflicts/models/ui_chunk.dart';
import 'package:xceleration/coach/merge_conflicts/models/ui_record.dart';
import 'package:xceleration/coach/merge_conflicts/utils/merge_conflicts_utils.dart';
import 'package:xceleration/coach/merge_conflicts/utils/timing_data_converter.dart' show CoachTimingDataConverter;
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
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

  late final IPostFrameCallbackScheduler _scheduler;

  /// Force UI rebuild (used by UIChunk when records change)
  void invalidateUICache() {
    _needsUIRebuild = true;
  }

  MergeConflictsController({
    required this.masterRace,
    required this.timingChunks,
    required this.raceRunners,
    IPostFrameCallbackScheduler? scheduler,
    Map<int, Set<String>>? recordedTimes,
  }) : _scheduler = scheduler ?? WidgetsBindingAdapter() {
    if (recordedTimes != null) {
      _recordedTimes.addAll(recordedTimes);
      return;
    }
    _recordedTimes.addAll(recordedTimesOf(timingChunks));
  }

  /// The times the Timer recorded in each missing-time chunk of [chunks], by
  /// chunk id. Take this before any times are entered, and pass it back in
  /// each time the sheet opens: worked out again later, times the coach had
  /// entered would count as recorded and could no longer be edited.
  static Map<int, Set<String>> recordedTimesOf(List<TimingChunk> chunks) {
    final recorded = <int, Set<String>>{};
    for (final chunk in chunks) {
      if (chunk.conflictRecord?.conflict?.type == ConflictType.missingTime) {
        recorded[chunk.id] = chunk.timingData
            .map((d) => d.time)
            .where((t) => t != 'TBD')
            .toSet();
      }
    }
    return recorded;
  }

  /// The times the Timer recorded in each missing-time chunk, by chunk id.
  /// Every other time in such a chunk was entered by the coach and stays
  /// editable, even after it has been saved into the timing data.
  final Map<int, Set<String>> _recordedTimes = {};

  List<UIChunk> get uiChunks {
    // Cache the UI chunks to preserve controller state across rebuilds
    if (_cachedUIChunks == null ||
        _cachedUIChunks!.length != timingChunks.length ||
        _needsUIRebuild) {
      _cachedUIChunks = CoachTimingDataConverter.convertToUIChunks(
          timingChunks, raceRunners,
          recordedTimes: _recordedTimes);
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

    // Once every extra time is gone, each remaining time belongs to a runner:
    // removing another would leave a runner without a time and shift every
    // later runner onto the wrong time.
    final conflict = chunk.conflictRecord!.conflict!;
    if (conflict.offBy <= 0) {
      return false;
    }

    if (recordIndex >= 0 && recordIndex < chunk.timingData.length) {
      chunk.timingData.removeAt(recordIndex);
      // Don't auto-convert to confirmRunner when offBy reaches 0: the user
      // explicitly clicks "Resolve Conflict".
      conflict.offBy--;

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
  /// The UI chunks are rebuilt from the timing data afterwards, so runners
  /// are reassigned to the remaining times in order.
  void removeExtraTimeRecord(int chunkId, int recordIndex) {
    final uiChunk = _getUIChunk(chunkId);
    if (uiChunk == null) return;
    if (uiChunk.conflict.type != ConflictType.extraTime) return;
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
      validationError: newValue.isEmpty || newValue == 'TBD'
          ? null
          : _validateTimeInChunk(uiChunk, recordIndex, newValue),
    ));
    // Save what is entered so far, so it survives the chunks being rebuilt
    // (e.g. after an extra time is removed elsewhere).
    await syncChunkToBackendAndCheckResolution(uiChunk);
  }

  /// Called by widget on text change in a missing time field.
  void updateMissingTimeRecord(int chunkId, int recordIndex, String newValue) {
    final uiChunk = _getUIChunk(chunkId);
    if (uiChunk == null) return;
    final record = uiChunk.records[recordIndex];
    record.timeController.text = newValue;
    final validationError =
        _validateTimeInChunk(uiChunk, recordIndex, newValue);
    record.updateConflictTime(ConflictTime(
      time: newValue,
      isOriginallyTBD: record.isOriginallyTBD,
      validationError: validationError,
    ));
  }

  /// Called by widget when user taps the insert TBD button.
  ///
  /// Places an unfilled TBD slot directly before the time at [recordIndex]
  /// in a missing-time chunk, meaning the missed finisher came in before it.
  /// The nearest TBD after the target is used (else the nearest before), so
  /// TBDs the coach already placed stay put. Only times move: runners and
  /// places stay in finish order.
  void insertTbdAt(int chunkId, int recordIndex) {
    final uiChunk = _getUIChunk(chunkId);
    if (uiChunk == null) return;
    // Only a missing-time chunk has TBD slots. Adding one anywhere else would
    // add a finisher the timing data does not have.
    if (uiChunk.conflict.type != ConflictType.missingTime) return;
    final records = uiChunk.records;
    if (recordIndex < 0 || recordIndex >= records.length) return;

    int? from;
    for (int i = recordIndex + 1; i < records.length; i++) {
      if (records[i].isUnfilled) {
        from = i;
        break;
      }
    }
    if (from == null) {
      for (int i = recordIndex - 1; i >= 0; i--) {
        if (records[i].isUnfilled) {
          from = i;
          break;
        }
      }
    }
    if (from == null) return;
    // Removing a slot before the target shifts the target left by one.
    final to = from < recordIndex ? recordIndex - 1 : recordIndex;

    // The text field holds what the coach typed; it can differ from
    // conflictTime until the value is submitted.
    final contents = records
        .map((r) => ConflictTime(
              time: r.time,
              isOriginallyTBD: r.isOriginallyTBD,
              validationError: r.validationError,
            ))
        .toList();
    contents.insert(to, contents.removeAt(from));
    for (int i = 0; i < records.length; i++) {
      final old = records[i];
      records[i] = UIRecord(
        place: old.place,
        runner: old.runner,
        initialTime: contents[i].time,
        isOriginallyTBD: contents[i].isOriginallyTBD,
        validationError: contents[i].validationError,
      );
    }
    // Entered times now sit next to different neighbours: check them again.
    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      if (record.isOriginallyTBD && !record.isUnfilled) {
        record.validationError =
            _validateTimeInChunk(uiChunk, i, record.time);
      }
    }
    uiChunk.lastInsertedIndex = to;
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
    final error =
        validateTimeInContext(contextTimes, recordIndex, uiChunk.endTime);
    if (error != null) return error;
    // A time must also come after every finisher in earlier chunks, or this
    // runner would be placed ahead of runners who finished before them.
    final entered = TimeFormatter.loadDurationFromString(newValue);
    final previous = _previousFinishTime(uiChunk.chunkId);
    if (entered != null && previous != null && entered <= previous) {
      return 'Invalid Time';
    }
    return null;
  }

  /// The last recorded finish time in the chunks before [chunkId], or null.
  Duration? _previousFinishTime(int chunkId) {
    final index = timingChunks.indexWhere((c) => c.id == chunkId);
    for (int i = index - 1; i >= 0; i--) {
      for (final datum in timingChunks[i].timingData.reversed) {
        final time = TimeFormatter.loadDurationFromString(datum.time);
        if (time != null) return time;
      }
    }
    return null;
  }

  /// Manually resolve an extra time conflict for a specific chunk
  Future<void> resolveExtraTimeConflict(int chunkId) =>
      _resolveConflict(chunkId, ConflictType.extraTime);

  /// Manually resolve a missing time conflict for a specific chunk
  Future<void> resolveMissingTimeConflict(int chunkId) =>
      _resolveConflict(chunkId, ConflictType.missingTime);

  /// Resolves the chunk with [chunkId]. Chunks are addressed by id, not by
  /// position: the screen only lists chunks that have conflicts, so a list
  /// index there does not match a position in [timingChunks].
  Future<void> _resolveConflict(int chunkId, ConflictType expectedType) async {
    final chunkIndex = timingChunks.indexWhere((c) => c.id == chunkId);
    if (chunkIndex == -1) {
      return;
    }

    final chunk = timingChunks[chunkIndex];
    if (!chunk.hasConflict ||
        chunk.conflictRecord == null ||
        chunk.conflictRecord!.conflict == null ||
        chunk.conflictRecord!.conflict!.type != expectedType) {
      return;
    }

    // Only resolve a chunk whose times really match its runners; the button
    // being enabled is not enough.
    if (expectedType == ConflictType.extraTime) {
      if (chunk.conflictRecord!.conflict!.offBy > 0) return;
    } else if (!_commitMissingTimes(chunk)) {
      return;
    }

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

  /// Writes the entered times of a missing-time chunk into its timing data.
  /// Times typed without pressing Enter only live in the text fields, so
  /// resolving without this saved the chunk with its TBDs (or without its
  /// missing finishers). Returns false, and flags the slot, if any time is
  /// missing or invalid.
  bool _commitMissingTimes(TimingChunk chunk) {
    final uiChunk = _getUIChunk(chunk.id);
    if (uiChunk == null) return false;
    var valid = true;
    for (int i = 0; i < uiChunk.records.length; i++) {
      final record = uiChunk.records[i];
      // Only entered times are checked; recorded times came from the Timer.
      final error = record.isUnfilled
          ? 'Enter a time'
          : record.isOriginallyTBD
              ? _validateTimeInChunk(uiChunk, i, record.time)
              : null;
      if (error != null) {
        record.validationError = error;
        valid = false;
      }
    }
    if (!valid) {
      notifyListeners();
      return false;
    }
    chunk.timingData
      ..clear()
      ..addAll(uiChunk.records.map((r) => TimingDatum(time: r.time)));
    chunk.conflictRecord!.conflict!.offBy = 0;
    return true;
  }

  /// Sync UIChunk records to backend and check for chunk resolution
  Future<void> syncChunkToBackendAndCheckResolution(UIChunk uiChunk) async {
    final chunkIndex = timingChunks.indexWhere((c) => c.id == uiChunk.chunkId);
    if (chunkIndex == -1) {
      return;
    }
    final chunk = timingChunks[chunkIndex];

    // Sync UI record times to backend - replace all timing data. A slot that
    // is empty or invalid is kept as TBD, so the chunk keeps one entry per
    // finisher and nothing unchecked is saved.
    chunk.timingData.clear();
    chunk.timingData.addAll(uiChunk.records.map((record) => TimingDatum(
        time: record.isUnfilled || record.validationError != null
            ? 'TBD'
            : record.time)));

    // Update conflict count for missing time conflicts
    if (chunk.hasConflict &&
        chunk.conflictRecord?.conflict?.type == ConflictType.missingTime) {
      final conflict = chunk.conflictRecord!.conflict!;
      // Recalculate offBy based on current TBD count
      final tbdCount =
          chunk.timingData.where((datum) => datum.time == 'TBD').length;
      conflict.offBy = tbdCount;

      // Check if this chunk is now fully resolved
      if (conflict.offBy == 0) {
        Logger.d(
            'MergeConflictsController: Chunk ${uiChunk.chunkId} synced and is now fully resolved, consolidating confirmed times');

        // Consolidate confirmed times (merge adjacent confirmRunner chunks).
        // consolidateConfirmedTimes() calls notifyListeners() internally, so
        // we return early to avoid a redundant second rebuild.
        await consolidateConfirmedTimes();
        _needsUIRebuild = true;
        return;
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
          _scheduler.addPostFrameCallback(() {
            onReadyToClose?.call();
          });
          return; // Don't notify listeners since we're closing
        }
      }

      notifyListeners();
    }
  }

  /// Whether any chunk still has an unresolved missing- or extra-time
  /// conflict. Confirmed chunks and chunks with no conflict are resolved,
  /// however many of them there are.
  bool get hasConflicts => timingChunks.any((chunk) =>
      chunk.hasConflict &&
      chunk.conflictRecord!.conflict!.type != ConflictType.confirmRunner);

  /// End time of the chunk before the one with [chunkId], used as the lower
  /// bound when validating times; '0.0' for the first chunk.
  String previousEndTimeFor(int chunkId) {
    final index = timingChunks.indexWhere((c) => c.id == chunkId);
    for (int i = index - 1; i >= 0; i--) {
      final previous = timingChunks[i];
      if (previous.hasConflict) return previous.conflictRecord!.time;
      if (previous.timingData.isNotEmpty) return previous.timingData.last.time;
    }
    return '0.0';
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
    if (allConflictsResolved && hasValidTimeOrder && !hasConflicts) {
      // Schedule auto-close for next frame to avoid dispose issues
      _scheduler.addPostFrameCallback(() {
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
      // Keep a real, unique id: chunks are looked up by id, and a shared
      // placeholder id would make separate merged chunks collide.
      id: consecutiveChunks.first.id,
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
      Logger.e('Error clearing data: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  void dispose() {
    onReadyToClose = null;
    super.dispose();
  }
}
