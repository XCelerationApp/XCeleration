import 'package:flutter/material.dart';
import 'package:xcelerate/coach/merge_conflicts_screen/model/timing_data.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart' show RunnerRecord;
import '../../../utils/database_helper.dart';
import '../../../shared/models/race.dart';
import '../../../utils/runner_time_functions.dart';
import '../../../utils/encode_utils.dart';
import '../../../utils/enums.dart';
import '../../../core/services/device_connection_service.dart';
import '../../flows/model/flow_model.dart';
import '../../../coach/flows/controller/flow_controller.dart' as flows;

/// Controller class for the RaceScreen that handles all business logic
class RaceScreenController with ChangeNotifier {
  // Race data
  Race? race;
  int raceId;
  bool isRaceSetup = false;
  bool resultsLoaded = false;
  List<RunnerRecord>? runnerRecords;
  TimingData? timingData;
  bool hasBibConflicts = false;
  bool hasTimingConflicts = false;
  
  // Flow state
  String get flowState => race?.flowState ?? 'setup';

  // Getters for UI
  bool get raceSetup => isRaceSetup;
  
  // Constructor
  RaceScreenController({required this.raceId}) {
    loadRace();
  }
  
  /// Load the race data and any saved results
  Future<void> loadRace() async {
    final loadedRace = await DatabaseHelper.instance.getRaceById(raceId);
    race = loadedRace;
    notifyListeners();
    
    isRaceSetup = await DatabaseHelper.instance.checkIfRaceRunnersAreLoaded(raceId);
    
    // Load saved results if they exist
    final savedResults = await DatabaseHelper.instance.getRaceResultsData(raceId);
    if (savedResults != null) {
      runnerRecords = savedResults['runnerRecords'];
      timingData = savedResults['timingData'];
      resultsLoaded = true;
      
      // Check for conflicts in the loaded data
      hasBibConflicts = runnerRecords != null && containsBibConflicts(runnerRecords!);
      hasTimingConflicts = timingData != null && containsTimingConflicts(timingData!);
      notifyListeners();
    }
    
    continueRaceFlow();
  }
  
  /// Continue the race flow based on the current state
  Future<void> continueRaceFlow() async {
    if (race == null) return;
    
    // Handle different flow states (no implementation here, UI will use this information)
    notifyListeners();
  }
  
  /// Save race results to the database
  Future<void> saveRaceResults() async {
    if (runnerRecords != null && timingData != null) {
      await DatabaseHelper.instance.saveRaceResults(
        raceId,
        {
          'runnerRecords': runnerRecords,
          'timingData': timingData,
        },
      );
    }
  }
  
  /// Update the race flow state
  Future<void> updateRaceFlowState(String newState) async {
    await DatabaseHelper.instance.updateRaceFlowState(raceId, newState);
    race = race?.copyWith(flowState: newState);
    notifyListeners();
  }
  
  /// Check if runners are loaded and each team has minimum required runners
  Future<bool> checkIfRunnersAreLoaded() async {
    final currentRace = await DatabaseHelper.instance.getRaceById(raceId);
    final raceRunners = await DatabaseHelper.instance.getRaceRunners(raceId);
    
    // Check if we have any runners at all
    if (raceRunners.isEmpty) {
      return false;
    }

    // Check if each team has at least minimum runners for a race
    final teamRunnerCounts = <String, int>{};
    for (final runner in raceRunners) {
      final team = runner.school;
      teamRunnerCounts[team] = (teamRunnerCounts[team] ?? 0) + 1;
    }

    // Verify each team in the race has enough runners (minimum 5)
    for (final teamName in currentRace!.teams) {
      final runnerCount = teamRunnerCounts[teamName] ?? 0;
      if (runnerCount < 5) {
        return false;
      }
    }

    return true;
  }
  
  /// Get encoded runners data for sharing
  Future<String> getEncodedRunnersData() async {
    final List<RunnerRecord> runners = await getRunnersData();
    return runners.map((runner) => [
      runner.bib,
      runner.name,
      runner.school,
      runner.grade
    ].join(',')).join(' ');
  }
  
  /// Get the list of runners for the race
  Future<List<RunnerRecord>> getRunnersData() async {
    return await DatabaseHelper.instance.getRaceRunners(raceId);
  }
  
  /// Reset results loading state
  void resetResultsLoading() {
    resultsLoaded = false;
    hasBibConflicts = false;
    hasTimingConflicts = false;
    notifyListeners();
  }
  
  /// Check if there are timing conflicts in the data
  bool containsTimingConflicts(TimingData data) {
    return getConflictingRecords(data.records, data.records.length).isNotEmpty;
  }
  
  /// Check if there are bib conflicts in the runner records
  bool containsBibConflicts(List<RunnerRecord> records) {
    return records.any((record) => record.error != null);
  }
  
  /// Create device connections list for communication
  Map<DeviceName, Map<String, dynamic>> createDeviceConnectionList(
    DeviceType deviceType, 
    {DeviceName deviceName = DeviceName.coach, String data = ''}
  ) {
    return DeviceConnectionService.createOtherDeviceList(
      deviceName,
      deviceType,
      data: data,
    );
  }
  
  /// Process received data from other devices
  Future<void> processReceivedData(String? bibRecordsData, String? finishTimesData, BuildContext context) async {
    if (bibRecordsData == null || finishTimesData == null) {
      return;
    }
    
    var processedRunnerRecords = await processEncodedBibRecordsData(bibRecordsData, context, raceId);
    final processedTimingData = await processEncodedTimingData(finishTimesData, context);
    
    if (processedRunnerRecords.isNotEmpty && processedTimingData != null) {
      processedTimingData.records = await syncBibData(
        processedRunnerRecords.length, 
        processedTimingData.records, 
        processedTimingData.endTime, 
        context
      );
      
      runnerRecords = processedRunnerRecords;
      timingData = processedTimingData;
      resultsLoaded = true;
      hasBibConflicts = containsBibConflicts(processedRunnerRecords);
      hasTimingConflicts = containsTimingConflicts(processedTimingData);
      
      await saveRaceResults();
      notifyListeners();
    }
  }

  /// Setup the race with runners
  /// Delegates to FlowController for flow management
  Future<bool> setupRace(BuildContext context, List<FlowStep> steps) async {
    return await flows.FlowController.setupFlow(context, steps);
  }

  /// Pre-race setup flow
  /// Delegates to FlowController for flow management
  Future<bool> preRaceSetup(BuildContext context, List<FlowStep> steps) async {
    return await flows.FlowController.preRaceFlow(context, steps);
  }

  /// Post-race setup flow
  /// Delegates to FlowController for flow management
  Future<bool> postRaceSetup(BuildContext context, List<FlowStep> steps) async {
    return await flows.FlowController.postRaceFlow(context, steps);
  }
}
