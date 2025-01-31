import 'package:flutter/material.dart';
import 'package:race_timing_app/models/race.dart';
import 'package:race_timing_app/utils/time_formatter.dart';
import 'dart:math';
import 'package:race_timing_app/database_helper.dart';
import 'race_screen.dart';
import '../constants.dart';
import 'resolve_conflict.dart';
import '../runner_time_functions.dart';
import '../utils/timing_utils.dart';
import '../utils/dialog_utils.dart';

class EditAndResolveScreen extends StatefulWidget {
  final Race race;
  final Map<String, dynamic> timingData;

  const EditAndResolveScreen({
    super.key, 
    required this.race,
    required this.timingData,
  });

  @override
  State<EditAndResolveScreen> createState() => _EditAndResolveScreenState();
}

class _EditAndResolveScreenState extends State<EditAndResolveScreen> {
  // State variables
  late final ScrollController _scrollController;
  late final Map<int, TextEditingController> _finishTimeControllers;
  late final List<TextEditingController> _controllers;
  late final int _raceId;
  late final Race _race;
  late final Map<String, dynamic> _timingData;
  late List<Map<String, dynamic>> _runners;
  bool _dataSynced = false;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    _scrollController = ScrollController();
    _race = widget.race;
    _raceId = _race.race_id;
    _timingData = widget.timingData;
    _runners = [];
    _finishTimeControllers = _initializeFinishTimeControllers();
    _controllers = List.generate(_getNumberOfTimes(), (index) => TextEditingController());
    _fetchRunners();
  }

  Map<int, TextEditingController> _initializeFinishTimeControllers() {
    final controllers = <int, TextEditingController>{};
    for (var record in _timingData['records']) {
      if (record['type'] == 'runner_time' && record['is_confirmed'] == true) {
        controllers[record['place']] = TextEditingController(text: record['finish_time']);
      }
    }
    return controllers;
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    await _syncBibData(
      _timingData['bibs']?.cast<String>() ?? [], 
      _timingData['records']?.cast<Map<String, dynamic>>() ?? []
    );
  }

  // Database Operations
  Future<void> _fetchRunners() async {
    final fetchedRunners = await DatabaseHelper.instance
        .getRaceRunnersByBibs(_raceId, _timingData['bibs']?.cast<String>() ?? []);
    if (mounted) {
      setState(() => _runners = fetchedRunners.cast<Map<String, dynamic>>());
    }
  }

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Results saved successfully. View results?'),
        action: SnackBarAction(
          label: 'View Results',
          onPressed: () => _navigateToRaceScreen(),
        ),
      ),
    );
  }

  void _navigateToRaceScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RaceScreen(race: _race, initialTabIndex: 1),
      ),
    );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  // Timing Operations
  Future<void> _syncBibData(List<String> bibData, List<Map<String, dynamic>> records) async {
    final numberOfRunnerTimes = _getNumberOfTimes();
    if (numberOfRunnerTimes != bibData.length) {
      await _handleTimingDiscrepancy(bibData, records, numberOfRunnerTimes);
    } else {
      await _confirmRunnerNumber(useStopTime: true);
    }

    await _updateRunnerInfo(bibData, records);
    
    if (mounted) {
      setState(() => _dataSynced = true);
      if (!_checkIfAllRunnersResolved()) {
        await _openResolveDialog();
      }
    }
  }

  Future<void> _handleTimingDiscrepancy(List<String> bibData, List<Map<String, dynamic>> records, int numberOfRunnerTimes) async {
    final difference = bibData.length - numberOfRunnerTimes;
    if (difference > 0) {
      _missingRunnerTime(offBy: difference, useStopTime: true);
    } else {
      final numConfirmedRunners = records.where((r) => 
        r['type'] == 'runner_time' && r['is_confirmed'] == true
      ).length;
      
      if (numConfirmedRunners > bibData.length) {
        DialogUtils.showErrorDialog(context, 
          message: 'Cannot load bib numbers: more confirmed runners than loaded bib numbers.');
        return;
      }
      _extraRunnerTime(offBy: -difference, useStopTime: true);
    }
  }

  Future<void> _updateRunnerInfo(List<String> bibData, List<Map<String, dynamic>> records) async {
    for (int i = 0; i < bibData.length; i++) {
      final record = records.firstWhere(
        (r) => r['type'] == 'runner_time' && r['place'] == i + 1 && r['is_confirmed'] == true,
        orElse: () => {}.cast<String, dynamic>(),
      );
      if (record.isEmpty) continue;

      final [runner, isTeamRunner] = await DatabaseHelper.instance
          .getRaceRunnerByBib(_raceId, bibData[i], getTeamRunner: true);
      
      if (runner != null && mounted) {
        setState(() {
          final index = records.indexOf(record);
          records[index] = {
            ...record,
            ...runner,
            'race_runner_id': runner['race_runner_id'] ?? runner['runner_id'],
            'race_id': _raceId,
            'is_team_runner': isTeamRunner,
            'bib_number': bibData[i],
          };
        });
      }
    }
  }

  // Timing Utilities
  int _getNumberOfTimes() {
    final records = _timingData['records'] ?? [];
    return max(0, records.fold<int>(0, (int count, Map<String, dynamic> record) {
      if (record['type'] == 'runner_time') return count + 1;
      if (record['type'] == 'extra_runner_time') return count - 1;
      return count;
    }));
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

  Future<void> _resolveTooFewRunnerTimes(int conflictIndex) async {
    var records = _timingData['records'] ?? [];
    final bibData = _timingData['bibs'] ?? [];
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
          .getRaceRunnerByBib(_raceId, bibData[i], getTeamRunner: true);
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
    var records = _timingData['records'] ?? [];
    final bibData = _timingData['bibs'] ?? [];
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
          .getRaceRunnerByBib(_raceId, bibData[i], getTeamRunner: true);
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
    List<Duration> times,
    List<dynamic> runners,
    List<String> availableTimes,
    dynamic lastConfirmedRecord,
    Map<String, dynamic> conflictRecord,
    int lastConfirmedIndex,
    List<dynamic> bibData,
    int spaceBetweenConfirmedAndConflict,
  ) async {
    var records = _timingData['records'] ?? [];
    final unusedTimes = availableTimes
        .where((time) => !times.contains(loadDurationFromString(time)))
        .toList();

    if (unusedTimes.isEmpty) {
      DialogUtils.showErrorDialog(context, message: 'Please select a time for each runner.');
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
      
      _timingData['records']?.removeWhere((record) => unusedTimes.contains(record['finish_time']));
      runners.removeWhere((runner) => unusedTimes.contains(runner['finish_time']));
    });
    records = _timingData['records'] ?? [];

    final lastConfirmedRunnerPlace = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'];
    final lastConfirmedIndex = lastConfirmedRecord.isEmpty ? -1 : records.indexOf(lastConfirmedRecord); 
    for (int i = 0; i < runners.length; i++) {
      final int currentPlace = (i + lastConfirmedRunnerPlace + 1).toInt();
      var record = records[lastConfirmedIndex + spaceBetweenConfirmedAndConflict + i];
      final bibNumber = bibData[currentPlace - 1];    

      setState(() {
        record['finish_time'] = formatDuration(times[i]);
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
    // await _openResolveDialog();
  }


  void _updateConflictRecord(Map<String, dynamic> record, int numTimes) {
    record['numTimes'] = numTimes;
    record['type'] = 'confirm_runner_number';
    record['text_color'] = AppColors.navBarTextColor;
  }

  List<dynamic> _getConflictingRecords(
    List<dynamic> records,
    int conflictIndex,
  ) {
    final firstConflictIndex = records.sublist(0, conflictIndex).indexWhere(
        (record) => record['type'] == 'runner_time' && record['is_confirmed'] == false,
      );
    
    return firstConflictIndex == -1 ? [] : 
      records.sublist(firstConflictIndex, conflictIndex);
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully resolved conflict')),
    );
  }

  Future<void> _confirmRunnerNumber({bool useStopTime = false}) async {
    int numTimes = _getNumberOfTimes(); // Placeholder for actual length input
    
    Duration difference = getCurrentDuration(_timingData['startTime'], _timingData['endTime']);

    final records = _timingData['records'] ?? [];
    
    setState(() {
      _timingData['records'] = confirmRunnerNumber(records, numTimes, formatDuration(difference));

      scrollToBottom(_scrollController);
    });
  }
  
  void _extraRunnerTime({int offBy = 1, bool useStopTime = false}) async {
    final numTimes = _getNumberOfTimes().toInt();

    final records = _timingData['records'];
    final previousRunner = records.last;
    if (previousRunner['type'] != 'runner_time') {
      DialogUtils.showErrorDialog(context, message: 'You must have a unconfirmed runner time before pressing this button.');
      return;
    }

    final lastConfirmedRecord = records.lastWhere((r) => r['type'] == 'runner_time' && r['is_confirmed'] == true, orElse: () => {});
    final recordPlace = lastConfirmedRecord.isEmpty || lastConfirmedRecord['place'] == null ? 0 : lastConfirmedRecord['place'];

    if ((numTimes - offBy) == recordPlace) {
      bool confirmed = await DialogUtils.showConfirmationDialog(context, content: 'This will delete the last $offBy finish times, are you sure you want to continue?', title: 'Confirm Deletion');
      if (confirmed == false) {
        return;
      }
      setState(() {
        _timingData['records'].removeRange(_timingData['records'].length - offBy, _timingData['records'].length);
      });
      return;
    }
    else if (numTimes - offBy < recordPlace) {
      DialogUtils.showErrorDialog(context, message: 'You cannot remove a runner that is confirmed.');
      return;
    }

    setState(() {
      _timingData['records'] = extraRunnerTime(offBy, records, numTimes, formatDuration(_timingData['endTime']));

      scrollToBottom(_scrollController);
    });
  }

  void _missingRunnerTime({int offBy = 1, bool useStopTime = false}) {
    final int numTimes = _getNumberOfTimes();
    

    setState(() {
      _timingData['records'] = missingRunnerTime(offBy, _timingData['records'], numTimes, formatDuration(_timingData['endTime']));

      scrollToBottom(_scrollController);
    });
  }

  void _undoLastConflict() {
    print('undo last conflict');
    final records = _timingData['records'] ?? [];

    final lastConflict = records.reversed.firstWhere((r) => r['type'] != 'runner_time' && r['type'] != null, orElse: () => {}.cast<String, dynamic>());

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
      DialogUtils.showErrorDialog(context, message: 'Invalid time entered. Should be in HH:mm:ss.ms format');
      return false;
    }

    if (index < 0 || index >= time_records.length) {
      return false;
    }

    if (index > 0 && loadDurationFromString(time_records[index - 1]['finish_time'])! > parsedTime) {
      DialogUtils.showErrorDialog(context, message: 'Time must be greater than the previous time');
      return false;
    }

    if (index < time_records.length - 1 && loadDurationFromString(time_records[index + 1]['finish_time'])! < parsedTime) {
      DialogUtils.showErrorDialog(context, message: 'Time must be less than the next time');
      return false;
    }

    return true;
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
    // Dispose all controllers
    for (var controller in _finishTimeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = _timingData['startTime'];
    final endTime = _timingData['endTime'];
    final timeRecords = _timingData['records'] ?? [];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTimerDisplay(startTime, endTime),
            _buildControlButtons(startTime, timeRecords),
            _buildRecordsList(timeRecords),
            if (startTime != null && timeRecords.isNotEmpty)
              _buildActionButtons(timeRecords),
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
          child: _buildTimerText(context, elapsed),
        );
      },
    );
  }

  Duration _calculateElapsedTime(DateTime? startTime, Duration? endTime) {
    if (startTime == null) {
      return endTime ?? Duration.zero;
    }
    return DateTime.now().difference(startTime);
  }

  Widget _buildTimerText(BuildContext context, Duration elapsed) {
    final fontSize = MediaQuery.of(context).size.width * 0.135;
    return Text(
      formatDurationWithZeros(elapsed),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        height: 1.0,
      ),
      textAlign: TextAlign.left,
      strutStyle: StrutStyle(
        fontSize: fontSize * 1.11,
        height: 1.0,
        forceStrutHeight: true,
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
           _dataSynced && 
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
              itemCount: timeRecords.length,
              itemBuilder: (context, index) => _buildRecordItem(context, index, timeRecords),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(BuildContext context, int index, List<dynamic> timeRecords) {
    final timeRecord = timeRecords[index];
    final Map<String, dynamic> runner = (_runners.isNotEmpty && index < _runners.length) ? _runners[index] : {};
    if (_getFirstConflict()[0] == null || _finishTimeControllers[index] == null) {
      _finishTimeControllers[index] = TextEditingController(text: timeRecord['finish_time']);
    }

    switch (timeRecord['type']) {
      case 'runner_time':
        return _buildRunnerTimeRecord(context, index, timeRecord, runner);
      case 'confirm_runner_number':
        return _buildConfirmationRecord(context, index, timeRecord);
      default:
        return const SizedBox.shrink();
    }
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
    Map<String, dynamic> timeRecord, 
    Map<String, dynamic> runner, 
    int index
  ) {
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
    final isEnabled = timeRecord['finish_time'] != 'tbd' && 
                     timeRecord['finish_time'] != 'TBD' && 
                     _getFirstConflict()[0] == null;

    return SizedBox(
      width: 100,
      child: TextField(
        controller: _finishTimeControllers[index],
        decoration: InputDecoration(
          hintText: 'Finish Time',
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: timeRecord['conflict'] != null 
                ? timeRecord['text_color'] 
                : Colors.transparent,
            ),
          ),
          hintStyle: TextStyle(
            color: timeRecord['text_color'] ?? AppColors.darkColor,
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.blueAccent,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: timeRecord['text_color'] ?? AppColors.darkColor,
            ),
          ),
          disabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.transparent,
            ),
          ),
        ),
        style: TextStyle(
          color: timeRecord['text_color'] ?? AppColors.darkColor,
        ),
        enabled: isEnabled,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true, 
          decimal: false
        ),
        onSubmitted: (newValue) => _handleTimeSubmission(newValue, index, timeRecord),
      ),
    );
  }

  void _handleTimeSubmission(String newValue, int index, Map<String, dynamic> timeRecord) {
    if (newValue.isNotEmpty && _timeIsValid(newValue, index, _timingData['records'])) {
      timeRecord['finish_time'] = newValue;
    } else {
      // Reset to previous value
      _finishTimeControllers[index]?.text = timeRecord['finish_time'];
    }
  }

  Widget _buildRunnerTimeRecord(BuildContext context, int index, Map<String, dynamic> timeRecord, Map<String, dynamic> runner) {
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
                  _controllers.removeAt(_getNumberOfTimes() - 1);
                  _timingData['records']?.removeAt(index);
                  _scrollController.animateTo(
                    max(_scrollController.position.maxScrollExtent, 0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                });
              }
            },
            child: _buildRunnerInfoRow(context, timeRecord, runner, index),
          ),
          _buildDivider(),
        ],
      ),
    );
  }

  Widget _buildActionButtons(List<dynamic> timeRecords) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIconButton(Icons.check, AppColors.navBarTextColor, _confirmRunnerNumber),
          _buildIconButton(Icons.remove, AppColors.redColor, _extraRunnerTime),
          _buildIconButton(Icons.add, AppColors.redColor, _missingRunnerTime),
          if (_shouldShowUndoButton(timeRecords))
            _buildIconButton(Icons.undo, AppColors.redColor, _undoLastConflict),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 40, color: color),
      onPressed: onPressed,
    );
  }

  bool _shouldShowUndoButton(List<dynamic> timeRecords) {
    return timeRecords.isNotEmpty && 
           timeRecords.last['type'] != 'runner_time' && 
           timeRecords.last['type'] != null && 
           timeRecords.last['type'] != 'confirm_runner_number';
  }

  Widget _buildDivider() {
    return const Divider(
      thickness: 1,
      color: Color.fromRGBO(128, 128, 128, 0.5),
    );
  }
}


