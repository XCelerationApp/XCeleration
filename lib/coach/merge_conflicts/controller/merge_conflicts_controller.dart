import '../model/timing_data.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../model/chunk.dart';
import 'package:flutter/material.dart';
// import 'package:xcelerate/coach/merge_conflicts/model/chunk.dart';
import 'package:xcelerate/coach/merge_conflicts/model/resolve_information.dart';
// import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../../../utils/time_formatter.dart';
// import '../../../core/theme/typography.dart';
// import 'dart:math';
// import '../../../utils/database_helper.dart';
// import '../../races_screen/screen/races_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/dialog_utils.dart';
// import '../../../utils/runner_time_functions.dart';
// import '../utils/timing_utils.dart';
import '../../../utils/enums.dart';
// import '../model/timing_data.dart';
// import '../model/joined_record.dart';
import '../../../assistant/race_timer/timing_screen/model/timing_record.dart';
// import '../../../core/components/instruction_card.dart';
// import '../../race_screen/model/race_result.dart';

class MergeConflictsController with ChangeNotifier {
  late final int raceId;
  late final TimingData timingData;
  // late List<Map<String, dynamic>> runners;
  late List<RunnerRecord> runnerRecords;
  List<Chunk> chunks = [];
  Map<int, dynamic> selectedTimes = {};
  BuildContext? _context;

  MergeConflictsController({
    required this.raceId,
    required this.timingData,
    required this.runnerRecords,
  });

  void setContext(BuildContext context) {
    _context = context;
  }

  BuildContext get context {
    assert(_context != null, 'Context not set in MergeConflictsController. Call setContext() first.');
    return _context!;
  }

  void initState() {
    createChunks();
  }

  Future<void> saveResults() async {
    if (getFirstConflict()[0] != null) {
      DialogUtils.showErrorDialog(context, message: 'All runners must be resolved before proceeding.');
      return;
    }

    if (!validateRunnerInfo(runnerRecords)) {
      DialogUtils.showErrorDialog(context, message: 'All runners must have a bib number assigned before proceeding.');
      return;
    }

    Navigator.of(context).pop(timingData);
  }

  bool validateRunnerInfo(List<RunnerRecord> records) {
    return records.every((runner) => 
      runner.bib.isNotEmpty && 
      runner.name.isNotEmpty && 
      runner.grade > 0 && 
      runner.school.isNotEmpty
    );
  }

  Future<void> updateRunnerInfo() async {
    for (int i = 0; i < runnerRecords.length; i++) {
      final record = timingData.records.firstWhere(
        (r) => r.type == RecordType.runnerTime && r.place == i + 1 && r.isConfirmed == true,
        orElse: () => TimingRecord(elapsedTime: '', isConfirmed: false, conflict: null, type: RecordType.runnerTime, place: null, previousPlace: null, textColor: null),
      );
      if (record.place == null) continue;
      final runner = runnerRecords[i];
      final int index = timingData.records.indexOf(record);
      timingData.records[index] = TimingRecord(
        elapsedTime: record.elapsedTime,
        runnerNumber: runner.bib,
        isConfirmed: record.isConfirmed,
        conflict: record.conflict,
        type: record.type,
        place: record.place,
        previousPlace: record.previousPlace,
        textColor: record.textColor,
      );
    }
  }

  Future<void> createChunks() async {
    debugPrint('Creating chunks...');
    selectedTimes = {};
    final records = timingData.records;
    final newChunks = <Chunk>[];
    var startIndex = 0;
    var place = 1;
    // for (final record in records) {
    //   print('\n\nRecord: ${record.toMap()}');
    // }

    for (int i = 0; i < records.length; i += 1) {
      if (i >= records.length - 1 || records[i].type != RecordType.runnerTime) {
        // print('startIndex: $startIndex, i: $i, place: $place, conflict: ${records[i].conflict}, numTimes: ${records[i].conflict?.data?['numTimes']}, place: ${records[i].place}');
        newChunks.add(Chunk(
          records: records.sublist(startIndex, i + 1),
          type: records[i].type,
          runners: runnerRecords.sublist(place - 1, (records[i].conflict?.data?['numTimes'] ?? records[i].place)),
          conflictIndex: i,
        ));
        startIndex = i + 1;
        place = records[i].conflict?.data?['numTimes'] ?? records[i].place! + 1;
      }
    }

    for (int i = 0; i < newChunks.length; i += 1) {
      selectedTimes[newChunks[i].conflictIndex] = [];
      // final runners = chunks[i].runners;
      // final records = chunks[i].records;
      // debugPrint('chunk ${i + 1}: ${chunks[i]}');
      // debugPrint('-----------------------------');
      // debugPrint('runners length: ${runners.length}');
      // debugPrint('records length: ${records.length}');
      // chunks[i].joinedRecords = List.generate(
      //   runners.length,
      //   (j) => [runners[j], records[j]],
      // );
      // chunks[i].controllers = {'timeControllers': List.generate(runners.length, (j) => TextEditingController()), 'manualControllers': List.generate(runners.length, (j) => TextEditingController())};
      await newChunks[i].setResolveInformation(resolveTooManyRunnerTimes, resolveTooFewRunnerTimes);
    }

 
    chunks = newChunks;
    notifyListeners();
    debugPrint('Chunks created: $chunks');
  }

