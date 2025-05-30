import '../model/timing_data.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import '../model/chunk.dart';
import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/coach/merge_conflicts/model/resolve_information.dart';
import '../../../utils/time_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../utils/enums.dart';
import '../../../assistant/race_timer/model/timing_record.dart';

class MergeConflictsController with ChangeNotifier {
  late final int raceId;
  late final TimingData timingData;
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
    assert(_context != null,
        'Context not set in MergeConflictsController. Call setContext() first.');
    return _context!;
  }

  void initState() {
    createChunks();
  }

  Future<void> saveResults() async {
    if (getFirstConflict()[0] != null) {
      DialogUtils.showErrorDialog(context,
          message: 'All runners must be resolved before proceeding.');
      return;
    }

    if (!validateRunnerInfo(runnerRecords)) {
      DialogUtils.showErrorDialog(context,
          message:
              'All runners must have a bib number assigned before proceeding.');
      return;
    }
    
    // Ensure all conflicts are cleared before returning to load results screen
    clearAllConflicts();
    
    Navigator.of(context).pop(timingData);
  }

  bool validateRunnerInfo(List<RunnerRecord> records) {
    return records.every((runner) =>
        runner.bib.isNotEmpty &&
        runner.name.isNotEmpty &&
        runner.grade > 0 &&
        runner.school.isNotEmpty);
  }

  Future<void> updateRunnerInfo() async {
    for (int i = 0; i < runnerRecords.length; i++) {
      final record = timingData.records.firstWhere(
        (r) =>
            r.type == RecordType.runnerTime &&
            r.place == i + 1 &&
            r.isConfirmed == true,
        orElse: () => TimingRecord(
            elapsedTime: '',
            isConfirmed: false,
            conflict: null,
            type: RecordType.runnerTime,
            place: null,
            previousPlace: null,
            textColor: null),
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
    try {
      Logger.d('Creating chunks...');
      Logger.d('runnerRecords length: ${runnerRecords.length}');
      selectedTimes = {};
      final records = timingData.records;
      final newChunks = <Chunk>[];
      var startIndex = 0;
      var place = 1;

      for (int i = 0; i < records.length; i += 1) {
        try {
          Logger.d('Processing record: ${records[i]}');
          Logger.d('Record type: ${records[i].type}, place: ${records[i].place}, conflict: ${records[i].conflict?.data}');
          
          if (i >= records.length - 1 || records[i].type != RecordType.runnerTime) {
            // Extract and debug endIndex calculation
            final dynamic rawEndIndex = records[i].conflict?.data?['numTimes'] ?? records[i].place;
            Logger.d('Raw end index: $rawEndIndex (type: ${rawEndIndex?.runtimeType})'); 
            
            // Safely calculate end index with null checks and type validation
            int endIndex;
            if (rawEndIndex == null) {
              endIndex = place;
              Logger.d('Using default place as endIndex: $endIndex');
            } else if (rawEndIndex is int) {
              endIndex = rawEndIndex;
              Logger.d('Using int value as endIndex: $endIndex');
            } else {
              // Try to convert to int or fall back to default
              endIndex = int.tryParse(rawEndIndex.toString()) ?? place;
              Logger.d('Converted to endIndex: $endIndex');
            }
            
            // Ensure valid bounds for runner records
            final int startBound = place > 0 ? place - 1 : 0;
            final int endBound = endIndex > runnerRecords.length ? runnerRecords.length : endIndex;
            
            if (startBound >= endBound || startBound >= runnerRecords.length) {
              Logger.d('⚠️ Invalid bounds: start=$startBound, end=$endBound, max=${runnerRecords.length}');
              // Handle the case where bounds would cause an error - create an empty list
              newChunks.add(Chunk(
                records: records.sublist(startIndex, i + 1),
                type: records[i].type,
                runners: [],  // Empty list instead of invalid bounds
                conflictIndex: i,
              ));
            } else {
              // Normal case with valid bounds
              Logger.d('Creating chunk with runners[$startBound..$endBound]');
              newChunks.add(Chunk(
                records: records.sublist(startIndex, i + 1),
                type: records[i].type,
                runners: runnerRecords.sublist(startBound, endBound),
                conflictIndex: i,
              ));
            }
            
            startIndex = i + 1;
            
            // Safely update place
            if (records[i].conflict?.data?['numTimes'] != null) {
              place = records[i].conflict!.data!['numTimes'];
              Logger.d('Updated place from conflict.numTimes: $place');
            } else if (records[i].place != null) {
              place = records[i].place! + 1;
              Logger.d('Updated place from record.place: $place');
            } else {
              // If both are null, increment place by 1 to avoid getting stuck
              place += 1;
              Logger.d('Incremented place by 1: $place');
            }
          }
        } catch (e, stackTrace) {
          Logger.e('⚠️ Error processing record at index $i', e, stackTrace);
          // Continue with next record instead of failing entirely
          continue;
        }
      }

      Logger.d('Chunks created: $newChunks');

      // Handle setResolveInformation with error protection
      for (int i = 0; i < newChunks.length; i += 1) {
        try {
          selectedTimes[newChunks[i].conflictIndex] = [];
          await newChunks[i].setResolveInformation(
              resolveTooManyRunnerTimes, resolveTooFewRunnerTimes);
        } catch (e, stackTrace) {
          Logger.e('⚠️ Error setting resolve information for chunk $i', e, stackTrace);
        }
      }

      chunks = newChunks;
      notifyListeners();
      Logger.d('Chunks created: $chunks');
    } catch (e, stackTrace) {
      Logger.e('⚠️ Critical error in createChunks', e, stackTrace);
      // Create empty chunks to prevent UI from breaking completely
      chunks = [];
      notifyListeners();
    }
  }

  List<dynamic> getFirstConflict() {
    final records = timingData.records;
    final conflict = records.firstWhere(
      (record) =>
          record.type != RecordType.runnerTime &&
          record.type != RecordType.confirmRunner,
      orElse: () => TimingRecord(
          elapsedTime: '',
          runnerNumber: null,
          isConfirmed: false,
          conflict: null,
          type: RecordType.runnerTime,
          place: null,
          previousPlace: null,
          textColor: null),
    );
    return conflict.elapsedTime != ''
        ? [conflict.type, records.indexOf(conflict)]
        : [null, -1];
  }

  bool validateTimes(List<String> times, List<RunnerRecord> runners,
      TimingRecord lastConfirmed, TimingRecord conflictRecord) {
    // Handle empty times - prevent validation of empty strings
    if (times.any((time) => time.trim().isEmpty)) {
      DialogUtils.showErrorDialog(context,
          message: 'All time fields must be filled in');
      return false;
    }
    
    // Format validation - ensure times are in the correct format before parsing
    for (var i = 0; i < times.length; i++) {
      final String time = times[i].trim();
      final runner = i < runners.length ? runners[i] : runners.last;
      
      // Basic format check (allow both M:SS.ms and SS.ms formats)
      final bool validFormat = RegExp(r'^\d+:\d+\.\d+$|^\d+\.\d+$').hasMatch(time);
      if (!validFormat) {
        DialogUtils.showErrorDialog(context,
            message: 'Invalid time format for runner with bib ${runner.bib}. Use MM:SS.ms or SS.ms');
        return false;
      }
    }
    
    // Parse the times and check boundaries
    Duration lastConfirmedTime = lastConfirmed.elapsedTime.trim().isEmpty
        ? Duration.zero
        : TimeFormatter.loadDurationFromString(lastConfirmed.elapsedTime) ?? Duration.zero;
    
    Duration? conflictTime = TimeFormatter.loadDurationFromString(conflictRecord.elapsedTime);

    for (var i = 0; i < times.length; i++) {
      final time = TimeFormatter.loadDurationFromString(times[i]);
      final runner = i < runners.length ? runners[i] : runners.last;
      Logger.d('Validating time: $time for runner ${runner.bib}');

      if (time == null) {
        DialogUtils.showErrorDialog(context,
            message: 'Enter a valid time for runner with bib ${runner.bib}');
        return false;
      }

      if (time <= lastConfirmedTime ||
          time >=
              (conflictTime ??
                  Duration.zero)) {
        DialogUtils.showErrorDialog(context,
            message:
                'Time for ${runner.name} must be after ${lastConfirmed.elapsedTime} and before ${conflictRecord.elapsedTime}');
        return false;
      }
    }

    if (!isAscendingOrder(
        times.map((time) => TimeFormatter.loadDurationFromString(time) ?? Duration.zero).toList())) {
      DialogUtils.showErrorDialog(context,
          message: 'Times must be in ascending order');
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

  Future<ResolveInformation> resolveTooFewRunnerTimes(int conflictIndex) async {
    var records = timingData.records;
    final bibData =
        runnerRecords.map((runner) => runner.bib.toString()).toList();
    final conflictRecord = records[conflictIndex];

    final lastConfirmedIndex = records
        .sublist(0, conflictIndex)
        .lastIndexWhere((record) => record.type != RecordType.runnerTime);

    final lastConfirmedPlace =
        lastConfirmedIndex == -1 ? 0 : records[lastConfirmedIndex].place;

    final firstConflictingRecordIndex = records
            .sublist(lastConfirmedIndex + 1, conflictIndex)
            .indexWhere((record) => record.conflict != null) +
        lastConfirmedIndex +
        1;
    if (firstConflictingRecordIndex == -1) {
      throw Exception('No conflicting records found');
    }

    final startingIndex = lastConfirmedPlace ?? 0;

    final spaceBetweenConfirmedAndConflict = lastConfirmedIndex == -1
        ? 1
        : firstConflictingRecordIndex - lastConfirmedIndex;

    final List<TimingRecord> conflictingRecords = records.sublist(
        lastConfirmedIndex + spaceBetweenConfirmedAndConflict, conflictIndex);

    final List<String> conflictingTimes = conflictingRecords
        .where((record) => record.elapsedTime != '')
        .map((record) => record.elapsedTime)
        .where((time) => time != '' && time != 'TBD')
        .toList();
    // Safely create the runners list with boundary checks
    final int calculatedEndIndex = startingIndex + spaceBetweenConfirmedAndConflict;
    final int safeEndIndex = calculatedEndIndex > runnerRecords.length ? runnerRecords.length : calculatedEndIndex;
  
    // Ensure we don't create a negative range or go out of bounds
    final List<RunnerRecord> conflictingRunners;
    if (startingIndex < 0 || startingIndex >= runnerRecords.length || startingIndex >= safeEndIndex) {
      conflictingRunners = [];
      Logger.d('⚠️ Invalid range for conflictingRunners: start=$startingIndex, end=$safeEndIndex');
    } else {
      conflictingRunners = List<RunnerRecord>.from(runnerRecords.sublist(startingIndex, safeEndIndex));
    }

    return ResolveInformation(
      conflictingRunners: conflictingRunners,
      lastConfirmedPlace: lastConfirmedPlace ?? 0,
      availableTimes: conflictingTimes,
      allowManualEntry: true,
      conflictRecord: conflictRecord,
      lastConfirmedRecord: lastConfirmedIndex == -1 ? TimingRecord(place: -1, elapsedTime: '') : records[lastConfirmedIndex],
      bibData: bibData,
    );
  }

  Future<ResolveInformation> resolveTooManyRunnerTimes(
      int conflictIndex) async {
    Logger.d('_resolveTooManyRunnerTimes called');
    var records = (timingData.records as List<TimingRecord>?) ?? [];
    final bibData = runnerRecords.map((runner) => runner.bib).toList();
    final conflictRecord = records[conflictIndex];

    final lastConfirmedIndex = records
        .sublist(0, conflictIndex)
        .lastIndexWhere((record) => record.type != RecordType.runnerTime);
    
    final lastConfirmedPlace =
        lastConfirmedIndex == -1 ? 0 : records[lastConfirmedIndex].place ?? 0;

    final List<TimingRecord> conflictingRecords =
        records.sublist(lastConfirmedIndex + 1, conflictIndex);

    final List<String> conflictingTimes = conflictingRecords
        .where((record) => record.elapsedTime != '')
        .map((record) => record.elapsedTime)
        .where((time) => time != '' && time != 'TBD')
        .toList();
    // Safely determine end index with null check and boundary validation
    final dynamic rawEndIndex = conflictRecord.conflict?.data?['numTimes'];
    final int endIndex = rawEndIndex != null ? 
        (rawEndIndex is int ? rawEndIndex : int.tryParse(rawEndIndex.toString()) ?? lastConfirmedPlace) : 
        (conflictRecord.place ?? lastConfirmedPlace);
  
    // Ensure we don't exceed the bounds of runnerRecords
    final int safeEndIndex = endIndex > runnerRecords.length ? runnerRecords.length : endIndex;
  
    // Create conflictingRunners with safe bounds
    final List<RunnerRecord> conflictingRunners = lastConfirmedPlace < safeEndIndex ?
        runnerRecords.sublist(lastConfirmedPlace, safeEndIndex) : [];
    Logger.d('Conflicting runners: $conflictingRunners');

    // Add more debug information
    Logger.d('lastConfirmedIndex: $lastConfirmedIndex');
    Logger.d('lastConfirmedPlace: $lastConfirmedPlace');
    
    // Create a safe lastConfirmedRecord that handles the case where lastConfirmedIndex is -1
    final TimingRecord safeLastConfirmedRecord = lastConfirmedIndex == -1 ? 
        TimingRecord(place: lastConfirmedPlace, elapsedTime: '', isConfirmed: true) : 
        records[lastConfirmedIndex];
    
    return ResolveInformation(
      conflictingRunners: conflictingRunners,
      conflictingTimes: conflictingTimes,
      lastConfirmedPlace: lastConfirmedPlace,
      lastConfirmedRecord: safeLastConfirmedRecord,
      lastConfirmedIndex: lastConfirmedIndex,
      conflictRecord: conflictRecord,
      availableTimes: conflictingTimes,
      bibData: bibData,
    );
  }

  /// Consolidates all confirmed runnerTime records, reorders them sequentially,
  /// and preserves unresolved conflicts (missingRunner/extraRunner types).
  void consolidateConfirmedRunnerTimes() {
    // Extract all confirmed runnerTime records
    List<TimingRecord> confirmed = timingData.records
        .where((r) => r.type == RecordType.runnerTime && r.isConfirmed == true)
        .toList();

    // Sort by place (or elapsedTime if you want time order)
    confirmed.sort((a, b) => (a.place ?? 999).compareTo(b.place ?? 999));

    // Reassign places sequentially
    for (int i = 0; i < confirmed.length; i++) {
      confirmed[i].place = i + 1;
    }

    // Remove all confirmed runnerTime records from timingData.records
    timingData.records.removeWhere(
      (r) => r.type == RecordType.runnerTime && r.isConfirmed == true,
    );

    // Find the index to insert confirmed records (before the first unresolved conflict, or at the end)
    int insertIndex = timingData.records.indexWhere((r) =>
      r.type == RecordType.missingRunner || r.type == RecordType.extraRunner
    );
    if (insertIndex == -1) {
      // No conflicts left, append at end
      timingData.records.addAll(confirmed);
    } else {
      // Insert before the first conflict
      timingData.records.insertAll(insertIndex, confirmed);
    }

    notifyListeners();
  }

  Future<void> handleTooFewTimesResolution(
    Chunk chunk,
  ) async {
    try {
    final resolveData = chunk.resolve;
    if (resolveData == null) throw Exception('No resolve data found');
    
    if (chunk.controllers['timeControllers'] == null) {
      throw Exception('No time controllers found');
    }
    
    final runners = chunk.runners;
    final List<String> times = chunk.controllers['timeControllers']!
        .map((controller) => controller.text.toString())
        .toList()
        .cast<String>();

    final conflictRecord = resolveData.conflictRecord;

    if (!validateTimes(
        times, runners, resolveData.lastConfirmedRecord, conflictRecord)) {
      return;
    }
    final records = timingData.records;
    final lastConfirmedRunnerPlace = resolveData.lastConfirmedPlace;
    for (int i = 0; i < runners.length; i++) {
      final int currentPlace = (i + lastConfirmedRunnerPlace + 1).toInt();
      Logger.d('Current place: $currentPlace');
      var record = records.firstWhere(
          (element) => element.place == currentPlace,
          orElse: () => TimingRecord(
              elapsedTime: '',
              isConfirmed: false,
              conflict: null,
              type: RecordType.runnerTime,
              place: null,
              previousPlace: null,
              textColor: null));

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
    Logger.d('');
    Logger.d('updated conflict record: $conflictRecord');
    Logger.d('updated records: ${timingData.records}');
    Logger.d('');
    notifyListeners();

    // Delete all records with type confirm_runner between the conflict record and the last conflict
    int conflictIndex = records.indexOf(conflictRecord);
    int lastConflictIndex = records.lastIndexWhere((record) =>
        record.conflict != null && records.indexOf(record) < conflictIndex);
    timingData.records.removeWhere((record) =>
        record.type == RecordType.confirmRunner &&
        records.indexOf(record) > lastConflictIndex &&
        records.indexOf(record) < conflictIndex);

    showSuccessMessage();
    consolidateConfirmedRunnerTimes();
    await createChunks();
    } catch (e, stackTrace) {
      Logger.e('Error in handleTooFewTimesResolution', e, stackTrace);
      if (!context.mounted) return;
      DialogUtils.showErrorDialog(context, 
          message: 'An error occurred while resolving conflict: ${e.toString()}');
    }
  }

  Future<void> handleTooManyTimesResolution(
    Chunk chunk,
  ) async {
    try {
    if (chunk.controllers['timeControllers'] == null) {
      throw Exception('No time controllers found');
    }
    final List<String> times = chunk.controllers['timeControllers']!
        .map((controller) => controller.text.toString())
        .toList()
        .cast<String>();
    Logger.d('times: $times');
    Logger.d('records: ${chunk.records}');
    List<TimingRecord> records = chunk.records;
    final resolveData = chunk.resolve;
    if (resolveData == null) throw Exception('No resolve data found');
    final availableTimes = resolveData.availableTimes;
    final TimingRecord conflictRecord = resolveData.conflictRecord;
    final lastConfirmedIndex = resolveData.lastConfirmedIndex ?? -1;
    final lastConfirmedPlace = resolveData.lastConfirmedPlace;
    Logger.d('lastConfirmedPlace: $lastConfirmedPlace');
    List<RunnerRecord> runners = resolveData.conflictingRunners;

    if (!validateTimes(
        times, runners, resolveData.lastConfirmedRecord, conflictRecord)) {
      return;
    }

    final unusedTimes =
        availableTimes.where((time) => !times.contains(time)).toList();

    if (unusedTimes.isEmpty) {
      DialogUtils.showErrorDialog(context,
          message: 'Please select a time for each runner.');
      return;
    }
    Logger.d('Unused times: $unusedTimes');
    final List<TimingRecord> unusedRecords = records
        .where((record) => unusedTimes.contains(record.elapsedTime))
        .toList();
    Logger.d('Unused records: $unusedRecords');

    Logger.d('records: $records');
    Logger.d('runners before: $runners');

    records = timingData.records
        .where((record) => !unusedTimes.contains(record.elapsedTime))
        .toList();
    notifyListeners();
    records = timingData.records;

    Logger.d('runners: $runners');
    for (int i = 0; i < runners.length; i++) {
      final num currentPlace = i + lastConfirmedPlace + 1;
      var record = records[lastConfirmedIndex + 1 + i];
      final String bibNumber = runners[i].bib;

      Logger.d('currentPlace: $currentPlace');

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
    int lastConflictIndex = records.lastIndexWhere((record) =>
        record.conflict != null && records.indexOf(record) < conflictIndex);
    timingData.records.removeWhere((record) =>
        record.type == RecordType.confirmRunner &&
        records.indexOf(record) > lastConflictIndex &&
        records.indexOf(record) < conflictIndex);

    showSuccessMessage();
    consolidateConfirmedRunnerTimes();
    await createChunks();
    } catch (e, stackTrace) {
      Logger.e('Error in handleTooManyTimesResolution', e, stackTrace);
      if (!context.mounted) return;
      DialogUtils.showErrorDialog(context, 
          message: 'An error occurred while resolving conflict: ${e.toString()}');
    }
  }

  void updateConflictRecord(TimingRecord record, int numTimes) {
    record.type = RecordType.confirmRunner;
    record.place = numTimes;
    record.textColor = Colors.green;
    record.isConfirmed = true;
    record.conflict = null;
    record.previousPlace = null;
  }

  void showSuccessMessage() {
    DialogUtils.showSuccessDialog(context,
        message: 'Successfully resolved conflict');
  }
  
  /// Clears all conflict markers from timing records to ensure
  /// the load results screen doesn't show conflicts after resolution
  void clearAllConflicts() {
    Logger.d('Clearing all conflicts from timing data...');
    
    // Go through all records and fix any issues that could cause null checks
    int currentPlace = 1;
    List<TimingRecord> confirmedRecords = [];
    
    // First pass: Set all place values and clear conflicts
    for (int i = 0; i < timingData.records.length; i++) {
      final record = timingData.records[i];
      
      // 1. Fix missing place values for any record type
      if (record.place == null) {
        record.place = currentPlace;
        Logger.d('Assigned missing place $currentPlace to record with time ${record.elapsedTime}');
      }
      
      // 2. If it's a conflict record, convert it to confirmRunner
      if (record.type == RecordType.missingRunner || record.type == RecordType.extraRunner) {
        record.type = RecordType.confirmRunner;
        record.isConfirmed = true;
        record.textColor = Colors.green;
        
        // Ensure place is set (use index as fallback)
        if (record.place == null) {
          // Find the maximum place value used so far
          final int maxPlace = timingData.records
              .where((r) => r.place != null)
              .map((r) => r.place!)
              .fold(0, (max, place) => place > max ? place : max);
          record.place = maxPlace + 1;
          Logger.d('Assigned fallback place ${record.place} to conflict record');
        }
      }
      
      // 3. For runner time records, ensure they have proper elapsed time
      if (record.type == RecordType.runnerTime) {
        if (record.elapsedTime == 'TBD' || record.elapsedTime.isEmpty) {
          record.elapsedTime = '$currentPlace.0'; // Emergency placeholder
          Logger.d('WARNING: Added placeholder time for record at place ${record.place}');
        }
        
        // Keep track of max place for runner time records
        if (record.place! > currentPlace) {
          currentPlace = record.place!;
        }
        
        // Mark as confirmed
        record.isConfirmed = true;
        
        // Add to the list of confirmed records
        confirmedRecords.add(record);
      }
      
      // 4. Clear conflict data for all records
      record.conflict = null;
    }
    
    // Second pass: Ensure all runnerTime records are properly ordered by place
    confirmedRecords.sort((a, b) => (a.place ?? 999).compareTo(b.place ?? 999));
    
    // Reassign places if needed to ensure sequential places
    for (int i = 0; i < confirmedRecords.length; i++) {
      confirmedRecords[i].place = i + 1;
    }
    
    Logger.d('Fixed ${confirmedRecords.length} runner time records with proper places');
    Logger.d('All conflicts cleared from timing data');
  }

  void updateSelectedTime(
      int conflictIndex, String newValue, String? previousValue) {
    if (selectedTimes[conflictIndex] == null) {
      selectedTimes[conflictIndex] = <String>[];
    }

    selectedTimes[conflictIndex].add(newValue);

    if (previousValue != null &&
        previousValue.isNotEmpty &&
        previousValue != newValue) {
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
