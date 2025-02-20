import 'package:flutter/material.dart';
import '../utils/time_formatter.dart';
// import 'dart:math';
import '../database_helper.dart';
import 'races_screen.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
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
  // late final ScrollController _scrollController;
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
  }

  void _initializeState() {
    // _scrollController = ScrollController();
    _raceId = widget.raceId;
    _timingData = widget.timingData;
    _runnerRecords = widget.runnerRecords;
    print('_runnerRecords: $_runnerRecords');
    _createChunks();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _updateRunnerInfo();
  }

  Future<void> _saveResults() async {
    if (_getFirstConflict()[0] != null) {
      DialogUtils.showErrorDialog(context, message: 'All runners must be resolved before proceeding.');
      return;
    }

    final records = _timingData['records'] ?? [];
    if (!_validateRunnerInfo(_runnerRecords)) {
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
    final processedRecords = await Future.wait(records
      .where((record) => record['type'] == 'runner_time')
      .map((record) async {
        final recordIndex = record['place'] - 1;
        print(recordIndex);
        final raceRunner = await DatabaseHelper.instance.getRaceRunnerByBib(_raceId, _runnerRecords[recordIndex]['bib_number']);
        print(_runnerRecords[recordIndex]);
        print('race runner: $raceRunner');
        return {
          'race_id': _raceId,
          // 'bib_number': record['bib_number'],
          // 'name': record['name'],
          // 'grade': record['grade'],
          // 'school': record['school'],
          'place': record['place'],
          'race_runner_id': raceRunner?['race_runner_id'],
          'finish_time': record['finish_time'],
        };
      })
      .toList());

    await DatabaseHelper.instance.insertRaceResults(processedRecords);
  }

  void _showResultsSavedSnackBar() {
    _navigateToResultsScreen();
    DialogUtils.showSuccessDialog(context, message: 'Results saved successfully.');
  }

  void _navigateToResultsScreen() {
    DialogUtils.showErrorDialog(context, message: 'Results saved successfully. Results screen not yet implemented.');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RacesScreen(),
      ),
    );
  }

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

  Future<void> _createChunks() async {
    _selectedTimes = {};
    final records = _timingData['records'] ?? [];
    final chunks = <Map<String, dynamic>>[];
    var startIndex = 0;
    var place = 1;
    for (int i = 0; i < records.length; i += 1) {
      if (i >= records.length - 1 || records[i]['type'] != 'runner_time') {
        chunks.add({
          'records': records.sublist(startIndex, i + 1),
          'type': records[i]['type'],
          'runners': _runnerRecords.sublist(place - 1, (records[i]['numTimes'] ?? records[i]['place'])),
          'conflictIndex': i,
        });
        print('records[i][\'numTimes\']: ${records[i]['numTimes']}');
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
        // print('Resolved: ${chunks[i]['resolve']}');
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

  bool _validateTimes(List<String> times, BuildContext context, List<dynamic> runners, dynamic lastConfirmed, Map<String, dynamic> conflictRecord) {
    Duration? lastConfirmedTime = lastConfirmed?.isEmpty ? Duration.zero : loadDurationFromString(lastConfirmed['finish_time']);
    lastConfirmedTime ??= Duration.zero;

    // print('\n\ntimes: $times');
    // print('runners: $runners');
    // print('lastConfirmed time: $lastConfirmedTime');

    for (var i = 0; i < times.length; i++) {
      final time = loadDurationFromString(times[i]);
      final runner = i > runners.length - 1 ? runners.last : runners[i];
      print('time: $time');

      if (time == null) {
        DialogUtils.showErrorDialog(context, message: 'Enter a valid time for ${runner['name']}');
        return false;
      }
      
      if (time <= lastConfirmedTime) {
        DialogUtils.showErrorDialog(context, message: 'Time for ${runner['name']} must be after ${lastConfirmed['finish_time']}');
        return false;
      }

      if (time >= (loadDurationFromString(conflictRecord['finish_time']) ?? Duration.zero)) {
        DialogUtils.showErrorDialog(context, message: 'Time for ${runner['name']} must be before ${conflictRecord['finish_time']}');
        return false;
      }
      
    }

    if (!_isAscendingOrder(times.map((time) => loadDurationFromString(time)!).toList())) {
      DialogUtils.showErrorDialog(context, message: 'Times must be in ascending order');
      return false;
    }

    return true;
  }

  bool _isAscendingOrder(List<Duration> times) {
  for (var i = 0; i < times.length - 1; i++) {
    if (times[i] >= times[i + 1]) return false;
  }
  return true;
}

  // bool _checkIfAllRunnersResolved() {
  //   final records = _timingData['records']?.cast<Map<String, dynamic>>() ?? [];
  //   return records.every((runner) => 
  //     runner['bib_number'] != null && runner['is_confirmed'] == true
  //   );
  // }

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
    // final nextConfirmedRecord = records.sublist(conflictIndex + 1)
    //     .firstWhere((record) => record['is_confirmed'] == true, orElse: () => {}.cast<String, dynamic>());

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
      // 'nextConfirmedRecord': nextConfirmedRecord,
      'availableTimes': conflictingTimes,
      'allowManualEntry': true,
      'conflictRecord': conflictRecord,
      'selectedTimes': [],
      'lastConfirmedRecord': records[lastConfirmedIndex],
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
    print('_resolveTooManyRunnerTimes called');
    var records = (_timingData['records'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final bibData = _runnerRecords.map((runner) => runner['bib_number'].toString()).toList();
    final conflictRecord = records[conflictIndex];
    
    final lastConfirmedIndex = records.sublist(0, conflictIndex)
        .lastIndexWhere((record) => record['type'] != 'runner_time');
    // if (conflictIndex == -1) return {};
    
    // final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    final lastConfirmedPlace = lastConfirmedIndex == -1 ? 0 : records[lastConfirmedIndex]['numTimes'];
    // final nextConfirmedRecord = records.sublist(conflictIndex + 1)
    //     .firstWhere((record) => record['type'] == 'runner_time', orElse: () => {}.cast<String, dynamic>());

    final List<Map<String, dynamic>> conflictingRecords = records
        .sublist(lastConfirmedIndex + 1, conflictIndex)
        .cast<Map<String, dynamic>>();
    print('Conflicting records: $conflictingRecords');

    final firstConflictingRecordIndex = records.indexOf(conflictingRecords.first);
    if (firstConflictingRecordIndex == -1) return {};

    // final spaceBetweenConfirmedAndConflict = lastConfirmedIndex == -1 ? 1 : firstConflictingRecordIndex - lastConfirmedIndex;
    // print('Space between confirmed and conflict: $spaceBetweenConfirmedAndConflict');

    final List<String> conflictingTimes = conflictingRecords
        .where((record) => record['finish_time'] != null && record['finish_time'] is String)
        .map((record) => record['finish_time'] as String)
        .where((time) => time != '' && time != 'TBD')
        .toList();

    final List<Map<String, dynamic>> conflictingRunners = List<Map<String, dynamic>>.from(
      _runnerRecords.sublist(
        lastConfirmedPlace,
        conflictRecord['numTimes']
      )
    );
    print('Conflicting runners: $conflictingRunners');

    return {
      'conflictingRunners': conflictingRunners,
      'conflictingTimes': conflictingTimes,
      // 'spaceBetweenConfirmedAndConflict': spaceBetweenConfirmedAndConflict,
      'lastConfirmedPlace': lastConfirmedPlace,
      // 'nextConfirmedRecord': nextConfirmedRecord,
      'lastConfirmedRecord': records[lastConfirmedIndex],
      'lastConfirmedIndex': lastConfirmedIndex,
      'conflictRecord': conflictRecord,
      'availableTimes': conflictingTimes,
      'bibData': bibData,
    };
  }

  Future<void> _handleTooFewTimesResolution(
    Map<String, dynamic> chunk,
  ) async {
    final resolveData = chunk['resolve'] ?? {};
    final bibData = resolveData['bibData'];
    final runners = chunk['runners'];
    final List<String> times = chunk['controllers']['timeControllers'].map((controller) => controller.text.toString()).toList().cast<String>();

    // final lastConfirmedRecord = resolveData['lastConfirmedRecord'];
    
    final conflictRecord = resolveData['conflictRecord'];

    if (!_validateTimes(times, context, runners, resolveData['lastConfirmedRecord'], conflictRecord)) {
      return;
    }
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
        record['place'] = currentPlace;
        record['is_confirmed'] = true;
        record['conflict'] = null;
        record['name'] = runners[i]['name'];
        record['grade'] = runners[i]['grade'];
        record['school'] = runners[i]['school'];
        record['race_runner_id'] = runners[i]['race_runner_id'] ?? runners[i]['runner_id'];
        record['race_id'] = _raceId;
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
    Map<String, dynamic> chunk,
  ) async {
    final List<String> times = chunk['controllers']['timeControllers'].map((controller) => controller.text.toString()).toList().cast<String>();
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
    // final spaceBetweenConfirmedAndConflict = resolveData['spaceBetweenConfirmedAndConflict'] ?? -1;
    var runners = resolveData['conflictingRunners'] ?? [];

    if (!_validateTimes(times, context, runners, resolveData['lastConfirmedRecord'], conflictRecord)) {
      return;
    }

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

    print('records: $records');
    print('runners before: $runners');

    setState(() {
      _timingData['records'] = ((_timingData['records'] as List<dynamic>?) ?? [])
          .where((record) => !unusedTimes.contains((record as Map<String, dynamic>)['finish_time']))
          .toList();
      final List<Map<String, dynamic>> typedRunners = List<Map<String, dynamic>>.from(runners);
      runners = typedRunners.where((Map<String, dynamic> runner) => !unusedTimes.contains(runner['finish_time'])).toList();
    });
    records = _timingData['records'] ?? [];

    // final lastConfirmedRunnerPlace = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'] as int;
    print('runners: $runners');
    for (int i = 0; i < runners.length; i++) {
      final num currentPlace = i + lastConfirmedPlace + 1;
      var record = records[lastConfirmedIndex + 1 + i];
      final String bibNumber = runners[i]['bib_number'] as String;

      print('currentPlace: $currentPlace');

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

  // void _deleteConfirmedRecordsBeforeIndexUntilConflict(int recordIndex) {
  //   print(recordIndex);
  //   final records = _timingData['records'] ?? [];
  //   if (recordIndex < 0 || recordIndex >= records.length) {
  //     return;
  //   }
  //   final trimmedRecords = records.sublist(0, recordIndex + 1);
  //   for (int i = trimmedRecords.length - 1; i >= 0; i--) {
  //     if (trimmedRecords[i]['type'] != 'runner_time' && trimmedRecords[i]['type'] != 'confirm_runner_number') {
  //       break;
  //     }
  //     if (trimmedRecords[i]['type'] != 'runner_time' && trimmedRecords[i]['type'] == 'confirm_runner_number') {
  //       setState(() {
  //         records.removeAt(i);
  //       });
  //     }
  //   }
  // }

  int getRunnerIndex(int recordIndex) {
    final records = _timingData['records'] ?? [];
    final runnerRecords = records.where((record) => record['type'] == 'runner_time').toList();
    return runnerRecords.indexOf(records[recordIndex]);
  }

  // Future<bool> _confirmDeleteLastRecord(int recordIndex) async {
  //   final records = _timingData['records'] ?? [];
  //   final record = records[recordIndex];
  //   if (record['type'] == 'runner_time' && record['is_confirmed'] == false && record['conflict'] == null) {
  //     return await DialogUtils.showConfirmationDialog(context, title: 'Confirm Deletion', content: 'Are you sure you want to delete this runner?');
  //   }
  //   return false;
  // }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeRecords = _timingData['records'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Review Race Results', 
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500
          )
        ),
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
      ),
      body: Container(
        color: AppColors.backgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_getFirstConflict()[0] == null)
              _buildSaveButton(),
            Expanded(
              child: _buildInstructionsAndList(timeRecords),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _saveResults,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          fixedSize: const Size.fromHeight(50),
        ),
        child: const Text(
          'Save Race Results',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildInstructionsAndList(List<dynamic> timeRecords) {
    if (timeRecords.isEmpty) {
      return const Center(child: Text('No race results to review'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInstructionsCard(),
        const SizedBox(height: 16),
        _buildResultsList(timeRecords),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Theme(
        data: Theme.of(context).copyWith(
          hoverColor: Colors.grey[200],
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: const Text(
            'Review Race Results',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: const Icon(Icons.arrow_drop_down),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Check each runner\'s information is correct\n'
                    '2. Verify or adjust finish times as needed\n'
                    '3. Resolve any conflicts shown in orange\n'
                    '4. Save when all results are confirmed',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(List<dynamic> timeRecords) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _chunks.length,
      itemBuilder: (context, index) => _buildChunkItem(context, index, _chunks[index]),
    );
  }

  Widget _buildRunnerTimeRecord(BuildContext context, int index, List<dynamic> joinedRecord, Color color, Map<String, dynamic> chunk) {
    final runner = joinedRecord[0];
    final timeRecord = joinedRecord[1];
    final hasConflict = chunk['resolve'] != null;
    final confirmedColor = AppColors.confirmRunnerColor;
    final conflictColor = AppColors.primaryColor.withOpacity(0.9);
    print('runner place: ${runner['place']}');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: confirmedColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildPlaceNumber(timeRecord['place']),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildRunnerInfo(runner),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              color: hasConflict ? Colors.orange.shade200 : Colors.green.shade200,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: hasConflict ? conflictColor : confirmedColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: hasConflict
                  ? _buildTimeSelector(
                      chunk['controllers']['timeControllers'][index],
                      chunk['controllers']['manualControllers'][index],
                      chunk['resolve']['availableTimes'],
                      chunk['conflictIndex'],
                      manual: chunk['type'] != 'extra_runner_time',
                    )
                  : _buildConfirmedTime(timeRecord['finish_time']),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceNumber(int place) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '#$place',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRunnerInfo(Map<String, dynamic> runner) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          runner['name'] ?? '',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (runner['grade'] != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Grade ${runner["grade"]}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (runner['school'] != null)
              // Expanded(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    runner['school'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmedTime(String time) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.timer,
            size: 18,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
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
    int conflictIndex,
    {bool manual = true}
  ) {
    final availableOptions = times.where((time) => 
      time == timeController.text || !_selectedTimes[conflictIndex].contains(time)
    ).toList();

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: availableOptions.contains(timeController.text) ? timeController.text : null,
        hint: Text(
          timeController.text.isEmpty ? 'Select Time' : timeController.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        items: [
          if (manual) 
            DropdownMenuItem<String>(
              value: 'manual_entry',
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.25,
                child: TextField(
                  controller: manualController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    hintText: 'Enter time',
                    hintStyle: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        timeController.text = value;
                        if (_selectedTimes[conflictIndex].contains(timeController.text)) {
                          _selectedTimes[conflictIndex].remove(timeController.text);
                        }
                      });
                    }
                  },
                ),
              ),
            ),
          ...availableOptions.map((time) => DropdownMenuItem<String>(
            value: time,
            child: Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          )),
        ],
        onChanged: (value) {
          if (value == null) return;
          if (value == 'manual_entry') return;
          
          final previousValue = timeController.text;
          setState(() {
            timeController.text = value;
            _selectedTimes[conflictIndex].add(value);
            if (previousValue != value && previousValue.isNotEmpty) {
              _selectedTimes[conflictIndex].remove(previousValue);
            }
            if (manualController != null) {
              manualController.clear();
            }
          });
        },
        dropdownColor: AppColors.primaryColor,
        icon: const Icon(
          Icons.arrow_drop_down,
          color: Colors.white,
          size: 28,
        ),
        isExpanded: true,
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
            padding: const EdgeInsets.symmetric(vertical: 16.0),
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

  Widget _buildConfirmationRecord(BuildContext context, int index, Map<String, dynamic> timeRecord) {
    // final isLastRecord = index == _timingData['records'].length - 1;
    
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
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Confirmed',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          Text(
            timeRecord['finish_time'] ?? '',
            style: const TextStyle(
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

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
