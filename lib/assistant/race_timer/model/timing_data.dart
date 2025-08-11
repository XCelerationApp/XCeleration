import 'package:flutter/material.dart';
import 'package:xceleration/assistant/race_timer/model/ui_record.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../utils/timing_data_converter.dart';
import 'chunk_cacher.dart';

class TimingData with ChangeNotifier {
  TimingChunk currentChunk = TimingChunk(timingData: []);
  final ChunkCacher _chunkCacher = ChunkCacher();
  final TimingDataConverter _timingDataConverter = TimingDataConverter();
  DateTime? _startTime;
  Duration? _endTime;
  bool _raceStopped = true;

  DateTime? get startTime => _startTime;
  Duration? get endTime => _endTime;
  bool get raceStopped => _raceStopped;
  set raceStopped(bool value) {
    _raceStopped = value;
    notifyListeners();
  }

  void addRunnerTimeRecord(TimingDatum record) {
    if (record.conflict != null) {
      throw Exception('Runner time record cannot have a conflict');
    }
    if (!currentChunk.hasConflict) {
      currentChunk.timingData.add(record);
    } else {
      cacheCurrentChunk();
      currentChunk = TimingChunk(timingData: [record]);
    }
    notifyListeners();
  }

  void addConfirmRecord(TimingDatum record) {
    if (record.conflict?.type != ConflictType.confirmRunner) {
      throw Exception(
          'Confirm record must have a conflict of type confirmRunner');
    }
    if (!currentChunk.hasConflict) {
      currentChunk.conflictRecord = record;
    } else if (currentChunk.conflictRecord!.conflict?.type ==
        ConflictType.confirmRunner) {
      currentChunk.conflictRecord!.time = record.time;
    } else {
      cacheCurrentChunk();
      currentChunk = TimingChunk(timingData: [], conflictRecord: record);
    }
    notifyListeners();
  }

  void addMissingTimeRecord(TimingDatum record) {
    if (record.conflict?.type != ConflictType.missingTime) {
      throw Exception(
          'Missing time record must have a conflict of type missingTime');
    }
    if (!currentChunk.hasConflict) {
      currentChunk.conflictRecord = record;
    } else if (currentChunk.conflictRecord!.conflict?.type ==
        ConflictType.missingTime) {
      currentChunk.conflictRecord!.time = record.time;
      currentChunk.conflictRecord!.conflict!.offBy++;
    } else if (currentChunk.conflictRecord!.conflict?.type ==
        ConflictType.extraTime) {
      reduceCurrentConflictByOne(newTime: record.time);
    } else {
      cacheCurrentChunk();
      currentChunk = TimingChunk(timingData: [], conflictRecord: record);
    }
    notifyListeners();
  }

  void addExtraTimeRecord(TimingDatum record) {
    if (record.conflict?.type != ConflictType.extraTime) {
      throw Exception(
          'Extra time record must have a conflict of type extraTime');
    }
    if (!currentChunk.hasConflict) {
      currentChunk.conflictRecord = record;
    } else {
      final Conflict conflict = currentChunk.conflictRecord!.conflict!;
      if (conflict.type == ConflictType.extraTime) {
        currentChunk.conflictRecord!.time = record.time;
        currentChunk.conflictRecord!.conflict!.offBy++;
      } else if (currentChunk.conflictRecord!.conflict?.type ==
          ConflictType.missingTime) {
        reduceCurrentConflictByOne(newTime: record.time);
      } else {
        cacheCurrentChunk();
        currentChunk = TimingChunk(timingData: [], conflictRecord: record);
      }
    }
    notifyListeners();
  }

  void reduceCurrentConflictByOne({String? newTime}) {
    currentChunk.conflictRecord!.time =
        newTime ?? currentChunk.conflictRecord!.time;
    currentChunk.conflictRecord!.conflict!.offBy--;
    if (currentChunk.conflictRecord!.conflict!.offBy == 0) {
      currentChunk.conflictRecord = null;
    }
    notifyListeners();
  }

  void cacheCurrentChunk() {
    _chunkCacher.cacheChunk(currentChunk);
  }

  void deleteCurrentChunk() {
    if (_chunkCacher.isEmpty) {
      currentChunk = TimingChunk(timingData: []);
    } else {
      final TimingChunk? restoredChunk =
          _chunkCacher.restoreLastChunkFromCache();
      if (restoredChunk == null) {
        currentChunk = TimingChunk(timingData: []);
      } else {
        currentChunk = restoredChunk;
      }
    }
    notifyListeners();
  }

  void changeStartTime(DateTime? time) {
    _startTime = time;
    notifyListeners();
  }

  void changeEndTime(Duration? time) {
    _endTime = time;
    notifyListeners();
  }

  bool get hasTimingData =>
      currentChunk.timingData.isNotEmpty ||
      currentChunk.conflictRecord != null ||
      !_chunkCacher.isEmpty;

  Future<String> encodedRecords() async {
    final List<TimingChunk> chunks = [];
    if (!currentChunk.isEmpty) {
      if (!currentChunk.hasConflict && endTime != null) {
        currentChunk.conflictRecord = TimingDatum(
            time: endTime!.toString(),
            conflict: Conflict(type: ConflictType.confirmRunner));
      }
      chunks.add(currentChunk);
    }
    while (true) {
      final TimingChunk? chunk = _chunkCacher.restoreLastChunkFromCache();
      if (chunk == null) {
        break;
      }
      chunks.add(chunk);
    }

    final List<TimingDatum> records = [];
    for (TimingChunk chunk in chunks.reversed) {
      records.addAll(chunk.timingData);
      if (chunk.hasConflict) {
        records.add(chunk.conflictRecord!);
      }
    }

    return await TimingEncodeUtils.encodeTimeRecords(records);
  }

  List<UIRecord> get uiRecords {
    List<UIRecord> records = [];
    // add cached chunks
    List<UIChunk> cachedChunks = _chunkCacher.cachedChunks;
    records.addAll(cachedChunks.expand((chunk) => chunk.records));

    // Calculate starting place from last cached chunk's endingPlace if available
    int startingPlace = 1;
    if (cachedChunks.isNotEmpty) {
      startingPlace = cachedChunks.last.endingPlace;
    }

    // add current chunk
    final currentChunkRecords =
        TimingDataConverter.convertToUIChunk(currentChunk, startingPlace)
            .records;
    records.addAll(currentChunkRecords);
    return records;
  }

  void clearRecords() {
    currentChunk.timingData.clear();
    currentChunk.conflictRecord = null;
    _chunkCacher.clear();
    _timingDataConverter.clearCache();
    _startTime = null;
    _endTime = null;
    notifyListeners();
  }
}
