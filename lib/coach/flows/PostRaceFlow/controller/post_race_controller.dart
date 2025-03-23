import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import 'package:xcelerate/coach/flows/PostRaceFlow/steps/load_results/load_results_step.dart';
import 'package:xcelerate/coach/flows/PostRaceFlow/steps/review_results/review_results_step.dart';
import 'package:xcelerate/coach/flows/PostRaceFlow/steps/share_results/share_results_step.dart';
import 'package:xcelerate/coach/merge_conflicts_screen/screen/merge_conflicts_screen.dart';
// import 'package:xcelerate/coach/race_screen/widgets/bib_conflicts_sheet.dart';
// import 'package:xcelerate/coach/race_screen/widgets/timing_conflicts_sheet.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import 'package:xcelerate/coach/merge_conflicts_screen/model/timing_data.dart';
// import 'package:xcelerate/coach/resolve_bib_number_screen/screen/resolve_bib_number_screen.dart';
import 'package:xcelerate/coach/resolve_bib_number_screen/widgets/bib_conflicts_overview.dart';
import 'package:xcelerate/core/services/device_connection_service.dart';
// import 'package:xcelerate/utils/runner_time_functions.dart';
import 'package:xcelerate/utils/encode_utils.dart';
import 'package:xcelerate/utils/enums.dart';
import 'package:xcelerate/assistant/race_timer/timing_screen/model/timing_record.dart';
import 'package:xcelerate/utils/sheet_utils.dart';
import '../../../../utils/database_helper.dart';
import '../../controller/flow_controller.dart';

class PostRaceController {
  final int raceId;
  
  // Controller state
  late DevicesManager devices;
  
  // Flow steps
  late LoadResultsStep _loadResultsStep;
  late ReviewResultsStep _reviewResultsStep;
  late ShareResultsStep _shareResultsStep;
  
  // Constructor
  PostRaceController({required this.raceId, bool useTestData = false}) {
    devices = DeviceConnectionService.createDevices(
      DeviceName.coach,
      DeviceType.browserDevice,
    );
    _initializeSteps(useTestData);
  }
  
  // Initialize the flow steps
  void _initializeSteps([bool useTestData = false]) {
    _loadResultsStep = LoadResultsStep(
      devices: devices,
      reloadDevices: () => loadResults(),
      onResultsLoaded: (context) => useTestData ? _loadTestData(context) : processReceivedData(context),
      showBibConflictsSheet: (context) => showBibConflictsSheet(context),
      showTimingConflictsSheet: (context) => showTimingConflictsSheet(context),
      testMode: useTestData,
    );
    
    _reviewResultsStep = ReviewResultsStep();
    
    _shareResultsStep = ShareResultsStep();
  }

  Future<void> loadResults() async {
    final TimingData? savedResults = await DatabaseHelper.instance.getRaceResultsData(raceId);
    if (savedResults != null) {
      _reviewResultsStep.timingData = savedResults;
      _loadResultsStep.resultsLoaded = true;
      
      // Check for conflicts in the loaded data
      _loadResultsStep.hasBibConflicts = containsBibConflicts(savedResults.runnerRecords);
      _loadResultsStep.hasTimingConflicts = containsTimingConflicts(savedResults);
    }
  }
  
  Future<void> saveRaceResults() async {
    if (_reviewResultsStep.timingData != null) {
      await DatabaseHelper.instance.saveRaceResults(
        raceId,
        _reviewResultsStep.timingData!,
      );
    }
  }
  
  Future<void> processReceivedData(BuildContext context) async {
    String? bibRecordsData = devices.bibRecorder?.data;
    String? finishTimesData = devices.raceTimer?.data;
    if (bibRecordsData != null && finishTimesData != null) {
      final List<RunnerRecord> runnerRecords = await processEncodedBibRecordsData(
        bibRecordsData,
        context,
        raceId
      );
      
      final TimingData? processedTimingData = await processEncodedTimingData(
        finishTimesData,
        context
      );
      
      _reviewResultsStep.timingData = processedTimingData;
      _reviewResultsStep.runnerRecords = runnerRecords;
      
      _loadResultsStep.resultsLoaded = true;
      _loadResultsStep.hasBibConflicts = containsBibConflicts(runnerRecords);
      _loadResultsStep.hasTimingConflicts = containsTimingConflicts(processedTimingData!);
      
      if (!_loadResultsStep.hasBibConflicts && !_loadResultsStep.hasTimingConflicts) {
        _reviewResultsStep.timingData = await _mergeRunnerRecordsWithTimingData(processedTimingData, runnerRecords);
        await saveRaceResults();
      }
    }
  }

