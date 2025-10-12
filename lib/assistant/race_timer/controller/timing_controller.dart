import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:xceleration/assistant/race_timer/model/ui_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import '../../../core/utils/enums.dart';
import '../model/timing_data.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/components/dialog_utils.dart';
import '../model/timing_utils.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/device_connection_service.dart';
import '../../shared/widgets/other_races_sheet.dart';
import '../../shared/services/assistant_storage_service.dart';

class TimingController extends TimingData {
  final ScrollController scrollController = ScrollController();
  AudioPlayer? audioPlayer;
  bool isAudioPlayerReady = false;
  BuildContext? _context;
  final bool enableAudio;

  TimingController({this.enableAudio = true}) : super() {
    _initializeControllers();
  }

  void setContext(BuildContext context) {
    _context = context;
  }

  void _initializeControllers() {
    if (enableAudio) {
      audioPlayer = AudioPlayer();
      _initAudioPlayer();
    }
    _loadLastRace();
  }

  Future<void> showOtherRaces(BuildContext context) async {
    final races = await AssistantStorageService.instance
        .getRaces(DeviceName.raceTimer.toString());
    if (!context.mounted) return;

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
    final races = await AssistantStorageService.instance
        .getRaces(DeviceName.raceTimer.toString());
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
            DialogUtils.showErrorDialog(context,
                message: 'Race data not received');
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
            if (context.mounted) {
              DialogUtils.showErrorDialog(context,
                  message: 'Failed to parse race data: $e');
            }
          }
          try {
            await AssistantStorageService.instance.saveNewRace(raceRecord);
            clearRecords();
            // Also save an initial empty timing chunk for this race, so that the UI is ready for entry.
            // (If a chunk with id 0 already exists, this will update it.)
            await AssistantStorageService.instance.saveChunk(
              raceRecord.raceId,
              TimingChunk(id: 0, timingData: []),
            );
            _loadRace(raceRecord);
          } catch (e) {
            Logger.e('Error saving race: $e');
            if (context.mounted) {
              DialogUtils.showErrorDialog(context,
                  message: 'Failed to load race: $e');
            }
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
    final chunks =
        await AssistantStorageService.instance.getChunks(raceRecord.raceId);

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
    if (audioPlayer == null) return;
    try {
      await audioPlayer!.setReleaseMode(ReleaseMode.stop);
      await audioPlayer!.setSource(AssetSource('sounds/click.mp3'));
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

  Future<void> stopRace() async {
    if (_context == null) return;

    final confirmed = await DialogUtils.showConfirmationDialog(_context!,
        content: 'Are you sure you want to stop the race?',
        title: 'Stop the Race');
    if (confirmed != true) return;

    if (raceStopped == false && startTime != null) {
      raceDuration = DateTime.now().difference(startTime!);
      raceStopped = true;
      notifyListeners();
    }
  }

  Future<void> handleLogButtonPress() async {
    // Log the time first
    logTime();

    // Execute haptic feedback and audio playback without blocking the UI
    HapticFeedback.vibrate();
    HapticFeedback.lightImpact();

    if (isAudioPlayerReady && audioPlayer != null) {
      // Play audio without awaiting
      audioPlayer!.stop().then((_) {
        audioPlayer!.play(AssetSource('sounds/click.mp3'));
      });
    }
  }

  void logTime() {
    if (startTime == null || raceStopped) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!,
            message: 'Start time cannot be null or race stopped.');
      }
      return;
    }

