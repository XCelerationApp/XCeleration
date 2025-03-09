import 'package:flutter/material.dart';
import '../../../utils/database_helper.dart';
import '../../../shared/models/race.dart';
import '../../../utils/runner_time_functions.dart';
import '../../../utils/encode_utils.dart';
import '../../../utils/enums.dart';
import '../../../core/services/device_connection_service.dart';
import '../../flows/controller/flow_controller.dart';

/// Controller class for the RaceScreen that handles all business logic
class RaceScreenController with ChangeNotifier {
  // Race data
  Race? race;
  int raceId;
  bool isRaceSetup = false;
  bool resultsLoaded = false;
  List<Map<String, dynamic>>? runnerRecords;
  Map<String, dynamic>? timingData;
  bool hasBibConflicts = false;
  bool hasTimingConflicts = false;
  
  // Flow controller
  late FlowController flowController;
  
  // Flow state
  String get flowState => race?.flowState ?? 'setup';

  // Getters for UI
  bool get raceSetup => isRaceSetup;
  bool get isLoading => flowController.isLoading;
  
  // Constructor
  RaceScreenController({required this.raceId}) {
    flowController = FlowController(raceId: raceId);
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
  }
  
  /// Start current flow based on race state
  Future<bool> startCurrentFlow(BuildContext context) async {
    final result = await flowController.startCurrentFlow(context);
    
    // Reload race data after flow completion to ensure UI is up to date
    if (result) {
      await loadRace();
    }
    
    return result;
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
      final team = runner['school'] as String;
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
    final runners = await getRunnersData();
    return runners.map((runner) => [
      runner['bib_number'],
      runner['name'],
      runner['school'],
      runner['grade']
    ].join(',')).join(' ');
  }
  
  /// Get the list of runners for the race
  Future<List<dynamic>> getRunnersData() async {
    return await DatabaseHelper.instance.getRaceRunners(raceId);
  }
  
  /// Get race runners (used in the runners tab)
  Future<List<Map<String, dynamic>>> getRaceRunners() async {
    return await DatabaseHelper.instance.getRaceRunners(raceId);
  }
  
  /// Get race results (used in the results tab)
  Future<List<Map<String, dynamic>>> getRaceResults() async {
    final results = await DatabaseHelper.instance.getRaceResultsData(raceId);
    if (results == null) return [];
    
    // Extract runner records for display
    final runnersList = results['runnerRecords'] as List<dynamic>;
    return List<Map<String, dynamic>>.from(runnersList);
  }
  
  /// Reset results loading state
  void resetResultsLoading() {
    resultsLoaded = false;
    hasBibConflicts = false;
    hasTimingConflicts = false;
    notifyListeners();
  }
  
  /// Check if there are timing conflicts in the data
  bool containsTimingConflicts(Map<String, dynamic> data) {
    return getConflictingRecords(data['records'], data['records'].length).isNotEmpty;
  }
  
  /// Check if there are bib conflicts in the runner records
  bool containsBibConflicts(List<dynamic> records) {
    return records.any((record) => record['error'] != null);
  }
  

  @override
  void dispose() {
    flowController.dispose();
    super.dispose();
  }
}
