import 'package:flutter/material.dart';
import 'package:xcelerate/coach/race_screen/widgets/bib_conflicts_sheet.dart';
import 'package:xcelerate/coach/race_screen/widgets/timing_conflicts_sheet.dart';
import 'package:xcelerate/core/services/device_connection_service.dart';
import 'package:xcelerate/coach/flows/controller/flow_controller.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import 'package:xcelerate/utils/enums.dart';
import '../../../../utils/database_helper.dart';
import '../../../../utils/runner_time_functions.dart';
import '../../../../utils/encode_utils.dart';
import '../../../merge_conflicts_screen/model/timing_data.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../steps/load_results/load_results_step.dart';
import '../steps/review_results/review_results_step.dart';
import '../steps/save_results/save_results_step.dart';

class PostRaceController {
  final int raceId;
  
  // Controller state
  Map<DeviceName, Map<String, dynamic>> otherDevices = {};
  
  // Flow steps
  late LoadResultsStep _loadResultsStep;
  late ReviewResultsStep _reviewResultsStep;
  late SaveResultsStep _saveResultsStep;
  
  // Constructor
  PostRaceController({required this.raceId}) {
    otherDevices = DeviceConnectionService.createOtherDeviceList(
      DeviceName.coach,
      DeviceType.browserDevice,
    );
    
    _initializeSteps();
  }
  
  // Initialize the flow steps
  void _initializeSteps() {
    _loadResultsStep = LoadResultsStep(
      otherDevices: otherDevices,
      reloadDevices: () => loadResults(),
      onResultsLoaded: (context) => processReceivedData(context),
      showBibConflictsSheet: (context) => showBibConflictsSheet(context),
      showTimingConflictsSheet: (context) => showTimingConflictsSheet(context),
    );
    
    _reviewResultsStep = ReviewResultsStep();
    
    _saveResultsStep = SaveResultsStep();
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
    String? bibRecordsData = otherDevices[DeviceName.bibRecorder]?['data'];
    String? finishTimesData = otherDevices[DeviceName.raceTimer]?['data'];
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
        await saveRaceResults();
      }
    }
  }
  
  Future<bool> showPostRaceFlow(BuildContext context, bool dismissible) async {
    // Get steps
    final steps = _getSteps();
    
    return await showFlow(
      context: context,
      steps: steps,
      showProgressIndicator: dismissible,
    );
  }

  Future<void> showBibConflictsSheet(BuildContext context) async {
    if (_reviewResultsStep.runnerRecords == null) return;
    
    final updatedRunnerRecords = await showModalBottomSheet<List<RunnerRecord>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BibConflictsSheet(runnerRecords: _reviewResultsStep.runnerRecords!),
    );
    
    // Update runner records if a result was returned
    if (updatedRunnerRecords != null) {
      _reviewResultsStep.runnerRecords = updatedRunnerRecords;
      
      // Check if conflicts have been resolved
      _loadResultsStep.hasBibConflicts = containsBibConflicts(updatedRunnerRecords);
      
      // If all conflicts resolved, save results
      if (!_loadResultsStep.hasBibConflicts && !_loadResultsStep.hasTimingConflicts) {
        await saveRaceResults();
      }
    }
  }

  Future<void> showTimingConflictsSheet(BuildContext context) async {
    if (_reviewResultsStep.timingData == null) return;
    
    final conflictingRecords = getConflictingRecords(_reviewResultsStep.timingData!.records, _reviewResultsStep.timingData!.records.length);
    final updatedTimingData = await showModalBottomSheet<TimingData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimingConflictsSheet(
        conflictingRecords: conflictingRecords,
        timingData: _reviewResultsStep.timingData!,
        runnerRecords: _reviewResultsStep.runnerRecords!,
        raceId: raceId,
      ),
    );
    
    // Update timing data if a result was returned
    if (updatedTimingData != null) {
      _reviewResultsStep.timingData = updatedTimingData;
      
      // Check if conflicts have been resolved
      _loadResultsStep.hasTimingConflicts = containsTimingConflicts(updatedTimingData);
      
      // If all conflicts resolved, save results
      if (!_loadResultsStep.hasBibConflicts && !_loadResultsStep.hasTimingConflicts) {
        await saveRaceResults();
      }
    }
  }

  List<FlowStep> _getSteps() {
    return [
      _loadResultsStep,
      _reviewResultsStep,
      _saveResultsStep,
    ];
  }

  bool containsBibConflicts(List<RunnerRecord> records) {
    return records.any((record) => record.error != null);
  }

  bool containsTimingConflicts(TimingData data) {
    return getConflictingRecords(data.records, data.records.length).isNotEmpty;
  }
}