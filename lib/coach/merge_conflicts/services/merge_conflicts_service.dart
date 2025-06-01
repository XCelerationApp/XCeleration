import '../model/timing_data.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import '../model/chunk.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:flutter/material.dart';
import '../../../assistant/race_timer/model/timing_record.dart';
import '../model/resolve_information.dart';
import '../../../utils/enums.dart';
import 'dart:async';

class MergeConflictsService {
  /// Handles chunk creation and validation logic, extracted from MergeConflictsController.
  static Future<List<Chunk>> createChunks({
    required TimingData timingData,
    required List<RunnerRecord> runnerRecords,
    required Future<ResolveInformation> Function(int, TimingData, List<RunnerRecord>) resolveTooManyRunnerTimes,
    required Future<ResolveInformation> Function(int, TimingData, List<RunnerRecord>) resolveTooFewRunnerTimes,
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
      Logger.d('Runner $i: place=${i+1}, bib=${r.bib}, name=${r.name}');
    }
    Logger.d('--- DEBUG: All timingData.records before chunking ---');
    for (int i = 0; i < timingData.records.length; i++) {
      final rec = timingData.records[i];
      Logger.d('Record $i: place=${rec.place}, elapsedTime=${rec.elapsedTime}, type=${rec.type}');
    }

    for (int i = 0; i < records.length; i += 1) {
      try {
        Logger.d('Processing record: index=$i, record=${records[i]}');
        Logger.d('Record type: ${records[i].type}, place: ${records[i].place}, conflict: ${records[i].conflict?.data}');
        if (i >= records.length - 1 || records[i].type != RecordType.runnerTime) {
          // Break off a chunk after a non-runnerTime record
          final chunkRecords = records.sublist(startIndex, i + 1);
          Logger.d('Creating chunk with records.sublist($startIndex, ${i + 1})');
          newChunks.add(Chunk(
            records: chunkRecords,
            type: records[i].type,
            runners: runnerRecords, // Pass all runners; Chunk will filter
            conflictIndex: i,
          ));
          startIndex = i + 1;
        }
      } catch (e, stackTrace) {
        Logger.e('⚠️ Error processing record at index $i', e, stackTrace);
        continue;
      }
    }
    Logger.d('Chunks created: $newChunks');
    Logger.d('Final chunk runner total: ${newChunks.fold<int>(0, (sum, c) => sum + c.runners.length)} (should match runnerRecords.length: ${runnerRecords.length})');
    Logger.d('Final chunk record total: ${newChunks.fold<int>(0, (sum, c) => sum + c.records.length)} (should match records.length: ${records.length})');
    for (int i = 0; i < newChunks.length; i += 1) {
      try {
        localSelectedTimes[newChunks[i].conflictIndex] = [];
        await newChunks[i].setResolveInformation(
            resolveTooManyRunnerTimes, resolveTooFewRunnerTimes, timingData);
      } catch (e, stackTrace) {
        Logger.e('⚠️ Error setting resolve information for chunk $i', e, stackTrace);
      }
    }
    stopwatch.stop();
    Logger.d('createChunks took [38;5;2m${stopwatch.elapsedMilliseconds}ms[0m');
    return newChunks;
  }

  /// Validates times for runners, returns error message or null if valid.
  static String? validateTimes(
    List<String> times,
    List<dynamic> runners,
    TimingRecord lastConfirmedRecord,
    TimingRecord conflictRecord,
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
    return runnerRecords.every((runner) => runner.bib != '' && runner.bib.toString().isNotEmpty);
  }

  /// Resolves too few runner times conflict.
  static Future<ResolveInformation> resolveTooFewRunnerTimes(
    int conflictIndex,
    TimingData timingData,
    List<RunnerRecord> runnerRecords,
  ) async {
    var records = timingData.records;
    final bibData =
        runnerRecords.map((runner) => runner.bib.toString()).toList();
    final conflictRecord = records[conflictIndex];

    final lastConfirmedIndex = records
        .sublist(0, conflictIndex)
        .lastIndexWhere((record) => record.type != RecordType.runnerTime);

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

    final startingIndex = lastConfirmedPlace ?? 0;

    final spaceBetweenConfirmedAndConflict = lastConfirmedIndex == -1
        ? 1
        : firstConflictingRecordIndex - lastConfirmedIndex;

    final List<TimingRecord> conflictingRecords = records.sublist(
        lastConfirmedIndex + spaceBetweenConfirmedAndConflict, conflictIndex);

    final List<String> conflictingTimes = conflictingRecords
        .where((record) => record.elapsedTime != '')
        .map((record) => record.elapsedTime)
        .where((time) => time != '' && time != 'TBD')
        .toList();
    // Safely create the runners list with boundary checks
    final int calculatedEndIndex = startingIndex + spaceBetweenConfirmedAndConflict;
    final int safeEndIndex = calculatedEndIndex > runnerRecords.length ? runnerRecords.length : calculatedEndIndex;
  
    // Ensure we don't create a negative range or go out of bounds
    final List<RunnerRecord> conflictingRunners;
    if (startingIndex < 0 || startingIndex >= runnerRecords.length || startingIndex >= safeEndIndex) {
      conflictingRunners = [];
      Logger.d('⚠️ Invalid range for conflictingRunners: start=$startingIndex, end=$safeEndIndex');
    } else {
      conflictingRunners = List<RunnerRecord>.from(runnerRecords.sublist(startingIndex, safeEndIndex));
    }

    return ResolveInformation(
      conflictingRunners: conflictingRunners,
      lastConfirmedPlace: lastConfirmedPlace ?? 0,
      availableTimes: conflictingTimes,
      allowManualEntry: true,
      conflictRecord: conflictRecord,
      lastConfirmedRecord: lastConfirmedIndex == -1 ? TimingRecord(place: -1, elapsedTime: '') : records[lastConfirmedIndex],
      bibData: bibData,
    );
  }

