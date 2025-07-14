import '../../../core/utils/enums.dart';
import '../model/timing_data.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import '../model/chunk.dart';
import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../shared/models/time_record.dart';
import '../../merge_conflicts/services/merge_conflicts_service.dart';

class MergeConflictsController with ChangeNotifier {
  late final int raceId;
  late final TimingData timingData;
  late List<RunnerRecord> runnerRecords;
  List<Chunk> chunks = [];
  Map<int, dynamic> selectedTimes = {};
  BuildContext? _context;

  // Mode switching for comparison
  bool _useSimpleMode = false;
  bool get useSimpleMode => _useSimpleMode;

  void toggleMode() {
    _useSimpleMode = !_useSimpleMode;
    Logger.d('Switched to ${_useSimpleMode ? "Simple" : "Complex"} mode');
    notifyListeners();
  }

  void setSimpleMode(bool isSimple) {
    if (_useSimpleMode != isSimple) {
      _useSimpleMode = isSimple;
      Logger.d('Mode set to ${_useSimpleMode ? "Simple" : "Complex"}');
      notifyListeners();
    }
  }

  String get currentModeString => _useSimpleMode ? 'Simple' : 'Complex';

  String get modeDescription => _useSimpleMode
      ? 'Streamlined conflict resolution with direct controls'
      : 'Advanced conflict resolution with detailed chunk management';

  MergeConflictsController({
    required this.raceId,
    required this.timingData,
    required this.runnerRecords,
  });

  void setContext(BuildContext context) {
    _context = context;
  }

  BuildContext get context {
    assert(_context != null,
        'Context not set in MergeConflictsController. Call setContext() first.');
    return _context!;
  }

  void initState() {
    createChunks();
  }

  Future<void> saveResults() async {
    if (getFirstConflict()[0] != null) {
      DialogUtils.showErrorDialog(context,
          message: 'All runners must be resolved before proceeding.');
      return;
    }

    if (!MergeConflictsService.validateRunnerInfo(runnerRecords)) {
      DialogUtils.showErrorDialog(context,
          message:
              'All runners must have a bib number assigned before proceeding.');
      return;
    }
    // Ensure all conflicts are cleared before returning to load results screen
    MergeConflictsService.clearAllConflicts(timingData);
    Navigator.of(context).pop(timingData);
  }

  Future<void> updateRunnerInfo() async {
    for (int i = 0; i < runnerRecords.length; i++) {
      final place = i + 1;
      final runner = runnerRecords[i];

      final record = _findTimingRecordForPlace(place);
      if (record == null || record.place == null) continue;

      _updateRecordWithRunnerInfo(record, runner);
    }
  }

  /// Find the timing record for a specific place
  TimeRecord? _findTimingRecordForPlace(int place) {
    try {
      return timingData.records.firstWhere(
        (r) =>
            r.type == RecordType.runnerTime &&
            r.place == place &&
            r.isConfirmed == true,
      );
    } catch (e) {
      // No matching record found
      return null;
    }
  }

  /// Update a timing record with runner information
  void _updateRecordWithRunnerInfo(TimeRecord record, RunnerRecord runner) {
    final recordIndex = timingData.records.indexOf(record);
    if (recordIndex == -1) return;

    timingData.records[recordIndex] = TimeRecord(
      elapsedTime: record.elapsedTime,
      runnerNumber: runner.bib,
      isConfirmed: record.isConfirmed,
      conflict: record.conflict,
      type: record.type,
      place: record.place,
      previousPlace: record.previousPlace,
      textColor: record.textColor,
      bib: runner.bib,
      name: runner.name,
      grade: runner.grade,
      team: runner.team,
      teamAbbreviation: runner.teamAbbreviation,
      runnerId: runner.runnerId,
      raceId: raceId,
    );
  }

