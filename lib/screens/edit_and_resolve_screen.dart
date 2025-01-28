import 'package:flutter/material.dart';
import 'package:race_timing_app/models/race.dart';
// import 'package:race_timing_app/models/timing_data.dart';
import 'package:race_timing_app/utils/time_formatter.dart';
import 'dart:math';
import 'package:race_timing_app/database_helper.dart';
import 'dart:async';
import 'race_screen.dart';
import '../constants.dart';
import 'resolve_conflict.dart';
// import '../database_helper.dart';
import '../runner_time_functions.dart';

class EditAndResolveScreen extends StatefulWidget {
  final Race race;
  final Map<String, dynamic> timingData;

  const EditAndResolveScreen({
    super.key, 
    required this.race,
    required this.timingData,
  });

  @override
  _EditAndResolveScreenState createState() => _EditAndResolveScreenState();
}

class _EditAndResolveScreenState extends State<EditAndResolveScreen> {
  late List<TextEditingController> _controllers;
  final ScrollController _scrollController = ScrollController();
  late int raceId;
  late Race race;
  late Map<String, dynamic> timingData;
  bool dataSynced = false;
  late List<Map<String, dynamic>> runners = [];
  Map<int, TextEditingController> _finishTimeControllers = {};

    @override
  void initState() {
    super.initState();
    race = widget.race;
    raceId = race.race_id;
    timingData = widget.timingData;
    _fetchRunners();
    for (var time_record in timingData['records']) {
      print(time_record);
      print(time_record['place']);
      print(time_record['finish_time']);
      if (time_record['is_runner'] == true && time_record['is_confirmed'] == true) {
        _finishTimeControllers[time_record['place']] = TextEditingController(text: time_record['finish_time']);
      }
    }
    // runners = await DatabaseHelper.instance.getRaceRunnersByBibs(raceId, timingData['bibs'].cast<String>() ?? []);
    // timingData['bibs'] = timingData['bibs'].cast<String>();
    // timingData['records'] = timingData['records'].cast<Map<String, dynamic>>();
    _controllers = List.generate(_getNumberOfTimes(), (index) => TextEditingController());
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    await _syncBibData(timingData['bibs'].cast<String>() ?? [], timingData['records'].cast<Map<String, dynamic>>() ?? []);

  }

  // @override
  // void initState() {
  //   super.initState();
  //   race = widget.race;
  //   raceId = race.race_id;
  //   timingData = widget.timingData;
  //   _fetchRunners();
  //   for (var time_record in timingData['records']) {
  //     print(time_record);
  //     print(time_record['place']);
  //     print(time_record['finish_time']);
  //     _finishTimeControllers[time_record['place']] = TextEditingController(text: time_record['finish_time']);
  //   }
  //   // runners = await DatabaseHelper.instance.getRaceRunnersByBibs(raceId, timingData['bibs'].cast<String>() ?? []);
  //   // timingData['bibs'] = timingData['bibs'].cast<String>();
  //   // timingData['records'] = timingData['records'].cast<Map<String, dynamic>>();
  //   _controllers = List.generate(_getNumberOfTimes(), (index) => TextEditingController());
  //   _syncBibData(timingData['bibs'].cast<String>() ?? [], timingData['records'].cast<Map<String, dynamic>>() ?? []);
  // }

  Future<void> _fetchRunners() async {
    final fetchedRunners = await DatabaseHelper.instance.getRaceRunnersByBibs(raceId, timingData['bibs'].cast<String>() ?? []);
    setState(() {
      runners = fetchedRunners.cast<Map<String, dynamic>>();
    });
  }