    final time = TimeFormatter.formatDuration(
        getCurrentDuration(startTime, raceDuration));
    addRunnerTimeRecord(TimingDatum(time: time));
    scrollToBottom(scrollController);
    notifyListeners();
  }

  void confirmTimes() {
    if (startTime == null || raceStopped) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!,
            message: 'Race must be started to confirm a time.');
      }
      return;
    }
    final time = TimeFormatter.formatDuration(
        getCurrentDuration(startTime, raceDuration));

    addConfirmRecord(TimingDatum(
        time: time,
        conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1)));
    scrollToBottom(scrollController);
    notifyListeners();
  }

  Future<void> addMissingTime() async {
    if (startTime == null) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!,
            message: 'Race must be started to mark a missing time.');
      }
      return;
    }

    final time = TimeFormatter.formatDuration(
        getCurrentDuration(startTime, raceDuration));

    addMissingTimeRecord(TimingDatum(
        time: time,
        conflict: Conflict(type: ConflictType.missingTime, offBy: 1)));
    scrollToBottom(scrollController);
    notifyListeners();
  }

  Future<void> removeExtraTime() async {
    if (startTime == null || raceStopped) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!,
            message: 'Race must be started to mark an extra time.');
      }
      return;
    }
    final currentDuration = getCurrentDuration(startTime, raceDuration);

    final extraTimeRecord = TimingDatum(
        time: TimeFormatter.formatDuration(currentDuration),
        conflict: Conflict(type: ConflictType.extraTime, offBy: 1));

    if (!await _validateExtraTimeConflict(extraTimeRecord)) {
      return;
    }
    addExtraTimeRecord(extraTimeRecord);

    scrollToBottom(scrollController);
    notifyListeners();
  }

  Future<bool> _validateExtraTimeConflict(TimingDatum record) async {
    if (record.conflict?.type == ConflictType.confirmRunner) {
      DialogUtils.showErrorDialog(_context!,
          message: 'You cannot remove a confirmed time.');
      return false;
    }
    if (record.conflict?.type == ConflictType.missingTime) {
      return true;
    }

    // Calculate the total offBy that would result after adding this record
    int totalOffBy = record.hasConflict ? record.conflict!.offBy : 0;
    if (currentChunk.hasConflict &&
        currentChunk.conflictRecord!.conflict!.type == ConflictType.extraTime) {
      totalOffBy += currentChunk.conflictRecord!.conflict!.offBy;
    }

    final int numRunnerRecords = currentChunk.timingData.length;

    // If total off by is less than the number of records, then the conflict is valid
    if (totalOffBy < numRunnerRecords) {
      return true;
    } else if (totalOffBy == numRunnerRecords) {
      // let the user decide if they want to remove all the unconfirmed times
      if (await _handleTimesDeletion(totalOffBy)) {
        deleteCurrentChunk();
        return false; // Return false to prevent adding the record
      } else {
        return false;
      }
    } else {
      if (_context != null) {
        DialogUtils.showErrorDialog(
          _context!,
          message: "You can't remove any more unconfirmed times",
        );
      }
      return false;
    }
  }

  Future<bool> _handleTimesDeletion(int offBy) async {
    if (_context == null) return false;

    final confirmed = await DialogUtils.showConfirmationDialog(_context!,
        content:
            'This will delete the last $offBy finish times, are you sure you want to continue?',
        title: 'Confirm Deletion');
    if (confirmed) {
      return true;
    }
    return false;
  }

  Future<void> undoLastConflict() async {
    if (_context == null) return;

    final isConflict = currentChunk.conflictRecord?.conflict?.type !=
        ConflictType.confirmRunner;
    final dialogTitle = isConflict ? 'Undo Conflict' : 'Undo Confirmation';
    final dialogContent = isConflict
        ? 'Are you sure you want to undo the last conflict?'
        : 'Are you sure you want to undo the last confirmation?';

    final confirmed = await DialogUtils.showConfirmationDialog(
      _context!,
      title: dialogTitle,
      content: dialogContent,
    );

    if (confirmed != true) return;

    // Clear the conflict record
    currentChunk.conflictRecord = null;

    // If chunk becomes empty, delete it
    if (currentChunk.isEmpty) {
      deleteCurrentChunk();
    }

    scrollToBottom(scrollController);
    notifyListeners();
  }

  void clearRaceTimes() {
    if (_context == null) return;

    showDialog<bool>(
      context: _context!,
      builder: (context) => AlertDialog(
        title: const Text('Clear Race Times'),
        content: const Text('Are you sure you want to clear all race times?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed ?? false) {
        clearRecords();
        notifyListeners();
        AssistantStorageService.instance.deleteChunks(currentRace!.raceId);
      }
    });
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

  Future<bool> handleRecordDeletion(UIRecord record) async {
    if (_context == null) return false;

    final bool isUnconfirmed = record.textColor == Colors.black;

    // Unconfirmed runner time: delete by index
    if (isUnconfirmed) {
      final int index =
          currentChunk.timingData.indexOf(TimingDatum(time: record.time));
      if (index == -1) {
        return false;
      }
      final confirmed = await DialogUtils.showConfirmationDialog(
        _context!,
        title: 'Confirm Deletion',
        content: 'Are you sure you want to delete the time ${record.time}?',
      );
      if (!confirmed) return false;

      currentChunk.timingData.removeAt(index);
      AssistantStorageService.instance.updateChunkTimingData(
          currentRace!.raceId, currentChunk.id, currentChunk.timingData);
      if (currentChunk.timingData.isEmpty && !currentChunk.hasConflict) {
        deleteCurrentChunk();
        AssistantStorageService.instance
            .deleteChunk(currentRace!.raceId, currentChunk.id);
        return true;
      }
      notifyListeners();
      return true;
    }

    // Only allow deleting non-unconfirmed records if this is the last record
    final uiRecords = this.uiRecords;
    final int recordIndex = uiRecords.indexOf(record);
    final bool isLast = recordIndex == uiRecords.length - 1;
    if (!isLast) {
      DialogUtils.showErrorDialog(
        _context!,
        message: 'Cannot delete a record when there are later records.',
      );
      return false;
    }

    // Handle conflicts/confirmed types
    switch (record.type) {
      case RecordType.confirmRunner:
        {
          final confirmed = await DialogUtils.showConfirmationDialog(
            _context!,
            title: 'Confirm Deletion',
            content:
                'Are you sure you want to delete the confirmation ${record.time}?',
          );
          if (!confirmed) return false;
          // Clear conflict record
          currentChunk.conflictRecord = null;
          if (currentChunk.timingData.isEmpty) {
            deleteCurrentChunk();
          }
          notifyListeners();
          return true;
        }
      case RecordType.missingTime:
        {
          final confirmed = await DialogUtils.showConfirmationDialog(
            _context!,
            title: 'Confirm Deletion',
            content:
                'Are you sure you want to delete the missing time ${record.time}?',
          );
          if (!confirmed) return false;
          reduceCurrentConflictByOne();
          if (currentChunk.conflictRecord == null &&
              currentChunk.timingData.isEmpty) {
            deleteCurrentChunk();
            return true;
          }
          return true;
        }
      case RecordType.extraTime:
        {
          final confirmed = await DialogUtils.showConfirmationDialog(
            _context!,
            title: 'Confirm Deletion',
            content:
                'Are you sure you want to delete the extra time ${record.time}?',
          );
          if (!confirmed) return false;

          // Use existing method to reduce conflict by one
          reduceCurrentConflictByOne();

          if (currentChunk.conflictRecord == null &&
              currentChunk.timingData.isEmpty) {
            deleteCurrentChunk();
            return true;
          }
          return true;
        }
      case RecordType.runnerTime:
      default:
        DialogUtils.showErrorDialog(
          _context!,
          message: 'Cannot delete this record.',
        );
        return false;
    }
  }

  /// Deletes the current race and all its associated data
  Future<void> deleteCurrentRace() async {
    if (currentRace == null) return;

    try {
      // Clear all timing data first
      clearRecords();

      // Delete all chunks associated with this race
      await AssistantStorageService.instance.deleteChunks(currentRace!.raceId);

      // Delete the race from the database
      await AssistantStorageService.instance
          .deleteRace(currentRace!.raceId, currentRace!.type);

      // Reset race state
      raceStopped = false;

      // Clear the current race
      currentRace = null;

      _loadLastRace();

      notifyListeners();
    } catch (e) {
      Logger.e('Error deleting race: $e');
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!,
            message: 'Failed to delete race: $e');
      }
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    audioPlayer?.dispose();
    super.dispose();
  }
}
