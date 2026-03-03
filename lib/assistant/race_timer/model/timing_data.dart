import 'package:flutter/material.dart';
import 'package:xceleration/assistant/race_timer/model/ui_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../utils/timing_data_converter.dart';
import 'chunk_cacher.dart';
import '../../shared/services/assistant_storage_service.dart';
import 'package:xceleration/core/utils/logger.dart';

class TimingData with ChangeNotifier {
  TimingChunk currentChunk = TimingChunk(id: 0, timingData: []);
  final AssistantStorageService _storage;
  final ChunkCacher _chunkCacher;
  final TimingDataConverter _timingDataConverter;
  DateTime? _startTime;

  TimingData({
    required AssistantStorageService storage,
    ChunkCacher? chunkCacher,
    TimingDataConverter? timingDataConverter,
  })  : _storage = storage,
        _chunkCacher = chunkCacher ?? ChunkCacher(),
        _timingDataConverter = timingDataConverter ?? TimingDataConverter();
  Duration? _raceDuration;
  bool _raceStopped = true;
  RaceRecord? _currentRace;

  DateTime? get startTime => _startTime;
  Duration? get raceDuration => _raceDuration;
  bool get raceStopped => _raceStopped;
  RaceRecord? get currentRace => _currentRace;

  set raceStopped(bool value) {
    if (_raceStopped == value) {
      return;
    }
    if (_currentRace == null) {
      throw Exception('Race isn\'t loaded');
    }
    _storage.updateRaceStatus(_currentRace!.raceId, _currentRace!.type, value);
    _raceStopped = value;

    notifyListeners();
  }

  set startTime(DateTime? time) {
    if (_startTime == time) {
      return;
    }
    if (_currentRace == null) {
      throw Exception('Race isn\'t loaded');
    }
    _startTime = time;
    _storage.updateRaceStartTime(
        _currentRace!.raceId, _currentRace!.type, time);
    notifyListeners();
  }

  set raceDuration(Duration? duration) {
    if (_raceDuration == duration) {
      return;
    }
    if (_currentRace == null) {
      throw Exception('Race isn\'t loaded');
    }
    _raceDuration = duration;
    _storage.updateRaceDuration(
        _currentRace!.raceId, _currentRace!.type, duration);
    notifyListeners();
  }

  set currentRace(RaceRecord? race) {
    if (_currentRace == race) {
      return;
    }
    _currentRace = race;
    notifyListeners();
  }

