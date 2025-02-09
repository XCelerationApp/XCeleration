import 'package:flutter/material.dart';
import '../utils/time_formatter.dart';
import 'dart:math';
import '../database_helper.dart';
import 'races_screen.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
import 'resolve_conflict.dart';
import '../runner_time_functions.dart';
// import '../utils/timing_utils.dart';

class MergeConflictsScreen extends StatefulWidget {
  final int raceId;
  final Map<String, dynamic> timingData;
  final List<Map<String, dynamic>> runnerRecords;

  const MergeConflictsScreen({
    super.key, 
    required this.raceId,
    required this.timingData,
    required this.runnerRecords,
  });

  @override
  State<MergeConflictsScreen> createState() => _MergeConflictsScreenState();
}

class _MergeConflictsScreenState extends State<MergeConflictsScreen> {
  // State variables
  late final ScrollController _scrollController;
  // late final Map<int, TextEditingController> _finishTimeControllers;
  // late final List<TextEditingController> _controllers;
  late final int _raceId;
  late final Map<String, dynamic> _timingData;
  // late List<Map<String, dynamic>> _runners;
  late List<Map<String, dynamic>> _runnerRecords;
  List<dynamic> _chunks = [];
  List<String> _selectedTimes = [];

  @override
  void initState() {
    super.initState();
    _initializeState();
    _createChunks();
  }

  void _initializeState() {
    _scrollController = ScrollController();
    _raceId = widget.raceId;
    _timingData = widget.timingData;
    _runnerRecords = widget.runnerRecords;
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _updateRunnerInfo();
    // await _syncBibData(
    //   _timingData['bibs']?.cast<String>() ?? [], 
    //   _timingData['records']?.cast<Map<String, dynamic>>() ?? []
    // );
  }

  // Database Operations
  // Future<void> _fetchRunners() async {
  //   final fetchedRunners = await DatabaseHelper.instance
  //       .getRaceRunnersByBibs(_raceId, _timingData['bibs']?.cast<String>() ?? []);
  //   if (mounted) {
  //     setState(() => _runners = fetchedRunners.cast<Map<String, dynamic>>());
  //   }
  // }

  Future<void> _saveResults() async {
    if (!_checkIfAllRunnersResolved()) {
      DialogUtils.showErrorDialog(context, message: 'All runners must be resolved before proceeding.');
      return;
    }

    final records = _timingData['records'] ?? [];
    if (!_validateRunnerInfo(records)) {
      DialogUtils.showErrorDialog(context, message: 'All runners must have a bib number assigned before proceeding.');
      return;
    }

    await _processAndSaveRecords(records);
    _showResultsSavedSnackBar();
  }

  bool _validateRunnerInfo(List<dynamic> records) {
    return records.every((runner) => 
      runner['bib_number'] != null && 
      runner['name'] != null && 
      runner['grade'] != null && 
      runner['school'] != null
    );
  }

  Future<void> _processAndSaveRecords(List<dynamic> records) async {
    final processedRecords = records.where((record) => record['type'] == 'runner_time').map((record) {
      final cleanRecord = Map<String, dynamic>.from(record);
      ['bib_number', 'name', 'grade', 'school', 'text_color', 'is_confirmed', 
       'type', 'conflict'].forEach(cleanRecord.remove);
      return cleanRecord;
    }).toList();

    await DatabaseHelper.instance.insertRaceResults(processedRecords);
  }

  void _showResultsSavedSnackBar() {
    _navigateToResultsScreen();
    DialogUtils.showSuccessDialog(context, message: 'Results saved successfully. View results?');

    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: const Text('Results saved successfully. View results?'),
    //     action: SnackBarAction(
    //       label: 'View Results',
    //       onPressed: () => _navigateToRaceScreen(),
    //     ),
    //   ),
    // );
  }