  Future<TimingData> _mergeRunnerRecordsWithTimingData(TimingData timingData, List<RunnerRecord> runnerRecords) async {
    // TimingData newTimingData = TimingData(records: [], endTime: timingData.endTime);
    final List<TimingRecord> records = timingData.records.where((record) => record.type == RecordType.runnerTime).toList();
    // print('records length: ${records.length}');
    // print('runnerRecords length: ${runnerRecords.length}');
    for (var i = 0; i < records.length; i++) {
      final runnerRecord = runnerRecords.length > i ? runnerRecords[i] : null;
      final timingRecord = records[i];
      // print('\nrunnerRecord: ${runnerRecord?.toMap()}');
      // print('timingRecord: ${timingRecord.toMap()}\n');
      if (runnerRecord == null) {
        throw Exception('Runner record is null');
      }
      timingData.mergeRunnerData(
        timingRecord,
        runnerRecord,
        index: i,
      );
    }
    // print('timingData: ${timingData}');
    // print('runnerRecords: ${timingData.runnerRecords}');
    return timingData;
  }
  
  Future<void> _loadTestData(BuildContext context) async {
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

  Future<bool> showPostRaceFlow(BuildContext context, bool dismissible) async {
    // Get steps
    final steps = _getSteps();
    
    // Show the flow
    return await showFlow(
      context: context,
      steps: steps,
      showProgressIndicator: dismissible,
    );
  }

  Future<void> showBibConflictsSheet(BuildContext context) async {
    if (_reviewResultsStep.runnerRecords == null) return;
    
    final List<RunnerRecord>? updatedRunnerRecords = await sheet(
      context: context,
      title: 'Resolve Bib Numbers',
      body: BibConflictsOverview(
        records: _reviewResultsStep.runnerRecords!,
        raceId: raceId,
        onConflictSelected: (records) {
          Navigator.pop(context, records);
        },
      ),
    );

    debugPrint('Updated runner records: ${updatedRunnerRecords?[1].toMap()}!!!');
    
    // Update runner records if a result was returned
    if (updatedRunnerRecords != null) {
      _reviewResultsStep.runnerRecords = updatedRunnerRecords;
      
      // Check if conflicts have been resolved
      _loadResultsStep.hasBibConflicts = containsBibConflicts(updatedRunnerRecords);
      _loadResultsStep.hasTimingConflicts = containsTimingConflicts(_reviewResultsStep.timingData!);
    
      // If all conflicts resolved, save results
      if (!_loadResultsStep.hasBibConflicts && !_loadResultsStep.hasTimingConflicts) {
        _reviewResultsStep.timingData = await _mergeRunnerRecordsWithTimingData(_reviewResultsStep.timingData!, _reviewResultsStep.runnerRecords!);
        await saveRaceResults();
      }
    }
  }

  Future<void> showTimingConflictsSheet(BuildContext context) async {
    if (_reviewResultsStep.timingData == null) return;
    
    // final conflictingRecords = getConflictingRecords(_reviewResultsStep.timingData!.records, _reviewResultsStep.runnerRecords!);
    final updatedTimingData = await sheet(
      context: context,
      title: 'Merge Conflicts',
      body: MergeConflictsScreen(
        raceId: raceId,
        timingData: _reviewResultsStep.timingData!,
        runnerRecords: _reviewResultsStep.runnerRecords!,
        // onComplete: (TimingData timingData) async {
        //   _reviewResultsStep.timingData = timingData;
        //   _loadResultsStep.hasTimingConflicts = containsTimingConflicts(timingData);
        //   if (!_loadResultsStep.hasBibConflicts && !_loadResultsStep.hasTimingConflicts) {
        //     _reviewResultsStep.timingData = await _mergeRunnerRecordsWithTimingData(_reviewResultsStep.timingData!, _reviewResultsStep.runnerRecords!);
        //     await saveRaceResults();
        //   }
        // },
      ),
    );
    
    // Update timing data if a result was returned
    if (updatedTimingData != null) {
      _reviewResultsStep.timingData = updatedTimingData;
      
      // Check if conflicts have been resolved
      _loadResultsStep.hasTimingConflicts = containsTimingConflicts(updatedTimingData);
      
      // If all conflicts resolved, save results
      if (!_loadResultsStep.hasBibConflicts && !_loadResultsStep.hasTimingConflicts) {
        _reviewResultsStep.timingData = await _mergeRunnerRecordsWithTimingData(_reviewResultsStep.timingData!, _reviewResultsStep.runnerRecords!);
        await saveRaceResults();
      }
    }
  }

  List<FlowStep> _getSteps() {
    return [
      _loadResultsStep,
      _reviewResultsStep,
      _shareResultsStep,
    ];
  }

  bool containsBibConflicts(List<RunnerRecord> records) {
    return records.any((record) => record.error != null);
  }

  bool containsTimingConflicts(TimingData data) {
    return data.records.any((record) => record.conflict != null);
  }
}