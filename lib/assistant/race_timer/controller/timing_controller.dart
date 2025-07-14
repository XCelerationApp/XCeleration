import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/utils/enums.dart';
import '../model/timing_data.dart';
import '../../../core/utils/encode_utils.dart';
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
    final hasStoppedRace = endTime != null && records.isNotEmpty;

    if (hasStoppedRace) {
      // Continue the race instead of starting a new one
      _continueRace();
    } else if (records.isNotEmpty) {
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

    if (records.isNotEmpty) {
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

  Future<String> encodedRecords() async {
    return await TimingEncodeUtils.encodeTimeRecords(records);
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

    final difference =
        TimeFormatter.formatDuration(DateTime.now().difference(startTime!));
    addRecord(TimingDatum(time: difference));
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
    final currentDuration = getCurrentDuration(startTime, endTime);

    if (records.last.conflict?.type == ConflictType.confirmRunner) {
      records.last.time = TimeFormatter.formatDuration(currentDuration);
      notifyListeners();
      return;
    }
    records.add(TimingDatum(time: TimeFormatter.formatDuration(currentDuration), conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1)));
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

    if (records.isNotEmpty &&
        records.last.conflict?.type == ConflictType.confirmRunner) {
      DialogUtils.showErrorDialog(_context!,
          message: 'You cannot remove a confirmed time.');
      return;
    }

    final currentDuration = getCurrentDuration(startTime, endTime);

    // Check if previous record is also an extraTime conflict
    if (records.isNotEmpty &&
        records.last.conflict?.type == ConflictType.extraTime) {
      final int offBy = records.last.conflict!.offBy + 1;
      if (!await _validateExtraTimeConflict()) return;
      records.last.conflict!.offBy = offBy;
      records.last.time = TimeFormatter.formatDuration(currentDuration);
      notifyListeners();
      return;
    }

    if (records.isNotEmpty &&
        records.last.conflict?.type == ConflictType.missingTime) {
      final int offBy = records.last.conflict!.offBy - 1;
      if (offBy <= 0) {
        records.removeLast();
        notifyListeners();
        return;
      }
      records.last.conflict!.offBy = offBy;
      records.last.time = TimeFormatter.formatDuration(currentDuration);
      notifyListeners();
      return;
    }

    final int offBy = 1;

    records.add(TimingDatum(
        time: TimeFormatter.formatDuration(currentDuration),
        conflict: Conflict(type: ConflictType.extraTime, offBy: offBy)));
    if (!await _validateExtraTimeConflict()) {
      // There is only one unconfirmed time, and user does not want to remove it
      // remove the extra time conflict, since the user canceled
      records.removeLast();
      return;
    }
    scrollToBottom(scrollController);
    notifyListeners();
  }

  Future<bool> _validateExtraTimeConflict() async {
    if (_context == null) return false;

    final conflict = records.last.conflict;
    if (conflict == null) return false;

    if (conflict.type == ConflictType.confirmRunner) {
      return false;
    }

    final numOtherRecords = records.length - 1;

    // Get the first conflict starting from the end, excluding the last record

    late int numUnconfirmedRecords;

    final lastConflictIndex = records
        .take(records.length > 1 ? numOtherRecords : 0)
        .toList()
        .lastIndexWhere((r) => r.conflict != null);
    if (lastConflictIndex == -1) {
      numUnconfirmedRecords = numOtherRecords;
    } else {
      numUnconfirmedRecords = numOtherRecords - lastConflictIndex;
    }
    // If off by is less than the number of records (excluding the last record, which is the current conflict), then the conflict is valid
    if (conflict.offBy < numUnconfirmedRecords) {
      return true;
    } else if (conflict.offBy == numUnconfirmedRecords) {
      // let the user decide if they want to remove all the unconfirmed times
      return _handleTimesDeletion();
    } else {
      return false;
    }
  }

  Future<bool> _handleTimesDeletion() async {
    if (_context == null) return false;

    final conflict = records.last.conflict;
    if (conflict == null) return false;

    if (conflict.type != ConflictType.extraTime) {
      return false;
    }

    final offBy = conflict.offBy;

    final confirmed = await DialogUtils.showConfirmationDialog(_context!,
        content:
            'This will delete the last $offBy finish times, are you sure you want to continue?',
        title: 'Confirm Deletion');
    if (confirmed) {
      records.removeRange(records.length - offBy - 1, records.length);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> addMissingTime() async {
    if (startTime == null) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!,
            message: 'Race must be started to mark a missing time.');
      }
      return;
    }

    final currentDuration = getCurrentDuration(startTime, endTime);

    // Check if previous record is also a missingTime conflict
    if (records.isNotEmpty &&
        records.last.conflict?.type == ConflictType.missingTime) {
      records.last.conflict!.offBy += 1;
      records.last.time = TimeFormatter.formatDuration(currentDuration);
      notifyListeners();
      return;
    } else {
      records.add(TimingDatum(
          time: TimeFormatter.formatDuration(currentDuration),
          conflict: Conflict(type: ConflictType.missingTime, offBy: 1)));
      scrollToBottom(scrollController);
      notifyListeners();
    }
  }

  void undoLastConflict() {
    final conflict = records.last.conflict;
    if (conflict == null) {
      Logger.d('No conflict found');
      return;
    }
    records.removeLast();
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
      }
    });
  }

  Duration calculateElapsedTime(DateTime? startTime, Duration? endTime) {
    if (startTime == null) {
      return endTime ?? Duration.zero;
    }
    return DateTime.now().difference(startTime);
  }

  bool hasUndoableConflict() {
    return records.isNotEmpty && records.last.conflict != null;
  }

  Future<bool> confirmRecordDeletion(TimingDatum record) async {
    if (_context == null) return false;
    // Get the index of the record
    if (record.conflict == null) {
      final int index = records.indexOf(record);
      if (index == -1) return false;

      // Go towards the end of the records list until a conflict record is found
      TimingDatum? conflictRecord;
      for (int i = index; i < records.length; i++) {
        final r = records[i];
        if (r.conflict != null) {
          conflictRecord = r;
          break;
        }
      }

      if (conflictRecord?.conflict?.type == ConflictType.confirmRunner) {
        DialogUtils.showErrorDialog(
          _context!,
          message: 'Cannot delete a confirmed time.',
        );
        return false;
      } else if (conflictRecord?.conflict?.type != null) {
        DialogUtils.showErrorDialog(
          _context!,
          message: 'Cannot delete a time that is part of a conflict.',
        );
        return false;
      } else {
        return await DialogUtils.showConfirmationDialog(
          _context!,
          title: 'Confirm Deletion',
          content: 'Are you sure you want to delete this time?',
        );
      }
    } else {
      if (records.last != record) {
        if (record.conflict?.type == ConflictType.confirmRunner) {
          DialogUtils.showErrorDialog(
            _context!,
            message: 'Cannot delete a confirmation that is not the last one.',
          );
          return false;
        } else {
            DialogUtils.showErrorDialog(
              _context!,
              message: 'Cannot undo a conflict that is not the last one.',
            );
            return false;
          }
      } else {
        return await DialogUtils.showConfirmationDialog(
          _context!,
          title: 'Confirm Undo',
          content: 'Are you sure you want to undo this conflict?',
        );
      }
    }
  }

  void dismissTimeRecord(TimingDatum record) {
    records.remove(record);
    scrollToBottom(scrollController);
    notifyListeners();
  }

  @override
  void dispose() {
    scrollController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }
}
