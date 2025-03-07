import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../model/timing_data.dart';
import '../model/runner_record.dart';
import '../../../../utils/time_formatter.dart' as time_formatter;
import '../../../../utils/runner_time_functions.dart' as runner_functions;
import '../../../../core/components/dialog_utils.dart';
import '../../../../utils/enums.dart';
import '../model/timing_utils.dart';

class TimingController extends ChangeNotifier {
  final ScrollController scrollController = ScrollController();
  late final AudioPlayer audioPlayer;
  bool isAudioPlayerReady = false;
  late TimingData timingData;
  BuildContext? _context;

  TimingController({TimingData? timingData}) {
    this.timingData = timingData ?? TimingData();
    _initializeControllers();
  }

  // Getter for records
  List<RunnerRecord> get records => timingData.records;

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
      debugPrint('Error initializing audio player: $e');
      // Don't retry if the asset is missing
      if (e.toString().contains('The asset does not exist')) {
        debugPrint('Audio asset missing - continuing without sound');
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
    final endTime = timingData.endTime;
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
    final endTime = timingData.endTime;
    if (endTime == null) return;
    
    // Calculate a new start time that maintains the same elapsed time
    // when the race was stopped
    final now = DateTime.now();
    final newStartTime = now.subtract(endTime);
    
    timingData.changeStartTime(newStartTime);
    timingData.changeEndTime(null);
    notifyListeners();
  }

