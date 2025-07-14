import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/coach/merge_conflicts/model/timing_data.dart';
import 'package:xceleration/core/utils/runner_time_functions.dart';
import '../../../../../../shared/models/time_record.dart';
import '../../../../../../core/utils/database_helper.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/coach/resolve_bib_number_screen/widgets/bib_conflicts_overview.dart';
import 'package:xceleration/coach/merge_conflicts/screen/merge_conflicts_screen.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/utils/encode_utils.dart' as encode_utils;
import '../../../../../merge_conflicts/controller/merge_conflicts_controller.dart';
import '../../../../../race_results/model/results_record.dart';

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
  Future<void> resetDevices() async {
    devices.reset();
    // Re-encode and assign runner data after reset
    final encoded = await encode_utils.getEncodedRunnersData(raceId);
    devices.bibRecorder?.data = encoded;
    Logger.d('POST-RESET: Encoded runners data length: ${encoded.length}');
    resultsLoaded = false;
    hasBibConflicts = false;
    hasTimingConflicts = false;
    results = [];
    timingData = null;
    runnerRecords = null;
    notifyListeners();
  }

  /// Loads saved results from the database
  Future<void> loadResults() async {
    final List<ResultsRecord> savedResults =
        await DatabaseHelper.instance.getRaceResults(raceId);

    if (savedResults.isNotEmpty) {
      results = savedResults;
      resultsLoaded = true;
    }

    notifyListeners();
  }

  /// Saves race results to the database
  Future<void> saveRaceResults(List<ResultsRecord> resultRecords) async {
    try {
      await DatabaseHelper.instance.saveRaceResults(
        raceId,
        resultRecords,
      );
    } catch (e) {
      Logger.d('Error in saveRaceResults: $e');
      rethrow;
    }
  }

  /// Processes data received from devices
  Future<void> processReceivedData(BuildContext context) async {
    String? bibRecordsData = devices.bibRecorder?.data;
    String? finishTimesData = devices.raceTimer?.data;
    Logger.d(
        'Bib records data: ${bibRecordsData != null ? "Available" : "Null"}');
    Logger.d(
        'Finish times data: ${finishTimesData != null ? "Available" : "Null"}');

    if (bibRecordsData != null && finishTimesData != null) {
      runnerRecords = await processEncodedBibRecordsData(
          DatabaseHelper.instance, bibRecordsData, context, raceId);

      // Check if context is still mounted after async operation
      if (!context.mounted) return;

      Logger.d('Processed runner records: ${runnerRecords?.length ?? 0}');

      timingData = await processEncodedTimingData(finishTimesData, context);

      // Check if context is still mounted after second async operation
      if (!context.mounted) return;

      Logger.d(
          'Processed timing data: ${timingData?.records.length ?? 0} records');

      resultsLoaded = true;
      notifyListeners();

      await _ensureBibNumberAndRunnerRecordLengthsAreEqual();

      await _checkForConflictsAndSaveResults();
    } else {
      Logger.d(
          'Missing data source: bibRecordsData or finishTimesData is null');
    }
  }

  Future<void> _ensureBibNumberAndRunnerRecordLengthsAreEqual() async {
    if (runnerRecords != null && timingData != null) {
      if (runnerRecords!.length != timingData!.records.length) {
        Logger.d('Bib number and runner record lengths are not equal');
        int diff = runnerRecords!.length - timingData!.records.length;
        Logger.d('Difference: $diff');
        if (diff > 0) {
          Logger.d('Removing $diff records from runnerRecords');
          timingData!.records = removeExtraTime(diff, timingData!.records,
              runnerRecords!.length, timingData!.endTime);
        } else if (diff < 0) {
          Logger.d('Adding $diff records to timingData');
          timingData!.records = addMissingTime(diff.abs(), timingData!.records,
              runnerRecords!.length, timingData!.endTime);
        }
      } else if (timingData!.records.last.type == RecordType.runnerTime) {
        Logger.d('Last record is a runner time');
        timingData!.records = confirmTimes(timingData!.records,
            timingData!.records.length, timingData!.endTime);
      }
    }
  }

  Future<void> _checkForConflictsAndSaveResults() async {
    hasBibConflicts =
        runnerRecords != null ? containsBibConflicts(runnerRecords!) : false;
    hasTimingConflicts =
        timingData != null ? containsTimingConflicts(timingData!) : false;
    notifyListeners();

    if (!hasBibConflicts &&
        !hasTimingConflicts &&
        timingData != null &&
        runnerRecords != null) {
      final List<ResultsRecord> mergedResults =
          await _mergeRunnerRecordsWithTimingData(timingData!, runnerRecords!);
      Logger.d('Data merged, created ${mergedResults.length} result records');

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
    final List<TimeRecord> records = timingData.records
        .where((record) => record.type == RecordType.runnerTime)
        .toList();

    for (var i = 0; i < records.length; i++) {
      if (i >= runnerRecords.length) break;

      final runnerRecord = runnerRecords[i];
      final timeRecord = records[i];

      // Convert elapsed time string to Duration
      Duration finishDuration;
      finishDuration =
          TimeFormatter.loadDurationFromString(timeRecord.elapsedTime) ??
              Duration.zero;

      // Get or create runner ID
      int runnerId = runnerRecord.runnerId ?? await _findRunnerId(runnerRecord);

      mergedRecords.add(ResultsRecord(
        bib: runnerRecord.bib,
        place: timeRecord.place!,
        name: runnerRecord.name,
        team: runnerRecord.team,
        teamAbbreviation: runnerRecord.teamAbbreviation,
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
      final runner =
          await DatabaseHelper.instance.getRaceRunnerByBib(raceId, record.bib);
      if (runner != null && runner.runnerId != null) {
        Logger.d(
            'Found existing runner ID: ${runner.runnerId} for bib ${record.bib}');
        return runner.runnerId!;
      }

      Logger.d('No runner ID found for bib ${record.bib}, using 0 as fallback');
      return 0; // Fallback ID if we can't find a valid ID
    } catch (e) {
      Logger.d('Error finding runner ID: $e');
      return 0; // Fallback ID in case of error
    }
  }

  /// Loads test data for development purposes
  Future<void> loadTestData(BuildContext context) async {
    Logger.d('Loading test data...');
    // Fake encoded data strings
    final fakeBibRecordsData = '1 2 30 101';
    final fakeFinishTimesData = TimingData(records: [
      TimeRecord(
        elapsedTime: '1.0',
        isConfirmed: true,
        conflict: null,
        type: RecordType.runnerTime,
        place: 1,
      ),
      TimeRecord(
        elapsedTime: '2.0',
        isConfirmed: true,
        conflict: null,
        type: RecordType.runnerTime,
        place: 2,
      ),
      TimeRecord(
        elapsedTime: '3.0',
        isConfirmed: true,
        conflict: null,
        type: RecordType.runnerTime,
        place: 3,
      ),
      TimeRecord(
        elapsedTime: '3.5',
        isConfirmed: true,
        conflict: null,
        place: 3,
        type: RecordType.confirmRunner,
      ),
      TimeRecord(
        elapsedTime: 'TBD',
        isConfirmed: false,
        conflict: ConflictDetails(
          type: RecordType.missingTime,
          data: {'numTimes': 4, 'offBy': 1},
        ),
        place: 4,
        type: RecordType.runnerTime,
      ),
      TimeRecord(
        elapsedTime: '4.0',
        isConfirmed: false,
        conflict: ConflictDetails(
          type: RecordType.missingTime,
          data: {'numTimes': 4, 'offBy': 1},
        ),
        place: 4,
        type: RecordType.missingTime,
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

      // If there are still timing conflicts, open the timing conflicts sheet
      if (hasTimingConflicts &&
          !hasBibConflicts &&
          timingData != null &&
          context.mounted) {
        await showTimingConflictsSheet(context);
      }
    }
  }

  /// Shows sheet for resolving timing conflicts
  Future<void> showTimingConflictsSheet(BuildContext context) async {
    if (timingData == null || runnerRecords == null) return;

    final updatedTimingData = await sheet(
      context: context,
      title: 'Resolve Timing Conflicts',
      body: ChangeNotifierProvider(
        create: (_) => MergeConflictsController(
          raceId: raceId,
          timingData: timingData!,
          runnerRecords: runnerRecords!,
        ),
        child: MergeConflictsScreen(
          raceId: raceId,
          timingData: timingData!,
          runnerRecords: runnerRecords!,
        ),
      ),
      useBottomPadding: false,
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
