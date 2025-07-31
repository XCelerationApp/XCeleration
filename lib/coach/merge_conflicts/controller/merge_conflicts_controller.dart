import 'package:xceleration/coach/merge_conflicts/utils/timing_data_converter.dart';
import 'package:xceleration/core/utils/index.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

import '../../../core/utils/enums.dart';
import 'package:flutter/material.dart';
import '../../../core/components/dialog_utils.dart';

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
      TimingDataConverter.convertToUIChunks(timingChunks, raceRunners);

  BuildContext get context {
    assert(_context != null,
        'Context not set in MergeConflictsController. Call setContext() first.');
    return _context!;
  }

  void initState() {
    consolidateConfirmedTimes();
  }

  bool get hasConflicts =>
      (timingChunks.length != 1 || timingChunks.first.hasConflict);

  Future<void> returnMergedData() async {
    if (hasConflicts) {
      DialogUtils.showErrorDialog(context,
          message: 'All conflicts must be resolved before proceeding.');
      return;
    }
    Navigator.of(context).pop(timingChunks[0].timingData);
  }

  // Future<void> createChunks() async {
  //   try {
  //     Logger.d('Creating chunks...');
  //     Logger.d('raceRunners length: [38;5;2m${raceRunners.length}[0m');
  //     selectedTimes = {};
  //     // Use the service for chunk creation
  //     final newChunks = await MergeConflictsService.createChunks(
  //       timingData: timingData,
  //       raceRunners: raceRunners,
  //       resolveTooManyRunnerTimes:
  //           MergeConflictsService.resolveTooManyRunnerTimes,
  //       resolveTooFewRunnerTimes:
  //           MergeConflictsService.resolveTooFewRunnerTimes,
  //       selectedTimes: selectedTimes,
  //     );
  //     chunks = newChunks;
  //     // Validation and notification logic can remain here for now
  //     final totalChunkRunners =
  //         chunks.fold<int>(0, (sum, c) => sum + c.runners.length);
  //     final totalChunkRecords =
  //         chunks.fold<int>(0, (sum, c) => sum + c.records.length);
  //     if (totalChunkRunners != raceRunners.length) {
  //       Logger.e(
  //           'Chunk runner total (\x1b[38;5;1m$totalChunkRunners\x1b[0m) does not match raceRunners.length (\x1b[38;5;1m${raceRunners.length}\x1b[0m)');
  //       // Debug: Find which runners are missing from the chunks
  //       final allChunkRunnerPlaces = chunks
  //           .expand((c) => c.runners
  //               .asMap()
  //               .entries
  //               .map((e) => raceRunners.indexOf(e.value) + 1))
  //           .toSet();
  //       final allRunnerPlaces =
  //           Set<int>.from(List.generate(raceRunners.length, (i) => i + 1));
  //       final missingPlaces = allRunnerPlaces.difference(allChunkRunnerPlaces);
  //       Logger.e('Missing runner places: $missingPlaces');
  //       for (final place in missingPlaces) {
  //         final runner = raceRunners[place - 1];
  //         Logger.e(
  //             'Missing runner: place=$place, bib=${runner.bib}, name=${runner.name}');
  //         // Try to find which chunk (by record places) this runner might belong to
  //         for (int i = 0; i < chunks.length; i++) {
  //           final chunk = chunks[i];
  //           final chunkRecordPlaces =
  //               chunk.records.map((r) => r.place).toList();
  //           Logger.e('Chunk $i record places: $chunkRecordPlaces');
  //           if (chunkRecordPlaces.contains(place)) {
  //             Logger.e('Runner place $place matches chunk $i record places');
  //           }
  //         }
  //       }
  //       // Logger.d all chunk runner places for reference
  //       for (int i = 0; i < chunks.length; i++) {
  //         final chunk = chunks[i];
  //         final chunkRunnerPlaces =
  //             chunk.runners.map((r) => raceRunners.indexOf(r) + 1).toList();
  //         Logger.e('Chunk $i runner places: $chunkRunnerPlaces');
  //       }
  //       // Logger.d all record places for reference
  //       final allRecordPlaces = timingData.records.map((r) => r.place).toList();
  //       Logger.e('All record places: $allRecordPlaces');
  //       throw Exception(
  //           'Chunk runner total ($totalChunkRunners) does not match raceRunners.length (${raceRunners.length})');
  //     }
  //     if (totalChunkRecords != timingData.records.length) {
  //       Logger.e(
  //           'Chunk record total ([38;5;1m$totalChunkRecords[0m) does not match timingData.records.length ([38;5;1m${timingData.records.length}[0m)');
  //       throw Exception(
  //           'Chunk record total ($totalChunkRecords) does not match timingData.records.length (${timingData.records.length})');
  //     }
  //     for (int i = 0; i < chunks.length; i++) {
  //       final chunk = chunks[i];
  //       // New validation: joinedRecords should not have null runner or record, and no duplicate places
  //       for (final jr in chunk.joinedRecords) {
  //         if (jr.timeRecord.place == null || jr.timeRecord.place == 0) {
  //           Logger.e(
  //               'Chunk $i: Found JoinedRecord with missing place: ${jr.timeRecord.elapsedTime}');
  //           throw Exception(
  //               'Chunk $i: Found JoinedRecord with missing place: ${jr.timeRecord.elapsedTime}');
  //         }
  //       }

  //       // Optionally: check for duplicate places
  //       final places =
  //           chunk.joinedRecords.map((jr) => jr.timeRecord.place).toList();
  //       final uniquePlaces = places.toSet();
  //       if (places.length != uniquePlaces.length) {
  //         Logger.e('Chunk $i: Duplicate places in joinedRecords');
  //         throw Exception('Chunk $i: Duplicate places in joinedRecords');
  //       }

  //       if (chunk.joinedRecords.length != chunk.runners.length) {
  //         Logger.e(
  //             'Chunk $i: joinedRecords.length ([38;5;1m${chunk.joinedRecords.length}[0m) does not match runners.length ([38;5;1m${chunk.runners.length}[0m)');
  //         throw Exception(
  //             'Chunk $i: joinedRecords.length (${chunk.joinedRecords.length}) does not match runners.length (${chunk.runners.length})');
  //       }
  //     }

  //     notifyListeners();
  //     Logger.d('Chunks created: $chunks');
  //   } catch (e, stackTrace) {
  //     if (context.mounted) {
  //       Logger.e('⚠️ Critical error in createChunks',
  //           context: context, error: e, stackTrace: stackTrace);
  //     } else {
  //       Logger.e('⚠️ Critical error in createChunks',
  //           error: e, stackTrace: stackTrace);
  //     }
  //     // Create empty chunks to prevent UI from breaking completely
  //     chunks = [];
  //     notifyListeners();
  //   }
  // }

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

  Future<TimingChunk?> createNewResolvedChunk(
      List<String> times) async {
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

  // Future<TimingChunk?> handleMissingTimesResolution(TimingChunk chunk, List<TextEditingController> timeControllers) async {
  //   try {
  //     // Get user-provided times
  //     final userTimes =
  //         timeControllers.map((controller) => controller.text.trim()).toList();

  //     Logger.d('Resolving missing times with inputs: $userTimes');

  //     // Validate user input
  //     if (!_validateUserTimes(userTimes)) {
  //       _showError('All time fields must be filled with valid times');
  //       return null;
  //     }

  //     // Apply the missing times to records
  //     _applyMissingTimes(userTimes, chunk);

  //     // Mark conflict as resolved
  //     _markConflictResolved(chunk);

  //     notifyListeners();
  //     showSuccessMessage();
  //     await consolidateConfirmedTimes();
  //   } catch (e, stackTrace) {
  //     Logger.e('Error resolving missing times: $e',
  //         context: context.mounted ? context : null,
  //         error: e,
  //         stackTrace: stackTrace);
  //     _showError('Failed to resolve missing times. Please try again.');
  //   }
  // }

  /// Validate that all user-provided times are non-empty and valid
  bool _validateUserTimes(List<String> times) {
    return times.isNotEmpty &&
        times.every((time) =>
            time.isNotEmpty && time != 'TBD' && TimeFormatter.isDuration(time));
  }

  // /// Apply user-provided times to the missing time records
  // void _applyMissingTimes(List<String> userTimes, TimingChunk chunk) {
  //   final conflictPlace = chunk.conflictRecord?.conflict?.place!;

  //   // Apply times in forward order (place 1, 2, 3...)
  //   for (int i = 0; i < userTimes.length; i++) {
  //     final targetPlace = conflictPlace - userTimes.length + 1 + i;
  //     final userTime = userTimes[i];

  //     Logger.d('Updating place $targetPlace with time $userTime');

  //     // Find or create the record for this place
  //     final recordIndex = timingData.records
  //         .indexWhere((record) => record.place == targetPlace);

  //     if (recordIndex != -1) {
  //       // Update existing record
  //       final record = timingData.records[recordIndex];
  //       timingData.records[recordIndex] =
  //           _createUpdatedRecord(record, userTime, targetPlace);
  //     } else {
  //       // Create new record if needed
  //       timingData.records.add(_createNewTimeRecord(userTime, targetPlace));
  //     }
  //   }
  // }

  // /// Create an updated time record with the new time
  // TimeRecord _createUpdatedRecord(
  //     TimeRecord original, String newTime, int place) {
  //   return TimeRecord(
  //     elapsedTime: newTime,
  //     type: RecordType.runnerTime,
  //     place: place,
  //     isConfirmed: true,
  //     conflict: null,
  //     textColor: null,
  //     runnerNumber: original.runnerNumber,
  //     bib: original.bib,
  //     name: original.name,
  //     grade: original.grade,
  //     team: original.team,
  //     teamAbbreviation: original.teamAbbreviation,
  //     runnerId: original.runnerId,
  //     raceId: original.raceId,
  //     previousPlace: original.previousPlace,
  //   );
  // }

  // /// Create a new time record
  // TimeRecord _createNewTimeRecord(String time, int place) {
  //   return TimeRecord(
  //     elapsedTime: time,
  //     type: RecordType.runnerTime,
  //     place: place,
  //     isConfirmed: true,
  //     conflict: null,
  //     textColor: null,
  //     previousPlace: null,
  //   );
  // }

  // /// Mark the conflict as resolved
  // void _markConflictResolved(dynamic resolveData) {
  //   final conflictRecord = resolveData.conflictRecord;
  //   final lastConfirmedPlace = resolveData.lastConfirmedPlace;
  //   final runnersCount = resolveData.conflictingRunners.length;

  //   MergeConflictsService.updateConflictRecord(
  //     conflictRecord,
  //     lastConfirmedPlace + runnersCount,
  //   );

  //   final conflictIndex = timingData.records.indexOf(conflictRecord);
  //   if (conflictIndex != -1) {
  //     timingData.records[conflictIndex] = conflictRecord;
  //   }
  // }

  // Future<void> handleExtraTimesResolution(Chunk chunk) async {
  //   try {
  //     // Extract and validate input data
  //     final timeControllers = chunk.controllers['timeControllers'];
  //     final resolveData = chunk.resolve;

  //     if (timeControllers == null || resolveData == null) {
  //       _showError('Missing required data for conflict resolution');
  //       return;
  //     }

  //     // Get user-selected times (only from non-removed controllers)
  //     final selectedTimes = <String>[];
  //     final removedTimes = chunk.getRemovedTimes();

  //     for (int i = 0; i < timeControllers.length; i++) {
  //       final timeText = timeControllers[i].text.trim();
  //       // Only include times that haven't been marked for removal
  //       if (!removedTimes.contains(timeText)) {
  //         selectedTimes.add(timeText);
  //       }
  //     }

  //     Logger.d('Resolving extra times with selections: $selectedTimes');
  //     Logger.d('Available times: ${resolveData.availableTimes}');

  //     // Validate selections and determine unused times
  //     final validationResult = _validateExtraTimesSelection(selectedTimes,
  //         resolveData.availableTimes, resolveData.conflictingRunners, chunk);

  //     if (!validationResult.isValid) {
  //       _showError(validationResult.errorMessage);
  //       return;
  //     }

  //     // Update records with runner information first, then remove unused times
  //     _updateRecordsWithRunnerInfo(
  //         selectedTimes,
  //         resolveData.conflictingRunners,
  //         resolveData.lastConfirmedPlace,
  //         resolveData.lastConfirmedIndex ?? -1,
  //         chunk.records);

  //     // Remove unused times from timing data after updating records
  //     _removeUnusedTimes(validationResult.unusedTimes);

  //     // Mark conflict as resolved
  //     _markConflictResolved(resolveData);

  //     // Clean up confirmation records
  //     _cleanupConfirmationRecords(chunk.records, resolveData.conflictRecord);

  //     notifyListeners();
  //     showSuccessMessage();
  //     await consolidateConfirmedTimes();
  //   } catch (e, stackTrace) {
  //     Logger.e('Error resolving extra times: $e',
  //         context: context.mounted ? context : null,
  //         error: e,
  //         stackTrace: stackTrace);
  //     _showError('Failed to resolve extra times. Please try again.');
  //   }
  // }

  // /// Validate extra times selection and return validation result
  // _ExtraTimesValidationResult _validateExtraTimesSelection(
  //     List<String> selectedTimes,
  //     List<String> availableTimes,
  //     List<dynamic> runners,
  //     Chunk chunk) {
  //   final expectedRunnerCount = runners.length;
  //   final expectedTimesToRemove = availableTimes.length - expectedRunnerCount;

  //   Logger.d('Validation: selectedTimes=$selectedTimes');
  //   Logger.d('Validation: availableTimes=$availableTimes');
  //   Logger.d('Validation: expectedRunnerCount=$expectedRunnerCount');
  //   Logger.d('Validation: expectedTimesToRemove=$expectedTimesToRemove');
  //   Logger.d('Validation: removedTimeIndices=${chunk.removedTimeIndices}');

  //   // Special case: if we have exactly the right number of times for runners,
  //   // this shouldn't be treated as an extra times conflict
  //   if (expectedTimesToRemove <= 0) {
  //     return _ExtraTimesValidationResult(
  //         isValid: false,
  //         errorMessage:
  //             'No extra times to remove. You have exactly the right number of times for your runners.',
  //         unusedTimes: []);
  //   }

  //   // Get the times marked for removal from the UI
  //   final removedTimes = chunk.getRemovedTimes();
  //   Logger.d('Validation: removedTimes from UI=$removedTimes');

  //   // Check if we have the right number of times marked for removal
  //   if (removedTimes.length < expectedTimesToRemove) {
  //     final stillNeedToRemove = expectedTimesToRemove - removedTimes.length;
  //     return _ExtraTimesValidationResult(
  //         isValid: false,
  //         errorMessage:
  //             'Please remove $stillNeedToRemove more time(s) by clicking the X button.',
  //         unusedTimes: removedTimes);
  //   }

  //   if (removedTimes.length > expectedTimesToRemove) {
  //     final tooManyRemoved = removedTimes.length - expectedTimesToRemove;
  //     return _ExtraTimesValidationResult(
  //         isValid: false,
  //         errorMessage:
  //             'Too many times removed. Please undo $tooManyRemoved removal(s).',
  //         unusedTimes: removedTimes);
  //   }

  //   // Perfect! We have exactly the right number of times to remove
  //   return _ExtraTimesValidationResult(
  //       isValid: true, errorMessage: '', unusedTimes: removedTimes);
  // }

  // /// Remove unused times from timing data
  // void _removeUnusedTimes(List<String> unusedTimes) {
  //   Logger.d('Removing unused times: $unusedTimes');
  //   timingData.records
  //       .removeWhere((record) => unusedTimes.contains(record.elapsedTime));
  // }

  // /// Update records with runner information
  // void _updateRecordsWithRunnerInfo(
  //     List<String> selectedTimes,
  //     List<dynamic> runners,
  //     int lastConfirmedPlace,
  //     int lastConfirmedIndex,
  //     List<dynamic> chunkRecords) {
  //   // Find remaining runner time records in the chunk (after removal of unused times)
  //   final remainingraceRunners = chunkRecords
  //       .where((record) => record.type == RecordType.runnerTime)
  //       .toList();

  //   Logger.d(
  //       'Found ${remainingraceRunners.length} remaining runner time records to update');
  //   Logger.d('Available runners: ${runners.length}');
  //   Logger.d('Selected times: $selectedTimes');

  //   // Update each remaining record with sequential places and selected times
  //   for (int i = 0;
  //       i < remainingraceRunners.length &&
  //           i < runners.length &&
  //           i < selectedTimes.length;
  //       i++) {
  //     final record = remainingraceRunners[i];
  //     final runner = runners[i];
  //     final selectedTime = selectedTimes[i];
  //     final newPlace = lastConfirmedPlace + i + 1;

  //     Logger.d(
  //         'Updating record $i: newPlace=$newPlace, time=$selectedTime, runner=${runner.bib}');

  //     // Update record with selected time and runner info
  //     record.elapsedTime = selectedTime;
  //     record.bib = runner.bib;
  //     record.type = RecordType.runnerTime;
  //     record.place = newPlace;
  //     record.isConfirmed = true;
  //     record.conflict = null;
  //     record.name = runner.name;
  //     record.grade = runner.grade;
  //     record.team = runner.team;
  //     record.teamAbbreviation = runner.teamAbbreviation;
  //     record.runnerId = runner.runnerId;
  //     record.raceId = raceId;
  //     record.textColor = AppColors.navBarTextColor.toString();
  //   }

  //   final updatedCount = [
  //     remainingraceRunners.length,
  //     runners.length,
  //     selectedTimes.length
  //   ].reduce((a, b) => a < b ? a : b);
  //   Logger.d('Successfully updated $updatedCount records');
  // }

  // /// Clean up confirmation records between conflicts
  // void _cleanupConfirmationRecords(
  //     List<dynamic> records, dynamic conflictRecord) {
  //   final conflictIndex = records.indexOf(conflictRecord);
  //   final lastConflictIndex = records.lastIndexWhere((record) =>
  //       record.conflict != null && records.indexOf(record) < conflictIndex);

  //   timingData.records.removeWhere((record) =>
  //       record.type == RecordType.confirmRunner &&
  //       records.indexOf(record) > lastConflictIndex &&
  //       records.indexOf(record) < conflictIndex);
  // }

  void showSuccessMessage() {
    DialogUtils.showSuccessDialog(context,
        message: 'Successfully resolved conflict');
  }

  // /// Clears all conflict markers from timing records to ensure
  // /// the load results screen doesn't show conflicts after resolution
  // void clearAllConflicts() {
  //   Logger.d('Clearing all conflicts from timing data...');

  //   // Process each record to clear conflicts and fix issues
  //   _processRecordsForConflictClearing();

  //   // Ensure sequential places for runner time records
  //   _ensureSequentialPlaces();

  //   Logger.d('All conflicts cleared from timing data');
  // }

  // /// Process all records to clear conflicts and fix common issues
  // void _processRecordsForConflictClearing() {
  //   for (int i = 0; i < timingData.length; i++) {
  //     final record = timingData[i];

  //     // Fix missing place values
  //     if (record.place == null) {
  //       record.place = i + 1;
  //       Logger.d(
  //           'Assigned missing place ${record.place} to record with time ${record.elapsedTime}');
  //     }

  //     // Convert conflict records to confirmed records
  //     if (_isConflictRecord(record)) {
  //       _convertToConfirmedRecord(record);
  //     }

  //     // Validate runner time records
  //     if (record.type == RecordType.runnerTime) {
  //       _validateRunnerTimeRecord(record);
  //     }

  //     // Clear conflict data
  //     record.conflict = null;
  //   }
  // }

  // /// Check if a record is a conflict record
  // bool _isConflictRecord(TimingDatum record) {
  //   return record.conflict?.type == ConflictType.missingTime ||
  //       record.conflict?.type == ConflictType.extraTime;
  // }

  // /// Convert a conflict record to a confirmed record
  // void _convertToConfirmedRecord(TimingDatum record) {
  //   record.conflict = Conflict(type: ConflictType.confirmRunner);
  // }

  // /// Validate and fix runner time records
  // void _validateRunnerTimeRecord(TimingDatum record) {
  //   if (record.time == 'TBD' || record.time.isEmpty) {
  //     final placeholderTime = '${record.place ?? 1}.0';
  //     record.time = placeholderTime;
  //     Logger.e(
  //         'WARNING: Added placeholder time $placeholderTime for record at place ${record.place}');
  //   }
  //   record.isConfirmed = true;
  // }

  /// Ensure all runner time records have sequential places (1, 2, 3...)
  // void _ensureSequentialPlaces() {
  //   final runnerTimeRecords = timingData.records
  //       .where((r) => r.type == RecordType.runnerTime)
  //       .toList();

  //   // Sort by current place
  //   runnerTimeRecords.sort((a, b) => (a.place ?? 0).compareTo(b.place ?? 0));

  //   // Reassign sequential places
  //   for (int i = 0; i < runnerTimeRecords.length; i++) {
  //     runnerTimeRecords[i].place = i + 1;
  //   }

  //   Logger.d(
  //       'Fixed ${runnerTimeRecords.length} runner time records with sequential places');
  // }

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

  // // New method to update a single record in timingData
  // void updateRecordInTimingData(TimeRecord updatedRecord) {
  //   final index = timingData.records.indexWhere((record) =>
  //       record.place == updatedRecord.place &&
  //       record.type == updatedRecord.type);
  //   if (index != -1) {
  //     timingData.records[index] = updatedRecord;
  //     Logger.d(
  //         'Updated record in timingData: place=${updatedRecord.place}, time=${updatedRecord.elapsedTime}');
  //   } else {
  //     Logger.e(
  //         'Failed to update record in timingData: Record not found. Place: ${updatedRecord.place}, Time: ${updatedRecord.elapsedTime}');
  //   }
  //   notifyListeners();
  // }

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