//   @override
//   Widget build(BuildContext context) {
//     final startTime = _timingData['startTime'];
//     final endTime = _timingData['endTime'];
//     final time_records = _timingData['records'] ?? [];

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
//                       final startTime = _timingData['startTime'];
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
//                         width: MediaQuery.of(context).size.width * 0.9,
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
//                   if (startTime == null && time_records.isNotEmpty && time_records[0]['bib_number'] != null && _getFirstConflict()[0] == null)
//                     SizedBox(
//                       width: 330,
//                       height: 100,
//                       child: Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: LayoutBuilder(
//                           builder: (context, constraints) {
//                           double fontSize = constraints.maxWidth * 0.12;
//                             return ElevatedButton(
//                               onPressed: _saveResults,
//                               style: ElevatedButton.styleFrom(
//                               ),
//                               child: Text(
//                                 'Save Results',
//                                 style: TextStyle(fontSize: fontSize),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ),
//                   if (startTime == null && time_records.isNotEmpty && _dataSynced == true && _getFirstConflict()[0] != null)
//                     SizedBox(
//                       width: 330,
//                       height: 100,
//                       child: Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: LayoutBuilder(
//                           builder: (context, constraints) {
//                           double fontSize = constraints.maxWidth * 0.12;
//                             return ElevatedButton(
//                               onPressed: _openResolveDialog,
//                               style: ElevatedButton.styleFrom(
//                               ),
//                               child: Text(
//                                 'Resolve Conflicts',
//                                 style: TextStyle(fontSize: fontSize),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ),
//                 ],
//               ),