  Future<void> _showStartRaceDialog() async {
    if (_context == null) return;
    
    final records = timingData.records;
    if (records.isNotEmpty) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        _context!,
        title: 'Start a New Race',
        content: 'Are you sure you want to start a new race? Doing so will clear the existing times.',
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
        content:'Are you sure you want to stop the race?', 
        title: 'Stop the Race');
    if (confirmed != true) return;
    _finalizeRace();
  }

  void _initializeNewRace() {
    timingData.clearRecords();
    timingData.changeStartTime(DateTime.now());
    timingData.changeEndTime(null);
    notifyListeners();
  }

  void _finalizeRace() {
    final startTime = timingData.startTime;
    if (startTime != null) {
      final now = DateTime.now();
      final difference = now.difference(startTime);
      
      timingData.changeEndTime(difference);
      timingData.changeStartTime(null);
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
    final startTime = timingData.startTime;
    if (startTime == null) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!, message: 'Start time cannot be null.');
      }
      return;
    }

    final difference = DateTime.now().difference(startTime);
    timingData.addRecord(
      time_formatter.formatDuration(difference),
      place: runner_functions.getNumberOfTimes(records) + 1,
    );
    scrollToBottom(scrollController);
    notifyListeners();
  }

  void confirmRunnerNumber() {
    final numTimes = runner_functions.getNumberOfTimes(records);
    final difference = getCurrentDuration(timingData.startTime, timingData.endTime);
    
    final startTime = timingData.startTime;
    if (startTime == null) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!, message: 'Race must be started to confirm a runner number.');
      }
      return;
    }
    
    // Use the imported utility function by using a namespace prefix
    timingData.records = runner_functions.confirmRunnerNumber(records, numTimes, time_formatter.formatDuration(difference));
    scrollToBottom(scrollController);
    notifyListeners();
  }

  void extraRunnerTime({int offBy = 1}) {
    final numTimes = runner_functions.getNumberOfTimes(records);
    
    if (!_validateExtraRunnerTime(numTimes, offBy)) return;
    
    final difference = getCurrentDuration(timingData.startTime, timingData.endTime);
    final startTime = timingData.startTime;
    if (startTime == null) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!, message: 'Race must be started to mark an extra runner time.');
      }
      return;
    }
    
    timingData.records = runner_functions.extraRunnerTime(offBy, records, numTimes, time_formatter.formatDuration(difference));
    scrollToBottom(scrollController);
    notifyListeners();
  }

  bool _validateExtraRunnerTime(int numTimes, int offBy) {
    if (_context == null) return false;
    
    final previousRunner = records.last;
    if (previousRunner.type != RecordType.runnerTime) {
      DialogUtils.showErrorDialog(
        _context!, 
        message: 'You must have an unconfirmed runner time before pressing this button.'
      );
      return false;
    }

    final lastConfirmedRecord = records.lastWhere(
      (r) => r.type == RecordType.runnerTime && r.isConfirmed == true,
      orElse: () => RunnerRecord(
        id: '',
        elapsedTime: '',
        place: 0,
      ),
    );
    final recordPlace = lastConfirmedRecord.place ?? 0;

    if (numTimes - offBy == recordPlace) {
      _handleTimesDeletion(offBy);
      return false;
    } else if (numTimes - offBy < recordPlace) {
      DialogUtils.showErrorDialog(
        _context!, 
        message: 'You cannot remove a runner that is confirmed.'
      );
      return false;
    }

    return true;
  }

  Future<void> _handleTimesDeletion(int offBy) async {
    if (_context == null) return;
    
    final confirmed = await DialogUtils.showConfirmationDialog(
      _context!,
      content: 'This will delete the last $offBy finish times, are you sure you want to continue?',
      title: 'Confirm Deletion'
    );
    
    if (confirmed) {
      // Get a list of ids to remove
      final idsToRemove = records
          .reversed
          .take(offBy)
          .map((record) => record.id)
          .toList();
          
      // Remove records with those ids
      for (final id in idsToRemove) {
        final index = records.indexWhere((record) => record.id == id);
        if (index >= 0) {
          timingData.removeRecord(id);
        }
      }
      notifyListeners();
    }
  }

  void missingRunnerTime({int offBy = 1}) {
    final numTimes = runner_functions.getNumberOfTimes(records);
    final difference = getCurrentDuration(timingData.startTime, timingData.endTime);
    
    final startTime = timingData.startTime;
    
    if (startTime == null) {
      if (_context != null) {
        DialogUtils.showErrorDialog(_context!, message: 'Race must be started to mark a missing runner time.');
      }
      return;
    }
    
    timingData.records = runner_functions.missingRunnerTime(offBy, records, numTimes, time_formatter.formatDuration(difference));
    scrollToBottom(scrollController);
    notifyListeners();
  }

  void undoLastConflict() {
    try {
      final lastConflict = records.lastWhere(
        (r) => r.hasConflict() && !r.isResolved(),
        orElse: () => throw Exception('No undoable conflict found'),
      );
      
      if (lastConflict.conflict?.type == RecordType.extraRunner) {
        timingData.records = _undoExtraRunnerConflict(lastConflict, records);
      } else if (lastConflict.conflict?.type == RecordType.missingRunner) {
        timingData.records = _undoMissingRunnerConflict(lastConflict, records);
      }
      scrollToBottom(scrollController);
      notifyListeners();
    } catch (e) {
      debugPrint('Error undoing conflict: $e');
    }
  }

  List<RunnerRecord> _undoExtraRunnerConflict(RunnerRecord lastConflict, List<RunnerRecord> records) {
    if (lastConflict.isResolved()) {
      return records;
    }
    final lastConflictIndex = records.indexOf(lastConflict);
    final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r.type == RecordType.runnerTime).toList();
    final offBy = lastConflict.conflict?.data?['offBy'];

    records = runner_functions.updateTextColor(null, records, confirmed: false, endIndex: lastConflictIndex, clearConflictColor: true);
    for (int i = 0; i < offBy; i++) {
      final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
      record.previousPlace = record.place;
      print('Record: $record');
    }
    
    records.removeWhere((record) => record.id == lastConflict.id);
    return records;
  }

  List<RunnerRecord> _undoMissingRunnerConflict(RunnerRecord lastConflict, List<RunnerRecord> records) {
    if (lastConflict.isResolved()) {
      return records;
    }
    final lastConflictIndex = records.indexOf(lastConflict);
    final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r.type == RecordType.runnerTime).toList();
    final offBy = lastConflict.conflict?.data?['offBy'];

    records = runner_functions.updateTextColor(null, records, confirmed: false, endIndex: lastConflictIndex, clearConflictColor: true);
    
    // Store the IDs of records to remove
    final recordIdsToRemove = <String>[];
    
    for (int i = 0; i < offBy; i++) {
      final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
      recordIdsToRemove.add(record.id);
      print('Adding record ID to remove: ${record.id}');
    }

    recordIdsToRemove.add(lastConflict.id);
    // Remove records by ID
    records.removeWhere((record) => recordIdsToRemove.contains(record.id));
    
    if (records.isNotEmpty) {
      print('Last record after removals: ${records.last.toMap()}');
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
        timingData.clearRecords();
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
      records.last.hasConflict() &&
      !records.last.isResolved();
  }

  Future<bool> confirmRecordDismiss(RunnerRecord record) async {
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
    } else if (record.type == RecordType.missingRunner || record.type == RecordType.extraRunner) {
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

  void onDismissRunnerTimeRecord(RunnerRecord record, int index) {
    timingData.removeRecord(record.id);
    
    // Update places for subsequent records
    for (var i = index; i < records.length; i++) {
      if (records[i].type == RecordType.runnerTime) {
        if (records[i].place != null) {
          timingData.updateRecord(records[i].id, place: records[i].place! - 1);
        }
        else if (records[i].previousPlace != null) {
           timingData.updateRecord(records[i].id, previousPlace: records[i].previousPlace! - 1);
        }
      }
    }
    scrollToBottom(scrollController);
    notifyListeners();
  }

  void onDismissConfirmationRecord(RunnerRecord record, int index) {
    timingData.removeRecord(record.id);
    timingData.records = runner_functions.updateTextColor(null, records, endIndex: index);
    scrollToBottom(scrollController);
    notifyListeners();
  }

  void onDismissConflictRecord(RunnerRecord record) {
    undoLastConflict();
    scrollToBottom(scrollController);
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('TimingController disposed');
    scrollController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }
}