  List<dynamic> getFirstConflict() {
    final records = timingData.records;
    final conflict = records.firstWhere(
      (record) => record.type != RecordType.runnerTime && 
                  record.type != RecordType.confirmRunner,
      orElse: () => TimingRecord(elapsedTime: '', runnerNumber: null, isConfirmed: false, conflict: null, type: RecordType.runnerTime, place: null, previousPlace: null, textColor: null),
    );
    return conflict.elapsedTime != '' ? [conflict.type, records.indexOf(conflict)] : [null, -1];
  }

  bool validateTimes(List<String> times, List<RunnerRecord> runners, TimingRecord lastConfirmed, TimingRecord conflictRecord) {
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

    if (!isAscendingOrder(times.map((time) => loadDurationFromString(time)!).toList())) {
      DialogUtils.showErrorDialog(context, message: 'Times must be in ascending order');
      return false;
    }

    return true;
  }

  bool isAscendingOrder(List<Duration> times) {
  for (var i = 0; i < times.length - 1; i++) {
    if (times[i] >= times[i + 1]) return false;
  }
  return true;
}

  // bool checkIfAllRunnersResolved() {
  //   final records = timingData['records']?.cast<Map<String, dynamic>>() ?? [];
  //   return records.every((runner) => 
  //     runner['bib_number'] != null && runner['is_confirmed'] == true
  //   );
  // }

  Future<ResolveInformation> resolveTooFewRunnerTimes(int conflictIndex) async {
    var records = timingData.records;
    final bibData = runnerRecords.map((runner) => runner.bib.toString()).toList();
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
    if (firstConflictingRecordIndex == -1) throw Exception('No conflicting records found');

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
      runnerRecords.sublist(
        startingIndex,
        startingIndex + spaceBetweenConfirmedAndConflict
      )
    );

