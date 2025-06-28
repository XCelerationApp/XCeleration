import '../model/timing_data.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import '../model/chunk.dart';
import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../utils/enums.dart';
import '../../../assistant/race_timer/model/timing_record.dart';
import '../../merge_conflicts/services/merge_conflicts_service.dart';
import '../services/simple_conflict_resolver.dart';

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
          message: 'All runners must have a bib number assigned before proceeding.');
      return;
    }
    // Ensure all conflicts are cleared before returning to load results screen
    MergeConflictsService.clearAllConflicts(timingData);
    Navigator.of(context).pop(timingData);
  }

  Future<void> updateRunnerInfo() async {
    for (int i = 0; i < runnerRecords.length; i++) {
      final record = timingData.records.firstWhere(
        (r) =>
            r.type == RecordType.runnerTime &&
            r.place == i + 1 &&
            r.isConfirmed == true,
        orElse: () => TimeRecord(
            elapsedTime: '',
            isConfirmed: false,
            conflict: null,
            type: RecordType.runnerTime,
            place: i + 1,
            previousPlace: null,
            textColor: null),
      );
      if (record.place == null) continue;
      final runner = runnerRecords[i];
      final int index = timingData.records.indexOf(record);
      timingData.records[index] = TimeRecord(
        elapsedTime: record.elapsedTime,
        runnerNumber: runner.bib,
        isConfirmed: record.isConfirmed,
        conflict: record.conflict,
        type: record.type,
        place: record.place,
        previousPlace: record.previousPlace,
        textColor: record.textColor,
      );
    }
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
        resolveTooManyRunnerTimes: MergeConflictsService.resolveTooManyRunnerTimes,
        resolveTooFewRunnerTimes: MergeConflictsService.resolveTooFewRunnerTimes,
        selectedTimes: selectedTimes,
      );
      chunks = newChunks;
      // Validation and notification logic can remain here for now
      final totalChunkRunners = chunks.fold<int>(0, (sum, c) => sum + c.runners.length);
      final totalChunkRecords = chunks.fold<int>(0, (sum, c) => sum + c.records.length);
      if (totalChunkRunners != runnerRecords.length) {
        Logger.e('Chunk runner total (\x1b[38;5;1m$totalChunkRunners\x1b[0m) does not match runnerRecords.length (\x1b[38;5;1m${runnerRecords.length}\x1b[0m)');
        // Debug: Find which runners are missing from the chunks
        final allChunkRunnerPlaces = chunks.expand((c) => c.runners.asMap().entries.map((e) => runnerRecords.indexOf(e.value) + 1)).toSet();
        final allRunnerPlaces = Set<int>.from(List.generate(runnerRecords.length, (i) => i + 1));
        final missingPlaces = allRunnerPlaces.difference(allChunkRunnerPlaces);
        Logger.e('Missing runner places: $missingPlaces');
        for (final place in missingPlaces) {
          final runner = runnerRecords[place - 1];
          Logger.e('Missing runner: place=$place, bib=${runner.bib}, name=${runner.name}');
          // Try to find which chunk (by record places) this runner might belong to
          for (int i = 0; i < chunks.length; i++) {
            final chunk = chunks[i];
            final chunkRecordPlaces = chunk.records.map((r) => r.place).toList();
            Logger.e('Chunk $i record places: $chunkRecordPlaces');
            if (chunkRecordPlaces.contains(place)) {
              Logger.e('Runner place $place matches chunk $i record places');
            }
          }
        }
        // Logger.d all chunk runner places for reference
        for (int i = 0; i < chunks.length; i++) {
          final chunk = chunks[i];
          final chunkRunnerPlaces = chunk.runners.map((r) => runnerRecords.indexOf(r) + 1).toList();
          Logger.e('Chunk $i runner places: $chunkRunnerPlaces');
        }
        // Logger.d all record places for reference
        final allRecordPlaces = timingData.records.map((r) => r.place).toList();
        Logger.e('All record places: $allRecordPlaces');
        throw Exception('Chunk runner total ($totalChunkRunners) does not match runnerRecords.length (${runnerRecords.length})');
      }
      if (totalChunkRecords != timingData.records.length) {
        Logger.e('Chunk record total ([38;5;1m$totalChunkRecords[0m) does not match timingData.records.length ([38;5;1m${timingData.records.length}[0m)');
        throw Exception('Chunk record total ($totalChunkRecords) does not match timingData.records.length (${timingData.records.length})');
      }
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        // New validation: joinedRecords should not have null runner or record, and no duplicate places
        for (final jr in chunk.joinedRecords) {
          if (jr.timeRecord.place == null || jr.timeRecord.place == 0) {
            Logger.e('Chunk $i: Found JoinedRecord with missing place: ${jr.timeRecord.elapsedTime}');
            throw Exception('Chunk $i: Found JoinedRecord with missing place: ${jr.timeRecord.elapsedTime}');
          }
        }
        
        // Optionally: check for duplicate places
        final places = chunk.joinedRecords.map((jr) => jr.timeRecord.place).toList();
        final uniquePlaces = places.toSet();
        if (places.length != uniquePlaces.length) {
          Logger.e('Chunk $i: Duplicate places in joinedRecords');
          throw Exception('Chunk $i: Duplicate places in joinedRecords');
        }

        if (chunk.joinedRecords.length != chunk.runners.length) {
          Logger.e('Chunk $i: joinedRecords.length ([38;5;1m${chunk.joinedRecords.length}[0m) does not match runners.length ([38;5;1m${chunk.runners.length}[0m)');
          throw Exception('Chunk $i: joinedRecords.length (${chunk.joinedRecords.length}) does not match runners.length (${chunk.runners.length})');
        }
      }

      notifyListeners();
      Logger.d('Chunks created: $chunks');
    } catch (e, stackTrace) {
      if (context.mounted) {
        Logger.e('⚠️ Critical error in createChunks', context: context, error: e, stackTrace: stackTrace);
      }
      else {
        Logger.e('⚠️ Critical error in createChunks', error: e, stackTrace: stackTrace);
      }
      // Create empty chunks to prevent UI from breaking completely
      chunks = [];
      notifyListeners();
    }
  }

  /// Returns the first unresolved conflict in the timing data, or [null, -1] if none.
  List<dynamic> getFirstConflict() {
    final records = timingData.records;
    final conflict = records.firstWhere(
      (record) =>
          record.type != RecordType.runnerTime &&
          record.type != RecordType.confirmRunner,
      orElse: () => TimeRecord(
          elapsedTime: '',
          runnerNumber: null,
          isConfirmed: false,
          conflict: null,
          type: RecordType.runnerTime,
          place: null,
          previousPlace: null,
          textColor: null),
    );
    return conflict.elapsedTime != ''
        ? [conflict.type, records.indexOf(conflict)]
        : [null, -1];
  }

  /// Consolidates adjacent confirmRunner chunks into a single chunk,
  /// preserving all runnerTime records and keeping only the last confirmRunner record.
  Future<void> consolidateConfirmedTimes() async {
    await createChunks();
    
    Logger.d('Before consolidation: ${chunks.length} chunks');
    for (int x = 0; x < chunks.length; x++) {
      Logger.d('Chunk $x: type=${chunks[x].type}, records=${chunks[x].records.length}, runners=${chunks[x].runners.length}');
    }
    
    int i = 0;
    while (i < chunks.length) {
      // Only process confirmRunner chunks
      if (chunks[i].type == RecordType.confirmRunner) {
        int startIndex = i;
        int endIndex = i;
        
        // Find consecutive confirmRunner chunks
        while (endIndex + 1 < chunks.length && 
              chunks[endIndex + 1].type == RecordType.confirmRunner) {
          endIndex++;
        }
        
        // If we found multiple adjacent confirmRunner chunks, consolidate them
        if (endIndex > startIndex) {
          Logger.d('Found consecutive confirmRunner chunks from $startIndex to $endIndex');
          final confirmedRecords = chunks.sublist(startIndex, endIndex + 1).expand((chunk) => chunk.records).where((record) => record.type == RecordType.confirmRunner).toList();
          if (chunks[endIndex].records.last.type != RecordType.confirmRunner) {
            throw Exception('Last record in chunk is not a confirmRunner');
          }

          Logger.d('Confirmed records before removal: ${confirmedRecords.map((r) => r.place)}');

          confirmedRecords.removeLast();

          Logger.d('Confirmed records after removal: ${confirmedRecords.length}');

          Logger.d('Timing data records: ${timingData.records.length}');

          timingData.records.removeWhere((record) => confirmedRecords.contains(record));

          Logger.d('Timing data records after removal: ${timingData.records.length}');
      
          // Move to the next chunk after the consolidated one
          i = startIndex + 1;
        } else {
          // Single chunk, move to next
          i++;
        }
      } else {
        // Not a confirmRunner chunk, move to next
        i++;
      }
    }

    await createChunks();
    
    Logger.d('Final chunks count: ${chunks.length}');
    for (int x = 0; x < chunks.length; x++) {
      Logger.d('Final Chunk $x: type=${chunks[x].type}, records=${chunks[x].records.length}, runners=${chunks[x].runners.length}');
    }
    
    notifyListeners();
  }

  Future<void> handleMissingTimesResolution(Chunk chunk) async {
    try {
      // Validate required data
      final resolveData = chunk.resolve;
      final timeControllers = chunk.controllers['timeControllers'];

      if (resolveData == null) {
        _showError('Missing resolve data for conflict');
        return;
      }
      if (timeControllers == null) {
        _showError('Missing time input controllers');
        return;
      }

      // Extract user input
      final List<String> times = timeControllers
          .map((controller) => controller.text.toString())
          .toList()
          .cast<String>();

      Logger.d('Resolving missing times with inputs: $times');

      // Validate times
      final timesError = MergeConflictsService.validateTimes(
          times,
          chunk.runners,
          resolveData.lastConfirmedRecord,
          resolveData.conflictRecord);
      if (timesError != null) {
        _showError(timesError);
        return;
      }
      // Update records with new times
      final conflictRecord = resolveData.conflictRecord;
      final lastConfirmedRunnerPlace = resolveData.lastConfirmedPlace;

      for (int i = times.length - 1; i >= 0; i--) {
        final int currentPlace = (conflictRecord.place! - i).toInt();
        Logger.d(
            'Updating place $currentPlace with time ${times[times.length - i - 1]}');

        var record = timingData.records.firstWhere(
            (element) => element.place == currentPlace,
            orElse: () => TimeRecord(
                elapsedTime: '',
                type: RecordType.runnerTime,
                isConfirmed: false,
                conflict: null,
                place: currentPlace,
                previousPlace: null,
                textColor: null));

        record.elapsedTime = times[times.length - i - 1];
        record.type = RecordType.runnerTime;
        record.place = currentPlace;
        record.isConfirmed = true;
        record.conflict = null;
        record.textColor = null;
      }

      // Mark conflict as resolved
      MergeConflictsService.updateConflictRecord(
        conflictRecord,
        lastConfirmedRunnerPlace + chunk.runners.length,
      );
      timingData.records[timingData.records.indexOf(conflictRecord)] =
          conflictRecord;

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

  Future<void> handleExtraTimesResolution(Chunk chunk) async {
    try {
      // Validate required data
      final timeControllers = chunk.controllers['timeControllers'];
      final resolveData = chunk.resolve;

      if (timeControllers == null) {
        _showError('Missing time input controllers');
        return;
      }
      if (resolveData == null) {
        _showError('Missing resolve data for conflict');
        return;
      }

      // Extract user input
      final List<String> times = timeControllers
          .map((controller) => controller.text.toString())
          .toList()
          .cast<String>();

      Logger.d('Resolving extra times with selections: $times');
      Logger.d('Available times: ${resolveData.availableTimes}');

      List<TimeRecord> records = chunk.records;
      final availableTimes = resolveData.availableTimes;
      final TimeRecord conflictRecord = resolveData.conflictRecord;
      final lastConfirmedIndex = resolveData.lastConfirmedIndex ?? -1;
      final lastConfirmedPlace = resolveData.lastConfirmedPlace;
      Logger.d('lastConfirmedPlace: $lastConfirmedPlace');
      List<RunnerRecord> runners = resolveData.conflictingRunners;

      final timesError = MergeConflictsService.validateTimes(
          times, runners, resolveData.lastConfirmedRecord, conflictRecord);
      if (timesError != null) {
        _showError(timesError);
        return;
      }

    final unusedTimes =
        availableTimes.where((time) => !times.contains(time)).toList();

      if (unusedTimes.isEmpty) {
        _showError('Please select a time for each runner.');
        return;
      }

      if (unusedTimes.length + times.length != availableTimes.length) {
        Logger.e(
            'Time selection mismatch: unused(${unusedTimes.length}) + selected(${times.length}) != available(${availableTimes.length})');
        _showError('Please select a time for each runner.');
        return;
      }

      Logger.d('Unused times: $unusedTimes');
      timingData.records
          .removeWhere((record) => unusedTimes.contains(record.elapsedTime));
      // Logger.d('Unused records: $unusedRecords');

    Logger.d('records: $records');
    Logger.d('runners before: $runners');

      final usedRecords = records
          .where((record) => !unusedTimes.contains(record.elapsedTime))
          .toList();

      if (usedRecords.length != runners.length) {
        Logger.e(
            'Record count mismatch: usedRecords(${usedRecords.length}) != runners(${runners.length})');
        _showError('Please select a time for each runner.');
        return;
      }

    Logger.d('runners: $runners');
    for (int i = 0; i < runners.length; i++) {
      final num currentPlace = i + lastConfirmedPlace + 1;
      var record = records[lastConfirmedIndex + 1 + i];
      final String bibNumber = runners[i].bib;

      Logger.d('currentPlace: $currentPlace');

      record.elapsedTime = times[i];
      record.bib = bibNumber;
      record.type = RecordType.runnerTime;
      record.place = currentPlace.toInt();
      record.isConfirmed = true;
      record.conflict = null;
      record.name = runners[i].name;
      record.grade = runners[i].grade;
      record.school = runners[i].school;
      record.runnerId = runners[i].runnerId;
      record.raceId = raceId;
      record.textColor = AppColors.navBarTextColor;
    }
    MergeConflictsService.updateConflictRecord(
      conflictRecord,
      lastConfirmedPlace + runners.length,
    );
    notifyListeners();

    // Delete all records with type confirm_runner between the conflict record and the last conflict
    int conflictIndex = records.indexOf(conflictRecord);
    int lastConflictIndex = records.lastIndexWhere((record) =>
        record.conflict != null && records.indexOf(record) < conflictIndex);
    timingData.records.removeWhere((record) =>
        record.type == RecordType.confirmRunner &&
        records.indexOf(record) > lastConflictIndex &&
        records.indexOf(record) < conflictIndex);

    showSuccessMessage();
    consolidateConfirmedTimes();
    await createChunks();
    } catch (e, stackTrace) {
      Logger.e('Error resolving extra times: $e',
          context: context.mounted ? context : null,
          error: e,
          stackTrace: stackTrace);
      _showError('Failed to resolve extra times. Please try again.');
    }
  }

  void showSuccessMessage() {
    DialogUtils.showSuccessDialog(context,
        message: 'Successfully resolved conflict');
  }
  
  /// Clears all conflict markers from timing records to ensure
  /// the load results screen doesn't show conflicts after resolution
  void clearAllConflicts() {
    Logger.d('Clearing all conflicts from timing data...');
    
    // Go through all records and fix any issues that could cause null checks
    int currentPlace = 1;
    List<TimeRecord> confirmedRecords = [];
    
    // First pass: Set all place values and clear conflicts
    for (int i = 0; i < timingData.records.length; i++) {
      final record = timingData.records[i];
      
      // 1. Fix missing place values for any record type
      if (record.place == null) {
        record.place = currentPlace;
        Logger.d('Assigned missing place $currentPlace to record with time ${record.elapsedTime}');
      }
      
      // 2. If it's a conflict record, convert it to confirmRunner
      if (record.type == RecordType.missingTime || record.type == RecordType.extraTime) {
        record.type = RecordType.confirmRunner;
        record.isConfirmed = true;
        record.textColor = Colors.green;
        
        // Ensure place is set (use index as fallback)
        if (record.place == null) {
          // Find the maximum place value used so far
          final int maxPlace = timingData.records
              .where((r) => r.place != null)
              .map((r) => r.place!)
              .fold(0, (max, place) => place > max ? place : max);
          record.place = maxPlace + 1;
          Logger.d('Assigned fallback place ${record.place} to conflict record');
        }
      }
      
      // 3. For runner time records, ensure they have proper elapsed time
      if (record.type == RecordType.runnerTime) {
        if (record.elapsedTime == 'TBD' || record.elapsedTime.isEmpty) {
          record.elapsedTime = '$currentPlace.0'; // Emergency placeholder
          Logger.e('WARNING: Added placeholder time for record at place ${record.place}');
          throw Exception('WARNING: Added placeholder time for record at place ${record.place}');
        }
        
        // Keep track of max place for runner time records
        if (record.place! > currentPlace) {
          currentPlace = record.place!;
        }
        
        // Mark as confirmed
        record.isConfirmed = true;
        
        // Add to the list of confirmed records
        confirmedRecords.add(record);
      }
      
      // 4. Clear conflict data for all records
      record.conflict = null;
    }
    
    // Second pass: Ensure all runnerTime records are properly ordered by place
    confirmedRecords.sort((a, b) => (a.place ?? 999).compareTo(b.place ?? 999));
    
    // Reassign places if needed to ensure sequential places
    for (int i = 0; i < confirmedRecords.length; i++) {
      confirmedRecords[i].place = i + 1;
    }
    
    Logger.d('Fixed ${confirmedRecords.length} runner time records with proper places');
    Logger.d('All conflicts cleared from timing data');
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

  // ============================================================================
  // SIMPLE MODE METHODS - Direct conflict resolution without complex abstractions
  // ============================================================================

  /// Simple alternative to handleMissingTimesResolution
  /// Uses direct logic instead of chunks and services
  Future<void> handleMissingTimesSimple({
    required List<String> userTimes,
    required int conflictPlace,
  }) async {
    try {
      Logger.d('Simple mode: Resolving missing times at place $conflictPlace');

      // Use simple resolver
      final updatedRecords = SimpleConflictResolver.resolveMissingTimes(
        timingRecords: timingData.records,
        runners: runnerRecords,
        userTimes: userTimes,
        conflictPlace: conflictPlace,
      );

      // Update timing data
      timingData.records = updatedRecords;

      // Clean up any duplicates
      timingData.records = SimpleConflictResolver.cleanupDuplicateConfirmations(
        timingData.records,
      );

      notifyListeners();
      showSuccessMessage();
    } catch (e, stackTrace) {
      Logger.e('Simple mode error resolving missing times: $e',
          context: context.mounted ? context : null,
          error: e,
          stackTrace: stackTrace);
      _showError('Failed to resolve missing times. Please try again.');
    }
  }

  /// Simple alternative to handleExtraTimesResolution
  /// Uses direct logic instead of chunks and services
  Future<void> handleExtraTimesSimple({
    required List<String> timesToRemove,
    required int conflictPlace,
  }) async {
    try {
      Logger.d('Simple mode: Resolving extra times at place $conflictPlace');

      // Use simple resolver
      final updatedRecords = SimpleConflictResolver.resolveExtraTimes(
        timingRecords: timingData.records,
        timesToRemove: timesToRemove,
        conflictPlace: conflictPlace,
      );

      // Update timing data
      timingData.records = updatedRecords;

      // Clean up any duplicates
      timingData.records = SimpleConflictResolver.cleanupDuplicateConfirmations(
        timingData.records,
      );

      notifyListeners();
      showSuccessMessage();
    } catch (e, stackTrace) {
      Logger.e('Simple mode error resolving extra times: $e',
          context: context.mounted ? context : null,
          error: e,
          stackTrace: stackTrace);
      _showError('Failed to resolve extra times. Please try again.');
    }
  }

  /// Get all conflicts using simple identification
  List<ConflictInfo> getConflictsSimple() {
    return SimpleConflictResolver.identifyConflicts(timingData.records);
  }

  /// Check if there are any unresolved conflicts in simple mode
  bool hasUnresolvedConflictsSimple() {
    return getConflictsSimple().isNotEmpty;
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
