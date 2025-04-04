import 'package:flutter/material.dart';
import 'package:xcelerate/core/services/device_connection_service.dart';
import 'package:xcelerate/utils/encode_utils.dart';
import 'package:xcelerate/utils/enums.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import 'package:xcelerate/coach/merge_conflicts/model/timing_data.dart';
import '../../../../../../assistant/race_timer/model/timing_record.dart';
import '../../../../../../utils/database_helper.dart';
import '../../../../../race_results/model/results_record.dart';
import 'package:xcelerate/utils/sheet_utils.dart';
import 'package:xcelerate/utils/time_formatter.dart' as TimeFormatter;
import 'package:xcelerate/coach/resolve_bib_number_screen/widgets/bib_conflicts_overview.dart';
import 'package:xcelerate/coach/merge_conflicts/screen/merge_conflicts_screen.dart';

/// Controller that manages loading and processing of race results
class LoadResultsController with ChangeNotifier {
  final int raceId;
  bool _resultsLoaded = false;
  bool _hasBibConflicts = false;
  bool _hasTimingConflicts = false;
  List<ResultsRecord> results = [];
  TimingData? timingData;
  List<RunnerRecord>? runnerRecords;
  late final DevicesManager devices;
  final Function() callback;
  
  LoadResultsController({
    required this.raceId,
    required this.callback,
  }) {
    devices = DeviceConnectionService.createDevices(
      DeviceName.coach,
      DeviceType.browserDevice,
    );
    
    // Load any existing results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadResults();
    });
  }
  
  bool get resultsLoaded => _resultsLoaded;
  bool get hasBibConflicts => _hasBibConflicts;
  bool get hasTimingConflicts => _hasTimingConflicts;

  set resultsLoaded(bool value) {
    _resultsLoaded = value;
    notifyListeners();
  }

  set hasBibConflicts(bool value) {
    _hasBibConflicts = value;
    notifyListeners();
  }

  set hasTimingConflicts(bool value) {
    _hasTimingConflicts = value;
    notifyListeners();
  }

  /// Resets devices and clears state
  void resetDevices() {
    devices.reset();
    resultsLoaded = false;
    hasBibConflicts = false;
    hasTimingConflicts = false;
    results = [];
    notifyListeners();
  }

  /// Loads saved results from the database
  Future<void> loadResults() async {
    final List<ResultsRecord>? savedResults =
        await DatabaseHelper.instance.getRaceResultsData(raceId);
    print('Loaded ${savedResults?.length} results for race $raceId');
    if (savedResults != null) {
      resultsLoaded = true;
      results = savedResults;
      notifyListeners();
    }
  }

  /// Saves race results to the database
  Future<void> saveRaceResults(List<ResultsRecord> resultRecords) async {
    try {
      await DatabaseHelper.instance.saveRaceResults(
        raceId,
        resultRecords,
      );
      results = resultRecords;
    } catch (e) {
      print('Error in saveRaceResults: $e');
      rethrow;
    }
  }

  /// Processes data received from devices
  Future<void> processReceivedData(BuildContext context) async {
    String? bibRecordsData = devices.bibRecorder?.data;
    String? finishTimesData = devices.raceTimer?.data;
    print('Bib records data: ${bibRecordsData != null ? "Available" : "Null"}');
    print('Finish times data: ${finishTimesData != null ? "Available" : "Null"}');
    
    if (bibRecordsData != null && finishTimesData != null) {
      runnerRecords = await processEncodedBibRecordsData(
          bibRecordsData, context, raceId);
      print('Processed runner records: ${runnerRecords?.length ?? 0}');

      timingData = await processEncodedTimingData(finishTimesData, context);
      print('Processed timing data: ${timingData?.records.length ?? 0} records');

      resultsLoaded = true;
      notifyListeners();
      await _checkForConflictsAndSaveResults();
    } else {
      print('Missing data source: bibRecordsData or finishTimesData is null');
    }
  }

  Future<void> _checkForConflictsAndSaveResults() async {
    hasBibConflicts = runnerRecords != null ? containsBibConflicts(runnerRecords!) : false;
    hasTimingConflicts = timingData != null ? containsTimingConflicts(timingData!) : false;
    notifyListeners();

    if (!hasBibConflicts && !hasTimingConflicts && timingData != null && runnerRecords != null) {
      final List<ResultsRecord> mergedResults = await _mergeRunnerRecordsWithTimingData(
          timingData!, runnerRecords!);
      print('Data merged, created ${mergedResults.length} result records');
      
      results = mergedResults;
      notifyListeners();
      await saveRaceResults(mergedResults);
      callback();
    }
  }

  /// Merges runner records with timing data
  Future<List<ResultsRecord>> _mergeRunnerRecordsWithTimingData(
      TimingData timingData, List<RunnerRecord> runnerRecords) async {
    final List<ResultsRecord> mergedRecords = [];
    final List<TimingRecord> records = timingData.records
        .where((record) => record.type == RecordType.runnerTime)
        .toList();

    for (var i = 0; i < records.length; i++) {
      if (i >= runnerRecords.length) break;
      
      final runnerRecord = runnerRecords[i];
      final timingRecord = records[i];
      
      // Convert elapsed time string to Duration
      Duration finishDuration;
      finishDuration = TimeFormatter.loadDurationFromString(timingRecord.elapsedTime) ?? Duration.zero;
      
      // Get or create runner ID
      int runnerId = runnerRecord.runnerId ?? await _findRunnerId(runnerRecord);
      
      mergedRecords.add(ResultsRecord(
        bib: runnerRecord.bib,
        place: timingRecord.place!,
        name: runnerRecord.name,
        school: runnerRecord.school,
        grade: runnerRecord.grade,
        finishTime: finishDuration,
        raceId: raceId,
        runnerId: runnerId,
      ));
    }
    return mergedRecords;
  }

  /// Gets an existing runner ID or creates a new one if needed
  Future<int> _findRunnerId(RunnerRecord record) async {
    if (record.runnerId != null) {
      return record.runnerId!;
    }
    
    try {
      // Try to find runner by bib number in this race
      final runner = await DatabaseHelper.instance.getRaceRunnerByBib(raceId, record.bib);
      if (runner != null && runner.runnerId != null) {
        print('Found existing runner ID: ${runner.runnerId} for bib ${record.bib}');
        return runner.runnerId!;
      }
      
      print('No runner ID found for bib ${record.bib}, using 0 as fallback');
      return 0; // Fallback ID if we can't find a valid ID
    } catch (e) {
      print('Error finding runner ID: $e');
      return 0; // Fallback ID in case of error
    }
  }

  /// Loads test data for development purposes
  Future<void> loadTestData(BuildContext context) async {
    debugPrint('Loading test data...');
    // Fake encoded data strings
    final fakeBibRecordsData = '1 2 30 101';
    final fakeFinishTimesData = TimingData(records: [
      TimingRecord(
        elapsedTime: '1.0',
        isConfirmed: true,
        conflict: null,
        type: RecordType.runnerTime,
        place: 1,
      ),
      TimingRecord(
        elapsedTime: '2.0',
        isConfirmed: true,
        conflict: null,
        type: RecordType.runnerTime,
        place: 2,
      ),
      TimingRecord(
        elapsedTime: '3.0',
        isConfirmed: true,
        conflict: null,
        type: RecordType.runnerTime,
        place: 3,
      ),
      TimingRecord(
        elapsedTime: '3.5',
        isConfirmed: true,
        conflict: null,
        place: 3,
        type: RecordType.confirmRunner,
      ),
      TimingRecord(
        elapsedTime: 'TBD',
        isConfirmed: false,
        conflict: ConflictDetails(
          type: RecordType.missingRunner,
          isResolved: false,
          data: {'numTimes': 4, 'offBy': 1},
        ),
        place: 4,
        type: RecordType.runnerTime,
      ),
      TimingRecord(
        elapsedTime: '4.0',
        isConfirmed: false,
        conflict: ConflictDetails(
          type: RecordType.missingRunner,
          isResolved: false,
          data: {'numTimes': 4, 'offBy': 1},
        ),
        place: 4,
        type: RecordType.missingRunner,
      ),
    ], endTime: '13.7');

    // Inject fake data into the devices
    devices.bibRecorder?.data = fakeBibRecordsData;
    devices.raceTimer?.data = fakeFinishTimesData.encode();

    // Process the fake data
    await processReceivedData(context);
  }
  
  /// Shows sheet for resolving bib conflicts
  Future<void> showBibConflictsSheet(BuildContext context) async {
    if (runnerRecords == null) return;
    
    final List<RunnerRecord>? updatedRunnerRecords = await sheet(
      context: context,
      title: 'Resolve Bib Numbers',
      body: BibConflictsOverview(
        records: runnerRecords!,
        raceId: raceId,
        onConflictSelected: (records) {
          Navigator.pop(context, records);
        },
      ),
    );

    // Update runner records if a result was returned
    if (updatedRunnerRecords != null) {
      runnerRecords = updatedRunnerRecords;

      await _checkForConflictsAndSaveResults();
    }
  }

  /// Shows sheet for resolving timing conflicts
  Future<void> showTimingConflictsSheet(BuildContext context) async {
    if (timingData == null || runnerRecords == null) return;
    
    final updatedTimingData = await sheet(
      context: context,
      title: 'Resolve Timing Conflicts',
      body: MergeConflictsScreen(
        raceId: raceId,
        timingData: timingData!,
        runnerRecords: runnerRecords!,
      ),
    );
    
    // Update timing data if a result was returned
    if (updatedTimingData != null) {
      timingData = updatedTimingData;
      
      await _checkForConflictsAndSaveResults();
    }
  }

  /// Checks if there are any bib conflicts in the provided records
  bool containsBibConflicts(List<RunnerRecord> records) {
    return records.any((record) => record.error != null);
  }

  /// Checks if there are any timing conflicts in the timing data
  bool containsTimingConflicts(TimingData data) {
    return data.records.any((record) => record.conflict != null);
  }
}
