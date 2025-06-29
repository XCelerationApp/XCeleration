import '../../../core/utils/enums.dart';
import '../../../shared/models/time_record.dart';
import 'package:flutter/material.dart';
import 'package:xceleration/coach/merge_conflicts/model/resolve_information.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'joined_record.dart';
import 'timing_data.dart';

class Chunk {
  final List<TimeRecord> records;
  final RecordType type;
  late final List<RunnerRecord> runners;
  final int conflictIndex;
  List<JoinedRecord> joinedRecords;
  Map<String, List<TextEditingController>> controllers;
  ResolveInformation? resolve;
  TimingData? timingData;

  // Track removed time indices for extra time conflicts
  Set<int> removedTimeIndices = <int>{};

  Chunk({
    required this.records,
    required this.type,
    required List<RunnerRecord> runners,
    required this.conflictIndex,
  })  : joinedRecords = [],
        controllers = {} {
    // Include runners whose places match any record in this chunk
    final recordPlaces = records.map((r) => r.place).toSet();
    this.runners = [];

    // Filter runners based on places that exist in this chunk's records
    for (int i = 0; i < runners.length; i++) {
      final runnerPlace = i + 1;
      if (recordPlaces.contains(runnerPlace)) {
        this.runners.add(runners[i]);
        Logger.d(
            'Including runner ${runners[i].bib} (place $runnerPlace) in chunk');
      } else {
        Logger.d(
            'Runner ${runners[i].bib} (place $runnerPlace) is missing from this chunk - recordPlaces: $recordPlaces');
      }
    }
    // Build joinedRecords by matching runner index+1 to record.place
    joinedRecords = [];

    // Create joinedRecords for each runner that has a place in this chunk
    for (final runner in this.runners) {
      final runnerPlace = runners.indexOf(runner) + 1;

      // Find the primary record for this runner (prefer runnerTime, then others)
      TimeRecord? primaryRecord;

      // First try to find a runnerTime record for this place
      for (final record in records) {
        if (record.place == runnerPlace &&
            record.type == RecordType.runnerTime) {
          primaryRecord = record;
          break;
        }
      }

      // If no runnerTime record found, use any record with this place
      if (primaryRecord == null) {
        for (final record in records) {
          if (record.place == runnerPlace) {
            primaryRecord = record;
            break;
          }
        }
      }

      // If we found a record for this runner, create a joinedRecord
      if (primaryRecord != null) {
        joinedRecords
            .add(JoinedRecord(runner: runner, timeRecord: primaryRecord));
      }
    }
    // Use runners.length for controllers since they're based on runners
    controllers = {
      'timeControllers':
          List.generate(this.runners.length, (_) => TextEditingController()),
      'manualControllers':
          List.generate(this.runners.length, (_) => TextEditingController()),
    };
  }

  factory Chunk.fromMap(
      Map<String, dynamic> map, List<RunnerRecord> runnerRecords) {
    return Chunk(
      records: List<TimeRecord>.from(map['records']),
      type: map['type'],
      runners: runnerRecords.sublist(
        map['place'] - 1,
        (map['conflict']?.data?['numTimes'] ?? map['place']),
      ),
      conflictIndex: map['conflictIndex'],
    );
  }

  Future<void> setResolveInformation(
    Future<ResolveInformation> Function(int, TimingData, List<RunnerRecord>)
        resolveTooManyRunnerTimes,
    Future<ResolveInformation> Function(int, TimingData, List<RunnerRecord>)
        resolveTooFewRunnerTimes,
    TimingData timing,
  ) async {
    timingData = timing;
    if (type == RecordType.extraTime) {
      resolve =
          await resolveTooManyRunnerTimes(conflictIndex, timingData!, runners);
    } else if (type == RecordType.missingTime) {
      resolve =
          await resolveTooFewRunnerTimes(conflictIndex, timingData!, runners);
    }
  }

  /// Update the removed time indices from the UI
  void updateRemovedTimeIndices(Set<int> indices) {
    removedTimeIndices = Set.from(indices);
    Logger.d('Chunk: Updated removedTimeIndices to $removedTimeIndices');
  }

  /// Get the list of times that should be removed based on UI selections
  List<String> getRemovedTimes() {
    if (resolve?.availableTimes == null) return [];

    return removedTimeIndices
        .where((index) => index < resolve!.availableTimes.length)
        .map((index) => resolve!.availableTimes[index])
        .toList();
  }

  Future<void> handleResolve(
    Future<void> Function(Chunk) handleTooManyRunnerTimesResolve,
    Future<void> Function(Chunk) handleTooFewRunnerTimesResolve,
  ) async {
    if (type == RecordType.extraTime) {
      await handleTooManyRunnerTimesResolve(this);
    } else if (type == RecordType.missingTime) {
      await handleTooFewRunnerTimesResolve(this);
    }
  }
}
