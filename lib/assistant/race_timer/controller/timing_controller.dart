import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/services/haptic_feedback_service.dart';
import 'package:xceleration/assistant/race_timer/model/ui_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import '../../../core/utils/enums.dart';
import '../model/timing_data.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/time_formatter.dart';
import '../model/timing_utils.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/device_connection_service.dart';
import '../../shared/widgets/other_races_sheet.dart';
import '../../shared/services/i_assistant_storage_service.dart';
import '../../shared/services/demo_race_generator.dart';
import '../../../core/app_error.dart';
import '../../../core/result.dart';

sealed class RemoveExtraTimeResult {
  const RemoveExtraTimeResult();
}

final class RemoveExtraTimeOk extends RemoveExtraTimeResult {
  const RemoveExtraTimeOk();
}

final class RemoveExtraTimeError extends RemoveExtraTimeResult {
  const RemoveExtraTimeError(this.error);
  final AppError error;
}

final class RemoveExtraTimeConfirmRequired extends RemoveExtraTimeResult {
  const RemoveExtraTimeConfirmRequired(this.offBy);
  final int offBy;
}

class TimingController extends TimingData {
  final ScrollController scrollController = ScrollController();
  final AudioPlayer? _audioPlayer;
  final IAssistantStorageService _storage;
  final IHapticFeedback _hapticFeedback;
  bool isAudioPlayerReady = false;

  TimingController({
    required super.storage,
    AudioPlayer? audioPlayer,
    IHapticFeedback? hapticFeedback,
  })  : _storage = storage,
        _audioPlayer = audioPlayer,
        _hapticFeedback = hapticFeedback ?? HapticFeedbackService() {
    _initializeControllers();
  }

  void _initializeControllers() {
    if (_audioPlayer != null) {
      _initAudioPlayer();
    }
    _loadLastRace();
  }

  Future<void> showOtherRaces(BuildContext context) async {
    final result = await _storage.getRaces(DeviceName.raceTimer.toString());
    if (!context.mounted) return;
    final races = switch (result) {
      Success(:final value) => value,
      Failure() => <RaceRecord>[],
    };

    sheet(
      context: context,
      title: 'Other Races',
      body: OtherRacesSheet(
        races: races,
        currentRace: currentRace,
        onRaceSelected: loadOtherRace,
        role: DeviceName.raceTimer,
      ),
    );
  }

  Future<void> _loadLastRace() async {
    // Ensure demo race exists if no races are present
    await DemoRaceGenerator.ensureDemoRaceExists(
        DeviceName.raceTimer.toString());

    final result = await _storage.getRaces(DeviceName.raceTimer.toString());
    final races = switch (result) {
      Success(:final value) => value,
      Failure() => <RaceRecord>[],
    };
    if (races.isNotEmpty) {
      _loadRace(races.last);
    }
  }

  Future<void> showLoadRaceSheet(BuildContext context) async {
    final devices = DeviceConnectionService.createDevices(
      DeviceName.raceTimer,
      DeviceType.browserDevice,
    );
    sheet(
      context: context,
      title: 'Load Race',
      body: deviceConnectionWidget(
        context,
        devices,
        callback: () async {
          final data = devices.coach?.data;
          if (data == null) {
            return;
          }
          late RaceRecord raceRecord;
          try {
            Logger.d('Received race data: $data');
            raceRecord = RaceRecord.fromEncodedString(data,
                type: DeviceName.raceTimer.toString());

            Logger.d(
                'Parsed race record: ${raceRecord.name}, date: ${raceRecord.date}');
          } catch (e) {
            Logger.e('Error parsing race data: $e');
            return;
          }
          try {
            await _storage.saveNewRace(raceRecord);
            clearRecords();
            // Also save an initial empty timing chunk for this race, so that the UI is ready for entry.
            // (If a chunk with id 0 already exists, this will update it.)
            await _storage.saveChunk(
              raceRecord.raceId,
              TimingChunk(id: 0, timingData: []),
            );
            _loadRace(raceRecord);
          } catch (e) {
            Logger.e('Error saving race: $e');
          }
        },
      ),
    );
  }

  Future<void> _loadRace(RaceRecord raceRecord) async {
    currentRace = raceRecord;
    startTime = raceRecord.startedAt;
    raceDuration = raceRecord.duration;
    raceStopped = raceRecord.stopped;
    // Load timing chunks
    final chunksResult = await _storage.getChunks(raceRecord.raceId);
    final chunks = switch (chunksResult) {
      Success(:final value) => value,
      Failure() => <TimingChunk>[],
    };

    if (chunks.isNotEmpty) {
      // Set the last chunk as current
      currentChunk = chunks.last;
      // Cache all previous chunks (all except the last one) in memory only
      for (int i = 0; i < chunks.length - 1; i++) {
        final chunkToCache = chunks[i];
        // Cache in memory only, don't save to database during loading
        cacheChunkInMemoryOnly(chunkToCache);
      }
    }
    notifyListeners();
  }