    return ResolveInformation(
      conflictingRunners: conflictingRunners,
      lastConfirmedPlace: lastConfirmedPlace ?? 0,
      availableTimes: conflictingTimes,
      allowManualEntry: true,
      conflictRecord: conflictRecord,
      // selectedTimes: [],
      lastConfirmedRecord: records[lastConfirmedIndex],
      bibData: bibData,
    );
  }

  Future<ResolveInformation> resolveTooManyRunnerTimes(int conflictIndex) async {
    debugPrint('_resolveTooManyRunnerTimes called');
    var records = (timingData.records as List<TimingRecord>?) ?? [];
    final bibData = runnerRecords.map((runner) => runner.bib).toList();
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
    final List<RunnerRecord> conflictingRunners = runnerRecords.sublist(
      lastConfirmedPlace,
      conflictRecord.conflict?.data?['numTimes']
    );
    debugPrint('Conflicting runners: $conflictingRunners');

    return ResolveInformation(
      conflictingRunners: conflictingRunners,
      conflictingTimes: conflictingTimes,
      lastConfirmedPlace: lastConfirmedPlace,
      lastConfirmedRecord: records[lastConfirmedIndex],
      lastConfirmedIndex: lastConfirmedIndex,
      conflictRecord: conflictRecord,
      availableTimes: conflictingTimes,
      bibData: bibData,
    );
  }

  Future<void> handleTooFewTimesResolution(
    Chunk chunk,
  ) async {
    final resolveData = chunk.resolve;
    if (resolveData == null) throw Exception('No resolve data found');
    // final bibData = resolveData['bibData'];
    final runners = chunk.runners;
    final List<String> times = chunk.controllers['timeControllers']!.map((controller) => controller.text.toString()).toList().cast<String>();

    final conflictRecord = resolveData.conflictRecord;

    if (!validateTimes(times, runners, resolveData.lastConfirmedRecord, conflictRecord)) {
      return;
    }
    final records = timingData.records;
    final lastConfirmedRunnerPlace = resolveData.lastConfirmedPlace;
    for (int i = 0; i < runners.length; i++) {
      final int currentPlace = (i + lastConfirmedRunnerPlace + 1).toInt();
      debugPrint('Current place: $currentPlace');
      var record = records.firstWhere((element) => element.place == currentPlace, orElse: () => TimingRecord(elapsedTime: '', isConfirmed: false, conflict: null, type: RecordType.runnerTime, place: null, previousPlace: null, textColor: null));

      record.elapsedTime = times[i];
      record.type = RecordType.runnerTime;
      record.place = currentPlace;
      record.isConfirmed = true;
      record.conflict = null;
      record.textColor = null;
    }

    updateConflictRecord(
      conflictRecord,
      lastConfirmedRunnerPlace + runners.length,
    );
    debugPrint('');
    debugPrint('updated conflict record: $conflictRecord');
    debugPrint('updated records: ${timingData.records}');
    debugPrint('');
    notifyListeners();
    
    // Delete all records with type confirm_runner between the conflict record and the last conflict
    int conflictIndex = records.indexOf(conflictRecord);
    int lastConflictIndex = records.lastIndexWhere((record) => record.conflict != null && records.indexOf(record) < conflictIndex);
    timingData.records.removeWhere((record) =>
        record.type == RecordType.confirmRunner &&
        records.indexOf(record) > lastConflictIndex &&
        records.indexOf(record) < conflictIndex);

    showSuccessMessage();
    await createChunks();
  }

  Future<void> handleTooManyTimesResolution(
    Chunk chunk,
  ) async {
    final List<String> times = chunk.controllers['timeControllers']!.map((controller) => controller.text.toString()).toList().cast<String>();
    debugPrint('times: $times');
    debugPrint('records: ${chunk.records}');
    List<TimingRecord> records = chunk.records;
    final resolveData = chunk.resolve;
    if (resolveData == null) throw Exception('No resolve data found');
    // final bibData = resolveData['bibData'] ?? [];
    final availableTimes = resolveData.availableTimes;
    // final lastConfirmedRecord = resolveData['lastConfirmedRecord'] ?? {};
    final TimingRecord conflictRecord = resolveData.conflictRecord;
    final lastConfirmedIndex = resolveData.lastConfirmedIndex ?? -1;
    final lastConfirmedPlace = resolveData.lastConfirmedPlace;
    debugPrint('lastConfirmedPlace: $lastConfirmedPlace');
    // final spaceBetweenConfirmedAndConflict = resolveData['spaceBetweenConfirmedAndConflict'] ?? -1;
    List<RunnerRecord> runners = resolveData.conflictingRunners;

    if (!validateTimes(times, runners, resolveData.lastConfirmedRecord, conflictRecord)) {
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

    records = timingData.records
        .where((record) => !unusedTimes.contains(record.elapsedTime))
        .toList();
    // runners = runners.where((runner) => !unusedTimes.contains(runner.elapsedTime)).toList();
    notifyListeners();
    records = timingData.records;

    // final lastConfirmedRunnerPlace = lastConfirmedRecord.isEmpty ? 0 : lastConfirmedRecord['place'] as int;
    debugPrint('runners: $runners');
    for (int i = 0; i < runners.length; i++) {
      final num currentPlace = i + lastConfirmedPlace + 1;
      var record = records[lastConfirmedIndex + 1 + i];
      final String bibNumber = runners[i].bib;

      debugPrint('currentPlace: $currentPlace');

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
      record.raceId = raceId;
      record.textColor = AppColors.navBarTextColor;
    }

    updateConflictRecord(
      conflictRecord,
      lastConfirmedPlace + runners.length,
    );
    notifyListeners();

    // Delete all records with type confirm_runner between the conflict record and the last conflict
    int conflictIndex = records.indexOf(conflictRecord);
    int lastConflictIndex = records.lastIndexWhere((record) => record.conflict != null && records.indexOf(record) < conflictIndex);
    timingData.records.removeWhere((record) =>
        record.type == RecordType.confirmRunner &&
        records.indexOf(record) > lastConflictIndex &&
        records.indexOf(record) < conflictIndex);

    // Navigator.pop(context);
    showSuccessMessage();
    await createChunks();
  }

  void updateConflictRecord(TimingRecord record, int numTimes) {
    // record['numTimes'] = numTimes;
    record.type = RecordType.confirmRunner;
    record.place = numTimes;
    record.textColor = Colors.green;
    record.isConfirmed = true;
    record.conflict = null;
    record.previousPlace = null;
  }

  void showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully resolved conflict')),
    );
  }

  void updateSelectedTime(int conflictIndex, String newValue, String? previousValue) {
    if (selectedTimes[conflictIndex] == null) {
      selectedTimes[conflictIndex] = <String>[];
    }
    
    selectedTimes[conflictIndex].add(newValue);
    
    if (previousValue != null && previousValue.isNotEmpty && previousValue != newValue) {
      selectedTimes[conflictIndex].remove(previousValue);
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    _context = null;
    super.dispose();
  }
}