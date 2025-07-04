import '../../../core/utils/enums.dart';
import '../model/timing_data.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import '../model/chunk.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:flutter/material.dart';
import '../../../shared/models/time_record.dart';
import '../model/resolve_information.dart';
import 'dart:async';

class MergeConflictsService {
  /// Handles chunk creation and validation logic, extracted from MergeConflictsController.
  static Future<List<Chunk>> createChunks({
    required TimingData timingData,
    required List<RunnerRecord> runnerRecords,
    required Future<ResolveInformation> Function(
            int, TimingData, List<RunnerRecord>)
        resolveTooManyRunnerTimes,
    required Future<ResolveInformation> Function(
            int, TimingData, List<RunnerRecord>)
        resolveTooFewRunnerTimes,
    Map<int, dynamic>? selectedTimes,
  }) async {
    // Performance timing: measure chunk creation duration
    final stopwatch = Stopwatch()..start();
    Logger.d('Creating chunks (service)...');
    Logger.d('runnerRecords length: ${runnerRecords.length}');
    final records = timingData.records;
    final newChunks = <Chunk>[];
    var startIndex = 0;
    Map<int, dynamic> localSelectedTimes = selectedTimes ?? {};

    Logger.d('--- DEBUG: All runnerRecords before chunking ---');
    for (int i = 0; i < runnerRecords.length; i++) {
      final r = runnerRecords[i];
      Logger.d('Runner $i: place=${i + 1}, bib=${r.bib}, name=${r.name}');
    }
    Logger.d('--- DEBUG: All timingData.records before chunking ---');
    for (int i = 0; i < timingData.records.length; i++) {
      final rec = timingData.records[i];
      Logger.d(
          'Record $i: place=${rec.place}, elapsedTime=${rec.elapsedTime}, type=${rec.type}');
    }

    for (int i = 0; i < records.length; i += 1) {
      try {
        Logger.d('Processing record: index=$i, record=${records[i]}');
        Logger.d(
            'Record type: ${records[i].type}, place: ${records[i].place}, conflict: ${records[i].conflict?.data}');

        // Check if we should break off a chunk
        bool shouldBreakChunk = false;

        if (records[i].type != RecordType.runnerTime) {
          // Always break after non-runnerTime records (conflicts, confirmRunner)
          shouldBreakChunk = true;
        } else if (i == records.length - 1) {
          // Break at the end of records
          shouldBreakChunk = true;
        }
        // Never break after runnerTime records unless it's the end

        if (shouldBreakChunk) {
          final chunkRecords = records.sublist(startIndex, i + 1);
          Logger.d(
              'Creating chunk with records.sublist($startIndex, ${i + 1})');
          Logger.d(
              'Chunk records: ${chunkRecords.map((r) => 'place=${r.place}, type=${r.type}').toList()}');

          newChunks.add(Chunk(
            records: chunkRecords,
            type: records[i].type,
            runners: runnerRecords, // Pass all runners; Chunk will filter
            conflictIndex: i,
          ));
          startIndex = i + 1;
        }
      } catch (e, stackTrace) {
        Logger.e('⚠️ Error processing record at index $i',
            error: e, stackTrace: stackTrace);
        continue;
      }
    }
    Logger.d('Chunks created: $newChunks');
    Logger.d(
        'Final chunk runner total: ${newChunks.fold<int>(0, (sum, c) => sum + c.runners.length)} (should match runnerRecords.length: ${runnerRecords.length})');
    Logger.d(
        'Final chunk record total: ${newChunks.fold<int>(0, (sum, c) => sum + c.records.length)} (should match records.length: ${records.length})');
    for (int i = 0; i < newChunks.length; i += 1) {
      try {
        localSelectedTimes[newChunks[i].conflictIndex] = [];
        await newChunks[i].setResolveInformation(
            resolveTooManyRunnerTimes, resolveTooFewRunnerTimes, timingData);
      } catch (e, stackTrace) {
        Logger.e('⚠️ Error setting resolve information for chunk $i',
            error: e, stackTrace: stackTrace);
      }
    }
    stopwatch.stop();
    Logger.d(
        'createChunks took [38;5;2m${stopwatch.elapsedMilliseconds}ms[0m');
    return newChunks;
  }

