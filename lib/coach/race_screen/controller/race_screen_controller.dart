import 'package:flutter/material.dart';
import 'package:xcelerate/coach/race_screen/screen/race_screen.dart';
import 'package:xcelerate/utils/sheet_utils.dart' show sheet;
import '../../../utils/enums.dart';
import '../../../utils/database_helper.dart';
import '../../../shared/models/race.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../coach/flows/controller/flow_controller.dart';

/// Controller class for the RaceScreen that handles all business logic
class RaceScreenController with ChangeNotifier {
  // Race data
  Race? race;
  int raceId;
  bool isRaceSetup = false;
  late TabController tabController;
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

  static void showRaceScreen(BuildContext context, int raceId,
      {RaceScreenPage page = RaceScreenPage.main}) {
    sheet(
      context: context,
      body: RaceScreen(
        raceId: raceId,
        page: page,
      ),
    );
  }

  Future<void> init(BuildContext context) async {
    race = await loadRace();
    flowController = MasterFlowController(raceId: raceId, race: race);
    notifyListeners();
    if (race != null) {
      await continueRaceFlow(context);
    }
  }

  /// Load the race data and any saved results
  Future<Race?> loadRace() async {
    final loadedRace = await DatabaseHelper.instance.getRaceById(raceId);
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
  DevicesManager createDevices(DeviceType deviceType,
      {DeviceName deviceName = DeviceName.coach, String data = ''}) {
    return DeviceConnectionService.createDevices(
      deviceName,
      deviceType,
      data: data,
    );
  }
}
