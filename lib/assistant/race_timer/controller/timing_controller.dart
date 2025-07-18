import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:xceleration/assistant/race_timer/model/ui_record.dart';
import '../../../core/utils/enums.dart';
import '../model/timing_data.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/components/dialog_utils.dart';
import '../model/timing_utils.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

class TimingController extends TimingData {
  final ScrollController scrollController = ScrollController();
  late final AudioPlayer audioPlayer;
  bool isAudioPlayerReady = false;
  BuildContext? _context;

  TimingController() : super() {
    _initializeControllers();
  }

  void setContext(BuildContext context) {
    _context = context;
  }

  void _initializeControllers() {
    audioPlayer = AudioPlayer();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      await audioPlayer.setReleaseMode(ReleaseMode.stop);
      await audioPlayer.setSource(AssetSource('sounds/click.mp3'));
      isAudioPlayerReady = true;
      notifyListeners();
    } catch (e) {
      Logger.d('Error initializing audio player: $e');
      // Don't retry if the asset is missing
      if (e.toString().contains('The asset does not exist')) {
        Logger.d('Audio asset missing - continuing without sound');
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
    final hasStoppedRace = endTime != null && hasTimingData;

    if (hasStoppedRace) {
      // Continue the race instead of starting a new one
      _continueRace();
    } else if (hasTimingData) {
      // Ask for confirmation before starting a new race
      _showStartRaceDialog();
    } else {
      // Start a brand new race
      _initializeNewRace();
    }
  }

  void _continueRace() {
    if (endTime == null) return;
    raceStopped = false;
    notifyListeners();
  }

  Future<void> _showStartRaceDialog() async {
    if (_context == null) return;

    if (hasTimingData) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        _context!,
        title: 'Start a New Race',
        content:
            'Are you sure you want to start a new race? Doing so will clear the existing times.',
      );
      if (confirmed != true) return;
      _initializeNewRace();
    } else {
      _initializeNewRace();
    }
  }

  Future<void> stopRace() async {
    if (_context == null) return;

    final confirmed = await DialogUtils.showConfirmationDialog(_context!,
        content: 'Are you sure you want to stop the race?',
        title: 'Stop the Race');
    if (confirmed != true) return;
    _finalizeRace();
  }

  void _initializeNewRace() {
    clearRecords();
    changeStartTime(DateTime.now());
    raceStopped = false;
    notifyListeners();
  }

  void _finalizeRace() {
    final currentStartTime = startTime;
    if (raceStopped == false && currentStartTime != null) {
      final now = DateTime.now();
      final difference = now.difference(currentStartTime);

      changeEndTime(difference);
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

    if (isAudioPlayerReady) {
      // Play audio without awaiting
      audioPlayer.stop().then((_) {
        audioPlayer.play(AssetSource('sounds/click.mp3'));
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

    final time =
        TimeFormatter.formatDuration(getCurrentDuration(startTime, endTime));
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
    final time =
        TimeFormatter.formatDuration(getCurrentDuration(startTime, endTime));

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

    final time =
        TimeFormatter.formatDuration(getCurrentDuration(startTime, endTime));

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
    final currentDuration = getCurrentDuration(startTime, endTime);

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

    int offBy = record.hasConflict ? record.conflict!.offBy : 0;
    offBy++;

    final int numRunnerRecords = currentChunk.timingData.length;

    // If off by is less than the number of records (excluding the last record, which is the current conflict), then the conflict is valid
    if (offBy < numRunnerRecords) {
      return true;
    } else if (offBy == numRunnerRecords) {
      // let the user decide if they want to remove all the unconfirmed times
      if (await _handleTimesDeletion(offBy)) {
        deleteCurrentChunk();
        return true;
      } else {
        return false;
      }
    } else {
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

  // void undoLastConflict() {
  //   if (!currentChunk.hasConflict) {
  //     Logger.d('No conflict found');
  //     return;
  //   }
  //   currentChunk.conflictRecord == null;
  //   if (currentChunk.isEmpty) {
  //     deleteCurrentChunk();
  //   }
  //   scrollToBottom(scrollController);
  //   notifyListeners();
  // }

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
      }
    });
  }

  Duration calculateElapsedTime(DateTime? startTime, Duration? endTime) {
    if (startTime == null) {
      return endTime ?? Duration.zero;
    }
    return DateTime.now().difference(startTime);
  }

  // bool hasUndoableConflict() {
  //   return currentChunk.hasConflict;
  // }

  Future<bool> handleRecordDeletion(UIRecord record) async {
    final bool isUnconfirmed = record.textColor == Colors.black;
    if (_context == null) return false;
    // Get the index of the record
    if (isUnconfirmed) {
      final int index =
          currentChunk.timingData.indexOf(TimingDatum(time: record.time));
      if (index == -1) {
        Logger.e('cannot find record at index $index');
        return false;
      }
      if (await DialogUtils.showConfirmationDialog(
        _context!,
        title: 'Confirm Deletion',
        content: 'Are you sure you want to delete this time?',
      )) {
        currentChunk.timingData.removeAt(index);
        notifyListeners();
        return true;
      }
      return false;
    } else {
      if (record.type == RecordType.runnerTime ||
          record.conflictTime != currentChunk.conflictRecord!.time) {
        if (record.textColor == Colors.green) {
          DialogUtils.showErrorDialog(
            _context!,
            message: record.type == RecordType.runnerTime ? 'Cannot delete a confirmed time.' : 'Cannot delete an earlier confirmation.',
          );
          return false;
        } else {
          DialogUtils.showErrorDialog(
            _context!,
            message: 'Cannot delete a time that is part of a previous conflict.',
          );
          return false;
        }
      } else if (record.type == RecordType.missingTime) {
        if (await DialogUtils.showConfirmationDialog(
          _context!,
          title: 'Confirm Deletion',
          content: 'Are you sure you want to delete this missing time?',
        )) {
          reduceCurrentConflictByOne();
          return true;
        }
        return false;
      } else if(record.type == RecordType.extraTime) {
        if (await DialogUtils.showConfirmationDialog(
          _context!,
          title: 'Confirm Deletion',
          content: 'Are you sure you want to delete this extra time?',
        )) {
          late final String? newTime;
          if(record.time == currentChunk.conflictRecord!.time) {
            newTime = currentChunk.timingData.last.time;
          } else {
            // dont change the time, since the current conflict time isnt being removed
            newTime = null;
          }
          reduceCurrentConflictByOne(newTime: newTime);
          return true;
        }
        return false;
      } else if(record.type == RecordType.confirmRunner) {
        if (await DialogUtils.showConfirmationDialog(
          _context!,
          title: 'Confirm Deletion',
          content: 'Are you sure you want to delete this conflict?',
        )) {
          currentChunk.conflictRecord == null;
          notifyListeners();
          return true;
        }
      }
      return false;
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }
}
