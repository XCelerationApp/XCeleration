import 'package:flutter/material.dart';
import '../../../utils/database_helper.dart';
import '../../../shared/models/race.dart';
import '../../../utils/runner_time_functions.dart';
import '../../../utils/enums.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../coach/flows/controller/flow_controller.dart';

/// Controller class for the RaceScreen that handles all business logic
class RaceScreenController with ChangeNotifier {
  // Race data
  Race? race;
  int raceId;
  bool isRaceSetup = false;
  // bool resultsLoaded = false;
  // List<Map<String, dynamic>>? runnerRecords;
  // Map<String, dynamic>? timingData;
  // bool hasBibConflicts = false;
  // bool hasTimingConflicts = false;

  late MasterFlowController flowController;
  
  // Flow state
  String get flowState => race?.flowState ?? 'setup';

  // Getters for UI
  bool get raceSetup => isRaceSetup;
  
  // Constructor
  RaceScreenController({required this.raceId}) {
    flowController = MasterFlowController(raceId: raceId);
    loadRace();
  }
  
  /// Load the race data and any saved results
  Future<void> loadRace() async {
    final loadedRace = await DatabaseHelper.instance.getRaceById(raceId);
    race = loadedRace;
    notifyListeners();
    
    isRaceSetup = await DatabaseHelper.instance.checkIfRaceRunnersAreLoaded(raceId);
    
    
    continueRaceFlow();
  }
  
  /// Continue the race flow based on the current state
  Future<void> continueRaceFlow() async {
    if (race == null) return;
    
    // Handle different flow states (no implementation here, UI will use this information)
    notifyListeners();
  }
  
  
  /// Update the race flow state
  Future<void> updateRaceFlowState(String newState) async {
    await DatabaseHelper.instance.updateRaceFlowState(raceId, newState);
    race = race?.copyWith(flowState: newState);
    notifyListeners();
  }

  
  // /// Reset results loading state
  // void resetResultsLoading() {
  //   resultsLoaded = false;
  //   hasBibConflicts = false;
  //   hasTimingConflicts = false;
  //   notifyListeners();
  // }
  
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

  /// Setup the race with runners
  /// Delegates to FlowController for flow management
  Future<bool> setupRace(BuildContext context) async {
    return await flowController.setupFlow(context);
  }

  /// Pre-race setup flow
  /// Delegates to FlowController for flow management
  Future<bool> preRaceSetup(BuildContext context) async {
    return await flowController.preRaceFlow(context);
  }

  /// Post-race setup flow
  /// Delegates to FlowController for flow management
  Future<bool> postRaceSetup(BuildContext context) async {
    return await flowController.postRaceFlow(context);
  }
}
