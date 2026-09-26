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
import '../../../core/components/adjust_times_form.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/device_connection_service.dart';
import '../../shared/widgets/other_races_sheet.dart';
import '../../shared/services/i_assistant_storage_service.dart';
import '../../shared/utils/race_to_reopen.dart';
import '../../shared/services/assistant_export_service.dart';
import '../../shared/services/race_copy.dart';
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

  /// Set when the last race could not be loaded; the race is left closed so
  /// nothing is recorded over its unread times.
  AppError? loadError;

  /// The race that failed to load, so [retryLoad] can try it again.
  RaceRecord? _failedRace;

  TimingController({
    required super.storage,
    AudioPlayer? audioPlayer,
    IHapticFeedback? hapticFeedback,
    super.now,
    super.monotonic,
  })  : _storage = storage,
        _audioPlayer = audioPlayer,
        _hapticFeedback = hapticFeedback ?? HapticFeedbackService() {
    _initializeControllers();
  }

  /// Opening the last race, started when the Timer opens. Loading another
  /// race waits for it, so the last race cannot open over the new one.
  late final Future<void> initialLoad;

  void _initializeControllers() {
    if (_audioPlayer != null) {
      _initAudioPlayer();
    }
    initialLoad = _loadLastRace();
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

  /// True until the race to reopen has loaded, so the screen does not say
  /// "No race yet" while it is on its way.
  bool get loadingRace => _loadingRace;
  bool _loadingRace = true;

  Future<void> _loadLastRace() async {
    try {
      // Ensure demo race exists if no races are present
      await DemoRaceGenerator.ensureDemoRaceExists(
          DeviceName.raceTimer.toString());

      final result = await _storage.getRaces(DeviceName.raceTimer.toString());
      final races = switch (result) {
        Success(:final value) => value,
        Failure() => <RaceRecord>[],
      };
      final race = raceToReopen(races);
      if (race != null) {
        await _loadRace(race);
      }
    } finally {
      _loadingRace = false;
      // The screen may have closed while the race loaded.
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> showLoadRaceSheet(BuildContext context) async {
    final devices = DeviceConnectionService.createDevices(
      DeviceName.raceTimer,
      DeviceType.browserDevice,
    );
    sheet(
      context: context,
      title: 'Get Race from Coach',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'On the coach\'s phone, open the race and tap Send to '
              'Volunteers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF606060)),
            ),
          ),
          DeviceConnectionWidget(
        devices: devices,
        callback: () async {
          final data = devices.coach?.data;
          if (data == null) {
            return;
          }
          await loadRaceFromCoach(data);
        },
      ),
        ],
      ),
    );
  }

  /// Opens the race the coach sent as [data].
  ///
  /// A race already on this phone is opened with the times recorded for it:
  /// the coach may well send the same race twice. Only a race new to this
  /// phone starts from an empty first batch.
  @visibleForTesting
  Future<void> loadRaceFromCoach(String data) async {
    final RaceRecord sent;
    try {
      sent = RaceRecord.fromEncodedString(data,
          type: DeviceName.raceTimer.toString());
    } catch (e) {
      Logger.e('Error parsing race data: $e');
      return;
    }
    await initialLoad;
    switch (await _storage.receiveRace(sent)) {
      case Failure(:final error):
        Logger.e('[TimingController.loadRaceFromCoach] '
            '${error.originalException}');
      case Success(:final value):
        clearRecords();
        if (value.isNew) {
          await _storage.saveChunk(
            value.race.raceId,
            TimingChunk(id: 0, timingData: []),
          );
        }
        await _loadRace(value.race);
    }
  }

  /// A practice race started longer ago than this is started fresh when it
  /// opens: left from another day, its clock read 13 hours and new times
  /// five and a half, which looked broken.
  static const stalePractice = Duration(hours: 2);

  Future<void> _loadRace(RaceRecord raceRecord) async {
    // Let queued saves finish first, so what is read back is up to date.
    await pendingWrites;
    if (DemoRaceGenerator.isDemoRace(raceRecord) &&
        raceRecord.startedAt != null &&
        clockNow.difference(raceRecord.startedAt!) > stalePractice) {
      raceRecord = await _resetPractice(raceRecord);
    }
    // Read the saved times first. If that fails the race must not open: new
    // times would be saved over the unread chunks, which start at the same ids.
    final chunksResult = await _storage.getChunks(raceRecord.raceId);
    final List<TimingChunk> chunks;
    switch (chunksResult) {
      case Success(:final value):
        chunks = value;
      case Failure(:final error):
        Logger.e('[TimingController._loadRace] ${error.originalException}');
        // Close whatever race was open: its times were already cleared from
        // memory, so starting or logging would write over its saved data.
        currentRace = null;
        _failedRace = raceRecord;
        loadError = AppError(
          userMessage: 'Could not read the saved times for '
              '"${raceRecord.name}". They have not been changed. Try again, '
              'or restart the app.',
          originalException: error.originalException,
        );
        notifyListeners();
        return;
    }
    loadError = null;
    _failedRace = null;
    currentRace = raceRecord;
    startTime = raceRecord.startedAt;
    raceDuration = raceRecord.duration;
    raceStopped = raceRecord.stopped;

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
    invalidateRecordsCache();
    notifyListeners();
  }

  /// Clears the practice race's times and clock, so it starts again.
  Future<RaceRecord> _resetPractice(RaceRecord race) async {
    final id = race.raceId, type = race.type;
    await _storage.deleteChunks(id);
    await _storage.saveChunk(id, TimingChunk(id: 0, timingData: []));
    await _storage.updateRaceStartTime(id, type, null);
    await _storage.updateRaceDuration(id, type, null);
    await _storage.updateRaceStatus(id, type, true);
    return RaceRecord(
      raceId: id,
      date: race.date,
      name: race.name,
      type: type,
      stopped: true,
    );
  }

  /// Loads a previous race and its timing records
  Future<void> loadOtherRace(RaceRecord race) async {
    await initialLoad;
    clearRecords();

    await _loadRace(race);
  }

  /// Tries again to open the race that failed to load.
  Future<void> retryLoad() async {
    final race = _failedRace;
    if (race == null) return;
    await loadOtherRace(race);
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
    startTime = clockNow;
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
      raceDuration = raceElapsed;
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
        raceElapsed);
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
        raceElapsed);

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
        raceElapsed);

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
    final currentDuration = raceElapsed;

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
    final currentType = currentChunk.conflictRecord?.conflict?.type;
    // Right after a confirmation every time on screen is confirmed. An extra
    // time here made a conflict with no times of its own, which the coach
    // could never see or resolve.
    if (currentType == ConflictType.confirmRunner) {
      return const RemoveExtraTimeError(
          AppError(userMessage: 'You cannot remove a confirmed time.'));
    }
    // An extra time marks one of the times recorded since the last button,
    // and there are none since the missing time. (This used to cancel the
    // missing time, which threw away both the missed runner and the stray.)
    if (currentType == ConflictType.missingTime) {
      return const RemoveExtraTimeError(AppError(
          userMessage: 'There is no time to remove yet. Undo the missing '
              'time first, or log the time and then remove it.'));
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
      // Save the undo, or the conflict comes back after a restart.
      persistCurrentChunk();
      invalidateRecordsCache();
      notifyListeners();
    }
  }

  /// Clears all race times. Widget must show a confirmation dialog before calling this.
  Future<void> doClearRaceTimes() async {
    clearRecords();
    if (currentRace != null) {
      // Queued, so a save still waiting to run can't bring the times back.
      final race = currentRace!;
      await enqueueWrite(
          () => _storage.deleteChunks(race.raceId), 'clear race ${race.raceId}');
      // The saved clock goes too. Otherwise reopening the race brings back the
      // old start, and the Timer can only resume that clock, not start anew.
      await enqueueWrite(
          () => _storage.updateRaceStartTime(race.raceId, race.type, null),
          'clear the start of race ${race.raceId}');
      await enqueueWrite(
          () => _storage.updateRaceDuration(race.raceId, race.type, null),
          'clear the length of race ${race.raceId}');
    }
  }

  Duration calculateElapsedTime(DateTime? startTime, Duration? endTime) {
    if (startTime == null) {
      return endTime ?? Duration.zero;
    }
    return clockNow.difference(startTime);
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
      if (currentChunk.timingData.isEmpty && !currentChunk.hasConflict) {
        // deleteCurrentChunk removes this chunk's row. Deleting by
        // currentChunk.id afterwards deleted the previous chunk instead.
        deleteCurrentChunk();
        return true;
      }
      persistCurrentChunk();
      invalidateRecordsCache();
      notifyListeners();
      return true;
    }

    switch (record.type) {
      case RecordType.confirmRunner:
        currentChunk.conflictRecord = null;
        if (currentChunk.timingData.isEmpty) {
          deleteCurrentChunk();
        } else {
          persistCurrentChunk();
          invalidateRecordsCache();
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

  /// For a Timer who pressed Start before or after the gun: moves the clock
  /// and every time by the seconds they say.
  Future<void> showAdjustStartSheet(BuildContext context) async {
    await sheet(
      context: context,
      title: 'Started Early or Late?',
      body: AdjustTimesForm(
        explanation: timeShift == Duration.zero
            ? 'Pressed Start after the gun? Every time is short by the same '
                'amount. Say how many seconds and the clock and every time '
                'are corrected, so your coach gets times from the gun.'
            : 'Times already moved ${describeShift(timeShift)}. Any change '
                'here is added to that.',
        onShift: (by) {
          final refused = shiftAllTimes(by);
          return refused == null ? null : AppError(userMessage: refused);
        },
      ),
    );
  }

  Future<void> downloadRace(BuildContext context) async {
    if (currentRace == null) return;
    final race = currentRace!;
    final records = uiRecords;
    await saveRaceCopy(
      context,
      race: race,
      what: 'Finish Times',
      table: AssistantExportService.timerTable(records),
      exportFile: (format) =>
          AssistantExportService.exportTimerData(race, records, format),
    );
  }

  /// Deletes the current race and all its associated data.
  /// Returns an [AppError] if deletion fails, or null on success.
  Future<AppError?> deleteCurrentRace() async {
    if (currentRace == null) return null;

    try {
      // Clear all timing data first
      clearRecords();

      // Delete all chunks associated with this race. Queued, so a save still
      // waiting to run can't recreate them.
      final raceId = currentRace!.raceId;
      await enqueueWrite(
          () => _storage.deleteChunks(raceId), 'delete chunks of $raceId');

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

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    scrollController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }
}
