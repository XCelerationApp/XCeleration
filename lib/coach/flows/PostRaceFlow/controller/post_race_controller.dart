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
  late DevicesManager devices;
  
  // Flow steps
  late LoadResultsStep _loadResultsStep;
  late ReviewResultsStep _reviewResultsStep;
  late SaveResultsStep _saveResultsStep;
  
  // Constructor
  PostRaceController({required this.raceId}) {
    devices = DeviceConnectionService.createDevices(
      DeviceName.coach,
      DeviceType.browserDevice,
    );
    
    _initializeSteps();
  }
  
  // Initialize the flow steps
  void _initializeSteps() {
    _loadResultsStep = LoadResultsStep(
      devices: devices,
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
    String? bibRecordsData = devices.bibRecorder?.data;
    String? finishTimesData = devices.raceTimer?.data;
    if (bibRecordsData != null && finishTimesData != null) {
      await processEncodedBibRecordsData(
        bibRecordsData,
        context,
        raceId
      );
      
      final processedTimingData = await processEncodedTimingData(
        finishTimesData,
        context
      );
      
      _reviewResultsStep.timingData = processedTimingData;
      
      _loadResultsStep.resultsLoaded = true;
      _loadResultsStep.hasBibConflicts = containsBibConflicts(processedTimingData!.runnerRecords);
      _loadResultsStep.hasTimingConflicts = containsTimingConflicts(processedTimingData);
      
      await saveRaceResults();
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
    if (_reviewResultsStep.timingData == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BibConflictsSheet(runnerRecords: _reviewResultsStep.timingData!.runnerRecords),
    );
  }

  Future<void> showTimingConflictsSheet(BuildContext context) async {
    if (_reviewResultsStep.timingData == null) return;
    
    final conflictingRecords = getConflictingRecords(_reviewResultsStep.timingData!.records, _reviewResultsStep.timingData!.records.length);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimingConflictsSheet(
        conflictingRecords: conflictingRecords,
        timingData: _reviewResultsStep.timingData!,
        runnerRecords: _reviewResultsStep.timingData!.runnerRecords,
        raceId: raceId,
      ),
    );
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