  /// Validates times for runners, returns error message or null if valid.
  static String? validateTimes(
    List<String> times,
    List<dynamic> runners,
    TimeRecord lastConfirmedRecord,
    TimeRecord conflictRecord,
  ) {
    // Example validation logic (copy from controller)
    if (times.any((t) => t.isEmpty || t == 'TBD')) {
      return 'All times must be entered.';
    }
    // Add more validation as needed
    return null;
  }

  /// Validates runner info, returns true if all runners have a bib number.
  static bool validateRunnerInfo(List<RunnerRecord> runnerRecords) {
    return runnerRecords.every(
        (runner) => runner.bib != '' && runner.bib.toString().isNotEmpty);
  }

  /// Resolves too few runner times conflict.
  static Future<ResolveInformation> resolveTooFewRunnerTimes(
    int conflictIndex,
    TimingData timingData,
    List<RunnerRecord> runnerRecords,
  ) async {
    Logger.d('_resolveTooFewRunnerTimes called');
    Logger.d('conflictIndex: $conflictIndex');
    Logger.d('timingData.records: ${timingData.records.map((r) => r.toMap())}');
    Logger.d('runnerRecords: ${runnerRecords.map((r) => r.toMap())}');
    var records = timingData.records;
    final bibData =
        runnerRecords.map((runner) => runner.bib.toString()).toList();
    final conflictRecord = records[conflictIndex];

    // Find the last confirmed record (non-runner time) before this conflict
    final lastConfirmedIndex = records
        .sublist(0, conflictIndex)
        .lastIndexWhere((record) => record.type != RecordType.runnerTime);

    // Get place of last confirmed record, or 0 if none exists
    final lastConfirmedPlace =
        lastConfirmedIndex == -1 ? 0 : records[lastConfirmedIndex].place;

    final firstConflictingRecordIndex = records
            .sublist(lastConfirmedIndex + 1, conflictIndex)
            .indexWhere((record) => record.conflict != null) +
        lastConfirmedIndex +
        1;
    if (firstConflictingRecordIndex == -1) {
      throw Exception('No conflicting records found');
    }

    // final startingIndex = lastConfirmedPlace ?? 0;

    final spaceBetweenConfirmedAndConflict = lastConfirmedIndex == -1
        ? 1
        : firstConflictingRecordIndex - lastConfirmedIndex;

    final List<TimeRecord> conflictingRecords = records.sublist(
        lastConfirmedIndex + spaceBetweenConfirmedAndConflict, conflictIndex);

    final List<String> conflictingTimes = conflictingRecords
        .where(
            (record) => record.elapsedTime != '' && record.elapsedTime != 'TBD')
        .map((record) => record.elapsedTime)
        .toList();
    // Safely create the runners list with boundary checks
    // final int calculatedEndIndex = startingIndex + spaceBetweenConfirmedAndConflict;

    // // Ensure we don't create a negative range or go out of bounds
    // final List<RunnerRecord> conflictingRunners;
    // if (startingIndex < 0 || startingIndex >= runnerRecords.length || startingIndex >= calculatedEndIndex) {
    //   conflictingRunners = [];
    //   Logger.e('⚠️ Invalid range for conflictingRunners: start=$startingIndex, end=$calculatedEndIndex');
    //   throw Exception('Invalid range for conflictingRunners');
    // } else {
    //   // Valid range, get the sublist
    //   conflictingRunners = List<RunnerRecord>.from(runnerRecords.sublist(startingIndex, calculatedEndIndex));
    // }

    return ResolveInformation(
      conflictingRunners: runnerRecords,
      lastConfirmedPlace: lastConfirmedPlace ?? 0,
      availableTimes: conflictingTimes,
      allowManualEntry: true,
      conflictRecord: conflictRecord,
      lastConfirmedRecord: lastConfirmedIndex == -1
          ? TimeRecord(
              elapsedTime: '',
              isConfirmed: false,
              type: RecordType.runnerTime,
              place: -1)
          : records[lastConfirmedIndex],
      bibData: bibData,
    );
  }

