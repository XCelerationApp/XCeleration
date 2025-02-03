import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
      
      final conflict = _getFirstConflict();
      if (conflict[0] != null) {
        DialogUtils.showErrorDialog(
          context, 
          message: 'Race stopped. Make sure to resolve conflicts after loading bib numbers.',
          title: 'Race Stopped'
        );
      }
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

  void _shareTimes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Race Times'),
        content: SizedBox(
          width: 200,
          height: 200,
          child: QrImageView(
            data: _timingData.encode(),
            version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<dynamic> _getFirstConflict() {
    for (var record in _records) {
      if (record['type'] != 'runner_time' && record['type'] != 'confirm_runner_number') {
        return [record['type'], _records.indexOf(record)];
      }
    }
    return [null, -1];
  }

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

  Future<bool> _confirmDeleteLastRecord(int recordIndex) async {
    final record = _records[recordIndex];
    if (record['type'] == 'runner_time' && 
        record['is_confirmed'] == false && 
        record['conflict'] == null) {
      return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this runner?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ?? false;
    }
    return false;
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
                deviceType: DeviceType.raceTimerDevice,
                backUpShareFunction: _shareTimes,
                dataToTransfer: _timingData.encode(),
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
          return _buildRunnerTimeRecord(record, index);
        } else if (record['type'] == 'confirm_runner_number') {
          return _buildConfirmationRecord(record, index);
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _handleRecordLongPress(index),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${record['place']}',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: record['text_color'] != null ? AppColors.navBarTextColor : null,
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _handleConfirmationLongPress(index),
            child: Text(
              'Confirmed: ${record['finish_time']}',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.05,
                fontWeight: FontWeight.bold,
                color: record['text_color'],
              ),
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

  Future<void> _handleRecordLongPress(int index) async {
    if (index == _records.length - 1) {
      final confirmed = await _confirmDeleteLastRecord(index);
      if (confirmed) {
        setState(() {
          _records.removeAt(index);
          _scrollController.animateTo(
            max(_scrollController.position.maxScrollExtent, 0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    }
  }

  void _handleConfirmationLongPress(int index) {
    if (index == _records.length - 1) {
      setState(() {
        _records.removeAt(index);
        _updateTextColor(null);
      });
    }
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

// // Utility class for memoization
// class _MemoizedFunction<T, R> {
//   R? _lastResult;
//   T? _lastArg;
//   final R Function(T) _function;

//   _MemoizedFunction(this._function);

//   R call(T arg) {
//     if (_lastArg != arg) {
//       _lastArg = arg;
//       _lastResult = _function(arg);
//     }
//     return _lastResult!;
//   }
// }


// import 'dart:math';
// import 'package:race_timing_app/utils/time_formatter.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../models/timing_data.dart';
// import 'dart:async';
// import 'package:flutter/services.dart';
// import 'package:audioplayers/audioplayers.dart';
// import '../constants.dart';
// import 'package:qr_flutter/qr_flutter.dart';
// import '../device_connection_popup.dart';
// import '../device_connection_service.dart';
// import '../runner_time_functions.dart';
// import '../utils/timing_utils.dart';
// import '../utils/button_utils.dart';
// import '../utils/dialog_utils.dart';


// class TimingScreen extends StatefulWidget {
//   const TimingScreen({super.key});

//   @override
//   State<TimingScreen> createState() => _TimingScreenState();
// }

// class _TimingScreenState extends State<TimingScreen> with TickerProviderStateMixin {
//   final ScrollController _scrollController = ScrollController();
//   late AudioPlayer _audioPlayer;
//   bool _isAudioPlayerReady = false;
//   late TabController _tabController;
//   late bool dataSynced;

//   @override
//   void initState() {
//     super.initState();
//     _initAudioPlayer();
//     _tabController = TabController(length: 3, vsync: this); // Adjust length based on your tabs
//     // race = widget.race;
//     dataSynced = false;
//   }

//  Future<void> _initAudioPlayer() async {
//     try {
//       _audioPlayer = AudioPlayer();
//       await _audioPlayer.setReleaseMode(ReleaseMode.stop);
//       // Pre-load the audio file
//       await _audioPlayer.setSource(AssetSource('sounds/click.mp3'));
//       setState(() {
//         _isAudioPlayerReady = true;
//       });
//     } catch (e) {
//       print('Error initializing audio player: $e');
//       // Try to recreate the audio player if it failed
//       if (!_isAudioPlayerReady) {
//         await Future.delayed(Duration(milliseconds: 500));
//         if (mounted) {
//           _initAudioPlayer();
//         }
//       }
//     }
//   }

//   Future<void> _handleLogButtonPress() async {
//     try {
//       _logTime();
//       HapticFeedback.vibrate();
//       HapticFeedback.lightImpact();
//       if (_isAudioPlayerReady) {
//         try {
//           await _audioPlayer.stop(); // Stop any currently playing sound
//           await _audioPlayer.play(AssetSource('sounds/click.mp3'));
//         } catch (e) {
//           print('Error playing sound: $e');
//           // Reinitialize audio player if it failed
//           _initAudioPlayer();
//         }
//       }
//     } catch (e) {
//       print('Error in log button press: $e');
//     }
//   }

  // Future<void> _startRace() async {
  //   final records = Provider.of<TimingData>(context, listen: false).records;
  //   if (records.isNotEmpty) {
  //     final confirmed = await DialogUtils.showConfirmationDialog(
  //       context,
  //       title: 'Start a New Race',
  //       content: 'Are you sure you want to start a new race? Doing so will clear the existing times.',
  //     );
  //     if (confirmed != true) return;
  //     setState(() {
  //       records.clear();
  //       Provider.of<TimingData>(context, listen: false).changeStartTime(DateTime.now());
  //       Provider.of<TimingData>(context, listen: false).changeEndTime(null);
  //     });
  //   } else {
  //     setState(() {
  //       records.clear();
  //       Provider.of<TimingData>(context, listen: false).changeStartTime(DateTime.now());
  //     });
  //   }
  // }

  // void _stopRace() async{
  //   final confirmed = await DialogUtils.showConfirmationDialog(context, content:'Race stopped. Make sure to resolve conflicts after loading bib numbers.', title: 'Stop the Race');
  //   if (confirmed != true) return;
  //   final startTime = Provider.of<TimingData>(context, listen: false).startTime;
  //   if (startTime != null) {
  //     final now = DateTime.now();
  //     final difference = now.difference(startTime);
  //     setState(() {
  //       Provider.of<TimingData>(context, listen: false).changeEndTime(difference);
  //       Provider.of<TimingData>(context, listen: false).changeStartTime(null);
  //     });
  //     if (_getFirstConflict()[0] != null) {
  //       DialogUtils.showErrorDialog(context, message:'Race stopped. Make sure to resolve conflicts after loading bib numbers.', title: 'Race Stopped');
  //     }
  //   }
  // }

//   void _logTime() {
//     final startTime = Provider.of<TimingData>(context, listen: false).startTime;
//     if (startTime == null) {
//       DialogUtils.showErrorDialog(context, message:'Start time cannot be null.');
//       return;
//     }
//     final now = DateTime.now();
//     final difference = now.difference(startTime);

//     setState(() {
//       Provider.of<TimingData>(context, listen: false).addRecord({
//         'finish_time': formatDuration(difference),
//         'type': 'runner_time',
//         'is_confirmed': false,
//         'text_color': null,
//         'place': _getNumberOfTimes() + 1,
//       });

//       scrollToBottom(_scrollController);
//     });
//   }

//   void _shareTimes() {
//     final data = Provider.of<TimingData>(context, listen: false).encode(); // Ensure this returns a String
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text('Share Race Times'),
//           content: SizedBox(
//             width: 200,
//             height: 200,
//             child: QrImageView(
//               data: data,
//               version: QrVersions.auto,
//               errorCorrectionLevel: QrErrorCorrectLevel.M, // Adjust as needed
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Close'),
//             ),
//           ],
//         );
//       },
//     );
//   }


//   List<dynamic> _getFirstConflict() {
//     final records = Provider.of<TimingData>(context, listen: false).records;
//     for (var record in records) {
//       if (record['type'] != 'runner_time' && record['type'] != 'confirm_runner_number') {
//         return [record['type'], records.indexOf(record)];
//       }
//     }
//     return [null, -1];
//   }

//   void _updateTextColor(Color? color, {bool confirmed = false, String? conflict, endIndex}) {
//     List<dynamic> records = Provider.of<TimingData>(context, listen: false).records;
//     if (endIndex != null && endIndex < records.length && records.isNotEmpty) {
//       records = records.sublist(0, endIndex);
//     }
//     for (int i = records.length - 1; i >= 0; i--) {
//       if (records[i]['type'] != 'runner_time') {
//         break;
//       }
//       setState(() {
//         records[i]['text_color'] = color;
//         if (confirmed == true) {
//           records[i]['is_confirmed'] = true;
//           records[i]['conflict'] = conflict;
//         }
//         else {
//           records[i]['is_confirmed'] = false;
//           records[i]['conflict'] = null;
//         }
//       });
//     }
//   }

//   void _confirmRunnerNumber() async {
//     int numTimes = _getNumberOfTimes();
    
//     Duration difference = getCurrentDuration(Provider.of<TimingData>(context, listen: false).startTime, Provider.of<TimingData>(context, listen: false).endTime);

//     setState(() {
//       Provider.of<TimingData>(context, listen: false).records = confirmRunnerNumber(Provider.of<TimingData>(context, listen: false).records, numTimes, formatDuration(difference));

//       scrollToBottom(_scrollController);
//     });
//   }

//   void _extraRunnerTime({int offBy = 1, bool useStopTime = false}) async {
//     final numTimes = _getNumberOfTimes().toInt();

//     final records = Provider.of<TimingData>(context, listen: false).records;
//     final previousRunner = records.last;
//     if (previousRunner['type'] != 'runner_time') {
//       DialogUtils.showErrorDialog(context, message:'You must have a unconfirmed runner time before pressing this button.');
//       return;
//     }

//     final lastConfirmedRecord = records.lastWhere((r) => r['type'] == 'runner_time' && r['is_confirmed'] == true, orElse: () => {});
//     final recordPlace = lastConfirmedRecord.isEmpty || lastConfirmedRecord['place'] == null ? 0 : lastConfirmedRecord['place'];

//     if ((numTimes - offBy) == recordPlace) {
//       bool confirmed = await DialogUtils.showConfirmationDialog(context, content:'This will delete the last $offBy finish times, are you sure you want to continue?', title:'Confirm Deletion');
//       if (confirmed == false) {
//         return;
//       }
//       setState(() {
//         Provider.of<TimingData>(context, listen: false).records.removeRange(Provider.of<TimingData>(context, listen: false).records.length - offBy, Provider.of<TimingData>(context, listen: false).records.length);
//       });
//       return;
//     }
//     else if (numTimes - offBy < recordPlace) {
//       DialogUtils.showErrorDialog(context, message:'You cannot remove a runner that is confirmed.');
//       return;
//     }

//     Duration difference = getCurrentDuration(Provider.of<TimingData>(context, listen: false).startTime, Provider.of<TimingData>(context, listen: false).endTime);

//     setState(() {
//       Provider.of<TimingData>(context, listen: false).records = extraRunnerTime(offBy, records, numTimes, formatDuration(difference));

//       scrollToBottom(_scrollController);
//     });
//   }

//   void _missingRunnerTime({int offBy = 1, bool useStopTime = false}) {
//     final int numTimes = _getNumberOfTimes();
    
//     Duration difference = getCurrentDuration(Provider.of<TimingData>(context, listen: false).startTime, Provider.of<TimingData>(context, listen: false).endTime);


//     setState(() {
//       Provider.of<TimingData>(context, listen: false).records = missingRunnerTime(offBy, Provider.of<TimingData>(context, listen: false).records, numTimes, formatDuration(difference));

//       scrollToBottom(_scrollController);
//     });
//   }

  // int _getNumberOfTimes() {
  //   final records = Provider.of<TimingData>(context, listen: false).records;
  //   int count = 0;
  //   for (var record in records) {
  //     if (record['type'] == 'runner_time') {
  //       count++;
  //     } else if (record['type'] == 'extra_runner_time') {
  //       count--;
  //     } 
  //   }
  //   return max(0, count);
  // }


//   void _undoLastConflict() {
//     print('undo last conflict');
//     final records = Provider.of<TimingData>(context, listen: false).records;

//     final lastConflict = records.reversed.firstWhere((r) => r['type'] != 'runner_time' && r['type'] != null, orElse: () => {});

//     if (lastConflict.isEmpty || lastConflict['type'] == null) {
//       return;
//     }
    
//     final conflictType = lastConflict['type'];
//     if (conflictType == 'extra_runner_time') {
//       print('undo too many');
//       undoTooManyRunners(lastConflict, records);
//     }
//     else if (conflictType == 'missing_runner_time') {
//       print('undo too few');
//       undoTooFewRunners(lastConflict, records);
//     }
//   }

//   void undoTooManyRunners(Map lastConflict, records) {
//     if (lastConflict.isEmpty) {
//       return;
//     }
//     final lastConflictIndex = records.indexOf(lastConflict);
//     final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r['type'] == 'runner_time').toList();
//     final offBy = lastConflict['offBy'];

//     _updateTextColor(null, confirmed: false, endIndex: lastConflictIndex);
//     for (int i = 0; i < offBy; i++) {
//       final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
//       setState(() {
//         record['place'] = record['previous_place'];
//       });
//     }
//     setState(() {
//       records.remove(lastConflict);
//     });
//   }

//   void undoTooFewRunners(Map lastConflict, records) {
//     if (lastConflict.isEmpty) {
//       return;
//     }
//     final lastConflictIndex = records.indexOf(lastConflict);
//     final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r['type'] == 'runner_time').toList();
//     final offBy = lastConflict['offBy'];
//     print('off by: $offBy');

//     _updateTextColor(null, confirmed: false, endIndex: lastConflictIndex);
//     for (int i = 0; i < offBy; i++) {
//       final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
//       print('remove record: $record');
//       setState(() {
//         records.remove(record);
//       });
//     }
//     setState(() {
//       records.remove(lastConflict);
//     });
//   }


//   int getRunnerIndex(int recordIndex) {
//     final records = Provider.of<TimingData>(context, listen: false).records;
//     final runnerRecords = records.where((record) => record['type'] == 'runner_time').toList();
//     return runnerRecords.indexOf(records[recordIndex]);
//   }

//   Future<bool> _confirmDeleteLastRecord(int recordIndex) async {
//     final records = Provider.of<TimingData>(context, listen: false).records;
//     final record = records[recordIndex];
//     if (record['type'] == 'runner_time' && record['is_confirmed'] == false && record['conflict'] == null) {
//       final confirmed = await DialogUtils.showConfirmationDialog(context, title: 'Confirm Deletion', content: 'Are you sure you want to delete this runner?');
//       return confirmed;
//     }
//     return false;
//   }

//   _clearRaceTimes() async {
//     final confirmed = await DialogUtils.showConfirmationDialog(context, title: 'Clear Race Times', content: 'Are you sure you want to clear all race times?');
//     if (!confirmed) return;
//     setState(() {
//       Provider.of<TimingData>(context, listen: false).clearRecords();
//     });
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     _scrollController.dispose();
//     Provider.of<TimingData>(context, listen: false).clearRecords();
//     Provider.of<TimingData>(context, listen: false).changeStartTime(null);
//     _audioPlayer.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final startTime = Provider.of<TimingData>(context, listen: false).startTime;
//     final endTime = Provider.of<TimingData>(context, listen: false).endTime;
//     final records = Provider.of<TimingData>(context, listen: false).records;

//     return Scaffold(
//       // appBar: AppBar(title: const Text('Race Timing')),
//       body: Padding(
//         padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               // Race Timer Display
//               Row(
//                 children: [
//                   // Race time display
//                   StreamBuilder(
//                     stream: Stream.periodic(const Duration(milliseconds: 10)),
//                     builder: (context, snapshot) {
//                       final currentTime = DateTime.now();
//                       final startTime = Provider.of<TimingData>(context, listen: false).startTime;
//                       Duration elapsed;
//                       if (startTime == null) {
//                         if (endTime != null) {
//                           elapsed = endTime;
//                         }
//                         else {
//                           elapsed = Duration.zero;
//                         }
//                       }
//                       else {
//                          elapsed = currentTime.difference(startTime);
//                       }
//                       return Container(
//                         alignment: Alignment.centerLeft,
//                         padding: const EdgeInsets.only(top: 10, bottom: 10),
//                         // margin: EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.1), // 1/10 from left
//                         width: MediaQuery.of(context).size.width * 0.9, // 3/4 of screen width
//                         child: Text(
//                           formatDurationWithZeros(elapsed),
//                           style: TextStyle(
//                             fontSize: MediaQuery.of(context).size.width * 0.135,
//                             fontWeight: FontWeight.bold,
//                             fontFamily: 'monospace',
//                             height: 1.0,
//                           ),
//                           textAlign: TextAlign.left,
//                           strutStyle: StrutStyle(
//                             fontSize: MediaQuery.of(context).size.width * 0.15,
//                             height: 1.0,
//                             forceStrutHeight: true,
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//               // Buttons for Race Control
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   CircularButton(text: startTime == null ? 'Start' : 'Stop', color: startTime == null ? Colors.green : Colors.red, fontSize: 20, onPressed: startTime == null ? _startRace : _stopRace),
//                   if (startTime == null && records.isNotEmpty)
//                     Expanded(
//                       child: Padding(
//                         padding: const EdgeInsets.all(8.0), // Padding around the button
//                         child: LayoutBuilder(
//                           builder: (context, constraints) {
//                             return ElevatedButton(
//                               onPressed: () => showDeviceConnectionPopup(context, deviceType: DeviceType.raceTimerDevice, backUpShareFunction: _shareTimes, dataToTransfer: Provider.of<TimingData>(context, listen: false).encode()),
//                               style: ElevatedButton.styleFrom(
//                                 minimumSize: Size(0, 78),
//                                 padding: EdgeInsets.zero,
//                               ),
//                               child: Text(
//                                 'Share Times',
//                                 style: TextStyle(
//                                   fontSize: 20,
//                                   color: AppColors.darkColor,
//                                 ),
//                                 maxLines: 1,
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ),
//                   CircularButton(text: (records.isEmpty || startTime != null) ? 'Log' : 'Clear', color: const Color.fromARGB(255, 143, 143, 143), fontSize: 20, onPressed: (records.isNotEmpty && startTime == null) ? _clearRaceTimes : (startTime != null ? _handleLogButtonPress : null)),
//                 ],
//               ),

//               // Records Section
//               Expanded(
//                 child: Column(
//                   children: [
//                     if (records.isNotEmpty)
//                       Padding(
//                         padding: EdgeInsets.only(
//                           top: 15,
//                           left: MediaQuery.of(context).size.width * 0.02,
//                           right: MediaQuery.of(context).size.width * 0.02,
//                         ),
//                         child: Divider(
//                           thickness: 1,
//                           color: Color.fromRGBO(128, 128, 128, 0.5),
//                         ),
//                       ),
//                     Expanded(
//                       child: ListView.builder(
//                         controller: _scrollController,
//                         itemCount: records.length,
//                         itemBuilder: (context, index) {
//                           final record = records[index];
//                           if (records.isNotEmpty && record['type'] == 'runner_time') {
//                             return Container(
//                               margin: EdgeInsets.only(
//                                 top: 0,
//                                 bottom: MediaQuery.of(context).size.width * 0.02,
//                                 left: MediaQuery.of(context).size.width * 0.02,
//                                 right: MediaQuery.of(context).size.width * 0.01,
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   GestureDetector(
//                                     behavior: HitTestBehavior.opaque,
//                                     onLongPress: () async {
//                                       if (index == records.length - 1) {
//                                         final confirmed = await _confirmDeleteLastRecord(index);
//                                         if (confirmed ) {
//                                           setState(() {
//                                             Provider.of<TimingData>(context, listen: false).records.removeAt(index);
//                                             _scrollController.animateTo(
//                                               max(_scrollController.position.maxScrollExtent, 0),
//                                               duration: const Duration(milliseconds: 300),
//                                               curve: Curves.easeOut,
//                                             );
//                                           });
//                                         }
//                                       }
//                                     },
//                                     child: Row(
//                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           Text(
//                                             '${record['place']}',
//                                             style: TextStyle(
//                                               fontSize: MediaQuery.of(context).size.width * 0.05,
//                                               fontWeight: FontWeight.bold,
//                                             color: record['text_color'] != null ? AppColors.navBarTextColor : null,
//                                           ),
//                                         ),
//                                         Text(
//                                           '${record['finish_time']}',
//                                           style: TextStyle(
//                                             fontSize: MediaQuery.of(context).size.width * 0.05,
//                                             fontWeight: FontWeight.bold,
//                                             color: record['conflict'] == null ? record['text_color'] : AppColors.redColor,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                   Divider(
//                                     thickness: 1,
//                                     color: Color.fromRGBO(128, 128, 128, 0.5),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           } else if (records.isNotEmpty && record['type'] == 'confirm_runner_number') {
//                             return Container(
//                               margin: EdgeInsets.only(
//                                 top: MediaQuery.of(context).size.width * 0.01,
//                                 bottom: MediaQuery.of(context).size.width * 0.02,
//                                 left: MediaQuery.of(context).size.width * 0.02,
//                                 right: MediaQuery.of(context).size.width * 0.02,
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.end,
//                                 children: [
//                                   GestureDetector(
//                                     behavior: HitTestBehavior.opaque,
//                                     onLongPress: () {
//                                       if (index == records.length - 1) {
//                                         setState(() {
//                                           records.removeAt(index);
//                                           _updateTextColor(null);
//                                         });
//                                       }
//                                     },
//                                     child: Text(
//                                       'Confirmed: ${record['finish_time']}',
//                                       style: TextStyle(
//                                         fontSize: MediaQuery.of(context).size.width * 0.05,
//                                         fontWeight: FontWeight.bold,
//                                         color: record['text_color'],
//                                       ),
//                                     ),
//                                   ),
//                                   Divider(
//                                     thickness: 1,
//                                     color: Color.fromRGBO(128, 128, 128, 0.5),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           } else {
//                             return Container();
//                           }
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               if (startTime != null && records.isNotEmpty)
//                 Container(
//                   margin: EdgeInsets.symmetric(vertical: 8.0), // Adjust vertical margin as needed
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Center the buttons
//                     children: [
//                       IconButton(
//                         icon: const Icon(Icons.check, size: 40, color: AppColors.navBarTextColor),
//                         onPressed: _confirmRunnerNumber,
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: PopupMenuButton<void>(
//                           itemBuilder: (BuildContext context) => <PopupMenuEntry<void>>[
//                             PopupMenuItem<void>(
//                               onTap: _missingRunnerTime,
//                               child: Text('Missing runner time (Add a time)'),
//                             ),
//                             PopupMenuItem<void>(
//                               onTap: _extraRunnerTime,
//                               child: Text('Extra runner time (Remove a time)'),
//                             ),
//                           ],
//                           child: Text(
//                             'Adjust # of times',
//                             style: TextStyle(
//                               fontSize: 20,
//                               color: AppColors.darkColor,
//                             ),
//                           ),
//                         ),
//                       ),
//                       if (records.isNotEmpty && records.last['type'] != 'runner_time' && records.last['type'] != null && records.last['type'] != 'confirm_runner_number')
//                         IconButton(
//                           icon: const Icon(Icons.undo, size: 40, color: AppColors.mediumColor),
//                           onPressed: _undoLastConflict,
//                         ),
//                     ],
//                   ),
//                 ),
//             ],
//           ),
//       ),
//     );
//   }
// }
