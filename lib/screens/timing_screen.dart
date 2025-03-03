import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/timing_data.dart';
import '../models/runner_record.dart';
import '../utils/time_formatter.dart';
import '../utils/app_colors.dart';
import '../utils/device_connection_widget.dart';
import '../runner_time_functions.dart';
import '../utils/timing_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/button_utils.dart';
import '../utils/device_connection_service.dart';
import '../role_functions.dart';
import '../utils/tutorial_manager.dart';
import '../utils/typography.dart';
import '../utils/enums.dart';
import '../utils/sheet_utils.dart';


class TimingScreen extends StatefulWidget {
  const TimingScreen({super.key});

  @override
  State<TimingScreen> createState() => _TimingScreenState();
}

class _TimingScreenState extends State<TimingScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AudioPlayer _audioPlayer;
  bool _isAudioPlayerReady = false;
  late final TabController _tabController;
  late TimingData _timingData;
  List<RunnerRecord> get _records => _timingData.records;
  RunnerRecord? _selectedRecord;
  final TutorialManager tutorialManager = TutorialManager();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initAudioPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
        _setupTutorials();
    });
  }

  void _setupTutorials() {
    tutorialManager.startTutorial([
      // 'swipe_tutorial',
      'role_bar_tutorial',
    ]);
  }

  void _initializeControllers() {
    _tabController = TabController(length: 3, vsync: this);
    _audioPlayer = AudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setSource(AssetSource('sounds/click.mp3'));
      if (mounted) setState(() => _isAudioPlayerReady = true);
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
      // Don't retry if the asset is missing
      if (e.toString().contains('The asset does not exist')) {
        debugPrint('Audio asset missing - continuing without sound');
        return;
      }
      // Only retry for other types of errors
      if (!_isAudioPlayerReady && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        _initAudioPlayer();
      }
    }
  }

  void _startRace() {
    final endTime = _timingData.endTime;
    final hasStoppedRace = endTime != null && _records.isNotEmpty;
    
    if (hasStoppedRace) {
      // Continue the race instead of starting a new one
      _continueRace();
    } else if (_records.isNotEmpty) {
      // Ask for confirmation before starting a new race
      _showStartRaceDialog();
    } else {
      // Start a brand new race
      _initializeNewRace();
    }
  }

  void _continueRace() {
    final endTime = _timingData.endTime;
    if (endTime == null) return;
    
    // Calculate a new start time that maintains the same elapsed time
    // when the race was stopped
    final now = DateTime.now();
    final newStartTime = now.subtract(endTime);
    
    setState(() {
      _timingData.changeStartTime(newStartTime);
      _timingData.changeEndTime(null);
    });
  }

  Future<void> _showStartRaceDialog() async {
    final records = Provider.of<TimingData>(context, listen: false).records;
    if (records.isNotEmpty) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Start a New Race',
        content: 'Are you sure you want to start a new race? Doing so will clear the existing times.',
      );
      if (confirmed != true) return;
      _initializeNewRace();
    } else {
      _initializeNewRace();
    }
  }

  Future<void> _stopRace() async{
    final confirmed = await DialogUtils.showConfirmationDialog(context, content:'Are you sure you want to stop the race?', title: 'Stop the Race');
    if (confirmed != true) return;
    _finalizeRace();
  }



  void _initializeNewRace() {
    setState(() {
      _timingData.clearRecords();
      _timingData.changeStartTime(DateTime.now());
      _timingData.changeEndTime(null);
    });
  }


  void _finalizeRace() {
    final startTime = _timingData.startTime;
    if (startTime != null) {
      final now = DateTime.now();
      final difference = now.difference(startTime);
      setState(() {
        Future.microtask(() {
          _timingData.changeEndTime(difference);
          _timingData.changeStartTime(null);
        });
      });
      
      // final conflict = _getFirstConflict();
      // if (conflict[0] != null) {
      //   DialogUtils.showErrorDialog(
      //     context, 
      //     message: 'Race stopped. Make sure to resolve conflicts after loading bib numbers.',
      //     title: 'Race Stopped'
      //   );
      // }
    }
  }

  Future<void> _handleLogButtonPress() async {
      _logTime();
      await HapticFeedback.vibrate();
      await HapticFeedback.lightImpact();
      
      if (_isAudioPlayerReady) {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource('sounds/click.mp3'));
      }
  }

  void _logTime() {
    final startTime = _timingData.startTime;
    if (startTime == null) {
      DialogUtils.showErrorDialog(context, message: 'Start time cannot be null.');
      return;
    }

    final difference = DateTime.now().difference(startTime);
    setState(() {
      _timingData.addRecord(
        formatDuration(difference),
        place: getNumberOfTimes(_records) + 1,
      );
      scrollToBottom(_scrollController);
    });
  }


  // List<dynamic> _getFirstConflict() {
  //   for (var record in _records) {
  //     if (record['type'] != 'runner_time' && record['type'] != 'confirm_runner_number') {
  //       return [record['type'], _records.indexOf(record)];
  //     }
  //   }
  //   return [null, -1];
  // }

  void _confirmRunnerNumber() {
    final numTimes = getNumberOfTimes(_records);
    final difference = getCurrentDuration(_timingData.startTime, _timingData.endTime);
    
    final startTime = _timingData.startTime;
    if (startTime == null) {
      DialogUtils.showErrorDialog(context, message: 'Race must be started to confirm a runner number.');
      return;
    }
    
    // final now = DateTime.now();
    setState(() {
      _timingData.records = confirmRunnerNumber(_records, numTimes, formatDuration(difference));
      scrollToBottom(_scrollController);
    });
  }
  


  void _extraRunnerTime({int offBy = 1}) {
    final numTimes = getNumberOfTimes(_records);
    
    if (!_validateExtraRunnerTime(numTimes, offBy)) return;
    

    final difference = getCurrentDuration(_timingData.startTime, _timingData.endTime);
    final startTime = _timingData.startTime;
    if (startTime == null) {
      DialogUtils.showErrorDialog(context, message: 'Race must be started to mark an extra runner time.');
      return;
    }
    
    
    setState(() {
      _timingData.records = extraRunnerTime(offBy, _records, numTimes, formatDuration(difference));
      scrollToBottom(_scrollController);
    });
  }

  bool _validateExtraRunnerTime(int numTimes, int offBy) {
    final previousRunner = _records.last;
    if (previousRunner.type != RecordType.runnerTime) {
      DialogUtils.showErrorDialog(
        context, 
        message: 'You must have an unconfirmed runner time before pressing this button.'
      );
      return false;
    }

    final lastConfirmedRecord = _records.lastWhere(
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
        context, 
        message: 'You cannot remove a runner that is confirmed.'
      );
      return false;
    }

    return true;
  }

  Future<void> _handleTimesDeletion(int offBy) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      content: 'This will delete the last $offBy finish times, are you sure you want to continue?',
      title: 'Confirm Deletion'
    );
    
    if (confirmed) {
      setState(() {
        // Get a list of ids to remove
        final idsToRemove = _records
            .reversed
            .take(offBy)
            .map((record) => record.id)
            .toList();
            
        // Remove records with those ids
        for (final id in idsToRemove) {
          final index = _records.indexWhere((record) => record.id == id);
          if (index >= 0) {
            _timingData.removeRecord(id);
          }
        }
      });
    }
  }

  void _missingRunnerTime({int offBy = 1}) {
    final numTimes = getNumberOfTimes(_records);
    final difference = getCurrentDuration(_timingData.startTime, _timingData.endTime);
    

    final startTime = _timingData.startTime;
    
    if (startTime == null) {
      DialogUtils.showErrorDialog(context, message: 'Race must be started to mark a missing runner time.');
      return;
    }
    
    setState(() {
      _timingData.records = missingRunnerTime(offBy, _records, numTimes, formatDuration(difference));
      scrollToBottom(_scrollController);
    });
  }

  void _undoLastConflict() {
    final lastConflict = _records.lastWhere(
      (r) => r.hasConflict() && !r.isResolved(),
      orElse: () => throw Exception("No undoable conflict found"),
    );
    
    if (lastConflict.conflict?.type == RecordType.extraRunner) {
       _timingData.records = _undoExtraRunnerConflict(lastConflict, _records);
    } else if (lastConflict.conflict?.type == RecordType.missingRunner) {
      _timingData.records = _undoMissingRunnerConflict(lastConflict, _records);
    }
  }

  List<RunnerRecord> _undoExtraRunnerConflict(RunnerRecord lastConflict, records) {
    if (lastConflict.isResolved()) {
      return records;
    }
    final lastConflictIndex = records.indexOf(lastConflict);
    final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r.type == RecordType.runnerTime).toList();
    final offBy = lastConflict.conflict?.data?['offBy'];

    records = updateTextColor(Colors.transparent, records, confirmed: false, endIndex: lastConflictIndex);
    for (int i = 0; i < offBy; i++) {
      final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
      setState(() {
        print('preivous place: ${record.previousPlace}');
        record.previousPlace = record.place;
        // _timingData.updateRecord(record.id, place: record.previousPlace);
        print('new place: ${record.place}');
      });
    }
    setState(() {
      records.remove(lastConflict);
      // _timingData.removeRecord(lastConflict.id);
    });
    return records;
  }

  List<RunnerRecord> _undoMissingRunnerConflict(RunnerRecord lastConflict, records) {
    if (lastConflict.isResolved()) {
      return records;
    }
    final lastConflictIndex = records.indexOf(lastConflict);
    final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r.type == RecordType.runnerTime).toList();
    final offBy = lastConflict.conflict?.data?['offBy'];
    print('off by: $offBy');
    // final controllers = Provider.of<TimingData>(context, listen: false).c[raceId] ?? [];

    records = updateTextColor(Colors.transparent, records, confirmed: false, endIndex: lastConflictIndex);
    for (int i = 0; i < offBy; i++) {
      final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
      print('remove record: $record');
      setState(() {
        records.remove(record);
      });
    }
    setState(() {
      records.remove(lastConflict);
    });
    return records;
  }

  // void _updateTextColor(Color? color, {bool confirmed = false, Map<String, dynamic>? conflict, List<RunnerRecord>? records, int? endIndex}) {
  //   records ??= _records;
  //   endIndex ??= records.length;
  //   endIndex = min(endIndex, records.length);

  //   for (int i = records.length - 1; i >= 0; i--) {
  //     final record = records[i];
      
  //     setState(() {
  //       _timingData.updateRecord(
  //         record.id,
  //         isConfirmed: confirmed,
  //       );
  //     });
  //   }
  // }

  void _clearRaceTimes() {
    showDialog<bool>(
      context: context,
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
        setState(() {
          _timingData.clearRecords();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
      _timingData = Provider.of<TimingData>(context, listen: false);
    final startTime = _timingData.startTime;
    final endTime = _timingData.endTime;

    return TutorialRoot(
      tutorialManager: tutorialManager,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildRoleBar(context, 'timer', tutorialManager),
              const SizedBox(height: 8),
              _buildRaceInfoHeader(),
              const SizedBox(height: 8),
              _buildTimerDisplay(startTime, endTime),
              _buildControlButtons(startTime),
              if (_records.isNotEmpty) const SizedBox(height: 30),
              Expanded(child: _buildRecordsList()),
              if (startTime != null && _records.isNotEmpty)
                _buildBottomControls(),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildRaceInfoHeader() {
    final startTime = _timingData.startTime;
    final endTime = _timingData.endTime;
    final hasRace = startTime != null || (endTime != null && _records.isNotEmpty);
    final isRaceFinished = startTime == null && endTime != null && _records.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: hasRace ? const Color(0xFFF5F5F5) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: hasRace ? Border.all(color: Colors.grey.withOpacity(0.2)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isRaceFinished ? 'Race finished' : (hasRace ? 'Race in progress' : 'Ready to start'),
            style: AppTypography.bodyRegular.copyWith(
              fontSize: 16,
              color: hasRace 
                ? isRaceFinished ? Colors.green[700] : AppColors.primaryColor
                : Colors.black54,
              fontWeight: hasRace ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (_records.isNotEmpty)
            Text(
              'Runners: ${_records.where((r) => r.type == RecordType.runnerTime).length}',
              style: AppTypography.bodyRegular.copyWith(
                fontSize: 16,
                color: hasRace ? Colors.black87 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(DateTime? startTime, Duration? endTime) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 10)),
      builder: (context, _) {
        final elapsed = _calculateElapsedTime(startTime, endTime);
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 16),
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              formatDurationWithZeros(elapsed),
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.135,
                fontFamily: 'RobotoMono',
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButtons(DateTime? startTime) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRaceControlButton(startTime),
        if (startTime == null && _records.isNotEmpty)
          _buildShareButton(),
        _buildLogButton(startTime),
      ],
    );
  }

  Widget _buildRaceControlButton(DateTime? startTime) {
    final endTime = _timingData.endTime;
    final hasStoppedRace = startTime == null && endTime != null && _records.isNotEmpty;
    
    final buttonText = startTime != null ? 'Stop' : (hasStoppedRace ? 'Continue' : 'Start');
    final buttonColor = startTime == null ? Colors.green : Colors.red;
    
    return CircularButton(
      text: buttonText,
      color: buttonColor,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      onPressed: startTime == null ? _startRace : _stopRace,
    );
  }

  Widget _buildShareButton() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ElevatedButton(
              onPressed: () => sheet(
                context: context,
                title: 'Share Times',
                body: deviceConnectionWidget(
                  DeviceName.raceTimer,
                  DeviceType.advertiserDevice,
                  createOtherDeviceList(
                    DeviceName.raceTimer,
                    DeviceType.advertiserDevice,
                    data: _timingData.encode(),
                  ),
                )
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 78),
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.darkColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(39),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.share, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Share Times',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkColor,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogButton(DateTime? startTime) {
    return CircularButton(
      text: (_records.isEmpty || startTime != null) ? 'Log' : 'Clear',
      color: (_records.isEmpty && startTime == null) ? const Color.fromARGB(255, 201, 201, 201) : const Color(0xFF777777),
      fontSize: 18,
      fontWeight: FontWeight.w600,
      onPressed: (_records.isNotEmpty && startTime == null)
          ? _clearRaceTimes
          : (startTime != null ? _handleLogButtonPress : null),
    );
  }

  Widget _buildRecordsList() {
    if (_records.isEmpty) {
      return const Center(
        child: Text(
          'No race times yet',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: _records.length,
            separatorBuilder: (context, index) => const SizedBox(height: 1),
            itemBuilder: (context, index) {
              final record = _records[index];
        if (record.type == RecordType.runnerTime) {
          return Dismissible(
            key: ValueKey(record),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16.0),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              if (record.conflict != null) {
                DialogUtils.showErrorDialog(
                  context,
                  message: 'Cannot delete a time that is part of a conflict.',
                );
                return false;
              }
              if (record.isConfirmed == true) {
                DialogUtils.showErrorDialog(
                  context,
                  message: 'Cannot delete a confirmed time.',
                );
                return false;
              }
              return await DialogUtils.showConfirmationDialog(
                context,
                title: 'Confirm Deletion',
                content: 'Are you sure you want to delete this time?',
              );
            },
            onDismissed: (direction) {
              setState(() {
                _timingData.removeRecord(record.id);
                // Update places for subsequent records
                for (var i = index; i < _records.length; i++) {
                  if (_records[i].type == RecordType.runnerTime) {
                    if (_records[i].place != null) {
                      _timingData.updateRecord(_records[i].id, place: _records[i].place! - 1);
                    }
                    else if (_records[i].previousPlace != null) {
                       _timingData.updateRecord(_records[i].id, previousPlace: _records[i].previousPlace! - 1);
                    }
                  }
                }
                scrollToBottom(_scrollController);
              });
            },
            child: _buildRunnerTimeRecord(record, index),
          );
        } else if (record.type == RecordType.confirmRunner) {
          return Dismissible(
            key: ValueKey(record),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16.0),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
                  ),
            ),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              if (_records.last != record) {
                DialogUtils.showErrorDialog(
                  context,
                  message: 'Cannot delete a confirmation that is not the last one.',
                );
                return false;
              }
              return await DialogUtils.showConfirmationDialog(
                context,
                title: 'Confirm Deletion',
                content: 'Are you sure you want to delete this confirmation?',
              );
            },
            onDismissed: (direction) {
              setState(() {
                _timingData.removeRecord(record.id);
                _timingData.records = updateTextColor(Colors.transparent, _records, endIndex: index);
                scrollToBottom(_scrollController);
              });
            },
            child: _buildConfirmationRecord(record, index),
          );
        } else if (record.type == RecordType.missingRunner || record.type == RecordType.extraRunner) {
          return Dismissible(
            key: ValueKey(record),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16.0),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              if (_records.last != record) {
                DialogUtils.showErrorDialog(
                  context,
                  message: 'Cannot undo a conflict that is not the last one.',
                );
                return false;
              }
              return await DialogUtils.showConfirmationDialog(
                context,
                title: 'Confirm Undo',
                content: 'Are you sure you want to undo this conflict?',
              );
            },
            onDismissed: (direction) {
              setState(() {
                _undoLastConflict();
                scrollToBottom(_scrollController);
              });
            },
            child: _buildConflictRecord(record, index),
          );
        }
        return const SizedBox.shrink();
      },
    )
      )
      ]
      );
  }

  Widget _buildRunnerTimeRecord(RunnerRecord record, int index) {
    final isEven = index % 2 == 0;
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.02,
        0,
        MediaQuery.of(context).size.width * 0.01,
        0,
      ),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF5F5F5) : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${record.place ?? ''}',
            style: AppTypography.bodySemibold.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: record.textColor != null ? AppColors.confirmRunnerColor : null,
            ),
          ),
          Text(
            record.elapsedTime,
            style: AppTypography.bodySemibold.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: record.conflict == null
                  ? (record.isConfirmed == true
                      ? AppColors.confirmRunnerColor
                      : null)
                  : (record.conflict!.type != RecordType.confirmRunner
                      ? AppColors.redColor
                      : AppColors.confirmRunnerColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationRecord(RunnerRecord record, int index) {
    final isEven = index % 2 == 0;
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.02,
        0,
        MediaQuery.of(context).size.width * 0.02,
        0,
      ),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF5F5F5) : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Confirmed: ${record.elapsedTime}',
            style: AppTypography.bodySemibold.copyWith(
              fontSize: 18, 
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictRecord(RunnerRecord record, int index) {
    final isEven = index % 2 == 0;
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.02,
        0,
        MediaQuery.of(context).size.width * 0.02,
        0,
      ),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF5F5F5) : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            record.type == RecordType.missingRunner 
              ? 'Missing Runner at ${record.elapsedTime}'
              : 'Extra Runner at ${record.elapsedTime}',
            style: AppTypography.bodySemibold.copyWith(
              fontSize: 18,
              color: AppColors.redColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.check,
            color: Colors.green,
            onTap: _confirmRunnerNumber,
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.withOpacity(0.3),
          ),
          _buildAdjustTimesButton(),
          if (_hasUndoableConflict())
            _buildControlButton(
              icon: Icons.undo,
              color: AppColors.mediumColor,
              onTap: _undoLastConflict,
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 30,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAdjustTimesButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: PopupMenuButton<void>(
        itemBuilder: (BuildContext context) => <PopupMenuEntry<void>>[
          PopupMenuItem<void>(
            onTap: () => _missingRunnerTime(),
            child: Text(
              '+ (Add finish time)',
              style: AppTypography.bodyRegular.copyWith(fontSize: 17),
            ),
          ),
          PopupMenuItem<void>(
            onTap: () => _extraRunnerTime(),
            child: Text(
              '- (Remove finish time)',
              style: AppTypography.bodyRegular.copyWith(fontSize: 17),
            ),
          ),
        ],
        child: Text(
          'Adjust # of times',
          style: AppTypography.bodyRegular.copyWith(fontSize: 20),
        ),
      ),
    );
  }

  bool _hasUndoableConflict() {
    return _records.isNotEmpty &&
      _records.last.hasConflict() &&
      !_records.last.isResolved();
  }

  Duration _calculateElapsedTime(DateTime? startTime, Duration? endTime) {
    if (startTime == null) {
      return endTime ?? Duration.zero;
    }
    return DateTime.now().difference(startTime);
  }

  @override
  void dispose() {
    debugPrint('TimingScreen disposed');
    _tabController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    // _timingData.clearRecords();
    // _timingData.changeStartTime(null);
    super.dispose();
  }
}