  Future<void> createChunks() async {
    try {
      Logger.d('Creating chunks...');
      Logger.d('runnerRecords length: [38;5;2m${runnerRecords.length}[0m');
      selectedTimes = {};
      // Use the service for chunk creation
      final newChunks = await MergeConflictsService.createChunks(
        timingData: timingData,
        runnerRecords: runnerRecords,
        resolveTooManyRunnerTimes:
            MergeConflictsService.resolveTooManyRunnerTimes,
        resolveTooFewRunnerTimes:
            MergeConflictsService.resolveTooFewRunnerTimes,
        selectedTimes: selectedTimes,
      );
      chunks = newChunks;
      // Validation and notification logic can remain here for now
      final totalChunkRunners =
          chunks.fold<int>(0, (sum, c) => sum + c.runners.length);
      final totalChunkRecords =
          chunks.fold<int>(0, (sum, c) => sum + c.records.length);
      if (totalChunkRunners != runnerRecords.length) {
        Logger.e(
            'Chunk runner total (\x1b[38;5;1m$totalChunkRunners\x1b[0m) does not match runnerRecords.length (\x1b[38;5;1m${runnerRecords.length}\x1b[0m)');
        // Debug: Find which runners are missing from the chunks
        final allChunkRunnerPlaces = chunks
            .expand((c) => c.runners
                .asMap()
                .entries
                .map((e) => runnerRecords.indexOf(e.value) + 1))
            .toSet();
        final allRunnerPlaces =
            Set<int>.from(List.generate(runnerRecords.length, (i) => i + 1));
        final missingPlaces = allRunnerPlaces.difference(allChunkRunnerPlaces);
        Logger.e('Missing runner places: $missingPlaces');
        for (final place in missingPlaces) {
          final runner = runnerRecords[place - 1];
          Logger.e(
              'Missing runner: place=$place, bib=${runner.bib}, name=${runner.name}');
          // Try to find which chunk (by record places) this runner might belong to
          for (int i = 0; i < chunks.length; i++) {
            final chunk = chunks[i];
            final chunkRecordPlaces =
                chunk.records.map((r) => r.place).toList();
            Logger.e('Chunk $i record places: $chunkRecordPlaces');
            if (chunkRecordPlaces.contains(place)) {
              Logger.e('Runner place $place matches chunk $i record places');
            }
          }
        }
        // Logger.d all chunk runner places for reference
        for (int i = 0; i < chunks.length; i++) {
          final chunk = chunks[i];
          final chunkRunnerPlaces =
              chunk.runners.map((r) => runnerRecords.indexOf(r) + 1).toList();
          Logger.e('Chunk $i runner places: $chunkRunnerPlaces');
        }
        // Logger.d all record places for reference
        final allRecordPlaces = timingData.records.map((r) => r.place).toList();
        Logger.e('All record places: $allRecordPlaces');
        throw Exception(
            'Chunk runner total ($totalChunkRunners) does not match runnerRecords.length (${runnerRecords.length})');
      }
      if (totalChunkRecords != timingData.records.length) {
        Logger.e(
            'Chunk record total ([38;5;1m$totalChunkRecords[0m) does not match timingData.records.length ([38;5;1m${timingData.records.length}[0m)');
        throw Exception(
            'Chunk record total ($totalChunkRecords) does not match timingData.records.length (${timingData.records.length})');
      }
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        // New validation: joinedRecords should not have null runner or record, and no duplicate places
        for (final jr in chunk.joinedRecords) {
          if (jr.timeRecord.place == null || jr.timeRecord.place == 0) {
            Logger.e(
                'Chunk $i: Found JoinedRecord with missing place: ${jr.timeRecord.elapsedTime}');
            throw Exception(
                'Chunk $i: Found JoinedRecord with missing place: ${jr.timeRecord.elapsedTime}');
          }
        }

        // Optionally: check for duplicate places
        final places =
            chunk.joinedRecords.map((jr) => jr.timeRecord.place).toList();
        final uniquePlaces = places.toSet();
        if (places.length != uniquePlaces.length) {
          Logger.e('Chunk $i: Duplicate places in joinedRecords');
          throw Exception('Chunk $i: Duplicate places in joinedRecords');
        }

        if (chunk.joinedRecords.length != chunk.runners.length) {
          Logger.e(
              'Chunk $i: joinedRecords.length ([38;5;1m${chunk.joinedRecords.length}[0m) does not match runners.length ([38;5;1m${chunk.runners.length}[0m)');
          throw Exception(
              'Chunk $i: joinedRecords.length (${chunk.joinedRecords.length}) does not match runners.length (${chunk.runners.length})');
        }
      }

      notifyListeners();
      Logger.d('Chunks created: $chunks');
    } catch (e, stackTrace) {
      if (context.mounted) {
        Logger.e('⚠️ Critical error in createChunks',
            context: context, error: e, stackTrace: stackTrace);
      } else {
        Logger.e('⚠️ Critical error in createChunks',
            error: e, stackTrace: stackTrace);
      }
      // Create empty chunks to prevent UI from breaking completely
      chunks = [];
      notifyListeners();
    }
  }

  /// Returns the first unresolved conflict in the timing data, or [null, -1] if none.
  List<dynamic> getFirstConflict() {
    final conflictRecord = _findFirstConflictRecord();

    if (_hasValidConflict(conflictRecord)) {
      final conflictIndex = timingData.records.indexOf(conflictRecord);
      return [conflictRecord.type, conflictIndex];
    }

    return [null, -1];
  }

  /// Find the first record that represents a conflict
  TimeRecord _findFirstConflictRecord() {
    return timingData.records.firstWhere(
      _isConflictRecordType,
      orElse: _createEmptyTimeRecord,
    );
  }

  /// Check if a record represents a conflict type
  bool _isConflictRecordType(TimeRecord record) {
    return record.type != RecordType.runnerTime &&
        record.type != RecordType.confirmRunner;
  }

  /// Create an empty time record for when no conflicts are found
  TimeRecord _createEmptyTimeRecord() {
    return TimeRecord(
      elapsedTime: '',
      type: RecordType.runnerTime,
      runnerNumber: null,
      isConfirmed: false,
      conflict: null,
      place: null,
      previousPlace: null,
      textColor: null,
    );
  }

  /// Check if the found record represents a valid conflict
  bool _hasValidConflict(TimeRecord record) {
    return record.elapsedTime.isNotEmpty;
  }

  /// Consolidates adjacent confirmRunner chunks into a single chunk,
  /// preserving all runnerTime records and keeping only the last confirmRunner record.
  Future<void> consolidateConfirmedTimes() async {
    await createChunks();

    _logConsolidationStart();

    // Process chunks to consolidate adjacent confirmRunner chunks
    _processChunksForConsolidation();

    await createChunks();

    _logConsolidationEnd();
    notifyListeners();
  }

  /// Log the state before consolidation starts
  void _logConsolidationStart() {
    Logger.d('Before consolidation: ${chunks.length} chunks');
    for (int x = 0; x < chunks.length; x++) {
      Logger.d(
          'Chunk $x: type=${chunks[x].type}, records=${chunks[x].records.length}, runners=${chunks[x].runners.length}');
    }
  }

  /// Log the state after consolidation ends
  void _logConsolidationEnd() {
    Logger.d('Final chunks count: ${chunks.length}');
    for (int x = 0; x < chunks.length; x++) {
      Logger.d(
          'Final Chunk $x: type=${chunks[x].type}, records=${chunks[x].records.length}, runners=${chunks[x].runners.length}');
    }
  }

  /// Process all chunks to find and consolidate adjacent confirmRunner chunks
  void _processChunksForConsolidation() {
    int i = 0;
    while (i < chunks.length) {
      if (_isConfirmRunnerChunk(i)) {
        final consecutiveRange = _findConsecutiveConfirmRunnerChunks(i);

        if (_hasMultipleChunks(consecutiveRange)) {
          _consolidateChunkRange(consecutiveRange);
          i = consecutiveRange.start + 1; // Move past the consolidated chunks
        } else {
          i++; // Single chunk, move to next
        }
      } else {
        i++; // Not a confirmRunner chunk, move to next
      }
    }
  }

  /// Check if the chunk at index is a confirmRunner chunk
  bool _isConfirmRunnerChunk(int index) {
    return chunks[index].type == RecordType.confirmRunner;
  }

  /// Find the range of consecutive confirmRunner chunks starting at index
  _ChunkRange _findConsecutiveConfirmRunnerChunks(int startIndex) {
    int endIndex = startIndex;

    // Find consecutive confirmRunner chunks
    while (endIndex + 1 < chunks.length &&
        chunks[endIndex + 1].type == RecordType.confirmRunner) {
      endIndex++;
    }

    return _ChunkRange(start: startIndex, end: endIndex);
  }

  /// Check if the range contains multiple chunks
  bool _hasMultipleChunks(_ChunkRange range) {
    return range.end > range.start;
  }

  /// Consolidate chunks in the given range
  void _consolidateChunkRange(_ChunkRange range) {
    Logger.d(
        'Found consecutive confirmRunner chunks from ${range.start} to ${range.end}');

    final recordsToRemove = _getRecordsToRemove(range);
    _validateLastRecordIsConfirmRunner(range);
    _removeRedundantRecords(recordsToRemove);
  }

  /// Get the list of records that should be removed during consolidation
  List<dynamic> _getRecordsToRemove(_ChunkRange range) {
    final confirmedRecords = chunks
        .sublist(range.start, range.end + 1)
        .expand((chunk) => chunk.records)
        .where((record) => record.type == RecordType.confirmRunner)
        .toList();

    Logger.d(
        'Confirmed records before removal: ${confirmedRecords.map((r) => r.place)}');

    // Keep the last record, remove the rest
    confirmedRecords.removeLast();

    Logger.d('Confirmed records after removal: ${confirmedRecords.length}');

    return confirmedRecords;
  }

  /// Validate that the last record in the range is a confirmRunner
  void _validateLastRecordIsConfirmRunner(_ChunkRange range) {
    if (chunks[range.end].records.last.type != RecordType.confirmRunner) {
      throw Exception('Last record in chunk is not a confirmRunner');
    }
  }

  /// Remove redundant records from timing data
  void _removeRedundantRecords(List<dynamic> recordsToRemove) {
    Logger.d('Timing data records: ${timingData.records.length}');

    timingData.records
        .removeWhere((record) => recordsToRemove.contains(record));

    Logger.d('Timing data records after removal: ${timingData.records.length}');
  }

  Future<void> handleMissingTimesResolution(Chunk chunk) async {
    try {
      // Extract and validate input data
      final resolveData = chunk.resolve;
      final timeControllers = chunk.controllers['timeControllers'];

      if (resolveData == null || timeControllers == null) {
        _showError('Missing required data for conflict resolution');
        return;
      }

      // Get user-provided times
      final userTimes =
          timeControllers.map((controller) => controller.text.trim()).toList();

      Logger.d('Resolving missing times with inputs: $userTimes');

      // Validate user input
      if (!_validateUserTimes(userTimes)) {
        _showError('All time fields must be filled with valid times');
        return;
      }

      // Apply the missing times to records
      _applyMissingTimes(userTimes, resolveData);

      // Mark conflict as resolved
      _markConflictResolved(resolveData);

      notifyListeners();
      showSuccessMessage();
      await consolidateConfirmedTimes();
    } catch (e, stackTrace) {
      Logger.e('Error resolving missing times: $e',
          context: context.mounted ? context : null,
          error: e,
          stackTrace: stackTrace);
      _showError('Failed to resolve missing times. Please try again.');
    }
  }

  /// Validate that all user-provided times are non-empty and valid
  bool _validateUserTimes(List<String> times) {
    return times.every((time) => time.isNotEmpty && time != 'TBD');
  }

  /// Apply user-provided times to the missing time records
  void _applyMissingTimes(List<String> userTimes, dynamic resolveData) {
    final conflictPlace = resolveData.conflictRecord.place!;

    // Apply times in forward order (place 1, 2, 3...)
    for (int i = 0; i < userTimes.length; i++) {
      final targetPlace = conflictPlace - userTimes.length + 1 + i;
      final userTime = userTimes[i];

      Logger.d('Updating place $targetPlace with time $userTime');

      // Find or create the record for this place
      final recordIndex = timingData.records
          .indexWhere((record) => record.place == targetPlace);

      if (recordIndex != -1) {
        // Update existing record
        final record = timingData.records[recordIndex];
        timingData.records[recordIndex] =
            _createUpdatedRecord(record, userTime, targetPlace);
      } else {
        // Create new record if needed
        timingData.records.add(_createNewTimeRecord(userTime, targetPlace));
      }
    }
  }

  /// Create an updated time record with the new time
  TimeRecord _createUpdatedRecord(
      TimeRecord original, String newTime, int place) {
    return TimeRecord(
      elapsedTime: newTime,
      type: RecordType.runnerTime,
      place: place,
      isConfirmed: true,
      conflict: null,
      textColor: null,
      runnerNumber: original.runnerNumber,
      bib: original.bib,
      name: original.name,
      grade: original.grade,
      team: original.team,
      teamAbbreviation: original.teamAbbreviation,
      runnerId: original.runnerId,
      raceId: original.raceId,
      previousPlace: original.previousPlace,
    );
  }

  /// Create a new time record
  TimeRecord _createNewTimeRecord(String time, int place) {
    return TimeRecord(
      elapsedTime: time,
      type: RecordType.runnerTime,
      place: place,
      isConfirmed: true,
      conflict: null,
      textColor: null,
      previousPlace: null,
    );
  }

  /// Mark the conflict as resolved
  void _markConflictResolved(dynamic resolveData) {
    final conflictRecord = resolveData.conflictRecord;
    final lastConfirmedPlace = resolveData.lastConfirmedPlace;
    final runnersCount = resolveData.conflictingRunners.length;

    MergeConflictsService.updateConflictRecord(
      conflictRecord,
      lastConfirmedPlace + runnersCount,
    );

    final conflictIndex = timingData.records.indexOf(conflictRecord);
    if (conflictIndex != -1) {
      timingData.records[conflictIndex] = conflictRecord;
    }
  }

  Future<void> handleExtraTimesResolution(Chunk chunk) async {
    try {
      // Extract and validate input data
      final timeControllers = chunk.controllers['timeControllers'];
      final resolveData = chunk.resolve;

      if (timeControllers == null || resolveData == null) {
        _showError('Missing required data for conflict resolution');
        return;
      }

      // Get user-selected times (only from non-removed controllers)
      final selectedTimes = <String>[];
      final removedTimes = chunk.getRemovedTimes();

      for (int i = 0; i < timeControllers.length; i++) {
        final timeText = timeControllers[i].text.trim();
        // Only include times that haven't been marked for removal
        if (!removedTimes.contains(timeText)) {
          selectedTimes.add(timeText);
        }
      }

      Logger.d('Resolving extra times with selections: $selectedTimes');
      Logger.d('Available times: ${resolveData.availableTimes}');

      // Validate selections and determine unused times
      final validationResult = _validateExtraTimesSelection(selectedTimes,
          resolveData.availableTimes, resolveData.conflictingRunners, chunk);

      if (!validationResult.isValid) {
        _showError(validationResult.errorMessage);
        return;
      }

      // Update records with runner information first, then remove unused times
      _updateRecordsWithRunnerInfo(
          selectedTimes,
          resolveData.conflictingRunners,
          resolveData.lastConfirmedPlace,
          resolveData.lastConfirmedIndex ?? -1,
          chunk.records);

      // Remove unused times from timing data after updating records
      _removeUnusedTimes(validationResult.unusedTimes);

      // Mark conflict as resolved
      _markConflictResolved(resolveData);

      // Clean up confirmation records
      _cleanupConfirmationRecords(chunk.records, resolveData.conflictRecord);

      notifyListeners();
      showSuccessMessage();
      await consolidateConfirmedTimes();
      await createChunks();
    } catch (e, stackTrace) {
      Logger.e('Error resolving extra times: $e',
          context: context.mounted ? context : null,
          error: e,
          stackTrace: stackTrace);
      _showError('Failed to resolve extra times. Please try again.');
    }
  }

  /// Validate extra times selection and return validation result
  _ExtraTimesValidationResult _validateExtraTimesSelection(
      List<String> selectedTimes,
      List<String> availableTimes,
      List<dynamic> runners,
      Chunk chunk) {
    final expectedRunnerCount = runners.length;
    final expectedTimesToRemove = availableTimes.length - expectedRunnerCount;

    Logger.d('Validation: selectedTimes=$selectedTimes');
    Logger.d('Validation: availableTimes=$availableTimes');
    Logger.d('Validation: expectedRunnerCount=$expectedRunnerCount');
    Logger.d('Validation: expectedTimesToRemove=$expectedTimesToRemove');
    Logger.d('Validation: removedTimeIndices=${chunk.removedTimeIndices}');

    // Special case: if we have exactly the right number of times for runners,
    // this shouldn't be treated as an extra times conflict
    if (expectedTimesToRemove <= 0) {
      return _ExtraTimesValidationResult(
          isValid: false,
          errorMessage:
              'No extra times to remove. You have exactly the right number of times for your runners.',
          unusedTimes: []);
    }

    // Get the times marked for removal from the UI
    final removedTimes = chunk.getRemovedTimes();
    Logger.d('Validation: removedTimes from UI=$removedTimes');

    // Check if we have the right number of times marked for removal
    if (removedTimes.length < expectedTimesToRemove) {
      final stillNeedToRemove = expectedTimesToRemove - removedTimes.length;
      return _ExtraTimesValidationResult(
          isValid: false,
          errorMessage:
              'Please remove $stillNeedToRemove more time(s) by clicking the X button.',
          unusedTimes: removedTimes);
    }

    if (removedTimes.length > expectedTimesToRemove) {
      final tooManyRemoved = removedTimes.length - expectedTimesToRemove;
      return _ExtraTimesValidationResult(
          isValid: false,
          errorMessage:
              'Too many times removed. Please undo $tooManyRemoved removal(s).',
          unusedTimes: removedTimes);
    }

    // Perfect! We have exactly the right number of times to remove
    return _ExtraTimesValidationResult(
        isValid: true, errorMessage: '', unusedTimes: removedTimes);
  }

  /// Remove unused times from timing data
  void _removeUnusedTimes(List<String> unusedTimes) {
    Logger.d('Removing unused times: $unusedTimes');
    timingData.records
        .removeWhere((record) => unusedTimes.contains(record.elapsedTime));
  }

  /// Update records with runner information
  void _updateRecordsWithRunnerInfo(
      List<String> selectedTimes,
      List<dynamic> runners,
      int lastConfirmedPlace,
      int lastConfirmedIndex,
      List<dynamic> chunkRecords) {
    // Find remaining runner time records in the chunk (after removal of unused times)
    final remainingRunnerRecords = chunkRecords
        .where((record) => record.type == RecordType.runnerTime)
        .toList();

    Logger.d(
        'Found ${remainingRunnerRecords.length} remaining runner time records to update');
    Logger.d('Available runners: ${runners.length}');
    Logger.d('Selected times: $selectedTimes');

    // Update each remaining record with sequential places and selected times
    for (int i = 0;
        i < remainingRunnerRecords.length &&
            i < runners.length &&
            i < selectedTimes.length;
        i++) {
      final record = remainingRunnerRecords[i];
      final runner = runners[i];
      final selectedTime = selectedTimes[i];
      final newPlace = lastConfirmedPlace + i + 1;

      Logger.d(
          'Updating record $i: newPlace=$newPlace, time=$selectedTime, runner=${runner.bib}');

      // Update record with selected time and runner info
      record.elapsedTime = selectedTime;
      record.bib = runner.bib;
      record.type = RecordType.runnerTime;
      record.place = newPlace;
      record.isConfirmed = true;
      record.conflict = null;
      record.name = runner.name;
      record.grade = runner.grade;
      record.team = runner.team;
      record.teamAbbreviation = runner.teamAbbreviation;
      record.runnerId = runner.runnerId;
      record.raceId = raceId;
      record.textColor = AppColors.navBarTextColor.toString();
    }

    final updatedCount = [
      remainingRunnerRecords.length,
      runners.length,
      selectedTimes.length
    ].reduce((a, b) => a < b ? a : b);
    Logger.d('Successfully updated $updatedCount records');
  }

  /// Clean up confirmation records between conflicts
  void _cleanupConfirmationRecords(
      List<dynamic> records, dynamic conflictRecord) {
    final conflictIndex = records.indexOf(conflictRecord);
    final lastConflictIndex = records.lastIndexWhere((record) =>
        record.conflict != null && records.indexOf(record) < conflictIndex);

    timingData.records.removeWhere((record) =>
        record.type == RecordType.confirmRunner &&
        records.indexOf(record) > lastConflictIndex &&
        records.indexOf(record) < conflictIndex);
  }

  void showSuccessMessage() {
    DialogUtils.showSuccessDialog(context,
        message: 'Successfully resolved conflict');
  }

  /// Clears all conflict markers from timing records to ensure
  /// the load results screen doesn't show conflicts after resolution
  void clearAllConflicts() {
    Logger.d('Clearing all conflicts from timing data...');

    // Process each record to clear conflicts and fix issues
    _processRecordsForConflictClearing();

    // Ensure sequential places for runner time records
    _ensureSequentialPlaces();

    Logger.d('All conflicts cleared from timing data');
  }

  /// Process all records to clear conflicts and fix common issues
  void _processRecordsForConflictClearing() {
    for (int i = 0; i < timingData.records.length; i++) {
      final record = timingData.records[i];

      // Fix missing place values
      if (record.place == null) {
        record.place = i + 1;
        Logger.d(
            'Assigned missing place ${record.place} to record with time ${record.elapsedTime}');
      }

      // Convert conflict records to confirmed records
      if (_isConflictRecord(record)) {
        _convertToConfirmedRecord(record);
      }

      // Validate runner time records
      if (record.type == RecordType.runnerTime) {
        _validateRunnerTimeRecord(record);
      }

      // Clear conflict data
      record.conflict = null;
    }
  }

  /// Check if a record is a conflict record
  bool _isConflictRecord(TimeRecord record) {
    return record.type == RecordType.missingTime ||
        record.type == RecordType.extraTime;
  }

  /// Convert a conflict record to a confirmed record
  void _convertToConfirmedRecord(TimeRecord record) {
    record.type = RecordType.confirmRunner;
    record.isConfirmed = true;
    record.textColor = Colors.green.toString();

    // Ensure place is set if missing
    if (record.place == null) {
      final maxPlace = _findMaxPlaceValue();
      record.place = maxPlace + 1;
      Logger.d('Assigned fallback place ${record.place} to conflict record');
    }
  }

  /// Find the maximum place value currently in use
  int _findMaxPlaceValue() {
    return timingData.records
        .where((r) => r.place != null)
        .map((r) => r.place!)
        .fold(0, (max, place) => place > max ? place : max);
  }

  /// Validate and fix runner time records
  void _validateRunnerTimeRecord(TimeRecord record) {
    if (record.elapsedTime == 'TBD' || record.elapsedTime.isEmpty) {
      final placeholderTime = '${record.place ?? 1}.0';
      record.elapsedTime = placeholderTime;
      Logger.e(
          'WARNING: Added placeholder time $placeholderTime for record at place ${record.place}');
    }
    record.isConfirmed = true;
  }

  /// Ensure all runner time records have sequential places (1, 2, 3...)
  void _ensureSequentialPlaces() {
    final runnerTimeRecords = timingData.records
        .where((r) => r.type == RecordType.runnerTime)
        .toList();

    // Sort by current place
    runnerTimeRecords.sort((a, b) => (a.place ?? 0).compareTo(b.place ?? 0));

    // Reassign sequential places
    for (int i = 0; i < runnerTimeRecords.length; i++) {
      runnerTimeRecords[i].place = i + 1;
    }

    Logger.d(
        'Fixed ${runnerTimeRecords.length} runner time records with sequential places');
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

  // New method to update a single record in timingData
  void updateRecordInTimingData(TimeRecord updatedRecord) {
    final index = timingData.records.indexWhere((record) =>
        record.place == updatedRecord.place &&
        record.type == updatedRecord.type);
    if (index != -1) {
      timingData.records[index] = updatedRecord;
      Logger.d(
          'Updated record in timingData: place=${updatedRecord.place}, time=${updatedRecord.elapsedTime}');
    } else {
      Logger.e(
          'Failed to update record in timingData: Record not found. Place: ${updatedRecord.place}, Time: ${updatedRecord.elapsedTime}');
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

  /// Load mock data for testing purposes
  Future<void> loadMockData(
      List<RunnerRecord> mockRunners, TimingData mockTimingData) async {
    try {
      Logger.d(
          'Loading mock data: ${mockRunners.length} runners, ${mockTimingData.records.length} records');

      // Replace current data with mock data
      runnerRecords = List.from(mockRunners);
      timingData.records = List.from(mockTimingData.records);
      timingData.endTime = mockTimingData.endTime;
      timingData.startTime = mockTimingData.startTime;

      // Reset state
      chunks.clear();
      selectedTimes.clear();

      // Recreate chunks with new data
      await createChunks();

      Logger.d('Mock data loaded successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.e('Error loading mock data: $e',
          context: context.mounted ? context : null,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Clear all data for testing purposes
  Future<void> clearAllData() async {
    try {
      Logger.d('Clearing all data');

      // Clear all data
      runnerRecords.clear();
      timingData.records.clear();
      timingData.endTime = '';
      timingData.startTime = null;

      // Reset state
      chunks.clear();
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

/// Helper class for extra times validation results
class _ExtraTimesValidationResult {
  final bool isValid;
  final String errorMessage;
  final List<String> unusedTimes;

  _ExtraTimesValidationResult({
    required this.isValid,
    required this.errorMessage,
    required this.unusedTimes,
  });
}

/// Helper class for chunk range information
class _ChunkRange {
  final int start;
  final int end;

  _ChunkRange({
    required this.start,
    required this.end,
  });
}
