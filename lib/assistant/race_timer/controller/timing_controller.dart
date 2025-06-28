import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/utils/enums.dart';
import '../model/timing_data.dart';
import '../../../shared/models/time_record.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/utils/runner_time_functions.dart' as runner_functions;
import '../../../core/components/dialog_utils.dart';
import '../model/timing_utils.dart';

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

    final difference = DateTime.now().difference(startTime!);
    addRecord(
      TimeFormatter.formatDuration(difference),
      place: runner_functions.getNumberOfTimes(records) + 1,
    );
    scrollToBottom(scrollController);
    notifyListeners();
  }

  void confirmTimes() {
    final numTimes = runner_functions.getNumberOfTimes(records);
    final currentDuration = getCurrentDuration(startTime, endTime);

    if (startTime == null || raceStopped) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!,
            message: 'Race must be started to confirm a time.');
      }
      return;
    }

    if (records.last.type == RecordType.confirmRunner) {
      undoLastConflict();
    }

    // Use the imported utility function by using a namespace prefix
    records = runner_functions.confirmTimes(
        records, numTimes, TimeFormatter.formatDuration(currentDuration));
    scrollToBottom(scrollController);
    notifyListeners();
  }

  Future<void> removeExtraTime({int offBy = 1}) async {
    int numTimes = runner_functions.getNumberOfTimes(records);

    if (!await _validateOffBy(numTimes, offBy)) return;
    final currentDuration = getCurrentDuration(startTime, endTime);

    if (startTime == null || raceStopped) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!,
            message: 'Race must be started to mark an extra time.');
      }
      return;
    }

    // Check if previous record is also an extraTime conflict
    if (records.isNotEmpty && records.last.type == RecordType.extraTime) {
      final lastConflict = records.last.conflict;
      if (lastConflict != null &&
          lastConflict.data != null &&
          lastConflict.data!['offBy'] != null) {
        offBy += lastConflict.data!['offBy'] as int;
        undoLastConflict();
        Logger.d('last record: ${records.last.toMap()}');
        numTimes = runner_functions.getNumberOfTimes(records);
        if (!await _validateOffBy(numTimes, offBy)) {
          return;
        }
      }
    }

    records = runner_functions.removeExtraTime(offBy, records, numTimes,
        TimeFormatter.formatDuration(currentDuration));
    scrollToBottom(scrollController);
    notifyListeners();
  }

  Future<bool> _validateOffBy(int numTimes, int offBy) async {
    if (_context == null) return false;

    final previousRecord = records.last;

    if (previousRecord.type != RecordType.runnerTime &&
        previousRecord.type != RecordType.extraTime) {
      DialogUtils.showErrorDialog(_context!,
          message:
              'You must have an unconfirmed time before pressing this button.');
      return false;
    }

    final lastConfirmedRecord = records.lastWhere(
      (r) => r.type == RecordType.runnerTime && r.isConfirmed == true,
      orElse: () => TimeRecord(
        elapsedTime: '',
        place: 0,
      ),
    );
    final recordPlace = lastConfirmedRecord.place ?? 0;

    Logger.d('Off by: $offBy');
    Logger.d('Record place: $recordPlace');
    Logger.d('Num times: $numTimes');
    Logger.d('Num times - off by: ${numTimes - offBy}');
    Logger.d('Last record in _validateOffBy: ${records.last.toMap()}');

    if (numTimes - offBy == recordPlace) {
      await _handleTimesDeletion(offBy);
      return false;
    } else if (numTimes - offBy < recordPlace) {
      DialogUtils.showErrorDialog(_context!,
          message: 'You cannot remove a time that is confirmed.');
      return false;
    }

    return true;
  }

  Future<void> _handleTimesDeletion(int offBy) async {
    if (_context == null) return;

    final confirmed = await DialogUtils.showConfirmationDialog(_context!,
        content:
            'This will delete the last $offBy finish times, are you sure you want to continue?',
        title: 'Confirm Deletion');
    Logger.d('last recor in _handleTimesDeletion: ${records.last.toMap()}');
    if (confirmed) {
      for (int i = 0; i < offBy; i++) {
        Logger.d('Removing record ${records.last.place}');
        Logger.d('Removing record ${records.last.toMap()}');
        records.removeLast();
      }
      notifyListeners();
    }
  }

  Future<void> addMissingTime({int offBy = 1}) async {
    final numTimes = runner_functions.getNumberOfTimes(records);
    final currentDuration = getCurrentDuration(startTime, endTime);

    if (startTime == null) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!,
            message: 'Race must be started to mark a missing time.');
      }
      return;
    }

    // Check if previous record is also a missingTime conflict
    if (records.isNotEmpty && records.last.type == RecordType.missingTime) {
      Logger.d('Previous record is also a missingTime conflict');
      int prevOffBy = 0;
      final lastConflict = records.last.conflict;
      if (lastConflict != null &&
          lastConflict.data != null &&
          lastConflict.data!['offBy'] != null) {
        prevOffBy = lastConflict.data!['offBy'] as int;
      }
      undoLastConflict();
      offBy += prevOffBy;
      Logger.d('Off by: $offBy');
    }

    records = runner_functions.addMissingTime(offBy, records, numTimes,
        TimeFormatter.formatDuration(currentDuration));
    scrollToBottom(scrollController);
    notifyListeners();
  }

  void undoLastConflict() {
    try {
      if (records.last.type == RecordType.confirmRunner) {
        _undoConfirmTime();
        return;
      }
      final lastConflict = records.lastWhere(
        (r) => r.hasConflict() && !r.isResolved(),
        orElse: () => throw Exception('No undoable conflict found'),
      );

      if (lastConflict.conflict?.type == RecordType.extraTime) {
        records = _undoExtraTimeConflict(lastConflict, records);
      } else if (lastConflict.conflict?.type == RecordType.missingTime) {
        records = _undoMissingTimeConflict(lastConflict, records);
      }
      scrollToBottom(scrollController);
      notifyListeners();
    } catch (e) {
      Logger.d('Error undoing conflict: $e');
    }
  }

  void _undoConfirmTime() {
    if (records.last.type != RecordType.confirmRunner) {
      throw Exception('Last record is not a confirm runner');
    }
    records.removeLast();
    records = runner_functions.updateTextColor(null, records,
        confirmed: false, endIndex: records.length, clearConflictColor: true);
    scrollToBottom(scrollController);
    notifyListeners();
  }

  List<TimeRecord> _undoExtraTimeConflict(
      TimeRecord lastConflict, List<TimeRecord> records) {
    if (lastConflict.isResolved()) {
      return records;
    }
    final lastConflictIndex = records.indexOf(lastConflict);
    final recordsBeforeConflict = records
        .sublist(0, lastConflictIndex)
        .where((r) => r.type == RecordType.runnerTime)
        .toList();
    final offBy = lastConflict.conflict?.data?['offBy'] ?? 0;

    final lastConfirmIndexBeforeConflict = records
        .sublist(0, lastConflictIndex)
        .lastIndexWhere((r) => r.type == RecordType.confirmRunner);

    final newRecords = runner_functions.updateTextColor(null,
        records.sublist(lastConfirmIndexBeforeConflict + 1, lastConflictIndex),
        confirmed: false, clearConflictColor: true);

    // Replace the records in the specified range
    // First remove the existing elements in that range
    records.removeRange(lastConfirmIndexBeforeConflict + 1, lastConflictIndex);
    // Then insert the new elements at the correct position
    records.insertAll(lastConfirmIndexBeforeConflict + 1, newRecords);

    // Safely update previous place for affected records
    for (int i = 0; i < offBy; i++) {
      if (i < recordsBeforeConflict.length) {
        final recordIndex = lastConflictIndex - 1 - i;
        if (recordIndex >= 0 && recordIndex < records.length) {
          final record = records[recordIndex];
          record.place = record.previousPlace;
        }
      }
    }

    Logger.d('Removing record: ${records.removeAt(lastConflictIndex).toMap()}');

    notifyListeners();

    return records;
  }

  List<TimeRecord> _undoMissingTimeConflict(
      TimeRecord lastConflict, List<TimeRecord> records) {
    if (lastConflict.isResolved()) {
      return records;
    }
    final lastConflictIndex = records.indexOf(lastConflict);
    final recordsBeforeConflict = records
        .sublist(0, lastConflictIndex)
        .where((r) => r.type == RecordType.runnerTime)
        .toList();
    final offBy = lastConflict.conflict?.data?['offBy'] ?? 0;

    records = runner_functions.updateTextColor(null, records,
        confirmed: false,
        endIndex: lastConflictIndex,
        clearConflictColor: true);

    // Store the IDs of records to remove
    final recordIndicesToRemove = <int>[];

    for (int i = 0; i < offBy; i++) {
      if (i < recordsBeforeConflict.length) {
        recordIndicesToRemove.add(lastConflictIndex - i - 1);
      }
    }

    recordIndicesToRemove.add(lastConflictIndex);

    // Remove records by Index
    for (int index in recordIndicesToRemove.sorted((a, b) => b.compareTo(a))) {
      Logger.d('Removing record at index: $index');
      if (index >= 0 && index < records.length) {
        records.removeAt(index);
      }
    }

    return records;
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
    return records.isNotEmpty &&
        ((records.last.hasConflict() && !records.last.isResolved()) ||
            records.last.type == RecordType.confirmRunner);
  }

  Future<bool> confirmRecordDismiss(TimeRecord record) async {
    if (_context == null) return false;

    if (record.type == RecordType.runnerTime) {
      if (record.conflict != null) {
        DialogUtils.showErrorDialog(
          _context!,
          message: 'Cannot delete a time that is part of a conflict.',
        );
        return false;
      }

      if (record.isConfirmed == true) {
        DialogUtils.showErrorDialog(
          _context!,
          message: 'Cannot delete a confirmed time.',
        );
        return false;
      }

      return await DialogUtils.showConfirmationDialog(
        _context!,
        title: 'Confirm Deletion',
        content: 'Are you sure you want to delete this time?',
      );
    } else if (record.type == RecordType.confirmRunner) {
      if (records.last != record) {
        DialogUtils.showErrorDialog(
          _context!,
          message: 'Cannot delete a confirmation that is not the last one.',
        );
        return false;
      }

      return await DialogUtils.showConfirmationDialog(
        _context!,
        title: 'Confirm Deletion',
        content: 'Are you sure you want to delete this confirmation?',
      );
    } else if (record.type == RecordType.missingTime ||
        record.type == RecordType.extraTime) {
      if (records.last != record) {
        DialogUtils.showErrorDialog(
          _context!,
          message: 'Cannot undo a conflict that is not the last one.',
        );
        return false;
      }

      return await DialogUtils.showConfirmationDialog(
        _context!,
        title: 'Confirm Undo',
        content: 'Are you sure you want to undo this conflict?',
      );
    }

    return false;
  }

  void onDismissRunnerTimeRecord(TimeRecord record, int index) {
    // When removing a record, we need to handle records with no runnerId differently
    if (record.runnerId != null) {
      removeRecord(record.runnerId!);
    } else {
      // For records without a runnerId (like manual entries or unidentified runners)
      // Remove directly from the records list by index
      final records = List<TimeRecord>.from(this.records);
      if (index >= 0 && index < records.length) {
        records.removeAt(index);
        this.records = records;
      }
    }

    // Update places for subsequent records
    for (var i = index; i < records.length; i++) {
      if (records[i].type == RecordType.runnerTime) {
        if (records[i].place != null) {
          // Only try to update if runnerId is not null
          if (records[i].runnerId != null) {
            updateRecord(records[i].runnerId!, place: records[i].place! - 1);
          }
        } else if (records[i].previousPlace != null) {
          // Only try to update if runnerId is not null
          if (records[i].runnerId != null) {
            updateRecord(records[i].runnerId!,
                previousPlace: records[i].previousPlace! - 1);
          }
        }
      }
    }
    scrollToBottom(scrollController);
    notifyListeners();
  }

  void onDismissConfirmationRecord(TimeRecord record, int index) {
    removeRecord(record.runnerId!);
    records = runner_functions.updateTextColor(null, records, endIndex: index);
    scrollToBottom(scrollController);
    notifyListeners();
  }

  void onDismissConflictRecord(TimeRecord record) {
    undoLastConflict();
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
