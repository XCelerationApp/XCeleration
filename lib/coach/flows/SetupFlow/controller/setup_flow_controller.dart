import 'package:flutter/material.dart';
import '../../controller/flow_controller.dart';
import '../../../../utils/database_helper.dart';
import '../../../../utils/flow_widget.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../runners_management_screen/screen/runners_management_screen.dart';

/// Controller for managing the race setup flow
class SetupFlowController extends FlowController {
  /// Constructor
  SetupFlowController({required int raceId}) : super(raceId: raceId);
  
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
  
  /// Start the setup flow
  Future<bool> startFlow(BuildContext context) async {
    // Create the UI components
    final runnersManagementScreen = RunnersManagementScreen(
      raceId: raceId, 
      showHeader: false, 
      onBack: null,
      onContentChanged: () {}, // This will be handled by the FlowStep
    );
    
    final completionScreen = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 120, color: AppColors.primaryColor),
          const SizedBox(height: 32),
          Text(
            'Race Setup Complete!',
            style: AppTypography.titleSemibold.copyWith(color: AppColors.darkColor),
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re ready to start managing your race.',
            style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
          ),
        ],
      ),
    );
    
    // Create the flow steps
    final steps = await createSetupFlowSteps(
      runnersManagementScreen,
      completionScreen,
    );
    
    // Show the flow
    final result = await showFlow(
      context: context,
      steps: steps,
      dismissible: true,
    );
    
    // If flow was completed successfully, update the race state
    if (result) {
      final runnersLoaded = await checkIfRunnersAreLoaded();
      if (runnersLoaded) {
        await updateFlowStateToPreRace();
      }
    }
    
    return result;
  }
  
  /// Initialize the race setup flow with UI elements
  Future<List<FlowStep>> createSetupFlowSteps(
    Widget runnersManagementScreen,
    Widget completionScreen,
  ) async {
    return [
      FlowStep(
        title: 'Load Runners',
        description: 'Add runners to your race by entering their information or importing from a previous race. Each team needs at least 5 runners to proceed.',
        content: runnersManagementScreen,
        canProceed: checkIfRunnersAreLoaded,
      ),
      FlowStep(
        title: 'Setup Complete',
        description: 'Great job! You\'ve finished setting up your race. Click Next to begin the pre-race preparations.',
        content: completionScreen,
        canProceed: () async => true,
      ),
    ];
  }
  
  /// Update the race flow state when setup is complete
  Future<void> updateFlowStateToPreRace() async {
    await updateRaceFlowState('pre_race');
  }
}