  void _navigateToResultsScreen() {
    DialogUtils.showErrorDialog(context, message: 'Results saved successfully. Results screen not yet implemented.');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RacesScreen(),
      ),
    );
    // ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  // // Timing Operations
  // Future<void> _syncBibData(List<String> bibData, List<Map<String, dynamic>> records) async {
  //   final numberOfRunnerTimes = _getNumberOfTimes();
  //   if (numberOfRunnerTimes != bibData.length) {
  //     await _handleTimingDiscrepancy(bibData, records, numberOfRunnerTimes);
  //   } else {
  //     await _confirmRunnerNumber(useStopTime: true);
  //   }

  //   await _updateRunnerInfo(bibData, records);
    
  //   if (mounted) {
  //     setState(() => _dataSynced = true);
  //     if (!_checkIfAllRunnersResolved()) {
  //       await _openResolveDialog();
  //     }
  //   }
  // }

  // Future<void> _handleTimingDiscrepancy(List<String> bibData, List<Map<String, dynamic>> records, int numberOfRunnerTimes) async {
  //   final difference = bibData.length - numberOfRunnerTimes;
  //   if (difference > 0) {
  //     _missingRunnerTime(offBy: difference, useStopTime: true);
  //   } else {
  //     final numConfirmedRunners = records.where((r) => 
  //       r['type'] == 'runner_time' && r['is_confirmed'] == true
  //     ).length;
      
  //     if (numConfirmedRunners > bibData.length) {
  //       DialogUtils.showErrorDialog(context, 
  //         message: 'Cannot load bib numbers: more confirmed runners than loaded bib numbers.');
  //       return;
  //     }
  //     _extraRunnerTime(offBy: -difference, useStopTime: true);
  //   }
  // }

  Future<void> _updateRunnerInfo() async {
    for (int i = 0; i < _runnerRecords.length; i++) {
      final record = _timingData['records']?.cast<Map<String, dynamic>>()?.firstWhere(
        (r) => r['type'] == 'runner_time' && r['place'] == i + 1 && r['is_confirmed'] == true,
        orElse: () => {}.cast<String, dynamic>(),
      );
      if (record.isEmpty) continue;
      final runner = _runnerRecords[i];
      if (runner.isNotEmpty && mounted) {
        setState(() {
          final index = _timingData['records']?.indexOf(record);
          _timingData['records'][index] = {
            ...record,
            ...runner,
          };
        });
      }
    }
  }

  // // Timing Utilities
  // int _getNumberOfTimes() {
  //   final records = _timingData['records'] ?? [];
  //   return max(0, records.fold<int>(0, (int count, Map<String, dynamic> record) {
  //     if (record['type'] == 'runner_time') return count + 1;
  //     if (record['type'] == 'extra_runner_time') return count - 1;
  //     return count;
  //   }));
  // }

  Future<void> _createChunks() async {
    final records = _timingData['records'] ?? [];
    final chunks = <Map<String, dynamic>>[];
    var startIndex = 0;
    var place = 1;
    for (int i = 0; i < records.length; i += 1) {
      if (i + 1 > records.length || records[i]['type'] != 'runner_time') {
        chunks.add({
          'records': records.sublist(startIndex, i + 1),
          'type': records[i]['type'],
          'runners': _runnerRecords.sublist(place - 1, (records[i]['numTimes'] ?? records[i]['place'])),
          'conflictIndex': i,
        });
        startIndex = i + 1;
        place = records[i]['numTimes'] + 1;
      }
    }

    for (int i = 0; i < chunks.length; i += 1) {
      final runners = chunks[i]['runners'] ?? [];
      final records = chunks[i]['records'] ?? [];
      chunks[i]['joined_records'] = List.generate(
        runners.length,
        (j) => [runners[j], records[j]],
      );
      chunks[i]['controllers'] = {'timeControllers': List.generate(runners.length, (j) => TextEditingController()), 'manualControllers': List.generate(runners.length, (j) => TextEditingController())};
      if (chunks[i]['type'] == 'extra_runner_time') {
        chunks[i]['resolve'] = await _resolveTooManyRunnerTimes(chunks[i]['conflictIndex']);
        print('Resolved: ${chunks[i]['resolve']}');
      }
      else if (chunks[i]['type'] == 'too_many_runner_times') {
        chunks[i]['resolve'] = await _resolveTooFewRunnerTimes(chunks[i]['conflictIndex']);
        print('Resolved: ${chunks[i]['resolve']}');
      }
    }

 
    setState(() => _chunks = chunks);
  }

  List<dynamic> _getFirstConflict() {
    final records = _timingData['records'] ?? [];
    final conflict = records.firstWhere(
      (record) => record['type'] != 'runner_time' && 
                  record['type'] != null && 
                  record['type'] != 'confirm_runner_number',
      orElse: () => {}.cast<String, dynamic>(),
    );
    return conflict.isNotEmpty ? [conflict['type'], records.indexOf(conflict)] : [null, -1];
  }

  bool _checkIfAllRunnersResolved() {
    final records = _timingData['records']?.cast<Map<String, dynamic>>() ?? [];
    return records.every((runner) => 
      runner['bib_number'] != null && runner['is_confirmed'] == true
    );
  }

  Future<void> _openResolveDialog() async {
    print('Opening resolve dialog');
    final [firstConflict, conflictIndex] = _getFirstConflict();
    if (firstConflict == null){
      print('No conflicts left');
      _deleteConfirmedRecordsBeforeIndexUntilConflict(_timingData['records']!.length - 1);
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
        barrierDismissible: true,
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
                  if (firstConflict == 'missing_runner_time') {
                    print('Resolving too few runner times conflict at index $conflictIndex');
                    await _resolveTooFewRunnerTimes(conflictIndex);
                  }
                  else if (firstConflict == 'extra_runner_time') {
                    await _resolveTooManyRunnerTimes(conflictIndex);
                  }
                  else {
                    DialogUtils.showErrorDialog(context, message: 'Unknown conflict type: $firstConflict');
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

  Future<Map<String, dynamic>> _resolveTooFewRunnerTimes(int conflictIndex) async {
    var records = _timingData['records'] ?? [];
    final bibData = _runnerRecords.map((runner) => runner['bib_number']).toList();
    final conflictRecord = records[conflictIndex];
    
    final lastConfirmedIndex = records.sublist(0, conflictIndex)
        .lastIndexWhere((record) => record['is_confirmed'] == true);
    if (conflictIndex == -1) return {};
    
    final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    print('Last confirmed record: $lastConfirmedRecord');
    final nextConfirmedRecord = records.sublist(conflictIndex + 1)
        .firstWhere((record) => record['is_confirmed'] == true, orElse: () => {}.cast<String, dynamic>());

    final firstConflictingRecordIndex = records.sublist(0, conflictIndex).indexWhere((record) => record['is_confirmed'] == false);
    if (firstConflictingRecordIndex == -1) return {};

    final startingIndex = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'];
    print('Starting index: $startingIndex');

    List<dynamic> conflictingRunners = [];
    for (int i = startingIndex; i < conflictRecord['numTimes']; i++) {
      final runner = await DatabaseHelper.instance
          .getRaceRunnerByBib(_raceId, bibData[i]);
      if (runner != null) conflictingRunners.add(runner);
    }
    print('First conflicting record index: $firstConflictingRecordIndex');
    print('Last confirmed index: $lastConfirmedIndex');
    final spaceBetweenConfirmedAndConflict = firstConflictingRecordIndex == -1 ? 1 : firstConflictingRecordIndex - lastConfirmedIndex;
    print('Space between confirmed and conflict: $spaceBetweenConfirmedAndConflict');

    final conflictingRecords = records.sublist(lastConfirmedIndex + spaceBetweenConfirmedAndConflict, conflictIndex);

    final List<String> conflictingTimes = conflictingRecords.map((record) => record['finish_time']).cast<String>().toList();
    conflictingTimes.removeWhere((time) => time == '' || time == 'TBD');

    return {
      'conflictingRunners': conflictingRunners,
      'lastConfirmedRecord': lastConfirmedRecord,
      'nextConfirmedRecord': nextConfirmedRecord,
      'availableTimes': conflictingTimes,
      'allowManualEntry': true,
      'conflictRecord': conflictRecord,
      'selectedTimes': [],
      'conflictRecord': conflictRecord,
      'lastConfirmedIndex': lastConfirmedIndex,
      'bibData': bibData,
    };
    // await showDialog(
    //   context: context,
    //   barrierDismissible: true,
    //   builder: (context) => ConflictResolutionScreen(
    //     conflictingRunners: conflictingRunners,
    //     lastConfirmedRecord: lastConfirmedRecord,
    //     nextConfirmedRecord: nextConfirmedRecord,
    //     availableTimes: conflictingTimes,
    //     allowManualEntry: true,
    //     conflictRecord: conflictRecord,
    //     selectedTimes: [],
    //     onResolve: (formattedTimes) async => await _handleTooFewTimesResolution(
    //       formattedTimes,
    //       conflictingRunners,
    //       lastConfirmedRecord,
    //       conflictRecord,
    //       lastConfirmedIndex,
    //       bibData,
    //     ),
    //   ),
    // );
  }

  Future<Map<String, dynamic>> _resolveTooManyRunnerTimes(int conflictIndex) async {
    var records = _timingData['records'] ?? [];
    final bibData = _runnerRecords.map((runner) => runner['bib_number']).toList();
    final conflictRecord = records[conflictIndex];
    
    final lastConfirmedIndex = records.sublist(0, conflictIndex)
        .lastIndexWhere((record) => record['is_confirmed'] == true);
    if (conflictIndex == -1) return {};
    
    final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    final nextConfirmedRecord = records.sublist(conflictIndex + 1)
        .firstWhere((record) => record['is_confirmed'] == true, orElse: () => {}.cast<String, dynamic>());

    print('Last confirmed index: $lastConfirmedIndex');
    print('Conflict index: $conflictIndex');

    final conflictingRecords = getConflictingRecords(records, conflictIndex);
    print('Conflicting records: $conflictingRecords');

    final firstConflictingRecordIndex = records.indexOf(conflictingRecords.first);
    if (firstConflictingRecordIndex == -1) return {};

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
          .getRaceRunnerByBib(_raceId, bibData[i]);
      if (runner != null) conflictingRunners.add(runner);
    }

    print('Conflicting runners: $conflictingRunners');
    print('Conflicting times: $conflictingTimes');

    return {
      'conflictingRunners': conflictingRunners,
      'conflictingTimes': conflictingTimes,
      'spaceBetweenConfirmedAndConflict': spaceBetweenConfirmedAndConflict,
      'lastConfirmedIndex': lastConfirmedIndex,
      'nextConfirmedRecord': nextConfirmedRecord,
      'lastConfirmedRecord': lastConfirmedRecord,
      'conflictRecord': conflictRecord,
      'availableTimes': conflictingTimes,
      'bibData': bibData,
      'conflictingRunners': conflictingRunners,
      'conflictingTimes': conflictingTimes,
    };

    // await showDialog(
    //   context: context,
    //   barrierDismissible: true,
    //   builder: (context) => ConflictResolutionScreen(
    //     conflictingRunners: conflictingRunners,
    //     lastConfirmedRecord: lastConfirmedRecord,
    //     nextConfirmedRecord: nextConfirmedRecord,
    //     availableTimes: conflictingTimes,
    //     allowManualEntry: false,
    //     conflictRecord: conflictRecord,
    //     selectedTimes: [],
    //     onResolve: (formattedTimes) async => await _handleTooManyTimesResolution(
    //       formattedTimes,
    //       conflictingRunners,
    //       conflictingTimes,
    //       lastConfirmedRecord,
    //       conflictRecord,
    //       lastConfirmedIndex,
    //       bibData,
    //       spaceBetweenConfirmedAndConflict
    //     ),
    //   ),
    // );
  }

  Future<void> _handleTooFewTimesResolution(
    List<Duration> times,
    List<dynamic> runners,
    dynamic lastConfirmedRecord,
    Map<String, dynamic> conflictRecord,
    int lastConfirmedIndex,
    List<dynamic> bibData,
  ) async {
    final records = _timingData['records'] ?? [];
    final lastConfirmedRunnerPlace = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'];
    for (int i = 0; i < runners.length; i++) {
      final int currentPlace = (i + lastConfirmedRunnerPlace + 1).toInt();
      print('Current place: $currentPlace');
      var record = records.firstWhere((element) => element['place'] == currentPlace, orElse: () => {}.cast<String, dynamic>());
      final bibNumber = bibData[record['place'].toInt() - 1];   

      setState(() {
        record['finish_time'] = formatDuration(times[i]);
        record['bib_number'] = bibNumber;
        record['type'] = 'runner_time';
        record['is_confirmed'] = true;
        record['conflict'] = null;
        record['name'] = runners[i]['name'];
        record['grade'] = runners[i]['grade'];
        record['school'] = runners[i]['school'];
        record['race_runner_id'] = runners[i]['race_runner_id'] ?? runners[i]['runner_id'];
        record['race_id'] = _raceId;
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
    // Navigator.pop(context);
    _showSuccessMessage();
    // await _openResolveDialog();
  }

  Future<void> _handleTooManyTimesResolution(
    // List<Duration> times,
    // List<dynamic> runners,
    // List<String> availableTimes,
    // dynamic lastConfirmedRecord,
    // Map<String, dynamic> conflictRecord,
    // int lastConfirmedIndex,
    // List<dynamic> bibData,
    // int spaceBetweenConfirmedAndConflict,
    Map<String, dynamic> chunk,
  ) async {
    final times = chunk['controllers']['timeControllers'].map((controller) => controller.text).toList();
    print('times: $times');
    print('records: ${chunk['controllers']}');
    var records = chunk['records'] ?? [];
    final resolveData = chunk['resolve'] ?? [];
    final bibData = resolveData['bibData'] ?? [];
    final availableTimes = resolveData['availableTimes'] ?? [];
    final lastConfirmedRecord = resolveData['lastConfirmedRecord'] ?? {};
    final conflictRecord = resolveData['conflictRecord'] ?? {};
    final lastConfirmedIndex = resolveData['lastConfirmedIndex'] ?? -1;
    final spaceBetweenConfirmedAndConflict = resolveData['spaceBetweenConfirmedAndConflict'] ?? -1;
    var runners = resolveData['conflictingRunners'] ?? [];
    final unusedTimes = availableTimes
        .where((time) => !times.contains(time))
        .toList();

    if (unusedTimes.isEmpty) {
      DialogUtils.showErrorDialog(context, message: 'Please select a time for each runner.');
      return;
    }
    print('Unused times: $unusedTimes');
    final List<Map<String, dynamic>> typedRecords = List<Map<String, dynamic>>.from(records);
    final unusedRecords = typedRecords.where((record) => unusedTimes.contains(record['finish_time']));
    print('Unused records: $unusedRecords');

    setState(() {
      _timingData['records'] = ((_timingData['records'] as List<dynamic>?) ?? [])
          .where((record) => !unusedTimes.contains((record as Map<String, dynamic>)['finish_time']))
          .toList();
      final List<Map<String, dynamic>> typedRunners = List<Map<String, dynamic>>.from(runners);
      runners = typedRunners.where((Map<String, dynamic> runner) => !unusedTimes.contains(runner['finish_time'])).toList();
    });
    records = _timingData['records'] ?? [];

    final lastConfirmedRunnerPlace = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'] as int;
    
    for (int i = 0; i < runners.length; i++) {
      final int currentPlace = (i + lastConfirmedRunnerPlace + 1);
      var record = records[lastConfirmedIndex + spaceBetweenConfirmedAndConflict + i];
      final String bibNumber = runners[i]['bib_number'] as String;

      setState(() {
        record['finish_time'] = times[i];
        record['bib_number'] = bibNumber;
        record['type'] = 'runner_time';
        record['place'] = currentPlace;
        record['is_confirmed'] = true;
        record['conflict'] = null;
        record['name'] = runners[i]['name'];
        record['grade'] = runners[i]['grade'];
        record['school'] = runners[i]['school'];
        record['race_runner_id'] = runners[i]['race_runner_id'] ?? runners[i]['runner_id'];
        record['race_id'] = _raceId;
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
    // Navigator.pop(context);
    _showSuccessMessage();
    await _createChunks();
  }


  void _updateConflictRecord(Map<String, dynamic> record, int numTimes) {
    record['numTimes'] = numTimes;
    record['type'] = 'confirm_runner_number';
    record['text_color'] = AppColors.navBarTextColor;
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully resolved conflict')),
    );
  }

  void undoTooManyRunners(Map lastConflict, records) {
    if (lastConflict.isEmpty) {
      return;
    }
    final lastConflictIndex = records.indexOf(lastConflict);
    final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r['type'] == 'runner_time').toList();
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
    final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r['type'] == 'runner_time').toList();
    final offBy = lastConflict['offBy'];
    print('off by: $offBy');

    records = updateTextColor(null, records, confirmed: false, endIndex: lastConflictIndex);
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
  }

  void _deleteConfirmedRecordsBeforeIndexUntilConflict(int recordIndex) {
    print(recordIndex);
    final records = _timingData['records'] ?? [];
    if (recordIndex < 0 || recordIndex >= records.length) {
      return;
    }
    final trimmedRecords = records.sublist(0, recordIndex + 1);
    for (int i = trimmedRecords.length - 1; i >= 0; i--) {
      if (trimmedRecords[i]['type'] != 'runner_time' && trimmedRecords[i]['type'] != 'confirm_runner_number') {
        break;
      }
      if (trimmedRecords[i]['type'] != 'runner_time' && trimmedRecords[i]['type'] == 'confirm_runner_number') {
        setState(() {
          records.removeAt(i);
        });
      }
    }
  }

  int getRunnerIndex(int recordIndex) {
    final records = _timingData['records'] ?? [];
    final runnerRecords = records.where((record) => record['type'] == 'runner_time').toList();
    return runnerRecords.indexOf(records[recordIndex]);
  }

  Future<bool> _confirmDeleteLastRecord(int recordIndex) async {
    final records = _timingData['records'] ?? [];
    final record = records[recordIndex];
    if (record['type'] == 'runner_time' && record['is_confirmed'] == false && record['conflict'] == null) {
      return await DialogUtils.showConfirmationDialog(context, title: 'Confirm Deletion', content: 'Are you sure you want to delete this runner?');
    }
    return false;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = _timingData['startTime'];
    final timeRecords = _timingData['records'] ?? [];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // _buildTimerDisplay(startTime, endTime),
            _buildControlButtons(startTime, timeRecords),
            _buildRecordsList(timeRecords),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(DateTime? startTime, List<dynamic> timeRecords) {
    if (startTime != null || timeRecords.isEmpty) return const SizedBox.shrink();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_canShowSaveButton(timeRecords))
          _buildActionButton('Save Results', _saveResults),
        if (_canShowResolveButton(timeRecords))
          _buildActionButton('Resolve Conflicts', _openResolveDialog),
      ],
    );
  }

  bool _canShowSaveButton(List<dynamic> timeRecords) {
    return timeRecords.isNotEmpty && 
           timeRecords[0]['bib_number'] != null && 
           _getFirstConflict()[0] == null;
  }

  bool _canShowResolveButton(List<dynamic> timeRecords) {
    return timeRecords.isNotEmpty && 
           _getFirstConflict()[0] != null;
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: 330,
      height: 100,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ElevatedButton(
              onPressed: onPressed,
              child: Text(
                text,
                style: TextStyle(fontSize: constraints.maxWidth * 0.12),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecordsList(List<dynamic> timeRecords) {
    if (timeRecords.isEmpty) return const Expanded(child: SizedBox.shrink());

    return Expanded(
      child: Column(
        children: [
          _buildDivider(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _chunks.length,
              itemBuilder: (context, index) => _buildChunkItem(context, index, _chunks[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(
    TextEditingController timeController,
    TextEditingController? manualController,
    List<String> times,
  ) {
      final availableOptions = times.where((time) => time == timeController.text || !_selectedTimes.contains(time)).toList();
      final items = [
        ...availableOptions.map((time) => DropdownMenuItem<String>(
          value: time,
          child: Text(time),
        )),
        if (manualController != null)
          DropdownMenuItem<String>(
            value: manualController.text.isNotEmpty ? manualController.text : 'manual',
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              child: TextField(
                controller: manualController,
                decoration: InputDecoration(
                  hintText: 'Enter time',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ];

        return DropdownButtonFormField<String>(
          value: timeController.text.isNotEmpty ? timeController.text : null,
          items: items,
          onChanged: (value) {
            final previousValue = timeController.text;
            _handleTimeSelection(
              timeController,
              manualController,
              value,
            );
            if (value != null && value != 'manual') {
              setState(() {
                _selectedTimes.add(value);
                if (previousValue != value && previousValue.isNotEmpty) {
                  _selectedTimes.remove(previousValue);
                }
              });
              print('Selected times: $_selectedTimes');
            }
          },
          decoration: InputDecoration(hintText: 'Select Time'),
        );
  }

  void _handleTimeSelection(
    TextEditingController timeController,
    TextEditingController? manualController,
    String? value,
  ) {
    setState(() {
      if (value == 'manual' && manualController != null) {
        timeController.text = manualController.text;
      }
      else {
        timeController.text = value ?? '';
        if (manualController?.text.isNotEmpty == true && (value == null || value == '')) {
          timeController.text = manualController!.text;
        }
      }
    });

  }

  Widget _buildChunkItem(BuildContext context, int index, Map<String, dynamic> chunk) {
    // final timeRecord = chunk['records'][index];
    final Map<String, dynamic> runner = (_runnerRecords.isNotEmpty && index < _runnerRecords.length) ? _runnerRecords[index] : {};
    print('chunk: $chunk');

    switch (chunk['type']) {
      case 'runner_time':
        return Column(
          children: [
            for (var joinedRecord in chunk['joined_records']) ...[
              if (joinedRecord[1]['type'] == 'runner_time') ...[
                _buildRunnerTimeRecord(context, chunk['joined_records'].indexOf(joinedRecord), joinedRecord, Colors.green, chunk),
              ],
            ],
          ],
        );
      case 'confirm_runner_number':
        return Column(
          children: [
            for (var joinedRecord in chunk['joined_records']) ...[
              if (joinedRecord[1]['type'] == 'runner_time') ...[
                _buildRunnerTimeRecord(context, chunk['joined_records'].indexOf(joinedRecord), joinedRecord, Colors.green, chunk),
              ],
              if (joinedRecord[1]['type'] == 'confirm_runner_number') ...[
                _buildConfirmationRecord(context, chunk['joined_records'].indexOf(joinedRecord), joinedRecord[1]),
              ],
            ],
          ],
        );
      case 'extra_runner_time':
        return Column(
          children: [
            for (var joinedRecord in chunk['joined_records']) ...[
              if (joinedRecord[1]['type'] == 'runner_time') ...[
                _buildRunnerTimeRecord(context, chunk['joined_records'].indexOf(joinedRecord), joinedRecord, AppColors.primaryColor, chunk),
              ],
            ],
            _buildActionButton('Resolve', () => _handleTooManyTimesResolution(chunk)),
          ],
        );
      case 'missing_runner_time':
        return Column(
          children: [
            for (var joinedRecord in chunk['joined_records']) ...[
              if (joinedRecord[1]['type'] == 'runner_time') ...[
                _buildRunnerTimeRecord(context, chunk['joined_records'].indexOf(joinedRecord), joinedRecord, AppColors.primaryColor, chunk),
              ],
            ],
            _buildActionButton('Resolve', () => {print('resolving chunk: $chunk')}),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRunnerTimeRecord(BuildContext context, int index, List<dynamic> joinedRecord, Color color, Map<String, dynamic> chunk) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.02,
        0,
        MediaQuery.of(context).size.width * 0.01,
        0,
        // MediaQuery.of(context).size.width * 0.02,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () async {
              final confirmed = await _confirmDeleteLastRecord(index);
              if (confirmed) {
                setState(() {
                  _timingData['records']?.removeAt(index);
                  _scrollController.animateTo(
                    max(_scrollController.position.maxScrollExtent, 0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                });
              }
            },
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Runner info column (left)
                  Expanded(
                    child: Container(
                      color: Colors.green,
                      padding: const EdgeInsets.all(8.0),
                      child: _buildRunnerInfoColumn(context, joinedRecord, index),
                    ),
                  ),
                  // Vertical divider
                  Container(
                    width: 2,
                    color: AppColors.mediumColor,
                  ),
                  // Time column (right)
                  Expanded(
                    child: Container(
                      color: chunk['resolve'] == null ? Colors.green : AppColors.primaryColor,
                      padding: const EdgeInsets.all(8.0),
                      child: _buildTimeColumn(context, joinedRecord[1], index, chunk),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDivider(),
        ],
      ),
    );
  }

  Widget _buildRunnerInfoColumn(BuildContext context, List<dynamic> joinedRecord, int index) {
    final runner = joinedRecord[0];
    final timeRecord = joinedRecord[1];

    final textStyle = TextStyle(
      fontSize: MediaQuery.of(context).size.width * 0.05,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${timeRecord['place']}',
          style: textStyle,
        ),
        Text(
          _formatRunnerInfo(runner),
          style: textStyle,
        ),
      ],
    );
  }

  Widget _buildTimeColumn(BuildContext context, Map<String, dynamic> timeRecord, int index, Map<String, dynamic> chunk) {
    final textStyle = TextStyle(
      fontSize: MediaQuery.of(context).size.width * 0.05,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    return Center(
      // child: Text(
      //   '${timeRecord['finish_time']}',
      //   style: textStyle,
      // ),
      child: (chunk['resolve'] == null) ? 
      Text(
         '${timeRecord['finish_time']}',
         style: textStyle,
       ) : 
       _buildTimeSelector(chunk['controllers']['timeControllers'][index], chunk['controllers']['manualControllers'][index], chunk['resolve']['availableTimes']),
    );
  }

  Widget _buildConfirmationRecord(BuildContext context, int index, Map<String, dynamic> timeRecord) {
    final isLastRecord = index == _timingData['records'].length - 1;
    
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
            onLongPress: isLastRecord 
              ? () => _handleConfirmationDeletion(index)
              : null,
            child: Text(
              'Confirmed: ${timeRecord['finish_time']}',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.05,
                fontWeight: FontWeight.bold,
                color: timeRecord['text_color'],
              ),
            ),
          ),
          _buildDivider(),
        ],
      ),
    );
  }

  _handleConfirmationDeletion(int index) async {
    setState(() {
      _timingData['records'].removeAt(index);
      _timingData['records'] = updateTextColor(null, _timingData['records']);
    });
  }

  Widget _buildRunnerInfoRow(
    BuildContext context, 
    List<dynamic> joinedRecord, 
    int index
  ) {
    final runner = joinedRecord[0];
    final timeRecord = joinedRecord[1];

    final textStyle = TextStyle(
      fontSize: MediaQuery.of(context).size.width * 0.05,
      fontWeight: FontWeight.bold,
      color: timeRecord['text_color'] ?? AppColors.navBarTextColor,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Place number
        Text(
          '${timeRecord['place']}',
          style: textStyle.copyWith(
            color: timeRecord['text_color'] != null 
              ? AppColors.navBarTextColor 
              : null,
          ),
        ),

        // Runner information
        Text(
          _formatRunnerInfo(runner),
          style: textStyle,
        ),

        // Finish time input
        if (timeRecord['finish_time'] != null)
          _buildFinishTimeField(timeRecord, index, textStyle),
      ],
    );
  }

  String _formatRunnerInfo(Map<String, dynamic> runner) {
    return [
      if (runner['name'] != null) runner['name'],
      if (runner['grade'] != null) ' ${runner['grade']}',
      if (runner['school'] != null) ' ${runner['school']}    ',
    ].join();
  }

  Widget _buildFinishTimeField(
    Map<String, dynamic> timeRecord, 
    int index,
    TextStyle textStyle
  ) {
    return SizedBox(
      width: 100,
      child: Text(
        '${timeRecord['finish_time']}',
        style: textStyle,
      ),
    );
  }

  Widget _buildRunnerTimeRecordOld(BuildContext context, int index, List<dynamic> joinedRecord, Color color) {
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
            onLongPress: () async {
              final confirmed = await _confirmDeleteLastRecord(index);
              if (confirmed ) {
                setState(() {
                  _timingData['records']?.removeAt(index);
                  _scrollController.animateTo(
                    max(_scrollController.position.maxScrollExtent, 0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                });
              }
            },
            child: _buildRunnerInfoRow(context, joinedRecord, index),
          ),
          _buildDivider(),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      thickness: 1,
      color: AppColors.unselectedRoleTextColor,
    );
  }
}