  static Future<ResolveInformation> resolveTooManyRunnerTimes(
    int conflictIndex,
    TimingData timingData,
    List<RunnerRecord> runnerRecords,
  ) async {
    Logger.d('_resolveTooManyRunnerTimes called');
    var records = (timingData.records as List<TimeRecord>?) ?? [];
    final bibData = runnerRecords.map((runner) => runner.bib).toList();
    final conflictRecord = records[conflictIndex];

    final lastConfirmedIndex = records
        .sublist(0, conflictIndex)
        .lastIndexWhere((record) => record.type != RecordType.runnerTime);

    final lastConfirmedPlace =
        lastConfirmedIndex == -1 ? 0 : records[lastConfirmedIndex].place ?? 0;

    final List<TimeRecord> conflictingRecords =
        records.sublist(lastConfirmedIndex + 1, conflictIndex);

    final List<String> conflictingTimes = conflictingRecords
        .where((record) => record.elapsedTime != '')
        .map((record) => record.elapsedTime)
        .where((time) => time != '' && time != 'TBD')
        .toList();

    // Limit availableTimes to runnerCount + offBy for extraTime conflicts
    int runnerCount = runnerRecords.length;
    int offBy = 1;
    final conflictData = conflictRecord.conflict?.data;
    if (conflictData != null && conflictData['offBy'] != null) {
      final dynamic rawOffBy = conflictData['offBy'];
      if (rawOffBy is int) {
        offBy = rawOffBy;
      } else if (rawOffBy is String) {
        offBy = int.tryParse(rawOffBy) ?? 1;
      }
    }
    int maxTimes = runnerCount + offBy;
    List<String> limitedTimes = conflictingTimes.length > maxTimes
        ? conflictingTimes.sublist(0, maxTimes)
        : conflictingTimes;
    // DEBUG: Print service-side times allocation
    Logger.d('[DEBUG] (Service) runnerCount: '
        '[36m$runnerCount[0m, offBy: $offBy, maxTimes: $maxTimes, conflictingTimes: $conflictingTimes, limitedTimes: $limitedTimes');
    // Safely determine end index with null check and boundary validation
    // final dynamic rawEndIndex = conflictRecord.conflict?.data?['numTimes'];
    // final int endIndex = rawEndIndex != null ?
    //     (rawEndIndex is int ? rawEndIndex : int.tryParse(rawEndIndex.toString()) ?? lastConfirmedPlace) :
    //     (conflictRecord.place ?? lastConfirmedPlace);\
    // final int endIndex = rawEndIndex;

    // if (endIndex > runnerRecords.length || endIndex < lastConfirmedPlace) {
    //   Logger.e('⚠️ Invalid end index: endIndex=$endIndex, runners length=${runnerRecords.length}');
    //   throw Exception('Invalid end index: endIndex must be less than or equal to runners length');
    // }

    // Create conflictingRunners with safe bounds
    // final List<RunnerRecord> conflictingRunners = lastConfirmedPlace < endIndex ?
    //     runnerRecords.sublist(lastConfirmedPlace, endIndex) : [];
    // Logger.d('Conflicting runners: $conflictingRunners');

    // Add more debug information
    Logger.d('lastConfirmedIndex: $lastConfirmedIndex');
    Logger.d('lastConfirmedPlace: $lastConfirmedPlace');

    // Create a safe lastConfirmedRecord that handles the case where lastConfirmedIndex is -1
    final TimeRecord safeLastConfirmedRecord = lastConfirmedIndex == -1
        ? TimeRecord(
            elapsedTime: '',
            isConfirmed: true,
            type: RecordType.confirmRunner,
            place: lastConfirmedPlace)
        : records[lastConfirmedIndex];

    return ResolveInformation(
      conflictingRunners: runnerRecords,
      conflictingTimes: limitedTimes,
      lastConfirmedPlace: lastConfirmedPlace,
      lastConfirmedRecord: safeLastConfirmedRecord,
      lastConfirmedIndex: lastConfirmedIndex,
      conflictRecord: conflictRecord,
      availableTimes: conflictingTimes,
      bibData: bibData,
    );
  }

