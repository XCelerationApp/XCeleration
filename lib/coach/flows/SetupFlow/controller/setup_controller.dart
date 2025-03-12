import '../../controller/flow_controller.dart';
import '../../model/flow_model.dart';
import 'package:flutter/material.dart';
import '../../../runners_management_screen/screen/runners_management_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';

class SetupController {
  final int raceId;

  SetupController({required this.raceId});


  Future<bool> showSetupFlow(BuildContext context, bool showProgressIndicator) {
    return showFlow(
      context: context,
      showProgressIndicator: showProgressIndicator,
      steps: _getSteps(),
    );
  }
  List<FlowStep> _getSteps() {
    late final FlowStep runnersStep;
    runnersStep = FlowStep(
      title: 'Load Runners',
      description: 'Add runners to your race by entering their information or importing from a previous race. Each team needs at least 5 runners to proceed.',
      content: RunnersManagementScreen(
        raceId: raceId,
        showHeader: false,
        onBack: null,
        onContentChanged: () => runnersStep.notifyContentChanged(),
      ),
      canProceed: () => RunnersManagementScreen.checkMinimumRunnersLoaded(raceId),
    );

    final completionStep = FlowStep(
      title: 'Setup Complete',
      description: 'Great job! You\'ve finished setting up your race. Click Next to begin the pre-race preparations.',
      content: Center(
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
      ),
      canProceed: () async => true,
    );

    return [runnersStep, completionStep];
  }

}