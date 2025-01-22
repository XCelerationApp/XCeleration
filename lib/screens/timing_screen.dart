import 'dart:math';
import 'package:race_timing_app/utils/time_formatter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/timing_data.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../constants.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TimingScreen extends StatefulWidget {
  const TimingScreen({super.key});

  @override
  State<TimingScreen> createState() => _TimingScreenState();
}

class _TimingScreenState extends State<TimingScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final int raceId = 0;
  late AudioPlayer _audioPlayer;
  bool _isAudioPlayerReady = false;
  late TabController _tabController;
  late bool dataSynced;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _tabController = TabController(length: 3, vsync: this); // Adjust length based on your tabs
    // race = widget.race;
    // raceId = race.race_id;
    dataSynced = false;
  }

 Future<void> _initAudioPlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      // Pre-load the audio file
      await _audioPlayer.setSource(AssetSource('sounds/click.mp3'));
      setState(() {
        _isAudioPlayerReady = true;
      });
    } catch (e) {
      print('Error initializing audio player: $e');
      // Try to recreate the audio player if it failed
      if (!_isAudioPlayerReady) {
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          _initAudioPlayer();
        }
      }
    }
  }

  Future<void> _handleLogButtonPress() async {
    try {
      _logTime();
      HapticFeedback.vibrate();
      HapticFeedback.lightImpact();
      if (_isAudioPlayerReady) {
        try {
          await _audioPlayer.stop(); // Stop any currently playing sound
          await _audioPlayer.play(AssetSource('sounds/click.mp3'));
        } catch (e) {
          print('Error playing sound: $e');
          // Reinitialize audio player if it failed
          _initAudioPlayer();
        }
      }
    } catch (e) {
      print('Error in log button press: $e');
    }
  }

  void _startRace() {
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    if (records.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a New Race'),
          content: const Text('Are you sure you want to start a new race? Doing so will clear the existing times.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                setState(() {
                  records.clear();
                  Provider.of<TimingData>(context, listen: false).changeStartTime(DateTime.now(), raceId);
                  Provider.of<TimingData>(context, listen: false).changeEndTime(null, raceId);
                });
              },
              child: const Text('Yes'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        records.clear();
        Provider.of<TimingData>(context, listen: false).changeStartTime(DateTime.now(), raceId);
      });
    }
  }

  void _stopRace() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop the Race'),
        content: const Text('Are you sure you want to stop the race?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              final startTime = Provider.of<TimingData>(context, listen: false).startTime[raceId];
              if (startTime != null) {
                final now = DateTime.now();
                final difference = now.difference(startTime);
                setState(() {
                  Provider.of<TimingData>(context, listen: false).changeEndTime(difference, raceId);
                  Provider.of<TimingData>(context, listen: false).changeStartTime(null, raceId);
                });
                Navigator.of(context).pop(true);
                if (_getFirstConflict()[0] != null) {
                  _showErrorMessage('Race stopped. Make sure to resolve conflicts after loading bib numbers.', title: 'Race Stopped');
                }
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _logTime() {
    final startTime = Provider.of<TimingData>(context, listen: false).startTime[raceId];
    if (startTime == null) {
      _showErrorMessage('Start time cannot be null.');
      return;
    }
    final now = DateTime.now();
    final difference = now.difference(startTime);

    setState(() {
      Provider.of<TimingData>(context, listen: false).addRecord({
        'finish_time': formatDuration(difference),
        // 'bib_number': null,
        'is_runner': true,
        'is_confirmed': false,
        'text_color': null,
        'place': _getNumberOfTimes() + 1,
      }, raceId);

      // Scroll to bottom after adding new record
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });

    // Add a new controller for the new record
    Provider.of<TimingData>(context, listen: false).addController(TextEditingController(), raceId);
  }

  void _shareTimes() {
    _showQrCode();
  }

  void _showQrCode() {
    final data = _generateQrData(); // Ensure this returns a String
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Share Bib Numbers'),
          content: SizedBox(
            width: 200,
            height: 200,
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              errorCorrectionLevel: QrErrorCorrectLevel.M, // Adjust as needed
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _generateQrData() {
    return jsonEncode(Provider.of<TimingData>(context, listen: false).toMapForQR(raceId));
  }

  List<dynamic> _getFirstConflict() {
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    for (var record in records) {
      if (record['is_runner'] == false && record['type'] != null && record['type'] != 'confirm_runner_number') {
        return [record['type'], records.indexOf(record)];
      }
    }
    return [null, -1];
  }


  void _showErrorMessage(String message, {String? title}) {
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title ?? 'Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the popup
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
  }

  Future<bool> _showConfirmationMessage(String message) async {
    bool confirmed = false;
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Confirmation'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  confirmed = false;
                  Navigator.of(context).pop(); // Close the popup
                },
                child: Text('No'),
              ),
              TextButton(
                onPressed: () {
                  confirmed = true;
                  Navigator.of(context).pop(); // Close the popup
                },
                child: Text('Yes'),
              ),
            ],
          );
        },
      );
    return confirmed;
  }

  void _updateTextColor(Color? color, {bool confirmed = false, String? conflict, endIndex}) {
    List<Map<String, dynamic>> records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    if (endIndex != null && endIndex < records.length && records.isNotEmpty) {
      records = records.sublist(0, endIndex);
    }
    for (int i = records.length - 1; i >= 0; i--) {
      if (records[i]['is_runner'] == false) {
        break;
      }
      setState(() {
        records[i]['text_color'] = color;
        if (confirmed == true) {
          records[i]['is_confirmed'] = true;
          records[i]['conflict'] = conflict;
        }
        else {
          records[i]['is_confirmed'] = false;
          records[i]['conflict'] = null;
        }
      });
    }
  }

  void _confirmRunnerNumber({bool useStopTime = false}) async {
    // final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    int numTimes = _getNumberOfTimes(); // Placeholder for actual length input
    
    Duration difference;
    if (useStopTime == true) {
      difference = Provider.of<TimingData>(context, listen: false).endTime[raceId]!;
    }
    else {
      DateTime now = DateTime.now();
      final startTime = Provider.of<TimingData>(context, listen: false).startTime[raceId];
      if (startTime == null) {
        print('Start time cannot be null. 4');
        _showErrorMessage('Start time cannot be null.');
        return;
      }
      difference = now.difference(startTime);
    }

    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    
    final color = AppColors.navBarTextColor;
    _updateTextColor(color, confirmed: true);

    _deleteConfirmedRecordsBeforeIndexUntilConflict(records.length - 1);

    setState(() {
      Provider.of<TimingData>(context, listen: false).records[raceId]?.add({
        'finish_time': formatDuration(difference),
        'is_runner': false,
        'type': 'confirm_runner_number',
        'text_color': color,
        'numTimes': numTimes,
      });

      // Scroll to bottom after adding new record
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });
  }

  void _tooManyRunners({int offBy = 1, bool useStopTime = false}) async {
    if (offBy < 1) {
      offBy = 1;
    }
    // final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    final numTimes = _getNumberOfTimes().toInt();
    int correcttedNumTimes = numTimes - offBy; // Placeholder for actual length input

    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    final previousRunner = records.last;
    if (previousRunner['is_runner'] == false) {
      _showErrorMessage('You must have a unconfirmed runner time before pressing this button.');
      return;
    }

    final lastConfirmedRecord = records.lastWhere((r) => r['is_runner'] == true && r['is_confirmed'] == true, orElse: () => {});
    final recordPlace = lastConfirmedRecord.isEmpty || lastConfirmedRecord['place'] == null ? 0 : lastConfirmedRecord['place'];

    if ((numTimes - offBy) == recordPlace) {
      bool confirmed = await _showConfirmationMessage('This will delete the last $offBy finish times, are you sure you want to continue?');
      if (confirmed == false) {
        return;
      }
      setState(() {
        Provider.of<TimingData>(context, listen: false).records[raceId]?.removeRange(Provider.of<TimingData>(context, listen: false).records[raceId]!.length - offBy, Provider.of<TimingData>(context, listen: false).records[raceId]!.length);
      });
      return;
    }
    else if (numTimes - offBy < recordPlace) {
      _showErrorMessage('You cannot remove a runner that is confirmed.');
      return;
    }
    for (int i = 1; i <= offBy; i++) {
      final lastOffByRunner = records[records.length - i];
      if (lastOffByRunner['is_runner'] == true) {
        lastOffByRunner['previous_place'] = lastOffByRunner['place'];
        lastOffByRunner['place'] = '';
      }
    }

    Duration difference;
    if (useStopTime == true) {
      difference = Provider.of<TimingData>(context, listen: false).endTime[raceId]!;
    }
    else {
      DateTime now = DateTime.now();
      final startTime = Provider.of<TimingData>(context, listen: false).startTime[raceId];
      if (startTime == null) {
        print('Start time cannot be null. 4');
        _showErrorMessage('Start time cannot be null.');
        return;
      }
      difference = now.difference(startTime);
    }

    final color = AppColors.redColor;
    _updateTextColor(color, conflict: 'too_many_runner_times');

    setState(() {
      Provider.of<TimingData>(context, listen: false).records[raceId]?.add({
        'finish_time': formatDuration(difference),
        'is_runner': false,
        'type': 'too_many_runner_times',
        'text_color': color,
        'numTimes': correcttedNumTimes,
        'offBy': offBy,
      });

      // Scroll to bottom after adding new record
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });
  }

  void _tooFewRunners({int offBy = 1, bool useStopTime = false}) async {
    final int numTimes = _getNumberOfTimes(); // Placeholder for actual length input
    int correcttedNumTimes = numTimes + offBy; // Placeholder for actual length input
    
    Duration difference;
    if (useStopTime == true) {
      difference = Provider.of<TimingData>(context, listen: false).endTime[raceId]!;
    }
    else {
      DateTime now = DateTime.now();
      final startTime = Provider.of<TimingData>(context, listen: false).startTime[raceId];
      if (startTime == null) {
        print('Start time cannot be null. 6');
        _showErrorMessage('Start time cannot be null.');
        return;
      }
      difference = now.difference(startTime);
    }

    final color = AppColors.redColor;
    _updateTextColor(color, conflict: 'too_few_runner_times');

    setState(() {
      for (int i = 1; i <= offBy; i++) {
        Provider.of<TimingData>(context, listen: false).records[raceId]?.add({
          'finish_time': 'TBD',
          'bib_number': null,
          'is_runner': true,
          'is_confirmed': false,
          'conflict': 'too_few_runner_times',
          'text_color': color,
          'place': numTimes + i,
        });
        Provider.of<TimingData>(context, listen: false).addController(TextEditingController(), raceId);
      }

      Provider.of<TimingData>(context, listen: false).records[raceId]?.add({
        'finish_time': formatDuration(difference),
        'is_runner': false,
        'type': 'too_few_runner_times',
        'text_color': color,
        'numTimes': correcttedNumTimes,
        'offBy': offBy,
      });

      // Scroll to bottom after adding new record
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });
  }

  int _getNumberOfTimes() {
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    int count = 0;
    for (var record in records) {
      if (record['is_runner'] == true) {
        count++;
      } else if (record['type'] == 'too_many_runner_times') {
        count--;
      } 
      // else if (record['type'] == 'too_few_runner_times') {
      //   count++;
      // }
    }
    return max(0, count);
  }

  

  void _undoLastConflict() {
    print('undo last conflict');
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];

    final lastConflict = records.reversed.firstWhere((r) => r['is_runner'] == false && r['type'] != null, orElse: () => {});

    if (lastConflict.isEmpty || lastConflict['type'] == null) {
      return;
    }
    
    final conflictType = lastConflict['type'];
    if (conflictType == 'too_many_runner_times') {
      print('undo too many');
      undoTooManyRunners(lastConflict, records);
    }
    else if (conflictType == 'too_few_runner_times') {
      print('undo too few');
      undoTooFewRunners(lastConflict, records);
    }
  }

  void undoTooManyRunners(Map lastConflict, records) {
    if (lastConflict.isEmpty) {
      return;
    }
    final lastConflictIndex = records.indexOf(lastConflict);
    final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r['is_runner'] == true).toList();
    final offBy = lastConflict['offBy'];

    _updateTextColor(null, confirmed: false, endIndex: lastConflictIndex);
    for (int i = 0; i < offBy; i++) {
      final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
      setState(() {
        record['place'] = record['previous_place'];
      });
    }
    setState(() {
      records.remove(lastConflict);
    });
  }

  void undoTooFewRunners(Map lastConflict, records) {
    if (lastConflict.isEmpty) {
      return;
    }
    final lastConflictIndex = records.indexOf(lastConflict);
    final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r['is_runner'] == true).toList();
    final offBy = lastConflict['offBy'];
    print('off by: $offBy');
    final controllers = Provider.of<TimingData>(context, listen: false).controllers[raceId] ?? [];

    _updateTextColor(null, confirmed: false, endIndex: lastConflictIndex);
    for (int i = 0; i < offBy; i++) {
      final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
      print('remove record: $record');
      setState(() {
        controllers.removeAt(runnersBeforeConflict.length - 1 - i);
        records.remove(record);
      });
    }
    setState(() {
      records.remove(lastConflict);
    });
  }
  


  void _deleteConfirmedRecordsBeforeIndexUntilConflict(int recordIndex) {
    print(recordIndex);
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    if (recordIndex < 0 || recordIndex >= records.length) {
      return;
    }
    final trimmedRecords = records.sublist(0, recordIndex + 1);
    // print(trimmedRecords.length);
    for (int i = trimmedRecords.length - 1; i >= 0; i--) {
      // print(i);
      if (trimmedRecords[i]['is_runner'] == false && trimmedRecords[i]['type'] != 'confirm_runner_number') {
        break;
      }
      if (trimmedRecords[i]['is_runner'] == false && trimmedRecords[i]['type'] == 'confirm_runner_number') {
        setState(() {
          records.removeAt(i);
        });
      }
    }
  }

  int getRunnerIndex(int recordIndex) {
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    final runnerRecords = records.where((record) => record['is_runner'] == true).toList();
    return runnerRecords.indexOf(records[recordIndex]);
  }

  Future<bool> _confirmDeleteLastRecord(int recordIndex) async {
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    final record = records[recordIndex];
    if (record['is_runner'] == true && record['is_confirmed'] == false && record['conflict'] == null) {
      final confirmed = await showDialog<bool>(
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
      );
      return confirmed ?? false;
    }
    return false;
  }

  _clearRaceTimes() {
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
          Provider.of<TimingData>(context, listen: false).clearRecords(raceId);
          Provider.of<TimingData>(context, listen: false).controllers[raceId]?.clear();

        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    for (var controller in Provider.of<TimingData>(context, listen: false).controllers[raceId] ?? []) {
      controller.dispose();
    }
    Provider.of<TimingData>(context, listen: false).clearRecords(raceId);
    Provider.of<TimingData>(context, listen: false).changeStartTime(null, raceId);
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = Provider.of<TimingData>(context, listen: false).startTime[raceId];
    final endTime = Provider.of<TimingData>(context, listen: false).endTime[raceId];
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    // final controllers = Provider.of<TimingData>(context, listen: false).controllers[raceId] ?? [];

    return Scaffold(
      // appBar: AppBar(title: const Text('Race Timing')),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
        // child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Race Timer Display
              Row(
                children: [
                  // Race time display
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(milliseconds: 10)),
                    builder: (context, snapshot) {
                      final currentTime = DateTime.now();
                      final startTime = Provider.of<TimingData>(context, listen: false).startTime[raceId];
                      Duration elapsed;
                      if (startTime == null) {
                        if (endTime != null) {
                          elapsed = endTime;
                        }
                        else {
                          elapsed = Duration.zero;
                        }
                      }
                      else {
                         elapsed = currentTime.difference(startTime);
                      }
                      return Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(top: 10, bottom: 10),
                        // margin: EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.1), // 1/10 from left
                        width: MediaQuery.of(context).size.width * 0.9, // 3/4 of screen width
                        child: Text(
                          formatDurationWithZeros(elapsed),
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.135,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            height: 1.0,
                          ),
                          textAlign: TextAlign.left,
                          strutStyle: StrutStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.15,
                            height: 1.0,
                            forceStrutHeight: true,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              // Buttons for Race Control
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: startTime == null ? Colors.green : Colors.red, // Button color
                        border: Border.all(
                          // color: const Color.fromARGB(255, 60, 60, 60), // Inner darker border
                          color: AppColors.backgroundColor,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: startTime == null ? Colors.green : Colors.red, // Outer lighter border
                            spreadRadius: 2, // Width of the outer border
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: startTime == null ? _startRace : _stopRace,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: CircleBorder(),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                        ),
                        child: Text(
                          startTime == null ? 'Start' : 'Stop',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  if (startTime == null && records.isNotEmpty)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0), // Padding around the button
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                          // double fontSize = constraints.maxWidth * 0.11;
                          // print('font size: $fontSize');
                            return ElevatedButton(
                              onPressed: _shareTimes,
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(0, 78),
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
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
                    ),
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color.fromARGB(255, 143, 143, 143), // Button color
                          border: Border.all(
                            // color: const Color.fromARGB(255, 60, 60, 60), // Inner darker border
                            color: AppColors.backgroundColor,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(255, 143, 143, 143), // Outer lighter border
                              spreadRadius: 2, // Width of the outer border
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: (records.isNotEmpty && startTime == null) ? _clearRaceTimes : (startTime != null ? _handleLogButtonPress : null),
                          style: ElevatedButton.styleFrom(
                            // backgroundColor: const Color.fromARGB(255, 143, 143, 143),
                            backgroundColor: Colors.transparent,
                            shape: CircleBorder(
                              // side: BorderSide(
                              //   color: Color.fromARGB(255, 80, 80, 80), // Light gray border
                              //   width: 2, // Thin border
                              // ),
                            ),
                            padding: EdgeInsets.zero,
                            elevation: 0,
                          ),
                          child: Text(
                            (records.isEmpty || startTime != null) ? 'Log' : 'Clear',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (records.isNotEmpty && startTime == null) ? 20 : 24,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Records Section
              Expanded(
                child: Column(
                  children: [
                    if (records.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          top: 15,
                          left: MediaQuery.of(context).size.width * 0.02,
                          right: MediaQuery.of(context).size.width * 0.02,
                        ),
                        child: Divider(
                          thickness: 1,
                          color: Color.fromRGBO(128, 128, 128, 0.5),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          if (records.isNotEmpty && record['is_runner'] == true) {
                            return Container(
                              margin: EdgeInsets.only(
                                top: 0, // MediaQuery.of(context).size.width * 0.01,
                                bottom: MediaQuery.of(context).size.width * 0.02,
                                left: MediaQuery.of(context).size.width * 0.02,
                                right: MediaQuery.of(context).size.width * 0.01,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onLongPress: () async {
                                      if (index == records.length - 1) {
                                        final confirmed = await _confirmDeleteLastRecord(index);
                                        if (confirmed ) {
                                          setState(() {
                                            Provider.of<TimingData>(context, listen: false).controllers[raceId]?.removeAt(_getNumberOfTimes() - 1);
                                            Provider.of<TimingData>(context, listen: false).records[raceId]?.removeAt(index);
                                            _scrollController.animateTo(
                                              max(_scrollController.position.maxScrollExtent, 0),
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeOut,
                                            );
                                          });
                                        }
                                      }
                                    },
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
                                        // Text(
                                        //   [
                                        //     if (record['name'] != null) record['name'],
                                        //     if (record['grade'] != null) ' ${record['grade']}',
                                        //     if (record['school'] != null) ' ${record['school']}    ',
                                        //     if (record['finish_time'] != null) '${record['finish_time']}'
                                        //   ].join(),
                                        //   style: TextStyle(
                                        //     fontSize: MediaQuery.of(context).size.width * 0.05,
                                        //     fontWeight: FontWeight.bold,
                                        //     color: record['conflict'] == null ? record['text_color'] : AppColors.redColor,
                                        //   ),
                                        // ),
                                      ],
                                    ),
                                  ),
                                  Divider(
                                    thickness: 1,
                                    color: Color.fromRGBO(128, 128, 128, 0.5),
                                  ),
                                      // SizedBox(
                                      //   width: MediaQuery.of(context).size.width * 0.25,
                                      //   child: TextField(
                                      //     controller: controller,
                                      //     style: TextStyle(
                                      //       fontSize: MediaQuery.of(context).size.width * 0.04,
                                      //     ),
                                      //     keyboardType: TextInputType.number,
                                      //     decoration: InputDecoration(
                                      //       labelText: 'Bib #',
                                      //       labelStyle: TextStyle(
                                      //         fontSize: MediaQuery.of(context).size.width * 0.05,
                                      //       ),
                                      //       border: OutlineInputBorder(
                                      //         borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.02),
                                      //       ),
                                      //       contentPadding: EdgeInsets.symmetric(
                                      //         vertical: MediaQuery.of(context).size.width * 0.02,
                                      //         horizontal: MediaQuery.of(context).size.width * 0.03,
                                      //       ),
                                      //     ),
                                      //     onChanged: (value) => _updateBib(index, int.parse(value)),
                                      //   ),
                                      // ),
                                      // SizedBox(height: MediaQuery.of(context).size.width * 0.02),
                                      // if (record['name'] != null)
                                      //   Text(
                                      //     'Name: ${record['name']}',
                                      //     style: TextStyle(
                                      //       fontSize: MediaQuery.of(context).size.width * 0.035
                                      //     ),
                                      //   ),
                                      // if (record['grade'] != null)
                                      //   Text(
                                      //     'Grade: ${record['grade']}',
                                      //     style: TextStyle(
                                      //       fontSize: MediaQuery.of(context).size.width * 0.035
                                      //     ),
                                      //   ),
                                      // if (record['school'] != null)
                                      //   Text(
                                      //     'School: ${record['school']}',
                                      //     style: TextStyle(
                                      //       fontSize: MediaQuery.of(context).size.width * 0.035
                                      //     ),
                                      //   ),
                                ],
                              ),
                            );
                          } else if (records.isNotEmpty && record['type'] == 'confirm_runner_number') {
                            return Container(
                              margin: EdgeInsets.only(
                                top: MediaQuery.of(context).size.width * 0.01,
                                bottom: MediaQuery.of(context).size.width * 0.02,
                                left: MediaQuery.of(context).size.width * 0.02,
                                right: MediaQuery.of(context).size.width * 0.02,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onLongPress: () {
                                      if (index == records.length - 1) {
                                        setState(() {
                                          records.removeAt(index);
                                          _updateTextColor(null);
                                        });
                                      }
                                    },
                                    child: Text(
                                      'Confirmed: ${record['finish_time']}',
                                      style: TextStyle(
                                        fontSize: MediaQuery.of(context).size.width * 0.05,
                                        fontWeight: FontWeight.bold,
                                        color: record['text_color'],
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    thickness: 1,
                                    color: Color.fromRGBO(128, 128, 128, 0.5),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return Container();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (startTime != null && records.isNotEmpty)
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8.0), // Adjust vertical margin as needed
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Center the buttons
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, size: 40, color: AppColors.navBarTextColor),
                        onPressed: _confirmRunnerNumber,
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove, size: 40, color: AppColors.redColor),
                        onPressed: _tooManyRunners,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 40, color: AppColors.redColor),
                        onPressed: _tooFewRunners,
                      ),
                      if (records.isNotEmpty && !records.last['is_runner'] && records.last['type'] != null && records.last['type'] != 'confirm_runner_number')
                        IconButton(
                          icon: const Icon(Icons.undo, size: 40, color: AppColors.redColor),
                          onPressed: _undoLastConflict,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        // ),
      ),
    );
  }
}