//               // Records Section
//               Expanded(
//                 child: Column(
//                   children: [
//                     if (time_records.isNotEmpty)
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
//                         itemCount: time_records.length,
//                         itemBuilder: (context, index) {
//                           final runner = (_runners.isNotEmpty && index < _runners.length) ? _runners[index] : {};
//                           final time_record = time_records[index];
                          
//                           final timeController = _finishTimeControllers[index];
//                           if (time_record['type'] == 'runner_time' && (timeController == null || _getFirstConflict()[0] == null)) {
//                             _finishTimeControllers[index] = TextEditingController(text: time_record['finish_time']);
//                             timeController?.text = time_record['finish_time'];
//                           }

//                           if (time_records.isNotEmpty && time_record['type'] == 'runner_time') {
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
//                                       final confirmed = await _confirmDeleteLastRecord(index);
//                                       if (confirmed ) {
//                                         setState(() {
//                                           _controllers.removeAt(_getNumberOfTimes() - 1);
//                                           _timingData['records']?.removeAt(index);
//                                           _scrollController.animateTo(
//                                             max(_scrollController.position.maxScrollExtent, 0),
//                                             duration: const Duration(milliseconds: 300),
//                                             curve: Curves.easeOut,
//                                           );
//                                         });
//                                       }
//                                     },
//                                     child: Row(
//                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                       children: [
//                                         Text(
//                                           '${time_record['place']}',
//                                           style: TextStyle(
//                                             fontSize: MediaQuery.of(context).size.width * 0.05,
//                                             fontWeight: FontWeight.bold,
//                                           color: time_record['text_color'] != null ? AppColors.navBarTextColor : null,
//                                           ),
//                                         ),
//                                         Text(
//                                           [
//                                             if (runner['name'] != null) runner['name'],
//                                             if (runner['grade'] != null) ' ${runner['grade']}',
//                                             if (runner['school'] != null) ' ${runner['school']}    ',
//                                           ].join(),
//                                           style: TextStyle(
//                                             fontSize: MediaQuery.of(context).size.width * 0.05,
//                                             fontWeight: FontWeight.bold,
//                                             color: AppColors.navBarTextColor,
//                                           ),
//                                         ),
//                                         if (time_record['finish_time'] != null) 
//                                           // Use a TextField for editing the finish time
//                                           SizedBox(
//                                             width: 100, 
//                                             child: TextField(
//                                               controller: _finishTimeControllers[index],
//                                               decoration: InputDecoration(
//                                                 hintText: 'Finish Time',
//                                                 border: OutlineInputBorder(
//                                                   borderSide: BorderSide(
//                                                     color: time_record['conflict'] != null ? time_record['text_color'] : Colors.transparent,
//                                                   ),
//                                                 ),
//                                                 hintStyle: TextStyle(
//                                                   color: time_record['text_color'] ?? AppColors.darkColor,
//                                                 ),
//                                                 focusedBorder: OutlineInputBorder(
//                                                   borderSide: BorderSide(
//                                                     color: Colors.blueAccent,
//                                                   ),
//                                                 ),
//                                                 enabledBorder: OutlineInputBorder(
//                                                   borderSide: BorderSide(
//                                                     color: time_record['text_color'] ?? AppColors.darkColor,
//                                                   ),
//                                                 ),
//                                                 disabledBorder: OutlineInputBorder(
//                                                   borderSide: BorderSide(
//                                                     color: Colors.transparent,
//                                                   ),
//                                                 ),
//                                               ),
//                                               style: TextStyle(
//                                                 color: time_record['text_color'] ?? AppColors.darkColor,
//                                               ),
//                                               enabled: time_record['finish_time'] != 'tbd' && time_record['finish_time'] != 'TBD' && _getFirstConflict()[0] == null,
//                                               textAlign: TextAlign.center,
//                                               keyboardType: TextInputType.numberWithOptions(signed: true, decimal: false),
//                                               onSubmitted: (newValue) {
//                                                 // Update the time_record with the new value
//                                                 setState(() {
//                                                   if (newValue.isNotEmpty  && _timeIsValid(newValue, index, time_records)) {
//                                                     time_record['finish_time'] = newValue; // Update your data structure
//                                                   }
//                                                   else {
//                                                     _finishTimeControllers[index]?.text = time_record['finish_time'];
//                                                   }
//                                                 });
//                                               },
//                                             ),
//                                           ),
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
//                           } else if (time_records.isNotEmpty && time_record['type'] == 'confirm_runner_number') {
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
//                                       if (index == time_records.length - 1) {
//                                         setState(() {
//                                           time_records.removeAt(index);
//                                           _timingData['records'] = updateTextColor(null, time_records);
//                                         });
//                                       }
//                                     },
//                                     child: Text(
//                                       'Confirmed: ${time_record['finish_time']}',
//                                       style: TextStyle(
//                                         fontSize: MediaQuery.of(context).size.width * 0.05,
//                                         fontWeight: FontWeight.bold,
//                                         color: time_record['text_color'],
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
//                           }
//                           else {
//                             return Container();
//                           }
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               if (startTime != null && time_records.isNotEmpty)
//                 Container(
//                   margin: EdgeInsets.symmetric(vertical: 8.0), // Adjust vertical margin as needed
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Center the buttons
//                     children: [
//                       IconButton(
//                         icon: const Icon(Icons.check, size: 40, color: AppColors.navBarTextColor),
//                         onPressed: _confirmRunnerNumber,
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.remove, size: 40, color: AppColors.redColor),
//                         onPressed: _extraRunnerTime,
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.add, size: 40, color: AppColors.redColor),
//                         onPressed: _missingRunnerTime,
//                       ),
//                       if (time_records.isNotEmpty && time_records.last['type'] != 'runner_time' && time_records.last['type'] != null && time_records.last['type'] != 'confirm_runner_number')
//                         IconButton(
//                           icon: const Icon(Icons.undo, size: 40, color: AppColors.redColor),
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