  void addRunnerTimeRecord(TimingDatum record) {
    if (record.conflict != null) {
      throw Exception('Runner time record cannot have a conflict');
    }
    if (!currentChunk.hasConflict) {
      currentChunk.timingData.add(record);
      _storage.addLoggedTimingDatum(
          _currentRace!.raceId, currentChunk.id, record);
    } else {
      final int chunkId = currentChunk.id;
      cacheCurrentChunk();
      currentChunk = TimingChunk(id: chunkId + 1, timingData: [record]);
      _saveCurrentChunkInDatabase();
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
      _storage.saveChunkConflict(_currentRace!.raceId, currentChunk.id, record);
    } else if (currentChunk.conflictRecord!.conflict?.type ==
        ConflictType.confirmRunner) {
      currentChunk.conflictRecord!.time = record.time;
      _storage.saveChunkConflict(
          _currentRace!.raceId, currentChunk.id, currentChunk.conflictRecord!);
    } else {
      final int chunkId = currentChunk.id;
      cacheCurrentChunk();
      currentChunk =
          TimingChunk(id: chunkId + 1, timingData: [], conflictRecord: record);

      _saveCurrentChunkInDatabase();
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
      _storage.saveChunkConflict(_currentRace!.raceId, currentChunk.id, record);
    } else if (currentChunk.conflictRecord!.conflict?.type ==
        ConflictType.missingTime) {
      currentChunk.conflictRecord!.time = record.time;
      currentChunk.conflictRecord!.conflict!.offBy++;
      _storage.saveChunkConflict(
          _currentRace!.raceId, currentChunk.id, currentChunk.conflictRecord!);
    } else if (currentChunk.conflictRecord!.conflict?.type ==
        ConflictType.extraTime) {
      reduceCurrentConflictByOne(newTime: record.time);
      _storage.saveChunkConflict(
          _currentRace!.raceId, currentChunk.id, currentChunk.conflictRecord!);
    } else {
      final int chunkId = currentChunk.id;
      cacheCurrentChunk();
      currentChunk =
          TimingChunk(id: chunkId + 1, timingData: [], conflictRecord: record);
      _saveCurrentChunkInDatabase();
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
      _storage.saveChunkConflict(_currentRace!.raceId, currentChunk.id, record);
    } else {
      final Conflict conflict = currentChunk.conflictRecord!.conflict!;
      if (conflict.type == ConflictType.extraTime) {
        currentChunk.conflictRecord!.time = record.time;
        currentChunk.conflictRecord!.conflict!.offBy++;
        _storage.saveChunkConflict(_currentRace!.raceId, currentChunk.id,
            currentChunk.conflictRecord!);
      } else if (currentChunk.conflictRecord!.conflict?.type ==
          ConflictType.missingTime) {
        reduceCurrentConflictByOne(newTime: record.time);
        _storage.saveChunkConflict(_currentRace!.raceId, currentChunk.id,
            currentChunk.conflictRecord!);
      } else {
        final int chunkId = currentChunk.id;
        cacheCurrentChunk();
        currentChunk = TimingChunk(
            id: chunkId + 1, timingData: [], conflictRecord: record);
        _saveCurrentChunkInDatabase();
      }
    }
    notifyListeners();
  }

  void reduceCurrentConflictByOne({String? newTime}) {
    if (currentChunk.conflictRecord == null ||
        currentChunk.conflictRecord!.conflict == null) {
      return;
    }
    if (newTime != null) {
      currentChunk.conflictRecord!.time = newTime;
    }
    final Conflict conflict = currentChunk.conflictRecord!.conflict!;
    conflict.offBy = conflict.offBy - 1;
    if (conflict.offBy <= 0) {
      currentChunk.conflictRecord = null;
    }
    notifyListeners();
  }

  void cacheCurrentChunk() {
    _chunkCacher.cacheChunk(currentChunk);
  }

  /// Caches a chunk in memory only, without saving to database
  void cacheChunkInMemoryOnly(TimingChunk chunk) {
    _chunkCacher.cacheChunk(chunk);
  }

  void _saveCurrentChunkInDatabase() {
    if (_currentRace != null) {
      _storage.saveChunk(_currentRace!.raceId, currentChunk);
    } else {
      Logger.e('Skipping save - no race loaded');
    }
  }

  void deleteCurrentChunk() {
    if (_chunkCacher.isEmpty) {
      currentChunk = TimingChunk(id: 0, timingData: []);
    } else {
      final TimingChunk? restoredChunk =
          _chunkCacher.restoreLastChunkFromCache(currentChunk.id);
      if (restoredChunk == null) {
        currentChunk = TimingChunk(id: currentChunk.id - 1, timingData: []);
      } else {
        currentChunk = restoredChunk;
      }
    }
    notifyListeners();
  }

  bool get hasTimingData =>
      currentChunk.timingData.isNotEmpty ||
      currentChunk.conflictRecord != null ||
      !_chunkCacher.isEmpty;

  Future<String> encodedRecords() async {
    final List<TimingChunk> chunks = [];
    if (!currentChunk.isEmpty) {
      final bool shouldAddConfirm =
          !currentChunk.hasConflict && raceDuration != null;
      if (shouldAddConfirm) {
        currentChunk.conflictRecord = TimingDatum(
            time: raceDuration!.toString(),
            conflict: Conflict(type: ConflictType.confirmRunner));
      }
      chunks.add(currentChunk);
    }
    while (true) {
      final TimingChunk? chunk =
          _chunkCacher.restoreLastChunkFromCache(currentChunk.id);
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
    _raceDuration = null;
    notifyListeners();
  }
}
