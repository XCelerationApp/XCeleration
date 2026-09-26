import 'package:flutter/material.dart';
import 'package:xceleration/assistant/race_timer/model/ui_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/time_shift.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../utils/timing_data_converter.dart';
import 'chunk_cacher.dart';
import '../../shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/utils/time_formatter.dart';

class TimingData with ChangeNotifier {
  TimingChunk currentChunk = TimingChunk(id: 0, timingData: []);
  final IAssistantStorageService _storage;
  final ChunkCacher _chunkCacher;
  final RaceTimerDataConverter _timingDataConverter;
  DateTime? _startTime;
  List<UIRecord>? _cachedUiRecords;

  /// Fires when [currentRace] changes. Widgets that only show race identity
  /// (name, date) should listen to this instead of the main controller.
  final ValueNotifier<int> raceInfoSignal = ValueNotifier(0);

  /// Fires when [raceStopped], [startTime], or [raceDuration] changes. Widgets
  /// that control or display race-running state should listen to this.
  final ValueNotifier<int> raceStateSignal = ValueNotifier(0);

  /// Fires when the records list changes (any log/conflict/delete/clear).
  /// Widgets that display or depend on timing records should listen to this.
  final ValueNotifier<int> recordsSignal = ValueNotifier(0);

  /// [now] is the phone's clock and [monotonic] a clock that only moves
  /// forward; both can be replaced in tests.
  TimingData({
    required IAssistantStorageService storage,
    ChunkCacher? chunkCacher,
    RaceTimerDataConverter? timingDataConverter,
    DateTime Function()? now,
    Duration Function()? monotonic,
  })  : _storage = storage,
        _chunkCacher = chunkCacher ?? ChunkCacher(),
        _timingDataConverter = timingDataConverter ?? RaceTimerDataConverter(),
        _now = now ?? DateTime.now,
        _monotonic = monotonic ?? _appClockElapsed;

  static final Stopwatch _appClock = Stopwatch()..start();
  static Duration _appClockElapsed() => _appClock.elapsed;

  final DateTime Function() _now;
  final Duration Function() _monotonic;

  // Race time at the anchor and the monotonic clock's reading then. Reset
  // (to null) whenever the start time, running state or race changes.
  Duration? _anchorRaceTime;
  Duration _anchorMonotonic = Duration.zero;

  /// The phone's clock, read through the same source as [raceElapsed].
  DateTime get clockNow => _now();

