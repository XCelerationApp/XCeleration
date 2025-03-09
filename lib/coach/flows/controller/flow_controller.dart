import 'package:flutter/material.dart';
import '../../../utils/flow_widget.dart';
import '../../../utils/database_helper.dart';
import '../../../shared/models/race.dart';

// Flow controllers
import '../SetupFlow/controller/setup_flow_controller.dart';
import '../PreRaceFlow/controller/pre_race_flow_controller.dart';
import '../PostRaceFlow/controller/post_race_flow_controller.dart';

/// Master controller for orchestrating all race flows
class FlowController with ChangeNotifier {
  // Race data
  final int raceId;
  Race? _race;
  Race? get race => _race;
  
  // Flow state
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  // Flow controllers
  late SetupFlowController _setupFlowController;
  late PreRaceFlowController _preRaceFlowController;
  late PostRaceFlowController _postRaceFlowController;
  
  /// Constructor for FlowController
  FlowController({required this.raceId}) {
    _setupFlowController = SetupFlowController(raceId: raceId);
    _preRaceFlowController = PreRaceFlowController(raceId: raceId);
    _postRaceFlowController = PostRaceFlowController(raceId: raceId);
    
    // Load race data
    loadRace();
  }
  
  /// Load the race data
  Future<void> loadRace() async {
    _isLoading = true;
    notifyListeners();
    
    final raceData = await DatabaseHelper.instance.getRaceById(raceId);
    if (raceData != null) {
      _race = raceData;
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Determine the current flow state and start the appropriate flow
  Future<bool> startCurrentFlow(BuildContext context) async {
    if (_race == null) {
      await loadRace();
      if (_race == null) return false;
    }
    
    switch (_race!.flowState) {
      case 'setup':
        return await startSetupFlow(context);
      case 'pre_race':
        return await startPreRaceFlow(context);
      case 'post_race':
        return await startPostRaceFlow(context);
      case 'finished':
        // Race is already finished
        return true;
      default:
        // Default to setup if unknown state
        return await startSetupFlow(context);
    }
  }
  
  /// Start the setup flow
  Future<bool> startSetupFlow(BuildContext context) async {
    _isLoading = true;
    notifyListeners();
    
    final result = await _setupFlowController.startFlow(context);
    
    // Reload race data to get updated state
    await loadRace();
    
    // If setup was completed and moved to pre-race, auto-continue
    if (result && _race?.flowState == 'pre_race') {
      await startPreRaceFlow(context);
    }
    
    _isLoading = false;
    notifyListeners();
    
    return result;
  }
  
  /// Start the pre-race flow
  Future<bool> startPreRaceFlow(BuildContext context) async {
    _isLoading = true;
    notifyListeners();
    
    final result = await _preRaceFlowController.startFlow(context);
    
    // Reload race data to get updated state
    await loadRace();
    
    // If pre-race was completed and moved to post-race, auto-continue
    if (result && _race?.flowState == 'post_race') {
      await startPostRaceFlow(context);
    }
    
    _isLoading = false;
    notifyListeners();
    
    return result;
  }
  
  /// Start the post-race flow
  Future<bool> startPostRaceFlow(BuildContext context) async {
    _isLoading = true;
    notifyListeners();
    
    final result = await _postRaceFlowController.startFlow(context);
    
    // Reload race data to get updated state
    await loadRace();
    
    _isLoading = false;
    notifyListeners();
    
    return result;
  }
  
  /// Update the race flow state in the database
  Future<void> updateRaceFlowState(String newState) async {
    await DatabaseHelper.instance.updateRaceFlowState(raceId, newState);
    await loadRace();
  }
  
  /// Generic method to show a flow with the given steps
  Future<bool> showFlow({
    required BuildContext context,
    required List<FlowStep> steps,
    bool showProgressIndicator = false,
    bool dismissible = true,
  }) async {
    _isLoading = true;
    notifyListeners();
    
    final result = await showFlowWidget(
      context: context,
      steps: steps,
      showProgressIndicator: showProgressIndicator,
      dismissible: dismissible,
    );
    
    _isLoading = false;
    notifyListeners();
    
    return result;
  }
  
  @override
  void dispose() {
    _setupFlowController.dispose();
    _preRaceFlowController.dispose();
    _postRaceFlowController.dispose();
    super.dispose();
  }
}
