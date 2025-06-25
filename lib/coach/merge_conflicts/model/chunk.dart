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

  Chunk({
    required this.records,
    required this.type,
    required List<RunnerRecord> runners,
    required this.conflictIndex,
  })  : joinedRecords = [],
        controllers = {} {
    // Only keep runners whose (index+1) matches a record's place in this chunk
    final recordPlaces = records.map((r) => r.place).toSet();
    this.runners = [];

    // Filter runners and log those that are missing
    for (int i = 0; i < runners.length; i++) {
      if (recordPlaces.contains(i + 1)) {
        this.runners.add(runners[i]);
      } else {
        Logger.d('Runner ${runners[i].bib} is missing from this chunk');
      }
    }
    // Build joinedRecords by matching runner index+1 to record.place
    joinedRecords = [];
    for (final record in records) {
      if (record.type == RecordType.runnerTime &&
          record.place != null &&
          record.place! > 0) {
        final placeIdx = record.place! - 1;
        if (placeIdx >= 0 &&
            placeIdx < runners.length &&
            recordPlaces.contains(record.place)) {
          joinedRecords
              .add(JoinedRecord(runner: runners[placeIdx], timeRecord: record));
        }
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
