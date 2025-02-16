import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/timing_data.dart';
import '../utils/time_formatter.dart';
import '../utils/app_colors.dart';
import '../device_connection_popup.dart';
import '../runner_time_functions.dart';
import '../utils/timing_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/button_utils.dart';
import '../device_connection_service.dart';
import '../role_functions.dart';

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
  List<Map<String, dynamic>> get _records => _timingData.records;
  

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initAudioPlayer();
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
      if (!_isAudioPlayerReady && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        _initAudioPlayer();
      }
    }
  }

  void _startRace() {
    if (_records.isNotEmpty) {
      _showStartRaceDialog();
    } else {
      _initializeNewRace();
    }
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
      _records.clear();
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
      _timingData.addRecord({
        'finish_time': formatDuration(difference),
        'type': 'runner_time',
        'is_confirmed': false,
        'text_color': null,
        'place': _getNumberOfTimes() + 1,
      });
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
    final numTimes = _getNumberOfTimes();
    final difference = getCurrentDuration(_timingData.startTime, _timingData.endTime);

    setState(() {
      _timingData.records = confirmRunnerNumber(_records, numTimes, formatDuration(difference));
      scrollToBottom(_scrollController);
    });
  }

  void _extraRunnerTime({int offBy = 1}) async {
    final numTimes = _getNumberOfTimes();
    
    if (!_validateExtraRunnerTime(numTimes, offBy)) return;
    
    final difference = getCurrentDuration(_timingData.startTime, _timingData.endTime);
    
    setState(() {
      _timingData.records = extraRunnerTime(offBy, _records, numTimes, formatDuration(difference));
      scrollToBottom(_scrollController);
    });
  }

  bool _validateExtraRunnerTime(int numTimes, int offBy) {
    final previousRunner = _records.last;
    if (previousRunner['type'] != 'runner_time') {
      DialogUtils.showErrorDialog(
        context, 
        message: 'You must have an unconfirmed runner time before pressing this button.'
      );
      return false;
    }

    final lastConfirmedRecord = _records.lastWhere(
      (r) => r['type'] == 'runner_time' && r['is_confirmed'] == true,
      orElse: () => {},
    );
    final recordPlace = lastConfirmedRecord.isEmpty || lastConfirmedRecord['place'] == null 
        ? 0 
        : lastConfirmedRecord['place'];

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
        _records.removeRange(_records.length - offBy, _records.length);
      });
    }
  }

  void _missingRunnerTime({int offBy = 1}) {
    final numTimes = _getNumberOfTimes();
    final difference = getCurrentDuration(_timingData.startTime, _timingData.endTime);

    setState(() {
      _timingData.records = missingRunnerTime(offBy, _records, numTimes, formatDuration(difference));
      scrollToBottom(_scrollController);
    });
  }
  
  int _getNumberOfTimes() {
    return max(0, _records.fold<int>(0, (count, record) {
        if (record['type'] == 'runner_time') return count + 1;
        if (record['type'] == 'extra_runner_time') return count - 1;
        return count;
      }));
  }

  void _undoLastConflict() {
    final lastConflict = _records.reversed.firstWhere(
      (r) => r['type'] != 'runner_time' && r['type'] != null && r['type'] != 'confirm_runner_number',
      orElse: () => {},
    );

    if (lastConflict.isEmpty || lastConflict['type'] == null) return;
    
    if (lastConflict['type'] == 'extra_runner_time') {
      _undoTooManyRunners(lastConflict);
    } else if (lastConflict['type'] == 'missing_runner_time') {
      _undoTooFewRunners(lastConflict);
    }
  }

  void _undoTooManyRunners(Map<String, dynamic> lastConflict) {
    if (lastConflict.isEmpty) return;
    
    final lastConflictIndex = _records.indexOf(lastConflict);
    final runnersBeforeConflict = _records
        .sublist(0, lastConflictIndex)
        .where((r) => r['type'] == 'runner_time')
        .toList();
    final offBy = lastConflict['offBy'];

    _updateTextColor(null, confirmed: false, endIndex: lastConflictIndex);
    
    for (int i = 0; i < offBy; i++) {
      final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
      setState(() {
        record['place'] = record['previous_place'];
      });
    }
    
    setState(() {
      _records.remove(lastConflict);
    });
  }

  void _undoTooFewRunners(Map<String, dynamic> lastConflict) {
    if (lastConflict.isEmpty) return;
    
    final lastConflictIndex = _records.indexOf(lastConflict);
    final runnersBeforeConflict = _records
        .sublist(0, lastConflictIndex)
        .where((r) => r['type'] == 'runner_time')
        .toList();
    final offBy = lastConflict['offBy'];

    _updateTextColor(null, confirmed: false, endIndex: lastConflictIndex);
    
    for (int i = 0; i < offBy; i++) {
      final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
      setState(() {
        _records.remove(record);
      });
    }
    
    setState(() {
      _records.remove(lastConflict);
    });
  }

  void _updateTextColor(Color? color, {bool confirmed = false, String? conflict, int? endIndex}) {
    var records = _records;
    if (endIndex != null && endIndex < records.length) {
      records = records.sublist(0, endIndex);
    }

    for (int i = records.length - 1; i >= 0; i--) {
      final record = records[i];
      if (record['type'] != 'runner_time') break;
      
      setState(() {
        record['text_color'] = color;
        record['is_confirmed'] = confirmed;
        record['conflict'] = confirmed ? conflict : null;
      });
    }
  }

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

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Race Timing'),
      //   actions: [
      //     changeRoleButton(context, 'timer'),
      //   ],
      // ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildRoleBar(context, 'timer', 'Race Timing'),
            const SizedBox(height: 16),
            _buildTimerDisplay(startTime, endTime),
            _buildControlButtons(startTime),
            if (_records.isNotEmpty) const Divider(height: 30),
            Expanded(child: _buildRecordsList()),
            if (startTime != null && _records.isNotEmpty)
              _buildBottomControls(),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          width: MediaQuery.of(context).size.width * 0.9,
          child: Text(
            formatDurationWithZeros(elapsed),
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.135,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              height: 1.0,
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
    return CircularButton(
      text: startTime == null ? 'Start' : 'Stop',
      color: startTime == null ? Colors.green : Colors.red,
      fontSize: 20,
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
              onPressed: () => showDeviceConnectionPopup(
                context,
                deviceType: DeviceType.advertiserDevice,
                deviceName: DeviceName.raceTimer,
                otherDevices: createOtherDeviceList(
                  DeviceName.raceTimer,
                  DeviceType.advertiserDevice,
                  data: _timingData.encode(),
                ),
                
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 78),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'Share Times',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.darkColor,
                ),
                maxLines: 1,
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
      color: const Color.fromARGB(255, 143, 143, 143),
      fontSize: 20,
      onPressed: (_records.isNotEmpty && startTime == null)
          ? _clearRaceTimes
          : (startTime != null ? _handleLogButtonPress : null),
    );
  }

  Widget _buildRecordsList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        if (record['type'] == 'runner_time') {
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
              if (record['conflict'] != null) {
                DialogUtils.showErrorDialog(
                  context,
                  message: 'Cannot delete a time that is part of a conflict.',
                );
                return false;
              }
              if (record['is_confirmed'] == true) {
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
                _records.removeAt(index);
                // Update places for subsequent records
                for (var i = index; i < _records.length; i++) {
                  if (_records[i]['type'] == 'runner_time') {
                    _records[i]['place'] = _records[i]['place'] - 1;
                  }
                }
                scrollToBottom(_scrollController);
              });
            },
            child: _buildRunnerTimeRecord(record, index),
          );
        } else if (record['type'] == 'confirm_runner_number') {
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
                _records.removeAt(index);
                _updateTextColor(null);
                scrollToBottom(_scrollController);
              });
            },
            child: _buildConfirmationRecord(record, index),
          );
        } else if (record['type'] == 'missing_runner_time' || record['type'] == 'extra_runner_time') {
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
    );
  }

  Widget _buildRunnerTimeRecord(Map<String, dynamic> record, int index) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.02,
        0,
        MediaQuery.of(context).size.width * 0.01,
        MediaQuery.of(context).size.width * 0.02,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${record['place']}',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: record['text_color'] != null ? AppColors.confirmRunnerColor : null,
                  ),
                ),
                Text(
                  '${record['finish_time']}',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: record['conflict'] == null
                        ? record['text_color']
                        : AppColors.redColor,
                  ),
                ),
              ],
            ),
          const Divider(
            thickness: 1,
            color: Color.fromRGBO(128, 128, 128, 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationRecord(Map<String, dynamic> record, int index) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.02,
        MediaQuery.of(context).size.width * 0.01,
        MediaQuery.of(context).size.width * 0.02,
        MediaQuery.of(context).size.width * 0.02,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // GestureDetector(
          //   behavior: HitTestBehavior.opaque,
          //   onLongPress: () => _handleConfirmationLongPress(index),
            Text(
              'Confirmed: ${record['finish_time']}',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.05,
                fontWeight: FontWeight.bold,
                color: record['text_color'],
              ),
            ),
          // ),
          const Divider(
            thickness: 1,
            color: Color.fromRGBO(128, 128, 128, 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictRecord(Map<String, dynamic> record, int index) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.02,
        MediaQuery.of(context).size.width * 0.01,
        MediaQuery.of(context).size.width * 0.02,
        MediaQuery.of(context).size.width * 0.02,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            record['type'] == 'missing_runner_time' 
              ? 'Missing Runner at ${record['finish_time']}'
              : 'Extra Runner at ${record['finish_time']}',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.05,
              fontWeight: FontWeight.bold,
              color: record['text_color'],
            ),
          ),
          const Divider(
            thickness: 1,
            color: Color.fromRGBO(128, 128, 128, 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.check, size: 40, color: Colors.green),
            onPressed: _confirmRunnerNumber,
          ),
          Text('|', style: TextStyle(fontSize: 25),),
          _buildAdjustTimesButton(),
          if (_hasUndoableConflict())
            IconButton(
              icon: const Icon(Icons.undo, size: 40, color: AppColors.mediumColor),
              onPressed: _undoLastConflict,
            ),
        ],
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
            child: const Text('+ (Add finish time)', style: TextStyle(fontSize: 17),),
          ),
          PopupMenuItem<void>(
            onTap: () => _extraRunnerTime(),
            child: const Text('- (Remove finish time)', style: TextStyle(fontSize: 17),),
          ),
        ],
        child: const Text(
          'Adjust # of times',
          style: TextStyle(
            fontSize: 20,
            color: AppColors.darkColor,
          ),
        ),
      ),
    );
  }

  bool _hasUndoableConflict() {
    return _records.isNotEmpty &&
      _records.last['type'] != 'runner_time' &&
      _records.last['type'] != null &&
      _records.last['type'] != 'confirm_runner_number';
  }

  Duration _calculateElapsedTime(DateTime? startTime, Duration? endTime) {
    if (startTime == null) {
      return endTime ?? Duration.zero;
    }
    return DateTime.now().difference(startTime);
  }

  @override
  void dispose() {
    print('TimingScreen disposed');
    _tabController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    // _timingData.clearRecords();
    // _timingData.changeStartTime(null);
    super.dispose();
  }
}
