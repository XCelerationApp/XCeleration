import 'package:flutter/material.dart';
import '../../../utils/database_helper.dart';
import '../../../shared/models/race.dart';
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


  
  // Constructor
  RaceScreenController({required this.raceId});

  Future<void> init(BuildContext context) async {
    race = await loadRace();
    if (race == null) throw Exception('Race not found');

    flowController = MasterFlowController(raceId: raceId, race: race!);
    await continueRaceFlow(context);
  }
  
  /// Load the race data and any saved results
  Future<Race?> loadRace() async {
    final loadedRace = await DatabaseHelper.instance.getRaceById(raceId);
    notifyListeners();
    return loadedRace;
  }
  
  /// Update the race flow state
  Future<void> updateRaceFlowState(String newState) async {
    await DatabaseHelper.instance.updateRaceFlowState(raceId, newState);
    race = race?.copyWith(flowState: newState);
    notifyListeners();
  }

  /// Continue the race flow based on the current state
  Future<void> continueRaceFlow(BuildContext context) async {
    await flowController.continueRaceFlow(context);
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
}
