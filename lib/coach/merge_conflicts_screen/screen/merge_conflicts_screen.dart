import 'package:flutter/material.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../../../utils/time_formatter.dart';
import '../../../core/theme/typography.dart';
// import 'dart:math';
// import '../../../utils/database_helper.dart';
// import '../../races_screen/screen/races_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../utils/runner_time_functions.dart';
// import '../utils/timing_utils.dart';
import '../../../utils/enums.dart';
import '../model/timing_data.dart';
import '../../../assistant/race_timer/timing_screen/model/timing_record.dart';
// import '../../race_screen/model/race_result.dart';

class MergeConflictsScreen extends StatefulWidget {
  final int raceId;
  final TimingData timingData;
  final List<RunnerRecord> runnerRecords;
  // final Function(TimingData) onComplete;

  const MergeConflictsScreen({
    super.key, 
    required this.raceId,
    required this.timingData,
    required this.runnerRecords,
    // required this.onComplete,
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
  late final TimingData _timingData;
  // late List<Map<String, dynamic>> _runners;
  late List<RunnerRecord> _runnerRecords;
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
    debugPrint('_runnerRecords: $_runnerRecords');
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

    // final records = _timingData.records;
    if (!_validateRunnerInfo(_runnerRecords)) {
      DialogUtils.showErrorDialog(context, message: 'All runners must have a bib number assigned before proceeding.');
      return;
    }

    // await _processAndSaveRecords(records);
    // Call the onComplete callback with the resolved data
    // widget.onComplete(_timingData);
    
    // Ensure we exit with the resolved data
    Navigator.of(context).pop(_timingData);
    // _showResultsSavedSnackBar();
  }

  bool _validateRunnerInfo(List<RunnerRecord> records) {
    return records.every((runner) => 
      runner.bib.isNotEmpty && 
      runner.name.isNotEmpty && 
      runner.grade > 0 && 
      runner.school.isNotEmpty
    );
  }

  // Future<void> _processAndSaveRecords(List<TimingRecord> records) async {
  //   final List<RaceResult> processedRecords = await Future.wait(records
  //     .where((record) => record.type == RecordType.runnerTime)
  //     .map((record) async {
  //       final recordIndex = record.place! - 1;
  //       final RunnerRecord? raceRunner = await DatabaseHelper.instance.getRaceRunnerByBib(_raceId, _runnerRecords[recordIndex].bib);
  //       return RaceResult(
  //         raceId: _raceId,
  //         place: record.place,
  //         runnerId: raceRunner?.runnerId,
  //         finishTime: record.elapsedTime,
  //       );
  //     })
  //     .toList());

  //   await DatabaseHelper.instance.insertRaceResults(processedRecords);
    
  //   // Update the timing data with resolved records
  //   final resolvedTimingData = _timingData;
  //   resolvedTimingData.records = records;
    
  //   // Call the onComplete callback with the resolved data
  //   widget.onComplete(resolvedTimingData);
    
  //   // Ensure we exit with the resolved data
  //   Navigator.of(context).pop(resolvedTimingData);
  // }

  // void _showResultsSavedSnackBar() {
  //   _navigateToResultsScreen();
  //   DialogUtils.showSuccessDialog(context, message: 'Results saved successfully.');
  // }

  // void _navigateToResultsScreen() {
  //   DialogUtils.showErrorDialog(context, message: 'Results saved successfully. Results screen not yet implemented.');
  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => RacesScreen(),
  //     ),
  //   );
  // }

  Future<void> _updateRunnerInfo() async {
    for (int i = 0; i < _runnerRecords.length; i++) {
      final record = _timingData.records.firstWhere(
        (r) => r.type == RecordType.runnerTime && r.place == i + 1 && r.isConfirmed == true,
        orElse: () => TimingRecord(elapsedTime: '', isConfirmed: false, conflict: null, type: RecordType.runnerTime, place: null, previousPlace: null, textColor: null),
      );
      if (record.place == null) continue;
      final runner = _runnerRecords[i];
      if (mounted) {
        setState(() {
          final int index = _timingData.records.indexOf(record);
          _timingData.records[index] = TimingRecord(
            elapsedTime: record.elapsedTime,
            runnerNumber: runner.bib,
            isConfirmed: record.isConfirmed,
            conflict: record.conflict,
            type: record.type,
            place: record.place,
            previousPlace: record.previousPlace,
            textColor: record.textColor,
          );
        });
      }
    }
  }

  Future<void> _createChunks() async {
    _selectedTimes = {};
    final records = _timingData.records;
    debugPrint('Records: ${records.map((r) => r.toMap()).join('\n\n')}');
    final chunks = <Map<String, dynamic>>[];
    var startIndex = 0;
    var place = 1;
    // for (final record in records) {
    //   print('\n\nRecord: ${record.toMap()}');
    // }

    for (int i = 0; i < records.length; i += 1) {
      if (i >= records.length - 1 || records[i].type != RecordType.runnerTime) {
        // print('startIndex: $startIndex, i: $i, place: $place, conflict: ${records[i].conflict}, numTimes: ${records[i].conflict?.data?['numTimes']}, place: ${records[i].place}');
        chunks.add({
          'records': records.sublist(startIndex, i + 1),
          'type': records[i].type,
          'runners': _runnerRecords.sublist(place - 1, (records[i].conflict?.data?['numTimes'] ?? records[i].place)),
          'conflictIndex': i,
        });
        startIndex = i + 1;
        place = records[i].conflict?.data?['numTimes'] ?? records[i].place! + 1;
      }
    }

    for (int i = 0; i < chunks.length; i += 1) {
      _selectedTimes[chunks[i]['conflictIndex']] = [];
      final runners = chunks[i]['runners'] ?? [];
      final records = chunks[i]['records'] ?? [];
      debugPrint('chunk ${i + 1}: ${chunks[i]}');
      debugPrint('-----------------------------');
      debugPrint('runners length: ${runners.length}');
      debugPrint('records length: ${records.length}');
      chunks[i]['joined_records'] = List.generate(
        runners.length,
        (j) => [runners[j], records[j]],
      );
      chunks[i]['controllers'] = {'timeControllers': List.generate(runners.length, (j) => TextEditingController()), 'manualControllers': List.generate(runners.length, (j) => TextEditingController())};
      if (chunks[i]['type'] == RecordType.extraRunner) {
        chunks[i]['resolve'] = await _resolveTooManyRunnerTimes(chunks[i]['conflictIndex']);
        // debugPrint('Resolved: ${chunks[i]['resolve']}');
      }
      else if (chunks[i]['type'] == RecordType.missingRunner) {
        chunks[i]['resolve'] = await _resolveTooFewRunnerTimes(chunks[i]['conflictIndex']);
        // debugPrint('Resolved: ${chunks[i]['resolve']}');
      }
    }

 
    setState(() => _chunks = chunks);
    debugPrint('Bib number of second runner: ${_runnerRecords[1].bib}');
  }

  List<dynamic> _getFirstConflict() {
    final records = _timingData.records;
    final conflict = records.firstWhere(
      (record) => record.type != RecordType.runnerTime && 
                  record.type != RecordType.confirmRunner,
      orElse: () => TimingRecord(elapsedTime: '', runnerNumber: null, isConfirmed: false, conflict: null, type: RecordType.runnerTime, place: null, previousPlace: null, textColor: null),
    );
    return conflict.elapsedTime != '' ? [conflict.type, records.indexOf(conflict)] : [null, -1];
  }

  bool _validateTimes(List<String> times, BuildContext context, List<RunnerRecord> runners, TimingRecord lastConfirmed, TimingRecord conflictRecord) {
    Duration? lastConfirmedTime = lastConfirmed.elapsedTime == '' ? Duration.zero : loadDurationFromString(lastConfirmed.elapsedTime);
    lastConfirmedTime ??= Duration.zero;

    // debugPrint('\n\ntimes: $times');
    // debugPrint('runners: $runners');
    // debugPrint('lastConfirmed time: $lastConfirmedTime');

    for (var i = 0; i < times.length; i++) {
      final time = loadDurationFromString(times[i]);
      final runner = i > runners.length - 1 ? runners.last : runners[i];
      debugPrint('time: $time');

      if (time == null) {
        DialogUtils.showErrorDialog(context, message: 'Enter a valid time for ${runner.bib}');
        return false;
      }
      
      if (time <= lastConfirmedTime) {
        DialogUtils.showErrorDialog(context, message: 'Time for ${runner.name} must be after ${lastConfirmed.elapsedTime}');
        return false;
      }

      if (time >= (loadDurationFromString(conflictRecord.elapsedTime) ?? Duration.zero)) {
        DialogUtils.showErrorDialog(context, message: 'Time for ${runner.name} must be before ${conflictRecord.elapsedTime}');
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
    var records = _timingData.records;
    final bibData = _runnerRecords.map((runner) => runner.bib.toString()).toList();
    final conflictRecord = records[conflictIndex];
    
    // final lastConfirmedIndex = records.sublist(0, conflictIndex)
    //     .lastIndexWhere((record) => record['is_confirmed'] == true);
    // if (conflictIndex == -1) return {};
    
    // final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    final lastConfirmedIndex = records.sublist(0, conflictIndex)
        .lastIndexWhere((record) => record.type != RecordType.runnerTime);
    // if (conflictIndex == -1) return {};
    
    // final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    final lastConfirmedPlace = lastConfirmedIndex == -1 ? 0 : records[lastConfirmedIndex].place;
    // debugPrint('Last confirmed record: $lastConfirmedPlace');
    // final nextConfirmedRecord = records.sublist(conflictIndex + 1)
    //     .firstWhere((record) => record['is_confirmed'] == true, orElse: () => {}.cast<String, dynamic>());

    final firstConflictingRecordIndex = records.sublist(lastConfirmedIndex + 1, conflictIndex).indexWhere((record) => record.conflict != null) + lastConfirmedIndex + 1;
    if (firstConflictingRecordIndex == -1) return {};

    final startingIndex = lastConfirmedPlace ?? 0;
    // debugPrint('Starting index: $startingIndex');

    final spaceBetweenConfirmedAndConflict = lastConfirmedIndex == -1 ? 1 : firstConflictingRecordIndex - lastConfirmedIndex;
    // debugPrint('firstConflictingRecordIndex: $firstConflictingRecordIndex');
    debugPrint('lastConfirmedIndex here: $lastConfirmedIndex');
    // debugPrint('');
    // debugPrint('');
    // debugPrint('Space between confirmed and conflict: $spaceBetweenConfirmedAndConflict');

    final List<TimingRecord> conflictingRecords = records
        .sublist(lastConfirmedIndex + spaceBetweenConfirmedAndConflict, conflictIndex);

    // debugPrint('Conflicting records: $conflictingRecords');

    final List<String> conflictingTimes = conflictingRecords
        .where((record) => record.elapsedTime != '')
        .map((record) => record.elapsedTime)
        .where((time) => time != '' && time != 'TBD')
        .toList();
    // debugPrint('startingIndex: $startingIndex, spaceBetweenConfirmedAndConflict: $spaceBetweenConfirmedAndConflict');
    // debugPrint('_TimingRecords: $_TimingRecords');
    final List<RunnerRecord> conflictingRunners = List<RunnerRecord>.from(
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
    debugPrint('_resolveTooManyRunnerTimes called');
    var records = (_timingData.records as List<TimingRecord>?) ?? [];
    final bibData = _runnerRecords.map((runner) => runner.bib).toList();
    final conflictRecord = records[conflictIndex];
    
    final lastConfirmedIndex = records.sublist(0, conflictIndex)
        .lastIndexWhere((record) => record.type != RecordType.runnerTime);
    // if (conflictIndex == -1) return {};
    
    // final lastConfirmedRecord = lastConfirmedIndex == -1 ? {} : records[lastConfirmedIndex];
    final lastConfirmedPlace = lastConfirmedIndex == -1 ? 0 : records[lastConfirmedIndex].place ?? 0;
    // final nextConfirmedRecord = records.sublist(conflictIndex + 1)
    //     .firstWhere((record) => record['type'] == 'runner_time', orElse: () => {}.cast<String, dynamic>());

    final List<TimingRecord> conflictingRecords = records
        .sublist(lastConfirmedIndex + 1, conflictIndex);
    debugPrint('Conflicting records: $conflictingRecords');

    final firstConflictingRecordIndex = records.indexOf(conflictingRecords.first);
    if (firstConflictingRecordIndex == -1) return {};

    // final spaceBetweenConfirmedAndConflict = lastConfirmedIndex == -1 ? 1 : firstConflictingRecordIndex - lastConfirmedIndex;
    // debugPrint('Space between confirmed and conflict: $spaceBetweenConfirmedAndConflict');

    final List<String> conflictingTimes = conflictingRecords
        .where((record) => record.elapsedTime != '')
        .map((record) => record.elapsedTime)
        .where((time) => time != '' && time != 'TBD')
        .toList();

    final List<Map<String, dynamic>> conflictingRunners = List<Map<String, dynamic>>.from(
      _runnerRecords.sublist(
        lastConfirmedPlace,
        conflictRecord.conflict?.data?['numTimes']
      )
    );
    debugPrint('Conflicting runners: $conflictingRunners');

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
    // final bibData = resolveData['bibData'];
    final runners = chunk['runners'];
    final List<String> times = chunk['controllers']['timeControllers'].map((controller) => controller.text.toString()).toList().cast<String>();

    // final lastConfirmedRecord = resolveData['lastConfirmedRecord'];
    
    final conflictRecord = resolveData['conflictRecord'];

    if (!_validateTimes(times, context, runners, resolveData['lastConfirmedRecord'], conflictRecord)) {
      return;
    }
    final records = _timingData.records;
    final lastConfirmedRunnerPlace = resolveData['lastConfirmedPlace'] ?? 0;
    for (int i = 0; i < runners.length; i++) {
      final int currentPlace = (i + lastConfirmedRunnerPlace + 1).toInt();
      debugPrint('Current place: $currentPlace');
      var record = records.firstWhere((element) => element.place == currentPlace, orElse: () => TimingRecord(elapsedTime: '', isConfirmed: false, conflict: null, type: RecordType.runnerTime, place: null, previousPlace: null, textColor: null));
      // final bibNumber = bibData[record.place! - 1];   

      setState(() {
        record.elapsedTime = times[i];
        // record.bib = bibNumber;
        record.type = RecordType.runnerTime;
        record.place = currentPlace;
        record.isConfirmed = true;
        record.conflict = null;
        // record.name = runners[i]['name'];
        // record.grade = runners[i]['grade'];
        // record.school = runners[i]['school'];
        // record.runnerId = runners[i]['runner_id'] ?? runners[i]['runner_id'];
        // record.raceId = _raceId;
        record.textColor = null;
      });
    }

    setState(() {
      _updateConflictRecord(
        conflictRecord,
        lastConfirmedRunnerPlace + runners.length,
      );
      debugPrint('');
      debugPrint('updated conflict record: $conflictRecord');
      debugPrint('updated records: ${_timingData.records}');
      debugPrint('');
    });
    _showSuccessMessage();
    await _createChunks();
  }

  Future<void> _handleTooManyTimesResolution(
    Map<String, dynamic> chunk,
  ) async {
    final List<String> times = chunk['controllers']['timeControllers'].map((controller) => controller.text.toString()).toList().cast<String>();
    debugPrint('times: $times');
    debugPrint('records: ${chunk['controllers']}');
    List<TimingRecord> records = chunk['records'] ?? [];
    final resolveData = chunk['resolve'] ?? [];
    // final bibData = resolveData['bibData'] ?? [];
    final availableTimes = resolveData['availableTimes'] ?? [];
    // final lastConfirmedRecord = resolveData['lastConfirmedRecord'] ?? {};
    final TimingRecord conflictRecord = resolveData['conflictRecord'] ?? {};
    final lastConfirmedIndex = resolveData['lastConfirmedIndex'] ?? -1;
    final lastConfirmedPlace = resolveData['lastConfirmedPlace'] ?? -1;
    debugPrint('lastConfirmedPlace: $lastConfirmedPlace');
    // final spaceBetweenConfirmedAndConflict = resolveData['spaceBetweenConfirmedAndConflict'] ?? -1;
    List<RunnerRecord> runners = resolveData['conflictingRunners'] ?? [];

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
    debugPrint('Unused times: $unusedTimes');
    // final List<Map<String, dynamic>> typedRecords = List<Map<String, dynamic>>.from(records);
    final List<TimingRecord> unusedRecords = records.where((record) => unusedTimes.contains(record.elapsedTime)).toList();
    debugPrint('Unused records: $unusedRecords');

    debugPrint('records: $records');
    debugPrint('runners before: $runners');

    setState(() {
      _timingData.records = _timingData.records
          .where((record) => !unusedTimes.contains(record.elapsedTime))
          .toList();
      // runners = runners.where((runner) => !unusedTimes.contains(runner.elapsedTime)).toList();
    });
    records = _timingData.records;

    // final lastConfirmedRunnerPlace = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'] as int;
    debugPrint('runners: $runners');
    for (int i = 0; i < runners.length; i++) {
      final num currentPlace = i + lastConfirmedPlace + 1;
      var record = records[lastConfirmedIndex + 1 + i];
      final String bibNumber = runners[i].bib;

      debugPrint('currentPlace: $currentPlace');

      setState(() {
        record.elapsedTime = times[i];
        record.bib = bibNumber;
        record.type = RecordType.runnerTime;
        record.place = currentPlace.toInt();
        record.isConfirmed = true;
        record.conflict = null;
        record.name = runners[i].name;
        record.grade = runners[i].grade;
        record.school = runners[i].school;
        record.runnerId = runners[i].runnerId;
        record.raceId = _raceId;
        record.textColor = AppColors.navBarTextColor;
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


  void _updateConflictRecord(TimingRecord record, int numTimes) {
    // record['numTimes'] = numTimes;
    record.type = RecordType.confirmRunner;
    record.place = numTimes;
    record.textColor = Colors.green;
    record.isConfirmed = true;
    record.conflict = null;
    record.previousPlace = null;
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully resolved conflict')),
    );
  }

  void undoTooManyRunners(TimingRecord lastConflict, List<TimingRecord> records) {
    if (lastConflict.conflict?.data?['offBy'] == null) {
      return;
    }
    final lastConflictIndex = records.indexOf(lastConflict);
    final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r.type == RecordType.runnerTime).toList();
    final offBy = lastConflict.conflict!.data!['offBy'] as int? ?? 0;

    updateTextColor(null, records, confirmed: false, endIndex: lastConflictIndex);
    for (int i = 0; i < offBy; i++) {
      final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
      setState(() {
        record.place = record.previousPlace;
      });
    }
    setState(() {
      records.remove(lastConflict);
    });
  }

  void undoTooFewRunners(TimingRecord lastConflict, List<TimingRecord> records) {
    if (lastConflict.conflict?.data?['offBy'] == null) {
      return;
    }
    final lastConflictIndex = records.indexOf(lastConflict);
    final runnersBeforeConflict = records.sublist(0, lastConflictIndex).where((r) => r.type == RecordType.runnerTime).toList();
    final offBy = lastConflict.conflict!.data!['offBy'] as int? ?? 0;
    debugPrint('off by: $offBy');

    records = updateTextColor(null, records, confirmed: false, endIndex: lastConflictIndex);
    for (int i = 0; i < offBy; i++) {
      final record = runnersBeforeConflict[runnersBeforeConflict.length - 1 - i];
      debugPrint('remove record: $record');
      setState(() {
        records.remove(record);
      });
    }
    setState(() {
      records.remove(lastConflict);
    });
  }

  // void _deleteConfirmedRecordsBeforeIndexUntilConflict(int recordIndex) {
  //   debugPrint(recordIndex);
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
    final records = _timingData.records;
    final List<TimingRecord> timingRecords = records.where((record) => record.type == RecordType.runnerTime).toList();
    return timingRecords.indexOf(records[recordIndex]);
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
    final timeRecords = _timingData.records;

    return Scaffold(
      // appBar: AppBar(
      //   title: Text('Review Race Results', 
      //     style: TextStyle(
      //       color: Colors.white,
      //       fontWeight: FontWeight.w500
      //     )
      //   ),
      //   backgroundColor: AppColors.primaryColor,
      //   elevation: 0,
      // ),
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
          'Finished Merging Conflicts',
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
      padding: const EdgeInsets.symmetric(vertical: 16),
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
          title: Text(
            'Review Race Results',
            style: AppTypography.titleSemibold,
          ),
          trailing: const Icon(Icons.arrow_drop_down),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Check each runner\'s information is correct\n'
                    '2. Verify or adjust finish times as needed\n'
                    '3. Resolve any conflicts shown in orange\n'
                    '4. Save when all results are confirmed',
                    style: AppTypography.bodyRegular,
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
    final RunnerRecord runner = joinedRecord[0];
    final TimingRecord timeRecord = joinedRecord[1];
    final hasConflict = chunk['resolve'] != null;
    final confirmedColor = AppColors.confirmRunnerColor;
    final conflictColor = AppColors.primaryColor.withAlpha((0.9 * 255).round());
    debugPrint('runner place: ${timeRecord.place}');

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
                    _buildPlaceNumber(timeRecord.place!),
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
                      manual: chunk['type'] != RecordType.extraRunner,
                    )
                  : _buildConfirmedTime(timeRecord.elapsedTime),
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
        color: Colors.white.withAlpha((0.2 * 255).round()),
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

  Widget _buildRunnerInfo(RunnerRecord runner) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          runner.name,
          style: AppTypography.bodySemibold,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (runner.bib.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Bib ${runner.bib}',
                  style: AppTypography.bodyRegular,
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (runner.school.isNotEmpty)
              // Expanded(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    runner.school,
                    style: AppTypography.bodyRegular,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
            style: AppTypography.bodySemibold,
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
          style: AppTypography.bodySemibold,
        ),
        items: [
          if (manual) 
            DropdownMenuItem<String>(
              value: 'manual_entry',
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.25,
                child: TextField(
                  controller: manualController,
                  style: AppTypography.bodySemibold,
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
              style: AppTypography.bodySemibold,
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
    // print(chunk);
    // print(chunk['joined_records']);
    // print(chunk['type']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...chunk['joined_records'].map<Widget>((joinedRecord) {
          // print('\n');
          // print(joinedRecord[0].toMap());
          // print(joinedRecord[1].toMap());
          // print('\n');
          if (joinedRecord[1].type == RecordType.runnerTime) {
            return _buildRunnerTimeRecord(
              context,
              chunk['joined_records'].indexOf(joinedRecord),
              joinedRecord,
              chunk['type'] == RecordType.runnerTime || chunk['type'] == RecordType.confirmRunner
                  ? Colors.green
                  : AppColors.primaryColor,
              chunk,
            );
          } else if (joinedRecord[1].type == RecordType.confirmRunner) {
            return _buildConfirmationRecord(
              context,
              chunk['joined_records'].indexOf(joinedRecord),
              joinedRecord[1],
            );
          }
          return SizedBox.shrink();
        }).toList(),
        if (chunk['type'] == RecordType.extraRunner || chunk['type'] == RecordType.missingRunner)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: _buildActionButton(
              'Resolve Conflict',
              () => chunk['type'] == RecordType.extraRunner
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
        color: Colors.green.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.green.withAlpha((0.3 * 255).round()),
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
                style: AppTypography.bodyRegular,
              ),
            ],
          ),
          Text(
            timeRecord['finish_time'] ?? '',
            style: AppTypography.bodySemibold,
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
            color: Colors.black.withAlpha((0.1 * 255).round()),
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
          style: AppTypography.bodySemibold.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