  /// Updates a conflict record to mark it as resolved.
  static void updateConflictRecord(TimeRecord record, int numTimes) {
    record.type = RecordType.confirmRunner;
    record.place = numTimes;
    record.textColor = Colors.green.toString();
    record.isConfirmed = true;
    record.conflict = null;
    record.previousPlace = null;
  }

  /// Clears all conflict markers from timing records.
  static void clearAllConflicts(TimingData timingData) {
    Logger.d('Clearing all conflicts from timing data...');
    int currentPlace = 1;
    List<TimeRecord> confirmedRecords = [];
    List<TimeRecord> recordsWithPlaceholders = [];

    // First pass: update conflict records and identify runner time records
    for (int i = 0; i < timingData.records.length; i++) {
      final record = timingData.records[i];

      // Assign places to records without places
      if (record.place == null) {
        record.place = currentPlace;
        Logger.d(
            'Assigned missing place $currentPlace to record with time ${record.elapsedTime}');
      }

      // Handle conflict records (missingTime, extraTime)
      if (record.type == RecordType.missingTime ||
          record.type == RecordType.extraTime) {
        record.type = RecordType.confirmRunner;
        record.isConfirmed = true;
        record.textColor = Colors.green.toString();

        // Ensure conflict records have valid places
        if (record.place == null) {
          final int maxPlace = timingData.records
              .where((r) => r.place != null)
              .map((r) => r.place!)
              .fold(0, (max, place) => place > max ? place : max);
          record.place = maxPlace + 1;
          Logger.d(
              'Assigned fallback place ${record.place} to conflict record');
        }
      }

      // Handle runner time records
      if (record.type == RecordType.runnerTime) {
        // Add placeholders for empty times, but track these for later
        if (record.elapsedTime == 'TBD' || record.elapsedTime.isEmpty) {
          record.elapsedTime = '[38;5;1m$currentPlace.0[0m';
          Logger.e(
              'WARNING: Added placeholder time for record at place ${record.place}');
          throw Exception(
              'WARNING: Added placeholder time for record at place ${record.place}');
        }

        // Track maximum place seen
        if (record.place != null && record.place! > currentPlace) {
          currentPlace = record.place!;
        }

        // Mark as confirmed and collect for later sorting
        record.isConfirmed = true;
        confirmedRecords.add(record);
      }

      // Clear conflict markers
      record.conflict = null;
    }

    // Second pass: ensure places are sequential
    confirmedRecords.sort((a, b) => (a.place ?? 999).compareTo(b.place ?? 999));
    for (int i = 0; i < confirmedRecords.length; i++) {
      confirmedRecords[i].place = i + 1;

      // Update placeholder times to match new places
      if (recordsWithPlaceholders.contains(confirmedRecords[i])) {
        confirmedRecords[i].elapsedTime = '${confirmedRecords[i].place}.0';
      }
    }

    // Log results
    if (recordsWithPlaceholders.isNotEmpty) {
      Logger.d(
          'Created ${recordsWithPlaceholders.length} placeholder times for empty records');
    }
    Logger.d(
        'Fixed ${confirmedRecords.length} runner time records with proper places');
    Logger.d('All conflicts cleared from timing data');
  }
}