  /// Loads a previous race and its timing records
  Future<void> loadOtherRace(RaceRecord race) async {
    clearRecords();

    _loadRace(race);
  }

  Future<void> _initAudioPlayer() async {
    if (_audioPlayer == null) return;
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setSource(AssetSource('sounds/click.mp3'));
      isAudioPlayerReady = true;
      notifyListeners();
    } catch (e) {
      Logger.e('Error initializing audio player: $e');
      // Don't retry if the asset is missing
      if (e.toString().contains('The asset does not exist')) {
        Logger.e('Audio asset missing - continuing without sound');
        return;
      }
      // Only retry for other types of errors
      if (!isAudioPlayerReady) {
        await Future.delayed(const Duration(milliseconds: 500));
        _initAudioPlayer();
      }
    }
  }

  void startRace() {
    if (raceStopped && startTime != null) {
      // Continue the race instead of starting a new one
      _continueRace();
    } else {
      // Start a brand new race
      _startRace();
    }
  }

  void _startRace() {
    raceStopped = false;
    startTime = DateTime.now();
    raceDuration = null;
    notifyListeners();
  }

  void _continueRace() {
    if (!raceStopped) return;

    raceStopped = false;
    raceDuration = null;
    notifyListeners();
  }

  /// Stops the race. Widget must show a confirmation dialog before calling this.
  void stopRace() {
    if (raceStopped == false && startTime != null) {
      raceDuration = DateTime.now().difference(startTime!);
      raceStopped = true;
    }
  }

  Future<AppError?> handleLogButtonPress() async {
    final error = logTime();
    if (error != null) return error;

    _hapticFeedback.vibrate();
    _hapticFeedback.lightImpact();

    if (isAudioPlayerReady && _audioPlayer != null) {
      _audioPlayer.stop().then((_) {
        _audioPlayer.play(AssetSource('sounds/click.mp3'));
      });
    }
    return null;
  }

  AppError? logTime() {
    if (startTime == null || raceStopped) {
      return const AppError(
          userMessage: 'Start time cannot be null or race stopped.');
    }

    final time = TimeFormatter.formatDuration(
        getCurrentDuration(startTime, raceDuration));
    addRunnerTimeRecord(TimingDatum(time: time));
    scrollToBottom(scrollController);
    notifyListeners();
    return null;
  }

  AppError? confirmTimes() {
    if (startTime == null || raceStopped) {
      return const AppError(
          userMessage: 'Race must be started to confirm a time.');
    }
    final time = TimeFormatter.formatDuration(
        getCurrentDuration(startTime, raceDuration));

    addConfirmRecord(TimingDatum(
        time: time,
        conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1)));
    scrollToBottom(scrollController);
    notifyListeners();
    return null;
  }

  Future<AppError?> addMissingTime() async {
    if (startTime == null) {
      return const AppError(
          userMessage: 'Race must be started to mark a missing time.');
    }

    final time = TimeFormatter.formatDuration(
        getCurrentDuration(startTime, raceDuration));

    addMissingTimeRecord(TimingDatum(
        time: time,
        conflict: Conflict(type: ConflictType.missingTime, offBy: 1)));
    scrollToBottom(scrollController);
    notifyListeners();
    return null;
  }

  Future<RemoveExtraTimeResult> removeExtraTime() async {
    if (startTime == null || raceStopped) {
      return const RemoveExtraTimeError(
          AppError(userMessage: 'Race must be started to mark an extra time.'));
    }
    final currentDuration = getCurrentDuration(startTime, raceDuration);

    final extraTimeRecord = TimingDatum(
        time: TimeFormatter.formatDuration(currentDuration),
        conflict: Conflict(type: ConflictType.extraTime, offBy: 1));

    final result = _checkRemoveExtraTimeConflict(extraTimeRecord);
    if (result != null) return result;

    addExtraTimeRecord(extraTimeRecord);
    scrollToBottom(scrollController);
    notifyListeners();
    return const RemoveExtraTimeOk();
  }

  RemoveExtraTimeResult? _checkRemoveExtraTimeConflict(TimingDatum record) {
    if (record.conflict?.type == ConflictType.confirmRunner) {
      return const RemoveExtraTimeError(
          AppError(userMessage: 'You cannot remove a confirmed time.'));
    }
    if (record.conflict?.type == ConflictType.missingTime) {
      return null;
    }

    // Calculate the total offBy that would result after adding this record
    int totalOffBy = record.hasConflict ? record.conflict!.offBy : 0;
    if (currentChunk.hasConflict &&
        currentChunk.conflictRecord!.conflict!.type == ConflictType.extraTime) {
      totalOffBy += currentChunk.conflictRecord!.conflict!.offBy;
    }

    final int numRunnerRecords = currentChunk.timingData.length;

    if (totalOffBy < numRunnerRecords) {
      return null;
    } else if (totalOffBy == numRunnerRecords) {
      return RemoveExtraTimeConfirmRequired(totalOffBy);
    } else {
      return const RemoveExtraTimeError(
          AppError(userMessage: "You can't remove any more unconfirmed times"));
    }
  }

  /// Called after the widget confirms deletion of the current chunk.
  void executeRemoveExtraTimeDeletion() {
    deleteCurrentChunk();
  }

  String get undoDialogTitle {
    final isConflict = currentChunk.conflictRecord?.conflict?.type !=
        ConflictType.confirmRunner;
    return isConflict ? 'Undo Conflict' : 'Undo Confirmation';
  }

  String get undoDialogContent {
    final isConflict = currentChunk.conflictRecord?.conflict?.type !=
        ConflictType.confirmRunner;
    return isConflict
        ? 'Are you sure you want to undo the last conflict?'
        : 'Are you sure you want to undo the last confirmation?';
  }

  /// Executes the undo. Widget must show a confirmation dialog before calling this.
  void doUndoLastConflict() {
    currentChunk.conflictRecord = null;

    scrollToBottom(scrollController);
    if (currentChunk.isEmpty) {
      deleteCurrentChunk();
    } else {
      notifyListeners();
    }
  }

  /// Clears all race times. Widget must show a confirmation dialog before calling this.
  Future<void> doClearRaceTimes() async {
    clearRecords();
    if (currentRace != null) {
      _storage.deleteChunks(currentRace!.raceId);
    }
  }

  Duration calculateElapsedTime(DateTime? startTime, Duration? endTime) {
    if (startTime == null) {
      return endTime ?? Duration.zero;
    }
    return DateTime.now().difference(startTime);
  }

  bool get isLastRecordUndoable {
    // Show undo button for confirmations or conflicts
    final isUndoable = currentChunk.conflictRecord != null ||
        currentChunk.timingData.any(
            (record) => record.conflict?.type == ConflictType.confirmRunner);
    return isUndoable;
  }

  /// Validates whether a record can be deleted. Returns an [AppError] if deletion
  /// is not allowed, or null if the widget may proceed to show a confirmation dialog.
  AppError? validateDeleteRecord(UIRecord record) {
    final bool isUnconfirmed = record.textColor == Colors.black;

    if (isUnconfirmed) {
      final int index =
          currentChunk.timingData.indexOf(TimingDatum(time: record.time));
      if (index == -1) {
        return const AppError(userMessage: 'Record not found.');
      }
      return null;
    }

    final uiRecords = this.uiRecords;
    final int recordIndex = uiRecords.indexOf(record);
    final bool isLast = recordIndex == uiRecords.length - 1;
    if (!isLast) {
      return const AppError(
          userMessage: 'Cannot delete a record when there are later records.');
    }

    if (record.type == RecordType.runnerTime) {
      return const AppError(userMessage: 'Cannot delete this record.');
    }

    return null;
  }

  /// Executes the deletion of a record. Call [validateDeleteRecord] first and
  /// show a confirmation dialog before calling this.
  Future<bool> executeDeleteRecord(UIRecord record) async {
    final bool isUnconfirmed = record.textColor == Colors.black;

    if (isUnconfirmed) {
      final int index =
          currentChunk.timingData.indexOf(TimingDatum(time: record.time));
      if (index == -1) return false;

      currentChunk.timingData.removeAt(index);
      _storage.updateChunkTimingData(
          currentRace!.raceId, currentChunk.id, currentChunk.timingData);
      if (currentChunk.timingData.isEmpty && !currentChunk.hasConflict) {
        deleteCurrentChunk();
        _storage.deleteChunk(currentRace!.raceId, currentChunk.id);
        return true;
      }
      notifyListeners();
      return true;
    }

    switch (record.type) {
      case RecordType.confirmRunner:
        currentChunk.conflictRecord = null;
        if (currentChunk.timingData.isEmpty) {
          deleteCurrentChunk();
        } else {
          notifyListeners();
        }
        return true;
      case RecordType.missingTime:
        reduceCurrentConflictByOne();
        if (currentChunk.conflictRecord == null &&
            currentChunk.timingData.isEmpty) {
          deleteCurrentChunk();
        }
        return true;
      case RecordType.extraTime:
        reduceCurrentConflictByOne();
        if (currentChunk.conflictRecord == null &&
            currentChunk.timingData.isEmpty) {
          deleteCurrentChunk();
        }
        return true;
      case RecordType.runnerTime:
      default:
        return false;
    }
  }

  /// Deletes the current race and all its associated data.
  /// Returns an [AppError] if deletion fails, or null on success.
  Future<AppError?> deleteCurrentRace() async {
    if (currentRace == null) return null;

    try {
      // Clear all timing data first
      clearRecords();

      // Delete all chunks associated with this race
      await _storage.deleteChunks(currentRace!.raceId);

      // Delete the race from the database
      await _storage.deleteRace(currentRace!.raceId, currentRace!.type);

      // Reset race state
      raceStopped = false;

      // Clear the current race
      currentRace = null;

      _loadLastRace();

      notifyListeners();
      return null;
    } catch (e) {
      Logger.e('Error deleting race: $e');
      return AppError(
          userMessage: 'Failed to delete race.', originalException: e);
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }
}