  static Future<ResolveInformation> resolveTooManyRunnerTimes(
      int conflictIndex,
      TimingData timingData,
      List<RunnerRecord> runnerRecords,
      ) async {
    Logger.d('_resolveTooManyRunnerTimes called');
    var records = (timingData.records as List<TimingRecord>?) ?? [];
    final bibData = runnerRecords.map((runner) => runner.bib).toList();
    final conflictRecord = records[conflictIndex];

    final lastConfirmedIndex = records
        .sublist(0, conflictIndex)
        .lastIndexWhere((record) => record.type != RecordType.runnerTime);
    
    final lastConfirmedPlace =
        lastConfirmedIndex == -1 ? 0 : records[lastConfirmedIndex].place ?? 0;

    final List<TimingRecord> conflictingRecords =
        records.sublist(lastConfirmedIndex + 1, conflictIndex);

    final List<String> conflictingTimes = conflictingRecords
        .where((record) => record.elapsedTime != '')
        .map((record) => record.elapsedTime)
        .where((time) => time != '' && time != 'TBD')
        .toList();
    // Safely determine end index with null check and boundary validation
    final dynamic rawEndIndex = conflictRecord.conflict?.data?['numTimes'];
    final int endIndex = rawEndIndex != null ? 
        (rawEndIndex is int ? rawEndIndex : int.tryParse(rawEndIndex.toString()) ?? lastConfirmedPlace) : 
        (conflictRecord.place ?? lastConfirmedPlace);
  
    // Ensure we don't exceed the bounds of runnerRecords
    final int safeEndIndex = endIndex > runnerRecords.length ? runnerRecords.length : endIndex;
  
    // Create conflictingRunners with safe bounds
    final List<RunnerRecord> conflictingRunners = lastConfirmedPlace < safeEndIndex ?
        runnerRecords.sublist(lastConfirmedPlace, safeEndIndex) : [];
    Logger.d('Conflicting runners: $conflictingRunners');

    // Add more debug information
    Logger.d('lastConfirmedIndex: $lastConfirmedIndex');
    Logger.d('lastConfirmedPlace: $lastConfirmedPlace');
    
    // Create a safe lastConfirmedRecord that handles the case where lastConfirmedIndex is -1
    final TimingRecord safeLastConfirmedRecord = lastConfirmedIndex == -1 ? 
        TimingRecord(place: lastConfirmedPlace, elapsedTime: '', isConfirmed: true) : 
        records[lastConfirmedIndex];
    
    return ResolveInformation(
      conflictingRunners: conflictingRunners,
      conflictingTimes: conflictingTimes,
      lastConfirmedPlace: lastConfirmedPlace,
      lastConfirmedRecord: safeLastConfirmedRecord,
      lastConfirmedIndex: lastConfirmedIndex,
      conflictRecord: conflictRecord,
      availableTimes: conflictingTimes,
      bibData: bibData,
    );
  }

  /// Updates a conflict record to mark it as resolved.
  static void updateConflictRecord(TimingRecord record, int numTimes) {
    record.type = RecordType.confirmRunner;
    record.place = numTimes;
    record.textColor = Colors.green;
    record.isConfirmed = true;
    record.conflict = null;
    record.previousPlace = null;
  }

  /// Clears all conflict markers from timing records.
  static void clearAllConflicts(TimingData timingData) {
    Logger.d('Clearing all conflicts from timing data...');
    int currentPlace = 1;
    List<TimingRecord> confirmedRecords = [];
    for (int i = 0; i < timingData.records.length; i++) {
      final record = timingData.records[i];
      if (record.place == null) {
        record.place = currentPlace;
        Logger.d('Assigned missing place $currentPlace to record with time ${record.elapsedTime}');
      }
      if (record.type == RecordType.missingRunner || record.type == RecordType.extraRunner) {
        record.type = RecordType.confirmRunner;
        record.isConfirmed = true;
        record.textColor = Colors.green;
        if (record.place == null) {
          final int maxPlace = timingData.records.where((r) => r.place != null).map((r) => r.place!).fold(0, (max, place) => place > max ? place : max);
          record.place = maxPlace + 1;
          Logger.d('Assigned fallback place ${record.place} to conflict record');
        }
      }
      if (record.type == RecordType.runnerTime) {
        if (record.elapsedTime == 'TBD' || record.elapsedTime.isEmpty) {
          record.elapsedTime = '[38;5;1m$currentPlace.0[0m';
          Logger.e('WARNING: Added placeholder time for record at place ${record.place}');
          throw Exception('WARNING: Added placeholder time for record at place ${record.place}');
        }
        if (record.place! > currentPlace) {
          currentPlace = record.place!;
        }
        record.isConfirmed = true;
        confirmedRecords.add(record);
      }
      record.conflict = null;
    }
    confirmedRecords.sort((a, b) => (a.place ?? 999).compareTo(b.place ?? 999));
    for (int i = 0; i < confirmedRecords.length; i++) {
      confirmedRecords[i].place = i + 1;
    }
    Logger.d('Fixed ${confirmedRecords.length} runner time records with proper places');
    Logger.d('All conflicts cleared from timing data');
  }
} 