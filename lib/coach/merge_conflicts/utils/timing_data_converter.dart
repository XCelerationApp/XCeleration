import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

class TimingDataConverter {
  static List<UIChunk> convertToUIChunks(
      List<TimingChunk> timingChunks, List<RaceRunner> runners) {
    final runnersCopy = List<RaceRunner>.from(runners);
    final uiChunks = <UIChunk>[];
    int startingPlace = 1;
    for (var chunk in timingChunks) {
      final uiChunk = UIChunk(
          timingChunkHash: chunk.hashCode,
          times: chunk.timingData.map((e) => e.time).toList(),
          allRunners: runnersCopy,
          conflictRecord: chunk.conflictRecord!,
          startingPlace: startingPlace);
      uiChunks.add(uiChunk);
      startingPlace += uiChunk.records.length;
    }
    return uiChunks;
  }
}

class UIChunk {
  final int timingChunkHash;
  late final List<String> initialTimes;
  List<String> times;
  final int startingPlace;

  late final String startTime;
  late final String endTime;
  late final Conflict conflict;
  late final List<RaceRunner> runners;

  List<UIRecord> get records {
    final records = <UIRecord>[];
    for (int i = 0; i < times.length; i++) {
      if (i < runners.length) {
        records.add(UIRecord(
            initialTime: times[i],
            place: i + startingPlace,
            runner: runners[i]));
      } else {
        records.add(UIRecord(initialTime: 'TBD', place: null, runner: null));
      }
    }
    return records;
  }

  UIChunk(
      {required this.timingChunkHash,
      required this.times,
      required List<RaceRunner> allRunners,
      required TimingDatum conflictRecord,
      required this.startingPlace}) {
    if (times.isEmpty) {
      throw Exception('Times list cannot be empty');
    }

    int runnersLength = times.length;
    if (conflict.type == ConflictType.extraTime) {
      runnersLength -= conflict.offBy;
    }

    // Check if we have enough runners available
    if (allRunners.length < runnersLength) {
      throw Exception('Not enough runners available for timing data');
    }

    runners =
        List<RaceRunner>.generate(runnersLength, (_) => allRunners.removeAt(0));
    startTime = times.first;
    conflict = conflictRecord.conflict!;
    endTime = conflictRecord.time;
    if (conflict.type == ConflictType.missingTime) {
      // Check if we have enough runners for the missing times
      if (allRunners.length < conflict.offBy) {
        throw Exception(
            'Not enough runners available for missing time conflict');
      }

      for (int i = 0; i < conflict.offBy; i++) {
        times.add('TBD');
        runners.add(allRunners.removeAt(0));
      }
    }

    initialTimes = times;
  }

  void reset() {
    times = initialTimes;
  }

  void onRemoveExtraTime(int chunkIndex) async {
    if (conflict.type != ConflictType.missingTime) {
      throw Exception('Cannot remove time for non-missing time conflict');
    }
    times.removeAt(chunkIndex);
  }

  void onMissingTimeSubmitted(
      BuildContext context, int chunkIndex, String newValue) {
    UIRecord record = records[chunkIndex];
    if (record.time != 'TBD') {
      throw Exception('Cannot replace a time that is not TBD');
    }
    // Validate the input
    if (newValue.isNotEmpty &&
        newValue != 'TBD' &&
        TimeFormatter.loadDurationFromString(newValue) == null) {
      // Invalid time format, show error and don't update
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid time format. Please use MM:SS.ms or SS.ms')),
      );
      record.timeController.text = record.initialTime;
      return;
    }
    record.timeController.text = newValue;
  }

  void onMissingTimeChanged(BuildContext context, int chunkIndex, String newValue) {
    UIRecord record = records[chunkIndex];
    if (record.time != 'TBD') {
      throw Exception('Cannot replace a time that is not TBD');
    }
    record.timeController.text = newValue;
  }
}

class UIRecord {
  final String initialTime;
  final int? place;
  final RaceRunner? runner;
  late final TextEditingController timeController;

  String get time => timeController.text;

  UIRecord({required this.initialTime, required this.place, this.runner}) {
    timeController = TextEditingController(text: initialTime);
  }
}
