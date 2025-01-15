import 'dart:math';
// import 'package:race_timing_app/screens/results_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:race_timing_app/utils/time_formatter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/timing_data.dart';
// import 'package:race_timing_app/bluetooth_service.dart' as app_bluetooth;
import 'package:race_timing_app/database_helper.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:async';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
// import 'package:race_timing_app/models/race.dart';
import 'race_screen.dart';
import '../models/race.dart';
import '../constants.dart';
import 'resolve_conflict.dart';

class TimingScreen extends StatefulWidget {
  final Race race;

  const TimingScreen({
    super.key, 
    required this.race,
  });


  @override
  State<TimingScreen> createState() => _TimingScreenState();
}

class _TimingScreenState extends State<TimingScreen> with TickerProviderStateMixin {
  // final List<Map<String, dynamic>> _records = [];
  // DateTime? startTime;
  // final List<TextEditingController> _controllers = [];
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final ScrollController _scrollController = ScrollController();
  late int raceId;
  // List<BluetoothDevice> _availableDevices = [];
  // BluetoothDevice? _connectedDevice;
  late AudioPlayer _audioPlayer;
  bool _isAudioPlayerReady = false;
  late TabController _tabController;
  late Race race;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _tabController = TabController(length: 3, vsync: this); // Adjust length based on your tabs
    race = widget.race;
    raceId = race.race_id;
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
                if (_getFirstConflict() != [null, -1]) {
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
        'bib_number': null,
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

  void _updateBib(int index, String bib) async {
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    // Update the bib in the record
    setState(() {
      records[index]['bib_number'] = bib;
    });

    // Fetch runner details from the database
    final [runner, shared] = await DatabaseHelper.instance.getRaceRunnerByBib(raceId, bib, getShared: true);

    // Update the record with runner details if found
    if (runner != null) {
      setState(() {
        records[index]['name'] = runner['name'];
        records[index]['grade'] = runner['grade'];
        records[index]['school'] = runner['school'];
        records[index]['race_runner_id'] = runner['race_runner_id'] ?? runner['runner_id'];
        records[index]['race_id'] = raceId;
        records[index]['runner_is_shared'] = shared;
      });
    }
    else {
      print('Runner not found');
      setState(() {
        records[index]['name'] = null;
        records[index]['grade'] = null;
        records[index]['school'] = null;
        records[index]['race_runner_id'] = null;
        records[index]['race_id'] = null;
      });
    }
  }

  void _scanQRCode() async {
    try {
      final result = await BarcodeScanner.scan();
      if (result.type == ResultType.Barcode) {
        print('Scanned barcode: ${result.rawContent}');
        _processQRData(result.rawContent);
      }
    } catch (e) {
      if (e is MissingPluginException) {
        _showErrorMessage('The QR code scanner is not available on this device.');
        _processQRData(json.encode([1, 2, 3, 4, 6, 5]));
      }
      else {
        _showErrorMessage('Failed to scan QR code: $e');
      }
    }
  }

  void _processQRData(String qrData) async {
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    try {
      final List<dynamic> bibData = json.decode(qrData);

      if (bibData.isNotEmpty) {
        final List<String> bibDataStrings = bibData.cast<String>();

        print('Bib data: $bibDataStrings');

        // for (int bib in bibDataInts) {
        //   final runnerData = await DatabaseHelper.instance.getRaceRunnerByBib(raceId, bib, getShared: true);
        //   // runnerData['bib_number'] = bib;
        //   setState(() {
        //     Provider.of<TimingData>(context, listen: false).addRunnerData(bibDataInts, raceId);
        //   });
        //   print('Bib: $bib');
        // }

        setState(() {
          Provider.of<TimingData>(context, listen: false).setBibs(bibDataStrings, raceId);
        });
        _syncBibData(bibDataStrings, records);
      } else {
        _showErrorMessage('QR code data is empty.');
      }
    } catch (e) {
      _showErrorMessage('Failed to process QR code data: $e');
    }
  }

  void _syncBibData(List<String> bibData, List<Map<String, dynamic>> records) async {
    final numberOfRunnerTimes = _getNumberOfTimes();
    if (numberOfRunnerTimes != bibData.length) {
      _updateTextColor(AppColors.redColor, confirmed: false);
      print('Number of runner times does not match bib data length');
    }
    else {
      print('Number of runner times matches bib data length');
      _updateTextColor(AppColors.navBarTextColor, confirmed: true);
    }
    for (int i = 0; i < bibData.length; i++) {
      final record = records.where((r) => r['is_runner'] == true && r['place'] == i + 1 && r['is_confirmed'] == true).firstOrNull;
      if (record == null) {
        print('Record not found for place ${i + 1}');
        continue;
      }
      final index = records.indexOf(record);
      // final match = (record != null);

      // if (match) {
      //   final index = records.indexOf(record);
      //   setState(() {
      //     records[index]['bib_number'] = bibData[i];
      //   });
      // }

      final [runner, shared] = await DatabaseHelper.instance.getRaceRunnerByBib(raceId, bibData[i], getShared: true);
      if (runner != null) {
        setState(() {
          records[index]['name'] = runner['name'];
          records[index]['grade'] = runner['grade'];
          records[index]['school'] = runner['school'];
          records[index]['race_runner_id'] = runner['race_runner_id'] ?? runner['runner_id'];
          records[index]['race_id'] = raceId;
          records[index]['runner_is_shared'] = shared;
          records[index]['bib_number'] = bibData[i];
        });
      }
    }

    final allRunnersResolved = _checkIfAllRunnersResolved();
    if (!allRunnersResolved) {
      _openResolveDialog();
    }
  }

  Future<void> _openResolveDialog() async {
    print('Opening resolve dialog');
    // final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    final [firstConflict, conflictIndex] = _getFirstConflict();
    if (firstConflict == null){
      print('No conflicts left');
      _deleteConfirmedRecordsBeforeIndexUntilConflict(Provider.of<TimingData>(context, listen: false).records[raceId]!.length - 1);
      return;
    } // No conflicts left
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Resolve Runners'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conflict:',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 10),
                Text(
                  firstConflict == 'too_few_runner_times'
                      ? 'Not enough finish times were recorded. Please select which times correctly belong to the runners and enter in missing times.'
                      : 'More finish times were recorded than the number of runners. Please resolve the conflict by selecting which times correctly belong to the runners.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Update the record to resolve the conflict
                  Navigator.of(context).pop();
                  if (firstConflict == 'too_few_runner_times') {
                    print('Resolving too few runner times conflict at index $conflictIndex');
                    await _resolveTooFewRunnerTimes(conflictIndex);
                  }
                  else if (firstConflict == 'too_many_runner_times') {
                    await _resolveTooManyRunnerTimes(conflictIndex);
                  }
                  else {
                    _showErrorMessage('Unknown conflict type: $firstConflict');
                  }
                  // // Call this method again to check for the next conflict
                  // _openResolveDialog();
                },
                child: Text('Resolve'),
              ),
            ],
          );
        },
      );
  }

  // Future<void> _resolveTooFewRunnerTimes(int conflictIndex) async {
  //   print('Resolving too few runner times conflict at index $conflictIndex');
  //   var records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
  //   final bibData = Provider.of<TimingData>(context, listen: false).bibs[raceId] ?? [];
  //   final conflictRecord = records[conflictIndex];
    
  //   final lastConfirmedIndexBeforeConflict = records.sublist(0, conflictIndex).lastIndexWhere((record) => record['is_confirmed'] == true);
  //   if (lastConfirmedIndexBeforeConflict == -1 || conflictIndex == -1) return;
    
  //   print('lastConfirmedIndexBeforeConflict: $lastConfirmedIndexBeforeConflict');
  //   final lastConfirmedRecordBeforeConflict = records[lastConfirmedIndexBeforeConflict];
    
  //   final lastConfirmedRecordBeforeConflictTime = loadDurationFromString(lastConfirmedRecordBeforeConflict['finish_time']);
  //   final conflictRecordTime = loadDurationFromString(conflictRecord['finish_time']);

  //   final nextConfirmedRecordAfterConflict = records.sublist(conflictIndex + 1, records.length).firstWhere((record) => record['is_confirmed'] == true, orElse: () => {});

  //   final firstConflictingRecordIndex = records.indexOf(records.sublist(0, conflictIndex).firstWhere((record) => record['is_runner'] == true && record['is_confirmed'] == false && record['place'] == lastConfirmedRecordBeforeConflict['place'] + 1));
  //   final noExistingConflictRecords = firstConflictingRecordIndex == -1;
  //   print('firstConflictingRecordIndex: $firstConflictingRecordIndex');
  //   final spaceBetweenConfirmedAndConflict = firstConflictingRecordIndex - lastConfirmedIndexBeforeConflict;
  //   print('spaceBetweenConfirmedAndConflict: $spaceBetweenConfirmedAndConflict');

    // final conflictingRecords = noExistingConflictRecords ? [] : records.sublist(lastConfirmedIndexBeforeConflict + spaceBetweenConfirmedAndConflict, conflictIndex);
    // List<dynamic> conflictingRunners = [];
    // for (int i = lastConfirmedRecordBeforeConflict['place'].toInt(); i < conflictRecord['numTimes'].toInt(); i++) {
    //   await DatabaseHelper.instance.getRaceRunnerByBib(raceId, bibData[i], getShared: true).then((runner) {
    //     print('Runner: $runner');
    //     print('Runner[0]: ${runner[0]}');
    //     conflictingRunners.add(runner[0]);
    //   });
    // }

    // final List<TextEditingController> _timeControllers = List.generate(conflictingRunners.length, (_) => TextEditingController());
    // final List<TextEditingController> _manualEntryControllers = List.generate(conflictingRunners.length, (_) => TextEditingController());

    // final conflictingTimes = conflictingRecords.map((record) => record['finish_time']).toList();
    // conflictingTimes.removeWhere((time) => time == null || time == 'TBD');
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: Text('Enter Time for Conflicting Runners'),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //             children: [
  //               if (lastConfirmedRecordBeforeConflict != null && lastConfirmedRecordBeforeConflict != {})
  //                 Row(
  //                   children: [
  //                     Expanded(
  //                       child: Text(
  //                         '${lastConfirmedRecordBeforeConflict['name']} #${lastConfirmedRecordBeforeConflict['bib_number'].toString()} ${lastConfirmedRecordBeforeConflict['school']} - ${lastConfirmedRecordBeforeConflict['finish_time']}',
  //                         style: TextStyle(
  //                           fontWeight: FontWeight.w400,
  //                           color: AppColors.navBarTextColor,
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ...List.generate(conflictingRunners.length, (index) {
  //                 return Row(
  //                   children: [
  //                     Expanded(
  //                       child: Text(
  //                         '${conflictingRunners[index]['name']} #${conflictingRunners[index]['bib_number'].toString()} ${conflictingRunners[index]['school']}',
  //                         style: TextStyle(
  //                           fontWeight: FontWeight.w400,
  //                         ),
  //                       ),
  //                     ),
  //                     Expanded(
  //                       child: Row(
  //                         children: [
  //                           Expanded(
  //                             child: DropdownButtonFormField<String>(
  //                               value: _timeControllers[index].text.isNotEmpty
  //                                   ? _timeControllers[index].text
  //                                   : null,
  //                               items: [
  //                                 ...conflictingTimes.map((time) {
  //                                   return DropdownMenuItem<String>(
  //                                     value: time,
  //                                     child: Text(time),
  //                                   );
  //                                 }),
  //                                 DropdownMenuItem<String>(
  //                                   value: null,
  //                                   child: StatefulBuilder(
  //                                     builder: (context, setState) {
  //                                       return SizedBox(
  //                                         width: MediaQuery.of(context).size.width * 0.25,
  //                                         child: TextField(
  //                                           controller: _manualEntryControllers[index],
  //                                           decoration: InputDecoration(
  //                                             hintText: 'Enter time',
  //                                             border: InputBorder.none,
  //                                           ),
  //                                         ),
  //                                       );
  //                                     },
  //                                   ),
  //                                 )
  //                               ],
  //                               onChanged: (value) {
  //                                 if (value == null || value == '') {
  //                                   if (_manualEntryControllers[index].text.isNotEmpty) {
  //                                     _timeControllers[index].text = _manualEntryControllers[index].text;
  //                                   } else {
  //                                     _timeControllers[index].text = '';
  //                                   }
  //                                 } else {
  //                                   _timeControllers[index].text = value;
  //                                 }
  //                               },
  //                               decoration: InputDecoration(hintText: 'Select Time'),
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                   ],
  //                 );
  //               }
  //             ),
  //             if (nextConfirmedRecordAfterConflict != null && nextConfirmedRecordAfterConflict != {})
  //               Row(
  //                 children: [
  //                   Expanded(
  //                     child: Text(
  //                       '${nextConfirmedRecordAfterConflict['name']} #${nextConfirmedRecordAfterConflict['bib_number'].toString()} ${nextConfirmedRecordAfterConflict['school']} - ${nextConfirmedRecordAfterConflict['finish_time']}',
  //                       style: TextStyle(
  //                         fontWeight: FontWeight.w400,
  //                         color: AppColors.navBarTextColor,
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //             child: Text('Cancel'),
  //           ),
  //           TextButton(
  //             onPressed: () async {
  //               List<Duration> formattedTimes = [];
  //               // Logic to handle the entered times and resolve conflicts
  //               for (int i = 0; i < conflictingRunners.length; i++) {
  //                 final inputTime = _timeControllers[i].text;
  //                 if (inputTime.isEmpty || inputTime == '') {
  //                   _showErrorMessage('Please enter a time for runner ${conflictingRunners[i]['name']}');
  //                   return;
  //                 }
  //                 print('Input time: $inputTime');
  //                 String formatedTime;
  //                 if (!inputTime.contains(':')) {
  //                   formatedTime = '00:00:$inputTime';
  //                 }
  //                 else if (inputTime.allMatches(':').length == 1) {
  //                   formatedTime = '00:$inputTime';
  //                 }
  //                 else if (inputTime.allMatches(':').length == 2) {
  //                   formatedTime = inputTime;
  //                 }
  //                 else {
  //                   _showErrorMessage('Invalid time format: $inputTime. Too many colons.');
  //                   return;
  //                 }
  //                 if (formatedTime.allMatches('.').isEmpty) {
  //                   formatedTime = '$formatedTime.0';
  //                 }
  //                 else if (formatedTime.allMatches('.').length > 1) {
  //                   _showErrorMessage('Invalid time format: $inputTime. Too many decimal points.');
  //                   return Future.value(false);
  //                 }
  //                 final newDuration = Duration(hours: int.parse(formatedTime.split(':')[0]), minutes: int.parse(formatedTime.split(':')[1]), seconds: int.parse(formatedTime.split(':')[2].split('.')[0]), milliseconds: int.parse(formatedTime.split('.')[1].padRight(3, '0')));
                  
  //                 print('New duration: $newDuration');
  //                 // Check if the entered duration is valid
  //                 if (newDuration <= lastConfirmedRecordBeforeConflictTime) {
  //                   _showErrorMessage('New time must be greater than the last confirmed time: ${formatDuration(lastConfirmedRecordBeforeConflictTime)}.');
  //                   return;
  //                 }
  //                 if (newDuration >= conflictRecordTime) {
  //                   _showErrorMessage('New time must be before the conflict at: ${formatDuration(conflictRecordTime)}.');
  //                   return;
  //                 }

  //                 print('New time: $newDuration');
  //                 final newTime = formatDuration(newDuration);
  //                 print('Formatted new time: $newTime');

  //                 // Process the input time and update records accordingly
  //                 formattedTimes.add(newDuration);
  //               }

  //               // Make sure the durations are in ascending order
  //               if (formattedTimes.length > 1 &&
  //                   formattedTimes.asMap().entries.any((entry) {
  //                     int index = entry.key;
  //                     Duration element = entry.value;
  //                     return index < formattedTimes.length - 1 &&
  //                         element >= formattedTimes[index + 1];
  //                   })) {
  //                 _showErrorMessage('Times must be in ascending order.');
  //                 return;
  //               }

                // final lastConfirmedRunnerPlace = lastConfirmedRecordBeforeConflict['place'];
                // for (int i = 0; i < conflictingRunners.length; i++) {
                //   final int currentPlace = (i + lastConfirmedRunnerPlace + 1).toInt();
                //   print('Current place: $currentPlace');
                //   var record = records.firstWhere((element) => element['place'] == currentPlace, orElse: () => {});
                //   print('Record: $record');
                //   if (record == {} || record.isEmpty) {
                //     print('Record not found for place $currentPlace, creating new record');
                //     setState(() {
                //       Provider.of<TimingData>(context, listen: false).insertRecord(lastConfirmedIndexBeforeConflict + spaceBetweenConfirmedAndConflict + i, {
                //         'finish_time': formatDuration(formattedTimes[i]),
                //         'bib_number': null,
                //         'is_runner': true,
                //         'is_confirmed': false,
                //         'text_color': null,
                //         'place': currentPlace,
                //       }, raceId);
                //     });
                //     records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
                //     record = records.firstWhere((element) => element['place'] == currentPlace, orElse: () => {});
                //     if (record == {}) {
                //       _showErrorMessage('Failed to add record');
                //       return;
                //     }
                    
                //     Provider.of<TimingData>(context, listen: false).insertController(record['place'] - 1, TextEditingController(), raceId);
                //   }
                //   final bibNumber = bibData[record['place'].toInt() - 1];   

                //   setState(() {
                //     record['finish_time'] = formatDuration(formattedTimes[i]);
                //     record['bib_number'] = bibNumber;
                //     record['is_runner'] = true;
                //     record['is_confirmed'] = true;
                //     record['conflict'] = null;
                //     record['name'] = conflictingRunners[i]['name'];
                //     record['grade'] = conflictingRunners[i]['grade'];
                //     record['school'] = conflictingRunners[i]['school'];
                //     record['race_runner_id'] = conflictingRunners[i]['race_runner_id'] ?? conflictingRunners[i]['runner_id'];
                //     record['race_id'] = raceId;
                //     record['runner_is_shared'] = conflictingRunners[i]['runner_is_shared'];
                //     record['text_color'] = AppColors.navBarTextColor;
                //   });
                // }
                // setState(() {
                //   conflictRecord['numTimes'] = lastConfirmedRunnerPlace.toInt() + conflictingRunners.length;
                //   conflictRecord['type'] = 'confirm_runner_number';
                //   conflictRecord['conflict'] = null;
                //   conflictRecord['is_runner'] = false;
                //   conflictRecord['text_color'] = AppColors.navBarTextColor;
                //   // conflictRecord['finish_time'] = formatDuration(formattedTimes.last);
                // });
                // print('Records: $records');
                // Navigator.of(context).pop();
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(
                //     content: Text('Successfully resolved conflict'),
                //   ),
                // );


                // // // Call this method again to check for the next conflict
                // _openResolveDialog();
  //             },
  //             child: Text('Resolve'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // Future<void> _resolveTooManyRunnerTimes(int conflictIndex) async {
  //   print('Resolving too many runner times conflict at index $conflictIndex');
  //   var records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
  //   final bibData = Provider.of<TimingData>(context, listen: false).bibs[raceId] ?? [];
  //   final conflictRecord = records[conflictIndex];
    
  //   final lastConfirmedIndexBeforeConflict = records.sublist(0, conflictIndex).lastIndexWhere((record) => record['is_confirmed'] == true);
  //   if (lastConfirmedIndexBeforeConflict == -1 || conflictIndex == -1) return;
    
  //   print('lastConfirmedIndexBeforeConflict: $lastConfirmedIndexBeforeConflict');
  //   final lastConfirmedRecordBeforeConflict = records[lastConfirmedIndexBeforeConflict];
    
  //   final nextConfirmedRecordAfterConflict = records.sublist(conflictIndex + 1, records.length).firstWhere((record) => record['is_confirmed'] == true, orElse: () => {});

  //   final firstConflictingRecordIndex = records.indexOf(records.sublist(0, conflictIndex).firstWhere((record) => record['is_runner'] == true && record['is_confirmed'] == false && record['place'] == lastConfirmedRecordBeforeConflict['place'] + 1));
  //   final noExistingConflictRecords = firstConflictingRecordIndex == -1;
  //   print('firstConflictingRecordIndex: $firstConflictingRecordIndex');
  //   final spaceBetweenConfirmedAndConflict = firstConflictingRecordIndex - lastConfirmedIndexBeforeConflict;
  //   print('spaceBetweenConfirmedAndConflict: $spaceBetweenConfirmedAndConflict');

  //   final conflictingRecords = noExistingConflictRecords ? [] : records.sublist(lastConfirmedIndexBeforeConflict + spaceBetweenConfirmedAndConflict, conflictIndex);
  //   List<dynamic> conflictingRunners = [];
  //   for (int i = lastConfirmedRecordBeforeConflict['place'].toInt(); i < conflictRecord['numTimes'].toInt(); i++) {
  //     await DatabaseHelper.instance.getRaceRunnerByBib(raceId, bibData[i], getShared: true).then((runner) {
  //       print('Runner: $runner');
  //       print('Runner[0]: ${runner[0]}');
  //       conflictingRunners.add(runner[0]);
  //     });
  //   }

  //   final List<TextEditingController> _timeControllers = List.generate(conflictingRunners.length, (_) => TextEditingController());

  //   final conflictingTimes = conflictingRecords.map((record) => record['finish_time']).toList();
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: Text('Select Time for Conflicting Runners'),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //               if (lastConfirmedRecordBeforeConflict != null && lastConfirmedRecordBeforeConflict != {})
  //                 Row(
  //                   children: [
  //                     Expanded(
  //                       child: Text(
  //                         '${lastConfirmedRecordBeforeConflict['name']} #${lastConfirmedRecordBeforeConflict['bib_number'].toString()} ${lastConfirmedRecordBeforeConflict['school']} - ${lastConfirmedRecordBeforeConflict['finish_time']}',
  //                         style: TextStyle(
  //                           fontWeight: FontWeight.w400,
  //                           color: AppColors.navBarTextColor,
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ...List.generate(conflictingRunners.length, (index) {
  //                 return Row(
  //                   children: [
  //                     Expanded(
  //                       child: Text(
  //                         '${conflictingRunners[index]['name']} #${conflictingRunners[index]['bib_number'].toString()} ${conflictingRunners[index]['school']}',
  //                         style: TextStyle(
  //                           fontWeight: FontWeight.w400,
  //                         ),
  //                       ),
  //                     ),
  //                     Expanded(
  //                       child: DropdownButtonFormField<String>(
  //                         value: _timeControllers[index].text.isNotEmpty
  //                             ? _timeControllers[index].text
  //                             : null,
  //                         items: conflictingTimes.map((time) {
  //                           return DropdownMenuItem<String>(
  //                             value: time,
  //                             child: Text(time),
  //                           );
  //                         }).toList(),
  //                         onChanged: (value) {
  //                           if (value == null) {
  //                             _timeControllers[index].text = '';
  //                           } else {
  //                             _timeControllers[index].text = value;
  //                           }
  //                         },
  //                         decoration: InputDecoration(hintText: 'Select Time'),
  //                       ),
  //                     ),
  //                   ],
  //                 );
  //               }),
  //             if (nextConfirmedRecordAfterConflict != null && nextConfirmedRecordAfterConflict != {})
  //               Row(
  //                 children: [
  //                   Expanded(
  //                     child: Text(
  //                       '${nextConfirmedRecordAfterConflict['name']} #${nextConfirmedRecordAfterConflict['bib_number'].toString()} ${nextConfirmedRecordAfterConflict['school']} - ${nextConfirmedRecordAfterConflict['finish_time']}',
  //                       style: TextStyle(
  //                         fontWeight: FontWeight.w400,
  //                         color: AppColors.navBarTextColor,
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //             child: Text('Cancel'),
  //           ),
  //           TextButton(
  //             onPressed: () async {
  //               List<Duration> formattedTimes = [];
  //               // Logic to handle the entered times and resolve conflicts
  //               for (int i = 0; i < conflictingRunners.length; i++) {
  //                 final inputTime = _timeControllers[i].text;
  //                 if (inputTime.isEmpty || inputTime == '') {
  //                   _showErrorMessage('Please enter a time for runner ${conflictingRunners[i]['name']}');
  //                   return;
  //                 }
  //                 print('Input time: $inputTime');
  //                 String formatedTime;
                  // if (!inputTime.contains(':')) {
                  //   formatedTime = '00:00:$inputTime';
                  // }
                  // else if (inputTime.allMatches(':').length == 1) {
                  //   formatedTime = '00:$inputTime';
                  // }
                  // else if (inputTime.allMatches(':').length == 2) {
                  //   formatedTime = inputTime;
                  // }
                  // else {
                  //   _showErrorMessage('Invalid time format: $inputTime. Too many colons.');
                  //   return;
                  // }
                  // if (formatedTime.allMatches('.').isEmpty) {
                  //   formatedTime = '$formatedTime.0';
                  // }
                  // else if (formatedTime.allMatches('.').length > 1) {
                  //   _showErrorMessage('Invalid time format: $inputTime. Too many decimal points.');
                  //   return Future.value(false);
                  // }
                  // final newDuration = Duration(hours: int.parse(formatedTime.split(':')[0]), minutes: int.parse(formatedTime.split(':')[1]), seconds: int.parse(formatedTime.split(':')[2].split('.')[0]), milliseconds: int.parse(formatedTime.split('.')[1].padRight(3, '0')));
  //                 formattedTimes.add(newDuration);
  //               }

  //               if (formattedTimes.length > 1 &&
  //                   formattedTimes.asMap().entries.any((entry) {
  //                     int index = entry.key;
  //                     Duration element = entry.value;
  //                     return index < formattedTimes.length - 1 &&
  //                         element >= formattedTimes[index + 1];
  //                   })) {
  //                 _showErrorMessage('Times must be in ascending order.');
  //                 return;
  //               }
                // final unchosenTimes = List.from(conflictingTimes);
                // unchosenTimes.removeWhere((time) => formattedTimes.contains(loadDurationFromString(time)));

                // print('Unchosen times: $unchosenTimes');
                // if (unchosenTimes.length != 1) {
                //   _showErrorMessage('Please select a time for each runner.');
                //   return;
                // }
                // setState(() {
                //   records.removeWhere((record) => record['finish_time'] == unchosenTimes[0]);
                //   conflictingRunners.removeWhere((runner) => runner['finish_time'] == unchosenTimes[0]);
                //   //remove controller of the unchosen runner
                // });
                // records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];

                // final lastConfirmedRunnerPlace = lastConfirmedRecordBeforeConflict['place'];
                // for (int i = 0; i < conflictingRunners.length; i++) {
                //   final int currentPlace = (i + lastConfirmedRunnerPlace + 1).toInt();
                //   print('Current place: $currentPlace');
                //   var record = records[lastConfirmedIndexBeforeConflict + spaceBetweenConfirmedAndConflict + i];
                //   final bibNumber = bibData[currentPlace - 1];    

                //   setState(() {
                //     record['finish_time'] = formatDuration(formattedTimes[i]);
                //     record['bib_number'] = bibNumber;
                //     record['is_runner'] = true;
                //     record['place'] = currentPlace;
                //     record['is_confirmed'] = true;
                //     record['conflict'] = null;
                //     record['name'] = conflictingRunners[i]['name'];
                //     record['grade'] = conflictingRunners[i]['grade'];
                //     record['school'] = conflictingRunners[i]['school'];
                //     record['race_runner_id'] = conflictingRunners[i]['race_runner_id'] ?? conflictingRunners[i]['runner_id'];
                //     record['race_id'] = raceId;
                //     record['runner_is_shared'] = conflictingRunners[i]['runner_is_shared'];
                //     record['text_color'] = AppColors.navBarTextColor;
                //   });
                // }
  //               setState(() {
  //                 conflictRecord['numTimes'] = lastConfirmedRunnerPlace.toInt() + conflictingRunners.length;
  //                 conflictRecord['type'] = 'confirm_runner_number';
  //                 conflictRecord['conflict'] = null;
  //                 conflictRecord['is_runner'] = false;
  //                 conflictRecord['text_color'] = AppColors.navBarTextColor;
  //                 // conflictRecord['finish_time'] = formatDuration(formattedTimes.last);
  //               });
  //               print('Records: $records');
  //               Navigator.of(context).pop();
  //               ScaffoldMessenger.of(context).showSnackBar(
  //                 SnackBar(
  //                   content: Text('Successfully resolved conflict'),
  //                 ),
  //               );


  //               // // Call this method again to check for the next conflict
  //               _openResolveDialog();
  //             },
  //             child: Text('Resolve'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  Future<void> _resolveTooFewRunnerTimes(int conflictIndex) async {
    var records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    final bibData = Provider.of<TimingData>(context, listen: false).bibs[raceId] ?? [];
    final conflictRecord = records[conflictIndex];
    
    final lastConfirmedIndex = records.sublist(0, conflictIndex)
        .lastIndexWhere((record) => record['is_confirmed'] == true);
    if (conflictIndex == -1) return;
    
    final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    print('Last confirmed record: $lastConfirmedRecord');
    final nextConfirmedRecord = records.sublist(conflictIndex + 1)
        .firstWhere((record) => record['is_confirmed'] == true, orElse: () => {});

    final firstConflictingRecordIndex = records.sublist(0, conflictIndex).indexWhere((record) => record['is_confirmed'] == false);
    if (firstConflictingRecordIndex == -1) return;

    final startingIndex = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'];
    print('Starting index: $startingIndex');

    List<dynamic> conflictingRunners = [];
    for (int i = startingIndex; i < conflictRecord['numTimes']; i++) {
      final runner = await DatabaseHelper.instance
          .getRaceRunnerByBib(raceId, bibData[i], getShared: true);
      if (runner.isNotEmpty) conflictingRunners.add(runner[0]);
    }
    print('First conflicting record index: $firstConflictingRecordIndex');
    print('Last confirmed index: $lastConfirmedIndex');
    final spaceBetweenConfirmedAndConflict = firstConflictingRecordIndex == -1 ? 1 : firstConflictingRecordIndex - lastConfirmedIndex;
    print('Space between confirmed and conflict: $spaceBetweenConfirmedAndConflict');

    final conflictingRecords = records.sublist(lastConfirmedIndex + spaceBetweenConfirmedAndConflict, conflictIndex);

    final List<String> conflictingTimes = conflictingRecords.map((record) => record['finish_time']).cast<String>().toList();
    conflictingTimes.removeWhere((time) => time == '' || time == 'TBD');

    showDialog(
      context: context,
      builder: (context) => ConflictResolutionDialog(
        conflictingRunners: conflictingRunners,
        lastConfirmedRecord: lastConfirmedRecord,
        nextConfirmedRecord: nextConfirmedRecord,
        availableTimes: conflictingTimes,
        allowManualEntry: true,
        conflictRecord: conflictRecord,
        onResolve: (formattedTimes) => _handleTooFewTimesResolution(
          formattedTimes,
          conflictingRunners,
          lastConfirmedRecord,
          conflictRecord,
          lastConfirmedIndex,
          bibData,
        ),
      ),
    );
  }

  Future<void> _resolveTooManyRunnerTimes(int conflictIndex) async {
    var records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    final bibData = Provider.of<TimingData>(context, listen: false).bibs[raceId] ?? [];
    final conflictRecord = records[conflictIndex];
    
    final lastConfirmedIndex = records.sublist(0, conflictIndex)
        .lastIndexWhere((record) => record['is_confirmed'] == true);
    if (conflictIndex == -1) return;
    
    final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    final nextConfirmedRecord = records.sublist(conflictIndex + 1)
        .firstWhere((record) => record['is_confirmed'] == true, orElse: () => {});

    print('Last confirmed index: $lastConfirmedIndex');
    print('Conflict index: $conflictIndex');

    final conflictingRecords = _getConflictingRecords(records, conflictIndex);
    print('Conflicting records: $conflictingRecords');

    final firstConflictingRecordIndex = records.indexOf(conflictingRecords.first);
    if (firstConflictingRecordIndex == -1) return;

    final spaceBetweenConfirmedAndConflict = lastConfirmedIndex == -1 ? 1 : firstConflictingRecordIndex - lastConfirmedIndex;
    print('Space between confirmed and conflict: $spaceBetweenConfirmedAndConflict');

    final List<String> conflictingTimes = conflictingRecords
        .map((record) => record['finish_time'])
        .where((time) => time != null && time != 'TBD')
        .cast<String>()
        .toList();

    List<dynamic> conflictingRunners = [];
    for (int i = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place']; i < conflictRecord['numTimes']; i++) {
      final runner = await DatabaseHelper.instance
          .getRaceRunnerByBib(raceId, bibData[i], getShared: true);
      if (runner.isNotEmpty) conflictingRunners.add(runner[0]);
    }

    print('Conflicting runners: $conflictingRunners');
    print('Conflicting times: $conflictingTimes');

    showDialog(
      context: context,
      builder: (context) => ConflictResolutionDialog(
        conflictingRunners: conflictingRunners,
        lastConfirmedRecord: lastConfirmedRecord,
        nextConfirmedRecord: nextConfirmedRecord,
        availableTimes: conflictingTimes,
        allowManualEntry: false,
        conflictRecord: conflictRecord,
        onResolve: (formattedTimes) => _handleTooManyTimesResolution(
          formattedTimes,
          conflictingRunners,
          conflictingTimes,
          lastConfirmedRecord,
          conflictRecord,
          lastConfirmedIndex,
          bibData,
          spaceBetweenConfirmedAndConflict
        ),
      ),
    );
  }

  // Helper functions
  void _handleTooFewTimesResolution(
    List<Duration> times,
    List<dynamic> runners,
    dynamic lastConfirmedRecord,
    Map<String, dynamic> conflictRecord,
    int lastConfirmedIndex,
    List<dynamic> bibData,
  ) {
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    final lastConfirmedRunnerPlace = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'];
    for (int i = 0; i < runners.length; i++) {
      final int currentPlace = (i + lastConfirmedRunnerPlace + 1).toInt();
      print('Current place: $currentPlace');
      var record = records.firstWhere((element) => element['place'] == currentPlace, orElse: () => {});
      final bibNumber = bibData[record['place'].toInt() - 1];   

      setState(() {
        record['finish_time'] = formatDuration(times[i]);
        record['bib_number'] = bibNumber;
        record['is_runner'] = true;
        record['is_confirmed'] = true;
        record['conflict'] = null;
        record['name'] = runners[i]['name'];
        record['grade'] = runners[i]['grade'];
        record['school'] = runners[i]['school'];
        record['race_runner_id'] = runners[i]['race_runner_id'] ?? runners[i]['runner_id'];
        record['race_id'] = raceId;
        record['runner_is_shared'] = runners[i]['runner_is_shared'];
        record['text_color'] = AppColors.navBarTextColor;
      });
    }

    setState(() {
      _updateConflictRecord(
        conflictRecord,
        lastConfirmedRunnerPlace + runners.length,
      );
    });

    _showSuccessMessage();
    _openResolveDialog();
  }

  void _handleTooManyTimesResolution(
    List<Duration> times,
    List<dynamic> runners,
    List<String> availableTimes,
    dynamic lastConfirmedRecord,
    Map<String, dynamic> conflictRecord,
    int lastConfirmedIndex,
    List<dynamic> bibData,
    int spaceBetweenConfirmedAndConflict,
  ) {
    var records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    final unusedTimes = availableTimes
        .where((time) => !times.contains(loadDurationFromString(time)))
        .toList();

    if (unusedTimes.length != 1) {
      _showErrorMessage('Please select a time for each runner.');
      return;
    }
    print('Unused times: $unusedTimes');
    final unusedRecord = records.firstWhere((record) => record['finish_time'] == unusedTimes[0]);
    print('Unused record: $unusedRecord');

    setState(() {
      Provider.of<TimingData>(context, listen: false).records[raceId]?.removeWhere((record) => record['finish_time'] == unusedTimes[0]);
      runners.removeWhere((runner) => runner['finish_time'] == unusedTimes[0]);
      //remove controller of the unchosen runner
    });
    records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];

    final lastConfirmedRunnerPlace = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'];
    final lastConfirmedIndex = lastConfirmedRecord.isEmpty ? -1 : records.indexOf(lastConfirmedRecord); 
    for (int i = 0; i < runners.length; i++) {
      final int currentPlace = (i + lastConfirmedRunnerPlace + 1).toInt();
      var record = records[lastConfirmedIndex + spaceBetweenConfirmedAndConflict + i];
      final bibNumber = bibData[currentPlace - 1];    

      setState(() {
        record['finish_time'] = formatDuration(times[i]);
        record['bib_number'] = bibNumber;
        record['is_runner'] = true;
        record['place'] = currentPlace;
        record['is_confirmed'] = true;
        record['conflict'] = null;
        record['name'] = runners[i]['name'];
        record['grade'] = runners[i]['grade'];
        record['school'] = runners[i]['school'];
        record['race_runner_id'] = runners[i]['race_runner_id'] ?? runners[i]['runner_id'];
        record['race_id'] = raceId;
        record['runner_is_shared'] = runners[i]['runner_is_shared'];
        record['text_color'] = AppColors.navBarTextColor;
      });
    }

    setState(() {
      _updateConflictRecord(
        conflictRecord,
        (lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place']) + runners.length,
      );
    });

    _showSuccessMessage();
    _openResolveDialog();
  }


  void _updateConflictRecord(Map<String, dynamic> record, int numTimes) {
    record['numTimes'] = numTimes;
    record['type'] = 'confirm_runner_number';
    record['conflict'] = null;
    record['is_runner'] = false;
    record['text_color'] = AppColors.navBarTextColor;
  }

  List<dynamic> _getConflictingRecords(
    List<dynamic> records,
    int conflictIndex,
  ) {
    final firstConflictIndex = records.sublist(0, conflictIndex).indexWhere(
        (record) => record['is_runner'] == true && record['is_confirmed'] == false,
      );
    
    return firstConflictIndex == -1 ? [] : 
      records.sublist(firstConflictIndex, conflictIndex);
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully resolved conflict')),
    );
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

  void _saveResults() async {
    if (!_checkIfAllRunnersResolved()) {
      _showErrorMessage('All runners must be resolved before proceeding.');
      return;
    }
    // Check if all runners have a non-null bib number
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    bool allRunnersHaveRequiredInfo = records.every((runner) => runner['bib_number'] != null && runner['name'] != null && runner['grade'] != null && runner['school'] != null);

    if (allRunnersHaveRequiredInfo) {
      // Remove the 'bib_number' key from the records before saving since it is not in database
      for (var record in records) {
        if (record['is_runner'] == false) {
          records.remove(record);
          continue;
        }
        record.remove('bib_number');
        record.remove('name');
        record.remove('grade');
        record.remove('school');
        record.remove('text_color');
        record.remove('is_confirmed');
        record.remove('is_runner');
        record.remove('conflict');
      }

      await DatabaseHelper.instance.insertRaceResults(records);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Results saved successfully. View results?'),
          action: SnackBarAction(
            label: 'View Results',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => RaceScreen(race: race, initialTabIndex: 1), // Pass the race object and set results tab as initial
                ),
              );
              ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Optional: Hide the SnackBar
            },
          ),
        ),
      );
    } else {
      _showErrorMessage('All runners must have a bib number assigned before proceeding.');
    }
  }

  bool _checkIfAllRunnersResolved() {
    List<Map<String, dynamic>> records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    return records.every((runner) => runner['bib_number'] != null && runner['is_confirmed'] == true);
  }

  void _updateTextColor(Color? color, {bool confirmed = false, String? conflict = null}) {
    List<Map<String, dynamic>> records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
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
      });
    }
  }

  void _confirmRunnerNumber() async {
    // final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    int numTimes = _getNumberOfTimes(); // Placeholder for actual length input
    DateTime now = DateTime.now();
    final startTime = Provider.of<TimingData>(context, listen: false).startTime[raceId];
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    if (startTime == null) {
      _showErrorMessage('Start time cannot be null.');
      return;
    }
    final difference = now.difference(startTime);
    
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

  void _tooManyRunners() async {
    // final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    int numTimes = _getNumberOfTimes() - 1; // Placeholder for actual length input
    DateTime now = DateTime.now();
    final startTime = Provider.of<TimingData>(context, listen: false).startTime[raceId];
    if (startTime == null) {
      _showErrorMessage('Start time cannot be null.');
      return;
    }
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    final previousRunner = records.last;
    if (previousRunner['is_runner'] == false) {
      _showErrorMessage('You must have a finish time before pressing this button.');
      return;
    }
    if (records.length < 2 || records[records.length - 2]['is_runner'] == false) {
      bool confirmed = await _showConfirmationMessage('This will delete the last finish time, are you sure you want to continue?');
      if (confirmed == false) {
        return;
      }
      setState(() {
        Provider.of<TimingData>(context, listen: false).records[raceId]?.removeLast();
      });
      return;
    }
    previousRunner['place'] = '';

    final difference = now.difference(startTime);

    final color = AppColors.redColor;
    _updateTextColor(color, conflict: 'too_many_runner_times');

    setState(() {
      Provider.of<TimingData>(context, listen: false).records[raceId]?.add({
        'finish_time': formatDuration(difference),
        'is_runner': false,
        'type': 'too_many_runner_times',
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

  void _tooFewRunners() async {
    // final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    int numTimes = _getNumberOfTimes() + 1; // Placeholder for actual length input
    DateTime now = DateTime.now();
    final startTime = Provider.of<TimingData>(context, listen: false).startTime[raceId];
    if (startTime == null) {
      _showErrorMessage('Start time cannot be null.');
      return;
    }
    final difference = now.difference(startTime);

    final color = AppColors.redColor;
    _updateTextColor(color, conflict: 'too_few_runner_times');

    setState(() {
      Provider.of<TimingData>(context, listen: false).records[raceId]?.add({
        'finish_time': 'TBD',
        'bib_number': null,
        'is_runner': true,
        'is_confirmed': false,
        'conflict': 'too_few_runner_times',
        'text_color': color,
        'place': numTimes,
      });
      
      Provider.of<TimingData>(context, listen: false).addController(TextEditingController(), raceId);

      Provider.of<TimingData>(context, listen: false).records[raceId]?.add({
        'finish_time': formatDuration(difference),
        'is_runner': false,
        'type': 'too_few_runner_times',
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

  void _deleteConfirmedRecords() {
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    for (int i = records.length - 1; i >= 0; i--) {
      if (records[i]['is_runner'] == false && records[i]['type'] == 'confirm_runner_number') {
        setState(() {
          records.removeAt(i);
        });
      }
    }
  }

  void _deleteConfirmedRecordsBeforeIndexUntilConflict(int recordIndex) {
    print(recordIndex);
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    if (recordIndex < 0 || recordIndex >= records.length) {
      return;
    }
    final trimmedRecords = records.sublist(0, recordIndex + 1);
    print(trimmedRecords.length);
    for (int i = trimmedRecords.length - 1; i >= 0; i--) {
      print(i);
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
    final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    final controllers = Provider.of<TimingData>(context, listen: false).controllers[raceId] ?? [];

    return Scaffold(
      // appBar: AppBar(title: const Text('Race Timing')),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Race Timer Display
            if (startTime != null)
              Row(
                children: [
                  // Race time display
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(milliseconds: 10)),
                    builder: (context, snapshot) {
                      final currentTime = DateTime.now();
                      final startTime = Provider.of<TimingData>(context, listen: false).startTime[raceId];
                      if (startTime == null) {
                        _showErrorMessage('Start time cannot be null.');
                        return Container();
                      }
                      final elapsed = currentTime.difference(startTime);
                      return Container(
                        padding: const EdgeInsets.only(bottom: 10),
                        margin: EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.1), // 1/10 from left
                        width: MediaQuery.of(context).size.width * 0.75, // 3/4 of screen width
                        child: Text(
                          formatDurationWithZeros(elapsed),
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.1,
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0), // Padding around the button
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                      double fontSize = constraints.maxWidth * 0.11; // Scalable font size
                        return ElevatedButton(
                          onPressed: startTime == null ? _startRace : _stopRace,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(0, constraints.maxWidth * 0.15), // Button height scales
                            maximumSize: Size(double.infinity, constraints.maxWidth * 0.35),
                            backgroundColor: startTime == null ? Colors.green : Colors.red,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05, vertical: MediaQuery.of(context).size.width * 0.02),
                            child: Text(
                              startTime == null ? 'Start Race' : 'Stop Race',
                              style: TextStyle(fontSize: fontSize, color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (startTime == null && records.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0), // Padding around the button
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                        double fontSize = constraints.maxWidth * 0.11;
                          return ElevatedButton(
                            onPressed: _scanQRCode,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(0, constraints.maxWidth * 0.5),
                            ),
                            child: Text(
                              'Load Bib #s',
                              style: TextStyle(fontSize: fontSize),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (startTime == null && records.isNotEmpty && records[0]['bib_number'] != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0), // Padding around the button
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                        double fontSize = constraints.maxWidth * 0.12;
                          return ElevatedButton(
                            onPressed: _saveResults,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(0, constraints.maxWidth * 0.5),
                            ),
                            child: Text(
                              'Save Results',
                              style: TextStyle(fontSize: fontSize),
                            ),
                          );
                        },
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
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.02,
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
                        late TextEditingController controller;
                        if (records.isNotEmpty && record['is_runner'] == true) {
                          final runnerIndex = getRunnerIndex(index);
                          controller = controllers[runnerIndex];
                        }
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
                                  onLongPress: () async {
                                    if (index == records.length - 1) {
                                      final confirmed = await _confirmDeleteLastRecord(index);
                                      if (confirmed ) {
                                        setState(() {
                                          Provider.of<TimingData>(context, listen: false).controllers[raceId]?.removeAt(_getNumberOfTimes() - 1);
                                          Provider.of<TimingData>(context, listen: false).records[raceId]?.removeAt(index);
                                          _scrollController.animateTo(
                                            max(_scrollController.position.maxScrollExtent - 100, 0),
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
                                      Text(
                                        [
                                          if (record['name'] != null) record['name'],
                                          if (record['grade'] != null) ' ${record['grade']}',
                                          if (record['school'] != null) ' ${record['school']}    ',
                                          if (record['finish_time'] != null) '${record['finish_time']}'
                                        ].join(),
                                        style: TextStyle(
                                          fontSize: MediaQuery.of(context).size.width * 0.05,
                                          fontWeight: FontWeight.bold,
                                          color: record['conflict'] == null ? record['text_color'] : AppColors.redColor,
                                        ),
                                      ),
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
                                  onLongPress: () {
                                    if (index == records.length - 1) {
                                      setState(() {
                                        records.removeAt(index);
                                        _updateTextColor(null);
                                      });
                                    }
                                  },
                                  child: Text(
                                    record['type'] == 'confirm_runner_number'
                                      ? 'Confirmed: ${record['finish_time']}'
                                      : record['type'] == 'too_few_runner_times'
                                          ? '${record['numTimes']} - Ajusted finish count'
                                          : 'Ajust finish count to ${record['numTimes']}',
                                    // record['type'] == 'confirm_runner_number'
                                    //   ? 'Confirmed ${record['numTimes']} times'
                                    //   : '${record['numTimes']} - Ajusted number of times',
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
                  ],
                ),
              ),
            if (startTime != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0).copyWith(bottom: 8.0), // Padding around the button
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double fontSize = constraints.maxWidth * 0.12;
                    return ElevatedButton(
                      onPressed: _handleLogButtonPress,
                      style: ElevatedButton.styleFrom(
                        fixedSize: Size(constraints.maxWidth * 0.8, constraints.maxWidth * 0.35),
                        // minimumSize: Size(0, constraints.maxWidth * 0.5),
                        // maximumSize: Size(double.infinity, 150),

                      ),
                      child: Text(
                        'Log Time',
                        style: TextStyle(fontSize: fontSize),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
