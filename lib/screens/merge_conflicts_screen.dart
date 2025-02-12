import 'package:flutter/material.dart';
// import '../utils/time_formatter.dart';
import 'dart:math';
import '../database_helper.dart';
import 'races_screen.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
// import 'resolve_conflict.dart';
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
  Map<int, dynamic> _selectedTimes = {};

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
          final int index = _timingData['records']?.indexOf(record);
          _timingData['records'][index] = {
            ...record,
            ...runner,
          }.cast<String, dynamic>();
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
    _selectedTimes = {};
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
      _selectedTimes[chunks[i]['conflictIndex']] = [];
      final runners = chunks[i]['runners'] ?? [];
      final records = chunks[i]['records'] ?? [];
      print('chunk ${i + 1}: ${chunks[i]}');
      print('-----------------------------');
      print('runners length: ${runners.length}');
      print('records length: ${records.length}');
      chunks[i]['joined_records'] = List.generate(
        runners.length,
        (j) => [runners[j], records[j]],
      );
      chunks[i]['controllers'] = {'timeControllers': List.generate(runners.length, (j) => TextEditingController()), 'manualControllers': List.generate(runners.length, (j) => TextEditingController())};
      if (chunks[i]['type'] == 'extra_runner_time') {
        chunks[i]['resolve'] = await _resolveTooManyRunnerTimes(chunks[i]['conflictIndex']);
        print('Resolved: ${chunks[i]['resolve']}');
      }
      else if (chunks[i]['type'] == 'missing_runner_time') {
        chunks[i]['resolve'] = await _resolveTooFewRunnerTimes(chunks[i]['conflictIndex']);
        // print('Resolved: ${chunks[i]['resolve']}');
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
    var records = (_timingData['records'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final bibData = _runnerRecords.map((runner) => runner['bib_number'].toString()).toList();
    final conflictRecord = records[conflictIndex];
    
    // final lastConfirmedIndex = records.sublist(0, conflictIndex)
    //     .lastIndexWhere((record) => record['is_confirmed'] == true);
    // if (conflictIndex == -1) return {};
    
    // final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    final lastConfirmedIndex = records.sublist(0, conflictIndex)
        .lastIndexWhere((record) => record['type'] != 'runner_time');
    // if (conflictIndex == -1) return {};
    
    // final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    final lastConfirmedPlace = lastConfirmedIndex == -1 ? 0 : records[lastConfirmedIndex]['numTimes'];
    // print('Last confirmed record: $lastConfirmedPlace');
    final nextConfirmedRecord = records.sublist(conflictIndex + 1)
        .firstWhere((record) => record['is_confirmed'] == true, orElse: () => {}.cast<String, dynamic>());

    final firstConflictingRecordIndex = records.sublist(lastConfirmedIndex + 1, conflictIndex).indexWhere((record) => record['conflict'] != null) + lastConfirmedIndex + 1;
    if (firstConflictingRecordIndex == -1) return {};

    final startingIndex = lastConfirmedPlace as int;
    // print('Starting index: $startingIndex');

    final spaceBetweenConfirmedAndConflict = lastConfirmedIndex == -1 ? 1 : firstConflictingRecordIndex - lastConfirmedIndex;
    // print('firstConflictingRecordIndex: $firstConflictingRecordIndex');
    print('lastConfirmedIndex here: $lastConfirmedIndex');
    // print('');
    // print('');
    // print('Space between confirmed and conflict: $spaceBetweenConfirmedAndConflict');

    final List<Map<String, dynamic>> conflictingRecords = records
        .sublist(lastConfirmedIndex + spaceBetweenConfirmedAndConflict, conflictIndex)
        .cast<Map<String, dynamic>>();

    // print('Conflicting records: $conflictingRecords');

    final List<String> conflictingTimes = conflictingRecords
        .where((record) => record['finish_time'] != null && record['finish_time'] is String)
        .map((record) => record['finish_time'] as String)
        .where((time) => time != '' && time != 'TBD')
        .toList();
    // print('startingIndex: $startingIndex, spaceBetweenConfirmedAndConflict: $spaceBetweenConfirmedAndConflict');
    // print('_runnerRecords: $_runnerRecords');
    final List<Map<String, dynamic>> conflictingRunners = List<Map<String, dynamic>>.from(
      _runnerRecords.sublist(startingIndex, startingIndex + spaceBetweenConfirmedAndConflict)
    );

    return {
      'conflictingRunners': conflictingRunners,
      'lastConfirmedPlace': lastConfirmedPlace,
      'nextConfirmedRecord': nextConfirmedRecord,
      'availableTimes': conflictingTimes,
      'allowManualEntry': true,
      'conflictRecord': conflictRecord,
      'selectedTimes': [],
      // 'lastConfirmedIndex': lastConfirmedIndex,
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
    var records = (_timingData['records'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final bibData = _runnerRecords.map((runner) => runner['bib_number'].toString()).toList();
    final conflictRecord = records[conflictIndex];
    
    final lastConfirmedIndex = records.sublist(0, conflictIndex)
        .lastIndexWhere((record) => record['type'] != 'runner_time');
    // if (conflictIndex == -1) return {};
    
    // final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    final lastConfirmedPlace = lastConfirmedIndex == -1 ? 0 : records[lastConfirmedIndex]['numTimes'];
    final nextConfirmedRecord = records.sublist(conflictIndex + 1)
        .firstWhere((record) => record['is_confirmed'] == true, orElse: () => {}.cast<String, dynamic>());

    final List<Map<String, dynamic>> conflictingRecords = records
        .sublist(lastConfirmedIndex + 1, conflictIndex)
        .cast<Map<String, dynamic>>();
    print('Conflicting records: $conflictingRecords');

    final firstConflictingRecordIndex = records.indexOf(conflictingRecords.first);
    if (firstConflictingRecordIndex == -1) return {};

    final spaceBetweenConfirmedAndConflict = lastConfirmedIndex == -1 ? 1 : firstConflictingRecordIndex - lastConfirmedIndex;
    print('Space between confirmed and conflict: $spaceBetweenConfirmedAndConflict');

    final List<String> conflictingTimes = conflictingRecords
        .where((record) => record['finish_time'] != null && record['finish_time'] is String)
        .map((record) => record['finish_time'] as String)
        .where((time) => time != '' && time != 'TBD')
        .toList();

    final List<Map<String, dynamic>> conflictingRunners = List<Map<String, dynamic>>.from(
      _runnerRecords.sublist(
        lastConfirmedPlace,
        lastConfirmedPlace + spaceBetweenConfirmedAndConflict
      )
    );

    return {
      'conflictingRunners': conflictingRunners,
      'conflictingTimes': conflictingTimes,
      'spaceBetweenConfirmedAndConflict': spaceBetweenConfirmedAndConflict,
      'lastConfirmedPlace': lastConfirmedPlace,
      'nextConfirmedRecord': nextConfirmedRecord,
      // 'lastConfirmedRecord': lastConfirmedRecord,
      'lastConfirmedIndex': lastConfirmedIndex,
      'conflictRecord': conflictRecord,
      'availableTimes': conflictingTimes,
      'bibData': bibData,
    };
  }

  Future<void> _handleTooFewTimesResolution(
    // List<Duration> times,
    // List<dynamic> runners,
    // dynamic lastConfirmedRecord,
    // Map<String, dynamic> conflictRecord,
    // int lastConfirmedIndex,
    // List<dynamic> bibData,
    Map<String, dynamic> chunk,
  ) async {
    final resolveData = chunk['resolve'] ?? {};
    final bibData = resolveData['bibData'];
    final runners = chunk['runners'];
    final times = chunk['controllers']['timeControllers'].map((controller) => controller.text).toList();
    // final lastConfirmedRecord = resolveData['lastConfirmedRecord'];
    
    final conflictRecord = resolveData['conflictRecord'];
    final records = _timingData['records'] ?? [];
    final lastConfirmedRunnerPlace = resolveData['lastConfirmedPlace'] ?? 0;
    for (int i = 0; i < runners.length; i++) {
      final int currentPlace = (i + lastConfirmedRunnerPlace + 1).toInt();
      print('Current place: $currentPlace');
      var record = records.firstWhere((element) => element['place'] == currentPlace, orElse: () => {}.cast<String, dynamic>());
      final bibNumber = bibData[record['place'].toInt() - 1];   

      setState(() {
        record['finish_time'] = times[i];
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
      print('');
      print('updated conflict record: $conflictRecord');
      print('updated records: ${_timingData['records']}');
      print('');
    });
    _showSuccessMessage();
    await _createChunks();
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
    // final bibData = resolveData['bibData'] ?? [];
    final availableTimes = resolveData['availableTimes'] ?? [];
    // final lastConfirmedRecord = resolveData['lastConfirmedRecord'] ?? {};
    final conflictRecord = resolveData['conflictRecord'] ?? {};
    final lastConfirmedIndex = resolveData['lastConfirmedIndex'] ?? -1;
    final lastConfirmedPlace = resolveData['lastConfirmedPlace'] ?? -1;
    print('lastConfirmedPlace: $lastConfirmedPlace');
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

    // final lastConfirmedRunnerPlace = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'] as int;
    
    for (int i = 0; i < runners.length; i++) {
      final num currentPlace = i + lastConfirmedPlace + 1;
      var record = records[lastConfirmedIndex + spaceBetweenConfirmedAndConflict + i];
      final String bibNumber = runners[i]['bib_number'] as String;

      setState(() {
        record['finish_time'] = times[i];
        record['bib_number'] = bibNumber;
        record['type'] = 'runner_time';
        record['place'] = currentPlace as int;
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
        lastConfirmedPlace + runners.length,
      );
    });
    // Navigator.pop(context);
    _showSuccessMessage();
    await _createChunks();
  }


  void _updateConflictRecord(Map<String, dynamic> record, int numTimes) {
    // record['numTimes'] = numTimes;
    record['type'] = 'confirm_runner_number';
    record['text_color'] = Colors.green;
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
      appBar: AppBar(
        title: Text('Resolve Conflicts', 
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500
          )
        ),
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          // gradient: LinearGradient(
          //   begin: Alignment.topCenter,
          //   end: Alignment.bottomCenter,
          //   colors: [
          //     AppColors.primaryColor.withOpacity(0.1),
          //     Colors.white,
          //   ],
          // ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _buildRecordsList(timeRecords),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildRecordsList(List<dynamic> timeRecords) {
    if (timeRecords.isEmpty) return const Expanded(child: Center(child: Text('No records to display')));

    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
      ),
    );
  }

  Widget _buildRunnerTimeRecord(BuildContext context, int index, List<dynamic> joinedRecord, Color color, Map<String, dynamic> chunk) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.9),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: _buildRunnerInfoColumn(context, joinedRecord, index),
                    ),
                  ),
                  Container(
                    width: 2,
                    color: AppColors.mediumColor,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: chunk['resolve'] == null ? Colors.green.withOpacity(0.9) : AppColors.primaryColor.withOpacity(0.9),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: _buildTimeColumn(context, joinedRecord[1], index, chunk),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunnerInfoColumn(BuildContext context, List<dynamic> joinedRecord, int index) {
    final runner = joinedRecord[0];
    final timeRecord = joinedRecord[1];

    final textStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Colors.white,
      letterSpacing: 0.3,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '#${timeRecord['place']}',
                style: textStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (runner['is_team_runner'] == true)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.group,
                  color: Colors.white.withOpacity(0.8),
                  size: 16,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          runner['name'] ?? '',
          style: textStyle,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (runner['grade'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Grade ${runner['grade']}',
                  style: textStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            if (runner['grade'] != null && runner['school'] != null)
              const SizedBox(width: 8),
            if (runner['school'] != null)
              Expanded(
                child: Text(
                  runner['school'],
                  style: textStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeColumn(BuildContext context, Map<String, dynamic> timeRecord, int index, Map<String, dynamic> chunk) {
    final textStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: Colors.white,
      letterSpacing: 0.5,
    );

    return Center(
      child: chunk['resolve'] == null
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer,
                  color: Colors.white.withOpacity(0.8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  timeRecord['finish_time'],
                  style: textStyle,
                ),
              ],
            )
          : _buildTimeSelector(
              chunk['controllers']['timeControllers'][index],
              chunk['controllers']['manualControllers'][index],
              chunk['resolve']['availableTimes'],
              chunk['conflictIndex'],
              manual: chunk['type'] != 'extra_runner_time',
            ),
    );
  }

  // Widget _buildRunnerTimeRecordOld(BuildContext context, int index, List<dynamic> joinedRecord, Color color) {
  //   return Container(
  //     margin: EdgeInsets.fromLTRB(
  //       MediaQuery.of(context).size.width * 0.02,
  //       0,
  //       MediaQuery.of(context).size.width * 0.01,
  //       MediaQuery.of(context).size.width * 0.02,
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         GestureDetector(
  //           behavior: HitTestBehavior.opaque,
  //           onLongPress: () async {
  //             final confirmed = await _confirmDeleteLastRecord(index);
  //             if (confirmed ) {
  //               setState(() {
  //                 _timingData['records']?.removeAt(index);
  //                 _scrollController.animateTo(
  //                   max(_scrollController.position.maxScrollExtent, 0),
  //                   duration: const Duration(milliseconds: 300),
  //                   curve: Curves.easeOut,
  //                 );
  //               });
  //             }
  //           },
  //           child: _buildRunnerInfoRow(context, joinedRecord, index),
  //         ),
  //         _buildDivider(),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildRunnerInfoRow(
  //   BuildContext context, 
  //   List<dynamic> joinedRecord, 
  //   int index
  // ) {
  //   final runner = joinedRecord[0];
  //   final timeRecord = joinedRecord[1];

  //   final textStyle = TextStyle(
  //     fontSize: MediaQuery.of(context).size.width * 0.05,
  //     fontWeight: FontWeight.bold,
  //     color: timeRecord['text_color'] ?? AppColors.navBarTextColor,
  //   );

  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //     children: [
  //       // Place number
  //       Text(
  //         '${timeRecord['place']}',
  //         style: textStyle.copyWith(
  //           color: timeRecord['text_color'] != null 
  //             ? AppColors.navBarTextColor 
  //             : null,
  //         ),
  //       ),

  //       // Runner information
  //       Text(
  //         _formatRunnerInfo(runner),
  //         style: textStyle,
  //       ),

  //       // Finish time input
  //       if (timeRecord['finish_time'] != null)
  //         _buildFinishTimeField(timeRecord, index, textStyle),
  //     ],
  //   );
  // }

  String _formatRunnerInfo(Map<String, dynamic> runner) {
    return [
      if (runner['name'] != null) runner['name'],
      if (runner['grade'] != null) ' ${runner['grade']}',
      if (runner['school'] != null) ' ${runner['school']}    ',
    ].join();
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

  // Widget _buildFinishTimeField(
  //   Map<String, dynamic> timeRecord, 
  //   int index,
  //   TextStyle textStyle
  // ) {
  //   return SizedBox(
  //     width: 100,
  //     child: Text(
  //       '${timeRecord['finish_time']}',
  //       style: textStyle,
  //     ),
  //   );
  // }

  Widget _buildConfirmationRecord(BuildContext context, int index, Map<String, dynamic> timeRecord) {
    final isLastRecord = index == _timingData['records'].length - 1;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Confirmed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          Text(
            timeRecord['finish_time'] ?? '',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.green,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: AppColors.unselectedRoleTextColor.withOpacity(0.2),
    );
  }

  Widget _buildTimeSelector(
    TextEditingController timeController,
    TextEditingController? manualController,
    List<String> times,
    int conflictIndex,
    {bool manual = true}
  ) {
    final availableOptions = times.where((time) => 
      time == timeController.text || _selectedTimes[conflictIndex]?.contains(time) == false
    ).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: Colors.white,
            selectionColor: Colors.white.withOpacity(0.3),
          ),
          inputDecorationTheme: InputDecorationTheme(
            hintStyle: TextStyle(color: Colors.white),
          ),
        ),
        child: DropdownButtonFormField<String>(
          value: timeController.text.isNotEmpty ? timeController.text : null,
          hint: Text(
            'Select Time',
            style: TextStyle(color: Colors.white),
          ),
          items: [
            ...availableOptions.map((time) => DropdownMenuItem<String>(
              value: time,
              child: Text(time, style: TextStyle(color: Colors.white)),
            )),
            if (manualController != null && manual)
              DropdownMenuItem<String>(
                value: manualController.text.isNotEmpty ? manualController.text : 'manual',
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.25,
                  child: TextField(
                    controller: manualController,
                    style: TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: 'Enter time',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            final previousValue = timeController.text;
            _handleTimeSelection(timeController, manualController, value);
            if (value != null && value != 'manual') {
              setState(() {
                _selectedTimes[conflictIndex].add(value);
                if (previousValue != value && previousValue.isNotEmpty) {
                  _selectedTimes.remove(previousValue);
                }
              });
            }
          },
          dropdownColor: AppColors.primaryColor,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            enabledBorder: InputBorder.none,
            border: InputBorder.none,
          ),
          icon: Icon(Icons.arrow_drop_down, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildChunkItem(BuildContext context, int index, Map<String, dynamic> chunk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...chunk['joined_records'].map<Widget>((joinedRecord) {
          if (joinedRecord[1]['type'] == 'runner_time') {
            return _buildRunnerTimeRecord(
              context,
              chunk['joined_records'].indexOf(joinedRecord),
              joinedRecord,
              chunk['type'] == 'runner_time' || chunk['type'] == 'confirm_runner_number'
                  ? Colors.green
                  : AppColors.primaryColor,
              chunk,
            );
          } else if (joinedRecord[1]['type'] == 'confirm_runner_number') {
            return _buildConfirmationRecord(
              context,
              chunk['joined_records'].indexOf(joinedRecord),
              joinedRecord[1],
            );
          }
          return SizedBox.shrink();
        }).toList(),
        if (chunk['type'] == 'extra_runner_time' || chunk['type'] == 'missing_runner_time')
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildActionButton(
              'Resolve Conflict',
              () => chunk['type'] == 'extra_runner_time'
                  ? _handleTooManyTimesResolution(chunk)
                  : _handleTooFewTimesResolution(chunk),
            ),
          ),
      ],
    );
  }
}