  /// The race clock: time since the start while running, or the final time
  /// once stopped.
  ///
  /// The phone's clock is only read once, when the race starts, continues or
  /// is reopened; after that time is measured with a clock that can't go
  /// backwards. Reading the phone's clock on every tap meant a clock change
  /// mid-race (e.g. an automatic time sync) could make a later runner's time
  /// earlier than the one before, and reorder the results.
  Duration get raceElapsed {
    final start = _startTime;
    if (start == null) return _raceDuration ?? Duration.zero;
    if (_raceStopped) return _raceDuration ?? _now().difference(start);
    final anchor = _anchorRaceTime;
    if (anchor == null) {
      _anchorRaceTime = _now().difference(start);
      _anchorMonotonic = _monotonic();
      return _anchorRaceTime!;
    }
    return anchor + (_monotonic() - _anchorMonotonic);
  }
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
    _anchorRaceTime = null;
    raceStateSignal.value++;
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
    _anchorRaceTime = null;
    _storage.updateRaceStartTime(
        _currentRace!.raceId, _currentRace!.type, time);
    raceStateSignal.value++;
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
    raceStateSignal.value++;
    notifyListeners();
  }

  set currentRace(RaceRecord? race) {
    if (_currentRace == race) {
      return;
    }
    _currentRace = race;
    _anchorRaceTime = null;
    _timeShift = Duration.zero;
    raceInfoSignal.value++;
    notifyListeners();
  }

  void addRunnerTimeRecord(TimingDatum record) {
    if (record.conflict != null) {
      throw Exception('Runner time record cannot have a conflict');
    }
    if (!currentChunk.hasConflict) {
      currentChunk.timingData.add(record);
      _saveCurrentChunkInDatabase();
    } else {
      final int chunkId = currentChunk.id;
      cacheCurrentChunk();
      currentChunk = TimingChunk(id: chunkId + 1, timingData: [record]);
      _saveCurrentChunkInDatabase();
    }
    _cachedUiRecords = null;
    recordsSignal.value++;
    notifyListeners();
  }

  void addConfirmRecord(TimingDatum record) {
    if (record.conflict?.type != ConflictType.confirmRunner) {
      throw Exception(
          'Confirm record must have a conflict of type confirmRunner');
    }
    if (!currentChunk.hasConflict) {
      currentChunk.conflictRecord = record;
      _saveCurrentChunkInDatabase();
    } else if (currentChunk.conflictRecord!.conflict?.type ==
        ConflictType.confirmRunner) {
      currentChunk.conflictRecord!.time = record.time;
      _saveCurrentChunkInDatabase();
    } else {
      final int chunkId = currentChunk.id;
      cacheCurrentChunk();
      currentChunk =
          TimingChunk(id: chunkId + 1, timingData: [], conflictRecord: record);

      _saveCurrentChunkInDatabase();
    }
    _cachedUiRecords = null;
    recordsSignal.value++;
    notifyListeners();
  }

  void addMissingTimeRecord(TimingDatum record) {
    if (record.conflict?.type != ConflictType.missingTime) {
      throw Exception(
          'Missing time record must have a conflict of type missingTime');
    }
    if (!currentChunk.hasConflict) {
      currentChunk.conflictRecord = record;
      _saveCurrentChunkInDatabase();
    } else if (currentChunk.conflictRecord!.conflict?.type ==
        ConflictType.missingTime) {
      currentChunk.conflictRecord!.time = record.time;
      currentChunk.conflictRecord!.conflict!.offBy++;
      _saveCurrentChunkInDatabase();
    } else {
      // Note: an open extra-time conflict is NOT cancelled by this press.
      // They are two separate things that happened (a stray time, and then a
      // missed runner), and cancelling them out lost both: the stray stayed
      // in the results as a finisher and the missed runner vanished. The
      // extra-time chunk is closed and the missing time starts a new one.
      // To take back a press, use undo.

      final int chunkId = currentChunk.id;
      cacheCurrentChunk();
      currentChunk =
          TimingChunk(id: chunkId + 1, timingData: [], conflictRecord: record);
      _saveCurrentChunkInDatabase();
    }
    _cachedUiRecords = null;
    recordsSignal.value++;
    notifyListeners();
  }

  void addExtraTimeRecord(TimingDatum record) {
    if (record.conflict?.type != ConflictType.extraTime) {
      throw Exception(
          'Extra time record must have a conflict of type extraTime');
    }
    if (!currentChunk.hasConflict) {
      currentChunk.conflictRecord = record;
      _saveCurrentChunkInDatabase();
    } else {
      final Conflict conflict = currentChunk.conflictRecord!.conflict!;
      if (conflict.type == ConflictType.extraTime) {
        currentChunk.conflictRecord!.time = record.time;
        currentChunk.conflictRecord!.conflict!.offBy++;
        _saveCurrentChunkInDatabase();
      } else if (currentChunk.conflictRecord!.conflict?.type ==
          ConflictType.missingTime) {
        // An extra time marks one of the times already recorded, and there
        // are none since the missing time. TimingController refuses this
        // before it gets here; ignore it rather than record something wrong.
        Logger.e('Ignoring extra time: nothing recorded since the missing '
            'time. Undo the missing time instead.');
        return;
      } else {
        final int chunkId = currentChunk.id;
        cacheCurrentChunk();
        currentChunk = TimingChunk(
            id: chunkId + 1, timingData: [], conflictRecord: record);
        _saveCurrentChunkInDatabase();
      }
    }
    _cachedUiRecords = null;
    recordsSignal.value++;
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
    persistCurrentChunk();
    _cachedUiRecords = null;
    recordsSignal.value++;
    notifyListeners();
  }

  void cacheCurrentChunk() {
    _chunkCacher.cacheChunk(currentChunk);
  }

  /// Caches a chunk in memory only, without saving to database
  void cacheChunkInMemoryOnly(TimingChunk chunk) {
    _chunkCacher.cacheChunk(chunk);
  }

  /// Saves the whole of [currentChunk], replacing its row. Every change goes
  /// through here: appending one time by reading the row and writing it back
  /// lost times when two taps overlapped, and did nothing when the row was
  /// missing (e.g. after the race's times were cleared).
  void _saveCurrentChunkInDatabase() {
    final race = _currentRace;
    if (race == null) {
      Logger.e('Skipping save - no race loaded');
      return;
    }
    // Save what the chunk holds now: it keeps changing (and may be replaced)
    // before the queued write runs.
    final snapshot = _copyChunk(currentChunk);
    enqueueWrite(() => _storage.saveChunk(race.raceId, snapshot),
        'save chunk ${snapshot.id}');
  }

  static TimingChunk _copyChunk(TimingChunk chunk) {
    final conflictRecord = chunk.conflictRecord;
    return TimingChunk(
      id: chunk.id,
      timingData: [
        for (final datum in chunk.timingData) TimingDatum(time: datum.time)
      ],
      conflictRecord: conflictRecord == null
          ? null
          : TimingDatum(
              time: conflictRecord.time,
              conflict: Conflict(
                type: conflictRecord.conflict!.type,
                offBy: conflictRecord.conflict!.offBy,
              ),
            ),
    );
  }

  /// Saves [currentChunk] (times and conflict) after it was changed in place,
  /// e.g. by an undo or a deleted record. Without this the change was lost on
  /// restart and the removed conflict came back.
  void persistCurrentChunk() => _saveCurrentChunkInDatabase();

  Future<void> _writes = Future.value();

  /// Completes once every write queued so far has finished.
  Future<void> get pendingWrites => _writes;

  /// Runs storage writes one at a time, in the order they were made, so a
  /// later write can never land before (and be overwritten by) an earlier
  /// one. Failures are logged instead of dropped. The returned future
  /// completes when this write has run.
  Future<void> enqueueWrite(Future<Result<void>> Function() write, String what) {
    return _writes = _writes.then((_) async {
      try {
        final result = await write();
        if (result case Failure(:final error)) {
          Logger.e('[TimingData] Could not $what: ${error.originalException}');
        }
      } catch (e) {
        Logger.e('[TimingData] Could not $what: $e');
      }
    });
  }

  /// Removes [currentChunk] and makes the previous chunk current, deleting the
  /// removed chunk's row from storage.
  void deleteCurrentChunk() {
    final removedId = currentChunk.id;
    if (_currentRace != null) {
      final raceId = _currentRace!.raceId;
      enqueueWrite(() => _storage.deleteChunk(raceId, removedId),
          'delete chunk $removedId');
    }
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
    _cachedUiRecords = null;
    recordsSignal.value++;
    notifyListeners();
  }

  /// How far the times have been moved since this race was opened, for a
  /// Timer who pressed Start late (positive) or early (negative).
  Duration get timeShift => _timeShift;
  Duration _timeShift = Duration.zero;

  /// For a Timer who pressed Start [by] after the gun (or before it, when
  /// negative): moves the start back by that much, so the clock and every
  /// time already recorded read from the gun, and the coach gets the right
  /// times. Returns why nothing moved, if refused.
  String? shiftAllTimes(Duration by) {
    final race = _currentRace;
    final start = _startTime;
    if (race == null || start == null) return 'Start the race first.';
    if ((raceElapsed + by).isNegative) {
      return 'The clock has not reached ${_seconds(-by)} seconds yet.';
    }

    final chunks = [..._chunkCacher.cachedTimingChunks, currentChunk];
    final refused = shiftTimes(chunks, by);
    if (refused != null) return refused;

    // Rebuilt from the moved times: the cache keeps each chunk encoded.
    _chunkCacher.clear();
    for (final chunk in chunks.take(chunks.length - 1)) {
      _chunkCacher.cacheChunk(chunk);
    }
    for (final chunk in chunks) {
      final snapshot = _copyChunk(chunk);
      enqueueWrite(() => _storage.saveChunk(race.raceId, snapshot),
          'save moved chunk ${snapshot.id}');
    }

    startTime = start.subtract(by);
    final duration = _raceDuration;
    if (duration != null) raceDuration = duration + by;
    _timeShift += by;

    _cachedUiRecords = null;
    recordsSignal.value++;
    raceStateSignal.value++;
    notifyListeners();
    return null;
  }

  static String _seconds(Duration d) =>
      (d.inMilliseconds / 1000).toStringAsFixed(1);

  /// Returns the number of runners that have been assigned a finishing place,
  /// or null if no runners have finished yet.
  ///
  /// Computed directly from [ChunkCacher.startingPlace] and [currentChunk]
  /// without building the full [uiRecords] list.
  int? get runnerCount {
    // startingPlace is 0 when empty, 1 when the first chunk begins
    int total = _chunkCacher.startingPlace > 0
        ? _chunkCacher.startingPlace - 1
        : 0;

    if (!currentChunk.isEmpty) {
      if (!currentChunk.hasConflict) {
        total += currentChunk.timingData.length;
      } else {
        final conflict = currentChunk.conflictRecord!.conflict!;
        total += switch (conflict.type) {
          ConflictType.confirmRunner => currentChunk.timingData.length,
          ConflictType.missingTime =>
            currentChunk.timingData.length + conflict.offBy,
          ConflictType.extraTime =>
            currentChunk.timingData.length - conflict.offBy,
        };
      }
    }

    return total > 0 ? total : null;
  }

  bool get hasTimingData =>
      currentChunk.timingData.isNotEmpty ||
      currentChunk.conflictRecord != null ||
      !_chunkCacher.isEmpty;

  /// Encodes every record, oldest first, for sharing with the coach.
  ///
  /// Read-only: sharing can be retried (e.g. after a failed transfer), so this
  /// must not drain the chunk cache or modify [currentChunk].
  Future<String> encodedRecords() async {
    final List<TimingDatum> records = [];
    for (final chunk in _chunkCacher.cachedTimingChunks) {
      records.addAll(chunk.timingData);
      if (chunk.hasConflict) {
        records.add(chunk.conflictRecord!);
      }
    }

    if (!currentChunk.isEmpty) {
      records.addAll(currentChunk.timingData);
      if (currentChunk.hasConflict) {
        records.add(currentChunk.conflictRecord!);
      } else if (raceDuration != null) {
        // Closing checkpoint so the coach can confirm the final runner count.
        records.add(TimingDatum(
            time: TimeFormatter.formatDuration(raceDuration!),
            conflict: Conflict(type: ConflictType.confirmRunner)));
      }
    }

    return await TimingEncodeUtils.encodeTimeRecords(records);
  }

  List<UIRecord> get uiRecords => _cachedUiRecords ??= _buildUiRecords();

  List<UIRecord> _buildUiRecords() {
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
        RaceTimerDataConverter.convertToUIChunk(currentChunk, startingPlace)
            .records;
    records.addAll(currentChunkRecords);
    return records;
  }

  /// Invalidates the [uiRecords] cache and fires [recordsSignal].
  ///
  /// Call this from [TimingController] whenever [currentChunk] is mutated
  /// directly (without going through a [TimingData] mutation method) before
  /// calling [notifyListeners].
  void invalidateRecordsCache() {
    _cachedUiRecords = null;
    recordsSignal.value++;
  }

  @override
  void dispose() {
    raceInfoSignal.dispose();
    raceStateSignal.dispose();
    recordsSignal.dispose();
    super.dispose();
  }

  void clearRecords() {
    currentChunk.timingData.clear();
    currentChunk.conflictRecord = null;
    _chunkCacher.clear();
    _timingDataConverter.clearCache();
    _startTime = null;
    _anchorRaceTime = null;
    _raceDuration = null;
    _timeShift = Duration.zero;
    _cachedUiRecords = null;
    raceStateSignal.value++;
    recordsSignal.value++;
    notifyListeners();
  }
}