  void _saveResults() async {
    if (!_checkIfAllRunnersResolved()) {
      _showErrorMessage('All runners must be resolved before proceeding.');
      return;
    }
    // Check if all runners have a non-null bib number
    final records = timingData['records'] ?? [];
    bool allRunnersHaveRequiredInfo = records.every((runner) => runner['bib_number'] != null && runner['name'] != null && runner['grade'] != null && runner['school'] != null);

    if (allRunnersHaveRequiredInfo) {
      // Remove the non necessary keys from the records before saving since they are not in the database
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

  Future<void> _syncBibData(List<String> bibData, List<Map<String, dynamic>> records) async {
    final numberOfRunnerTimes = _getNumberOfTimes();
    if (numberOfRunnerTimes != bibData.length) {
      print('Number of runner times does not match bib data length');
      final difference = bibData.length - numberOfRunnerTimes;
      if (difference > 0) {
        print('Too few runners');
        _missingRunnerTime(offBy: difference, useStopTime: true);
      }
      else {
        print('Too many runners');
        final bibDataLength = bibData.length;
        final numConfirmedRunners = records.where((r) => r['is_runner'] == true && r['is_confirmed'] == true).length;
        if (numConfirmedRunners > bibDataLength) {
          _showErrorMessage('You cannot load bib numbers for runners if the there are more confirmed runners than loaded bib numbers.');
          return;
        } else{
          _extraRunnerTime(offBy: -difference, useStopTime: true);
        }
      }
    }
    else {
      print('Number of runner times matches bib data length');
      await _confirmRunnerNumber(useStopTime: true);
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

      final [runner, isTeamRunner] = await DatabaseHelper.instance.getRaceRunnerByBib(raceId, bibData[i], getTeamRunner: true);
      if (runner != null) {
        setState(() {
          records[index]['name'] = runner['name'];
          records[index]['grade'] = runner['grade'];
          records[index]['school'] = runner['school'];
          records[index]['race_runner_id'] = runner['race_runner_id'] ?? runner['runner_id'];
          records[index]['race_id'] = raceId;
          records[index]['is_team_runner'] = isTeamRunner;
          records[index]['bib_number'] = bibData[i];
        });
      }
    }

    setState(() {
      dataSynced = true;
    });

    final allRunnersResolved = _checkIfAllRunnersResolved();
    if (!allRunnersResolved) {
      await _openResolveDialog();
    }
  }

  Future<void> _openResolveDialog() async {
    print('Opening resolve dialog');
    // final records = timingData['records'] ?? [];
    final [firstConflict, conflictIndex] = _getFirstConflict();
    if (firstConflict == null){
      print('No conflicts left');
      _deleteConfirmedRecordsBeforeIndexUntilConflict(timingData['records']!.length - 1);
      return;
    } // No conflicts left
    print(firstConflict == 'missing_runner_time'
                      ? 'Not enough finish times were recorded. Please select which times correctly belong to the runners and enter in missing times.'
                      : 'More finish times were recorded than the number of runners. Please resolve the conflict by selecting which times correctly belong to the runners.');
    print(firstConflict);
    print(conflictIndex);
    if (!mounted) return; // Check if the widget is still mounted
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          print('Opening resolve dialog for conflict $firstConflict at index $conflictIndex');
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
                  firstConflict == 'missing_runner_time'
                      ? 'Not enough finish times were recorded. Please select which times correctly belong to the runners and enter in missing times.'
                      : 'More finish times were recorded than the number of runners. Please resolve the conflict by selecting which times correctly belong to the runners.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (!mounted) return; // Check if the widget is still mounted
                  // Update the record to resolve the conflict
                  // Navigator.of(context).pop();
                  if (firstConflict == 'missing_runner_time') {
                    print('Resolving too few runner times conflict at index $conflictIndex');
                    await _resolveTooFewRunnerTimes(conflictIndex);
                  }
                  else if (firstConflict == 'extra_runner_time') {
                    await _resolveTooManyRunnerTimes(conflictIndex);
                  }
                  else {
                    _showErrorMessage('Unknown conflict type: $firstConflict');
                  }
                  if (!mounted) return; // Check if the widget is still mounted
                  // // Call this method again to check for the next conflict
                  Navigator.of(context).pop();
                  _openResolveDialog();
                },
                child: Text('Resolve'),
              ),
            ],
          );
        },
      );
  }

  Future<void> _resolveTooFewRunnerTimes(int conflictIndex) async {
    var records = timingData['records'] ?? [];
    final bibData = timingData['bibs'] ?? [];
    final conflictRecord = records[conflictIndex];
    print('Conflict record: $conflictRecord!!!!!!');
    
    final lastConfirmedIndex = records.sublist(0, conflictIndex)
        .lastIndexWhere((record) => record['is_confirmed'] == true);
    if (conflictIndex == -1) return;
    
    final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    print('Last confirmed record: $lastConfirmedRecord');
    final nextConfirmedRecord = records.sublist(conflictIndex + 1)
        .firstWhere((record) => record['is_confirmed'] == true, orElse: () => {}.cast<String, dynamic>());

    final firstConflictingRecordIndex = records.sublist(0, conflictIndex).indexWhere((record) => record['is_confirmed'] == false);
    if (firstConflictingRecordIndex == -1) return;

    final startingIndex = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'];
    print('Starting index: $startingIndex');

    List<dynamic> conflictingRunners = [];
    for (int i = startingIndex; i < conflictRecord['numTimes']; i++) {
      final runner = await DatabaseHelper.instance
          .getRaceRunnerByBib(raceId, bibData[i], getTeamRunner: true);
      if (runner.isNotEmpty) conflictingRunners.add(runner[0]);
    }
    print('First conflicting record index: $firstConflictingRecordIndex');
    print('Last confirmed index: $lastConfirmedIndex');
    final spaceBetweenConfirmedAndConflict = firstConflictingRecordIndex == -1 ? 1 : firstConflictingRecordIndex - lastConfirmedIndex;
    print('Space between confirmed and conflict: $spaceBetweenConfirmedAndConflict');

    final conflictingRecords = records.sublist(lastConfirmedIndex + spaceBetweenConfirmedAndConflict, conflictIndex);

    final List<String> conflictingTimes = conflictingRecords.map((record) => record['finish_time']).cast<String>().toList();
    conflictingTimes.removeWhere((time) => time == '' || time == 'TBD');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConflictResolutionDialog(
        conflictingRunners: conflictingRunners,
        lastConfirmedRecord: lastConfirmedRecord,
        nextConfirmedRecord: nextConfirmedRecord,
        availableTimes: conflictingTimes,
        allowManualEntry: true,
        conflictRecord: conflictRecord,
        selectedTimes: [],
        onResolve: (formattedTimes) async => await _handleTooFewTimesResolution(
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
    var records = timingData['records'] ?? [];
    final bibData = timingData['bibs'] ?? [];
    final conflictRecord = records[conflictIndex];
    
    final lastConfirmedIndex = records.sublist(0, conflictIndex)
        .lastIndexWhere((record) => record['is_confirmed'] == true);
    if (conflictIndex == -1) return;
    
    final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    final nextConfirmedRecord = records.sublist(conflictIndex + 1)
        .firstWhere((record) => record['is_confirmed'] == true, orElse: () => {}.cast<String, dynamic>());

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
          .getRaceRunnerByBib(raceId, bibData[i], getTeamRunner: true);
      if (runner.isNotEmpty) conflictingRunners.add(runner[0]);
    }

    print('Conflicting runners: $conflictingRunners');
    print('Conflicting times: $conflictingTimes');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConflictResolutionDialog(
        conflictingRunners: conflictingRunners,
        lastConfirmedRecord: lastConfirmedRecord,
        nextConfirmedRecord: nextConfirmedRecord,
        availableTimes: conflictingTimes,
        allowManualEntry: false,
        conflictRecord: conflictRecord,
        selectedTimes: [],
        onResolve: (formattedTimes) async => await _handleTooManyTimesResolution(
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
  Future<void> _handleTooFewTimesResolution(
    List<Duration> times,
    List<dynamic> runners,
    dynamic lastConfirmedRecord,
    Map<String, dynamic> conflictRecord,
    int lastConfirmedIndex,
    List<dynamic> bibData,
  ) async {
    final records = timingData['records'] ?? [];
    final lastConfirmedRunnerPlace = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'];
    for (int i = 0; i < runners.length; i++) {
      final int currentPlace = (i + lastConfirmedRunnerPlace + 1).toInt();
      print('Current place: $currentPlace');
      var record = records.firstWhere((element) => element['place'] == currentPlace, orElse: () => {}.cast<String, dynamic>());
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
        record['is_team_runner'] = runners[i]['is_team_runner'];
        record['text_color'] = AppColors.navBarTextColor;
      });
    }

    setState(() {
      _updateConflictRecord(
        conflictRecord,
        lastConfirmedRunnerPlace + runners.length,
      );
    });
    // Navigator.of(context).pop();
    _showSuccessMessage();
    await _openResolveDialog();
  }

  Future<void> _handleTooManyTimesResolution(
    List<Duration> times,
    List<dynamic> runners,
    List<String> availableTimes,
    dynamic lastConfirmedRecord,
    Map<String, dynamic> conflictRecord,
    int lastConfirmedIndex,
    List<dynamic> bibData,
    int spaceBetweenConfirmedAndConflict,
  ) async {
    var records = timingData['records'] ?? [];
    final unusedTimes = availableTimes
        .where((time) => !times.contains(loadDurationFromString(time)))
        .toList();

    if (unusedTimes.isEmpty) {
      _showErrorMessage('Please select a time for each runner.');
      return;
    }
    print('Unused times: $unusedTimes');
    final unusedRecords = records.where((record) => unusedTimes.contains(record['finish_time']));
    print('Unused records: $unusedRecords');

    setState(() {
      for (var record in unusedRecords.toList().reversed.toList()) {
        if (record['place'] != null) {
          print('Place: ${record['place']}');
          final index = record['place'] != '' ? record['place'] - 1 : record['previous_place'] - 1;
          _controllers[index].dispose();
          _controllers.removeAt(index);
        }
      }
      
      timingData['records']?.removeWhere((record) => unusedTimes.contains(record['finish_time']));
      runners.removeWhere((runner) => unusedTimes.contains(runner['finish_time']));
    });
    records = timingData['records'] ?? [];

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
        record['is_team_runner'] = runners[i]['is_team_runner'];
        record['text_color'] = AppColors.navBarTextColor;
      });
    }

    setState(() {
      _updateConflictRecord(
        conflictRecord,
        (lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place']) + runners.length,
      );
    });

    // Navigator.of(context).pop();
    _showSuccessMessage();
    await _openResolveDialog();
  }


  void _updateConflictRecord(Map<String, dynamic> record, int numTimes) {
    record['numTimes'] = numTimes;
    record['type'] = 'confirm_runner_number';
    // record['conflict'] = null;
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
    final records = timingData['records'] ?? [];
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

  bool _checkIfAllRunnersResolved() {
    List<Map<String, dynamic>> records = timingData['records'].cast<Map<String, dynamic>>() ?? [];
    return records.every((runner) => runner['bib_number'] != null && runner['is_confirmed'] == true);
  }


  Future<void> _confirmRunnerNumber({bool useStopTime = false}) async {
    // final records = timingData['records'] ?? [];
    int numTimes = _getNumberOfTimes(); // Placeholder for actual length input
    
    Duration difference;
    if (useStopTime == true) {
      difference = timingData['endTime']!;
    }
    else {
      DateTime now = DateTime.now();
      final startTime = timingData['startTime'];
      if (startTime == null) {
        print('Start time cannot be null. 4');
        _showErrorMessage('Start time cannot be null.');
        return;
      }
      difference = now.difference(startTime);
    }

    final records = timingData['records'] ?? [];
    
    setState(() {
      timingData['records'] = confirmRunnerNumber(records, numTimes, formatDuration(difference));

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
  
  void _extraRunnerTime({int offBy = 1, bool useStopTime = false}) async {
    final numTimes = _getNumberOfTimes().toInt();

    final records = timingData['records'];
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
        timingData['records'].removeRange(timingData['records'].length - offBy, timingData['records'].length);
      });
      return;
    }
    else if (numTimes - offBy < recordPlace) {
      _showErrorMessage('You cannot remove a runner that is confirmed.');
      return;
    }

    setState(() {
      timingData['records'] = extraRunnerTime(offBy, records, numTimes, timingData['endTime']);

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

  void _missingRunnerTime({int offBy = 1, bool useStopTime = false}) {
    final int numTimes = _getNumberOfTimes();
    

    setState(() {
      timingData['records'] = missingRunnerTime(offBy, timingData['records'], numTimes, timingData['endTime']);

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

  // Future<void> _extraRunnerTime({int offBy = 1, bool useStopTime = false}) async {
  //   if (offBy < 1) {
  //     offBy = 1;
  //   }
  //   // final records = timingData['records'] ?? [];
  //   final numTimes = _getNumberOfTimes().toInt();
  //   int correcttedNumTimes = numTimes - offBy; // Placeholder for actual length input

  //   final records = timingData['records'] ?? [];
  //   final previousRunner = records.last;
  //   if (previousRunner['is_runner'] == false) {
  //     _showErrorMessage('You must have a unconfirmed runner time before pressing this button.');
  //     return;
  //   }

  //   final lastConfirmedRecord = records.lastWhere((r) => r['is_runner'] == true && r['is_confirmed'] == true, orElse: () => {}.cast<String, dynamic>());
  //   final recordPlace = lastConfirmedRecord.isEmpty || lastConfirmedRecord['place'] == null ? 0 : lastConfirmedRecord['place'];

  //   if ((numTimes - offBy) == recordPlace) {
  //     bool confirmed = await _showConfirmationMessage('This will delete the last $offBy finish times, are you sure you want to continue?');
  //     if (confirmed == false) {
  //       return;
  //     }
  //     setState(() {
  //       timingData['records']?.removeRange(timingData['records']!.length - offBy, timingData['records']!.length);
  //     });
  //     return;
  //   }
  //   else if (numTimes - offBy < recordPlace) {
  //     _showErrorMessage('You cannot remove a runner that is confirmed.');
  //     return;
  //   }
  //   for (int i = 1; i <= offBy; i++) {
  //     final lastOffByRunner = records[records.length - i];
  //     if (lastOffByRunner['is_runner'] == true) {
  //       lastOffByRunner['previous_place'] = lastOffByRunner['place'];
  //       lastOffByRunner['place'] = '';
  //     }
  //   }

  //   Duration difference;
  //   if (useStopTime == true) {
  //     difference = timingData['endTime']!;
  //   }
  //   else {
  //     DateTime now = DateTime.now();
  //     final startTime = timingData['startTime'];
  //     if (startTime == null) {
  //       print('Start time cannot be null. 4');
  //       _showErrorMessage('Start time cannot be null.');
  //       return;
  //     }
  //     difference = now.difference(startTime);
  //   }

  //   final color = AppColors.redColor;
  //   _updateTextColor(color, conflict: 'extra_runner_time');

  //   setState(() {
  //     timingData['records']?.add({
  //       'finish_time': formatDuration(difference),
  //       'is_runner': false,
  //       'type': 'extra_runner_time',
  //       'text_color': color,
  //       'numTimes': correcttedNumTimes,
  //       'offBy': offBy,
  //     });

  //     // Scroll to bottom after adding new record
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       _scrollController.animateTo(
  //         _scrollController.position.maxScrollExtent,
  //         duration: const Duration(milliseconds: 300),
  //         curve: Curves.easeOut,
  //       );
  //     });
  //   });
  // }

  // Future<void> _missingRunnerTime({int offBy = 1, bool useStopTime = false}) async {
  //   final int numTimes = _getNumberOfTimes();
  //   int correcttedNumTimes = numTimes + offBy;
    
  //   Duration difference;
  //   if (useStopTime == true) {
  //     difference = timingData['endTime']!;
  //   }
  //   else {
  //     DateTime now = DateTime.now();
  //     final startTime = timingData['startTime'];
  //     if (startTime == null) {
  //       print('Start time cannot be null. 6');
  //       _showErrorMessage('Start time cannot be null.');
  //       return;
  //     }
  //     difference = now.difference(startTime);
  //   }

  //   final color = AppColors.redColor;
  //   _updateTextColor(color, conflict: 'missing_runner_time');

  //   setState(() {
  //     for (int i = 1; i <= offBy; i++) {
  //       print('Adding record $i!!!!!');
  //       timingData['records']?.add({
  //         'finish_time': 'TBD',
  //         'bib_number': null,
  //         'is_runner': true,
  //         'is_confirmed': false,
  //         'conflict': 'missing_runner_time',
  //         'text_color': color,
  //         'place': numTimes + i,
  //       });
  //       _controllers.add(TextEditingController());
  //     }

  //     timingData['records']?.add({
  //       'finish_time': formatDuration(difference),
  //       'is_runner': false,
  //       'type': 'missing_runner_time',
  //       'text_color': color,
  //       'numTimes': correcttedNumTimes,
  //       'offBy': offBy,
  //     });

  //     // Scroll to bottom after adding new record
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       _scrollController.animateTo(
  //         _scrollController.position.maxScrollExtent,
  //         duration: const Duration(milliseconds: 300),
  //         curve: Curves.easeOut,
  //       );
  //     });
  //   });
  // }

  int _getNumberOfTimes() {
    final records = timingData['records'] ?? [];
    int count = 0;
    for (var record in records) {
      if (record['is_runner'] == true) {
        count++;
      } else if (record['type'] == 'extra_runner_time') {
        count--;
      } 
      // else if (record['type'] == 'missing_runner_time') {
      //   count++;
      // }
    }
    return max(0, count);
  }

  void _undoLastConflict() {
    print('undo last conflict');
    final records = timingData['records'] ?? [];

    final lastConflict = records.reversed.firstWhere((r) => r['is_runner'] == false && r['type'] != null, orElse: () => {}.cast<String, dynamic>());

    if (lastConflict.isEmpty || lastConflict['type'] == null) {
      return;
    }
    
    final conflictType = lastConflict['type'];
    if (conflictType == 'extra_runner_time') {
      print('undo too many');
      undoTooManyRunners(lastConflict, records);
    }
    else if (conflictType == 'missing_runner_time') {
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

    updateTextColor(null, records, confirmed: false, endIndex: lastConflictIndex);
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
    final controllers = _controllers;

    records = updateTextColor(null, records, confirmed: false, endIndex: lastConflictIndex);
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

  bool _timeIsValid(String newValue, int index, List<dynamic> time_records) {
    Duration? parsedTime = loadDurationFromString(newValue);
    if (parsedTime == null || parsedTime < Duration.zero) {
      _showErrorMessage('Invalid time entered. Should be in HH:mm:ss.ms format');
      return false;
    }

    if (index < 0 || index >= time_records.length) {
      return false;
    }

    if (index > 0 && loadDurationFromString(time_records[index - 1]['finish_time'])! > parsedTime) {
      _showErrorMessage('Time must be greater than the previous time');
      return false;
    }

    if (index < time_records.length - 1 && loadDurationFromString(time_records[index + 1]['finish_time'])! < parsedTime) {
      _showErrorMessage('Time must be less than the next time');
      return false;
    }

    return true;
  }

  // void _deleteConfirmedRecords() {
  //   final records = timingData['records'] ?? [];
  //   for (int i = records.length - 1; i >= 0; i--) {
  //     if (records[i]['is_runner'] == false && records[i]['type'] == 'confirm_runner_number') {
  //       setState(() {
  //         records.removeAt(i);
  //       });
  //     }
  //   }
  // }

  void _deleteConfirmedRecordsBeforeIndexUntilConflict(int recordIndex) {
    print(recordIndex);
    final records = timingData['records'] ?? [];
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
    final records = timingData['records'] ?? [];
    final runnerRecords = records.where((record) => record['is_runner'] == true).toList();
    return runnerRecords.indexOf(records[recordIndex]);
  }

  Future<bool> _confirmDeleteLastRecord(int recordIndex) async {
    final records = timingData['records'] ?? [];
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
    // Dispose all controllers
    for (var controller in _finishTimeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = timingData['startTime'];
    final endTime = timingData['endTime'];
    final time_records = timingData['records'] ?? [];
    // final controllers = _controllers ?? [];

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
                      final startTime = timingData['startTime'];
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
                  if (startTime == null && time_records.isNotEmpty && time_records[0]['bib_number'] != null && _getFirstConflict()[0] == null)
                    SizedBox(
                      width: 330,
                      height: 100,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0), // Padding around the button
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                          double fontSize = constraints.maxWidth * 0.12;
                          // print('button width: ${constraints.maxWidth *}');
                            return ElevatedButton(
                              onPressed: _saveResults,
                              style: ElevatedButton.styleFrom(
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
                  if (startTime == null && time_records.isNotEmpty && dataSynced == true && _getFirstConflict()[0] != null)
                    SizedBox(
                      width: 330,
                      height: 100,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0), // Padding around the button
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                          double fontSize = constraints.maxWidth * 0.12;
                            return ElevatedButton(
                              onPressed: _openResolveDialog,
                              style: ElevatedButton.styleFrom(
                                // minimumSize: Size(0, constraints.maxWidth * 0.5),
                              ),
                              child: Text(
                                'Resolve Conflicts',
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
                    if (time_records.isNotEmpty)
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
                        itemCount: time_records.length,
                        itemBuilder: (context, index) {
                          final runner = (runners.isNotEmpty && index < runners.length) ? runners[index] : {};
                          final time_record = time_records[index];
                          
                          final timeController = _finishTimeControllers[index];
                          if (timeController == null && time_record['is_runner'] == true) {
                            _finishTimeControllers[index] = TextEditingController(text: time_record['finish_time']);
                            timeController?.text = time_record['finish_time'];
                          }

                          // late TextEditingController controller;
                          // if (time_records.isNotEmpty && time_record['is_runner'] == true) {
                          //   final runnerIndex = getRunnerIndex(index);
                          //   controller = _controllers[runnerIndex];
                          // }
                          if (time_records.isNotEmpty && time_record['is_runner'] == true) {
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
                                      // if (index == records.length - 1) {
                                      final confirmed = await _confirmDeleteLastRecord(index);
                                      if (confirmed ) {
                                        setState(() {
                                          _controllers.removeAt(_getNumberOfTimes() - 1);
                                          timingData['records']?.removeAt(index);
                                          _scrollController.animateTo(
                                            max(_scrollController.position.maxScrollExtent, 0),
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeOut,
                                          );
                                        });
                                      }
                                      // }
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${time_record['place']}',
                                          style: TextStyle(
                                            fontSize: MediaQuery.of(context).size.width * 0.05,
                                            fontWeight: FontWeight.bold,
                                          color: time_record['text_color'] != null ? AppColors.navBarTextColor : null,
                                          ),
                                        ),
                                        Text(
                                          [
                                            if (runner['name'] != null) runner['name'],
                                            if (runner['grade'] != null) ' ${runner['grade']}',
                                            if (runner['school'] != null) ' ${runner['school']}    ',
                                          ].join(),
                                          style: TextStyle(
                                            fontSize: MediaQuery.of(context).size.width * 0.05,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.navBarTextColor,
                                          ),
                                        ),
                                        if (time_record['finish_time'] != null) 
                                          // Use a TextField for editing the finish time
                                          SizedBox(
                                            width: 100, // Set a width for the TextField
                                            child: TextField(
                                              controller: _finishTimeControllers[index],
                                              decoration: InputDecoration(
                                                hintText: 'Finish Time',
                                                border: OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: time_record['conflict'] != null ? time_record['text_color'] : Colors.transparent,
                                                  ),
                                                ),
                                                hintStyle: TextStyle(
                                                  color: time_record['text_color'],
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: Colors.blueAccent,
                                                  ),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: time_record['text_color'],
                                                  ),
                                                ),
                                                disabledBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: Colors.transparent,
                                                  ),
                                                ),
                                              ),
                                              style: TextStyle(
                                                color: time_record['text_color'],
                                              ),
                                              enabled: time_record['finish_time'] != 'tbd' && time_record['finish_time'] != 'TBD' && _getFirstConflict()[0] == null,
                                              textAlign: TextAlign.center,
                                              keyboardType: TextInputType.numberWithOptions(signed: true, decimal: false),
                                              onSubmitted: (newValue) {
                                                // Update the time_record with the new value
                                                setState(() {
                                                  if (newValue.isNotEmpty  && _timeIsValid(newValue, index, time_records)) {
                                                    time_record['finish_time'] = newValue; // Update your data structure
                                                  }
                                                  else {
                                                    _finishTimeControllers[index]?.text = time_record['finish_time'];
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Divider(
                                    thickness: 1,
                                    color: Color.fromRGBO(128, 128, 128, 0.5),
                                  ),
                                ],
                              ),
                            );
                          } else if (time_records.isNotEmpty && time_record['type'] == 'confirm_runner_number') {
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
                                      if (index == time_records.length - 1) {
                                        setState(() {
                                          time_records.removeAt(index);
                                          timingData['records'] = updateTextColor(null, time_records);
                                        });
                                      }
                                    },
                                    child: Text(
                                      'Confirmed: ${time_record['finish_time']}',
                                      style: TextStyle(
                                        fontSize: MediaQuery.of(context).size.width * 0.05,
                                        fontWeight: FontWeight.bold,
                                        color: time_record['text_color'],
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
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (startTime != null && time_records.isNotEmpty)
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
                        onPressed: _extraRunnerTime,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 40, color: AppColors.redColor),
                        onPressed: _missingRunnerTime,
                      ),
                      if (time_records.isNotEmpty && !time_records.last['is_runner'] && time_records.last['type'] != null && time_records.last['type'] != 'confirm_runner_number')
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
