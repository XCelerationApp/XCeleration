import 'package:flutter/material.dart';
import '../controller/setup_flow_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../runners_management_screen/screen/runners_management_screen.dart';

class SetupFlowScreen extends StatefulWidget {
  final int raceId;
  final Function onComplete;
  
  const SetupFlowScreen({
    Key? key,
    required this.raceId,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends State<SetupFlowScreen> {
  late SetupFlowController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = SetupFlowController(raceId: widget.raceId);
    _startSetupFlow();
  }
  
  Future<void> _startSetupFlow() async {
    // Create the runners management screen
    final runnersManagementScreen = RunnersManagementScreen(
      raceId: widget.raceId,
      showHeader: false,
      onBack: null,
      onContentChanged: () async {},
    );
    
    // Create completion screen
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
    
    // Create flow steps
    final steps = await _controller.createSetupFlowSteps(
      runnersManagementScreen,
      completionScreen,
    );
    
    // Show the flow
    final isCompleted = await _controller.showFlow(
      context: context,
      steps: steps,
      showProgressIndicator: true,
    );
    
    if (isCompleted) {
      final isRunnersLoaded = await _controller.checkIfRunnersAreLoaded();
      if (isRunnersLoaded) {
        await _controller.updateFlowStateToPreRace();
        widget.onComplete();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(); // This widget doesn't need a UI as it only shows the flow
  }
}
