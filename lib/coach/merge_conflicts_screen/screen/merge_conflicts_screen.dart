import 'package:flutter/material.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../../../utils/time_formatter.dart';
import '../../../core/theme/typography.dart';
// import 'dart:math';
// import '../../../utils/database_helper.dart';
// import '../../races_screen/screen/races_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/dialog_utils.dart';
// import '../../../utils/runner_time_functions.dart';
// import '../utils/timing_utils.dart';
import '../../../utils/enums.dart';
import '../model/timing_data.dart';
import '../../../assistant/race_timer/timing_screen/model/timing_record.dart';
import '../../../core/components/instruction_card.dart';
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
      
      if (time <= lastConfirmedTime || time >= (loadDurationFromString(conflictRecord.elapsedTime) ?? Duration.zero)) {
        DialogUtils.showErrorDialog(context, message: 'Time for ${runner.name} must be after ${lastConfirmed.elapsedTime} and before ${conflictRecord.elapsedTime}');
        return false;
      }

      // if (time >= (loadDurationFromString(conflictRecord.elapsedTime) ?? Duration.zero)) {
      //   DialogUtils.showErrorDialog(context, message: 'Time for ${runner.name} must be before ${conflictRecord.elapsedTime}');
      //   return false;
      // }
      
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
    final List<RunnerRecord> conflictingRunners = List<RunnerRecord>.from(
      _runnerRecords.sublist(
        startingIndex,
        startingIndex + spaceBetweenConfirmedAndConflict
      )
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

    // debugPrint('Conflicting records: $conflictingRecords');

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
    
    // Delete all records with type confirm_runner between the conflict record and the last conflict
    int conflictIndex = records.indexOf(conflictRecord);
    int lastConflictIndex = records.lastIndexWhere((record) => record.conflict != null && records.indexOf(record) < conflictIndex);
    _timingData.records.removeWhere((record) =>
        record.type == RecordType.confirmRunner &&
        records.indexOf(record) > lastConflictIndex &&
        records.indexOf(record) < conflictIndex);

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

    // Delete all records with type confirm_runner between the conflict record and the last conflict
    int conflictIndex = records.indexOf(conflictRecord);
    int lastConflictIndex = records.lastIndexWhere((record) => record.conflict != null && records.indexOf(record) < conflictIndex);
    _timingData.records.removeWhere((record) =>
        record.type == RecordType.confirmRunner &&
        records.indexOf(record) > lastConflictIndex &&
        records.indexOf(record) < conflictIndex);

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

  Widget _buildConfirmationRecord(BuildContext context, int index, List<dynamic> joinedRecord) {
    final TimingRecord timeRecord = joinedRecord[1];
    
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Confirmed',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              timeRecord.elapsedTime,
              style: TextStyle(
                color: AppColors.darkColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeRecords = _timingData.records;

    return Scaffold(
      body: Container(
        color: AppColors.backgroundColor,
        child: SafeArea(
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
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ElevatedButton(
        onPressed: _saveResults,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Finished Merging Conflicts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsAndList(List<dynamic> timeRecords) {
    if (timeRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No race results to review',
              style: AppTypography.titleSemibold.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildResultsList(timeRecords),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // const SizedBox(height: 16),
        // Container(
        //   padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        //   child: Text(
        //     'Merge Conflicts',
        //     style: AppTypography.displayLarge.copyWith(
        //       color: AppColors.darkColor,
        //       fontSize: 28,
        //     ),
        //   ),
        // ),
        _buildInstructionsCard(),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return InstructionCard(
      title: 'Review Race Results',
      instructions: [
        InstructionItem(number: '1', text: 'Find the runners with the unknown times (orange)'),
        InstructionItem(number: '2', text: 'Update times as needed'),
        InstructionItem(number: '3', text: 'Save when all results are confirmed'),
      ],
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
    
    final Color conflictColor = hasConflict ? AppColors.primaryColor : Colors.green;
    final Color bgColor = conflictColor.withOpacity(0.05);
    final Color borderColor = conflictColor.withOpacity(0.5);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0.3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: 0.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildPlaceNumber(timeRecord.place!, conflictColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildRunnerInfo(runner, conflictColor),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 0.5, color: borderColor),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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

  Widget _buildPlaceNumber(int place, Color color) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          '#$place',
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildRunnerInfo(RunnerRecord runner, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          runner.name,
          style: AppTypography.bodySemibold.copyWith(
            color: AppColors.darkColor,
            fontSize: 14,
            letterSpacing: -0.1,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (runner.bib.isNotEmpty)
              _buildInfoChip('Bib ${runner.bib}', accentColor),
            if (runner.school.isNotEmpty)
              _buildInfoChip(runner.school, AppColors.mediumColor.withOpacity(0.8)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 11,
          letterSpacing: -0.1,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildConfirmedTime(String time) {
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: TextStyle(
              color: AppColors.darkColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.2,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: availableOptions.contains(timeController.text) ? timeController.text : null,
          hint: Text(
            timeController.text.isEmpty ? 'Select Time' : timeController.text,
            style: TextStyle(
              color: AppColors.darkColor,
              fontWeight: FontWeight.w500,
              fontSize: 15,
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
                    style: TextStyle(
                      color: AppColors.darkColor,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: AppColors.primaryColor,
                    decoration: InputDecoration(
                      hintText: 'Enter time',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 15,
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
                style: TextStyle(
                  color: AppColors.darkColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
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
          dropdownColor: Colors.white,
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppColors.primaryColor,
            size: 28,
          ),
          isExpanded: true,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildChunkItem(BuildContext context, int index, Map<String, dynamic> chunk) {
    final chunkType = chunk['type'] as RecordType;
    final record = chunk['records'].last as TimingRecord;
    final previousChunk = index > 0 ? _chunks[index - 1] : null;
    final previousChunkEndTime = previousChunk != null ? previousChunk['records'].last.elapsedTime : '0.0';
    

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chunkType == RecordType.extraRunner || chunkType == RecordType.missingRunner)
            _buildConflictHeader(chunkType, record, previousChunkEndTime, record.elapsedTime),
          if (chunkType == RecordType.confirmRunner)
            _buildConfirmHeader(record),
          const SizedBox(height: 8),
          ...chunk['joined_records'].map<Widget>((joinedRecord) {
            if (joinedRecord[1].type == RecordType.runnerTime) {
              return _buildRunnerTimeRecord(
                context,
                chunk['joined_records'].indexOf(joinedRecord),
                joinedRecord,
                chunkType == RecordType.runnerTime || chunkType == RecordType.confirmRunner
                    ? Colors.green
                    : AppColors.primaryColor,
                chunk,
              );
            } else if (joinedRecord[1].type == RecordType.confirmRunner) {
              return _buildConfirmationRecord(
                context,
                chunk['joined_records'].indexOf(joinedRecord),
                joinedRecord,
              );
            }
            return const SizedBox.shrink();
          }).toList(),
          if (chunkType == RecordType.extraRunner || chunkType == RecordType.missingRunner)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: _buildActionButton(
                'Resolve Conflict',
                () => chunkType == RecordType.extraRunner
                    ? _handleTooManyTimesResolution(chunk)
                    : _handleTooFewTimesResolution(chunk),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConflictHeader(RecordType type, TimingRecord conflictRecord, String startTime, String endTime) {
    final String title = type == RecordType.extraRunner
        ? 'Too Many Runner Times'
        : 'Missing Runner Times';
    final String description = '${type == RecordType.extraRunner
        ? 'There are more times recorded by the timing assistant than runners'
        : 'There are more runners than times recorded by the timing assistant'}. Please select or enter appropriate times between $startTime and $endTime to resolve the discrepancy between recorded times and runners.';
    final IconData icon = type == RecordType.extraRunner
        ? Icons.group_add
        : Icons.person_search;
        
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title at ${conflictRecord.elapsedTime}',
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.primaryColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmHeader(TimingRecord confirmRecord) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmed Results at ${confirmRecord.elapsedTime}',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These runner results have been confirmed',
                  style: TextStyle(
                    color: Colors.green.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
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
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync_problem, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    super.dispose();
  }
}
