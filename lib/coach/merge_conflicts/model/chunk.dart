import 'package:xceleration/assistant/race_timer/model/timing_record.dart';
import 'package:flutter/material.dart';
import 'package:xceleration/coach/merge_conflicts/model/resolve_information.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/utils/enums.dart';
import 'joined_record.dart';

class Chunk {
  final List<TimingRecord> records;
  final RecordType type;
  final List<RunnerRecord> runners;
  final int conflictIndex;
  List<JoinedRecord> joinedRecords;
  Map<String, List<TextEditingController>> controllers;
  ResolveInformation? resolve;

  Chunk({
    required this.records,
    required this.type,
    required this.runners,
    required this.conflictIndex,
  })  : joinedRecords = List.generate(
          runners.length,
          (j) => JoinedRecord(runner: runners[j], timeRecord: records[j]),
        ),
        controllers = {
          'timeControllers':
              List.generate(runners.length, (_) => TextEditingController()),
          'manualControllers':
              List.generate(runners.length, (_) => TextEditingController()),
        };

  factory Chunk.fromMap(
      Map<String, dynamic> map, List<RunnerRecord> runnerRecords) {
    return Chunk(
      records: List<TimingRecord>.from(map['records']),
      type: map['type'],
      runners: runnerRecords.sublist(
        map['place'] - 1,
        (map['conflict']?.data?['numTimes'] ?? map['place']),
      ),
      conflictIndex: map['conflictIndex'],
    );
  }

  Future<void> setResolveInformation(
    Future<ResolveInformation> Function(int) resolveTooManyRunnerTimes,
    Future<ResolveInformation> Function(int) resolveTooFewRunnerTimes,
  ) async {
    if (type == RecordType.extraRunner) {
      resolve = await resolveTooManyRunnerTimes(conflictIndex);
    } else if (type == RecordType.missingRunner) {
      resolve = await resolveTooFewRunnerTimes(conflictIndex);
    }
  }

  Future<void> handleResolve(
    Future<void> Function(Chunk) handleTooManyRunnerTimesResolve,
    Future<void> Function(Chunk) handleTooFewRunnerTimesResolve,
  ) async {
    if (type == RecordType.extraRunner) {
      await handleTooManyRunnerTimesResolve(this);
    } else if (type == RecordType.missingRunner) {
      await handleTooFewRunnerTimesResolve(this);
    }
  }
}
