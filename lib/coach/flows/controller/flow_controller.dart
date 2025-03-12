import 'package:flutter/material.dart';
import '../model/flow_model.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/sheet_utils.dart';
import '../../../core/theme/typography.dart';
import '../../flows/widgets/flow_indicator.dart';
import '../SetupFlow/controller/setup_controller.dart';
import '../PreRaceFlow/controller/pre_race_controller.dart';
import '../PostRaceFlow/controller/post_race_controller.dart';

import 'dart:async';

/// Controller class for handling all flow-related operations
class MasterFlowController {
  final int raceId;
  late SetupController setupController;
  late PreRaceController preRaceController;
  late PostRaceController postRaceController;

  MasterFlowController({required this.raceId}) {
    setupController = SetupController(raceId: raceId);
    preRaceController = PreRaceController(raceId: raceId);
    postRaceController = PostRaceController(raceId: raceId);
  }
  
  /// Setup the race with runners
  /// Shows a flow with the provided steps and handles user progression
  Future<bool> setupFlow(BuildContext context) async {
    return await setupController.showSetupFlow(context, true);
  }

  /// Pre-race setup flow
  /// Shows a flow for pre-race setup and coordination
  Future<bool> preRaceFlow(BuildContext context) async {
    return await preRaceController.showPreRaceFlow(context, true);
  }

  /// Post-race setup flow
  /// Shows a flow for post-race data collection and result processing
  Future<bool> postRaceFlow(BuildContext context) async {
    return await postRaceController.showPostRaceFlow(context, true);
  }

}

class FlowController extends ChangeNotifier {
  int _currentIndex = 0;
  final List<FlowStep> steps;
  StreamSubscription<void>? _contentChangeSubscription;

  FlowController(this.steps) {
    _subscribeToCurrentStep();
  }

  void _subscribeToCurrentStep() {
    _contentChangeSubscription?.cancel();
    _contentChangeSubscription = currentStep.onContentChange.listen((_) {
      notifyListeners();
    });
  }

  int get currentIndex => _currentIndex;
  bool get canGoBack => _currentIndex > 0;
  bool get canGoForward => _currentIndex < steps.length - 1;

  FlowStep get currentStep => steps[_currentIndex];

  Future<bool> canProceedToNextStep() async {
    if (currentStep.canProceed == null) return true;
    try {
      return await currentStep.canProceed!();
    } catch (e) {
      print('Error in canProceed: $e');
      return false; // Handle errors gracefully
    }
  }

  Future<void> goToNext() async {
    if (canGoForward && await canProceedToNextStep()) {
      currentStep.onNext?.call();
      _currentIndex++;
      _subscribeToCurrentStep();
      notifyListeners();
    }
  }

  void goBack() {
    if (canGoBack) {
      currentStep.onBack?.call();
      _currentIndex--;
      _subscribeToCurrentStep();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _contentChangeSubscription?.cancel();
    for (final step in steps) {
      step.dispose();
    }
    super.dispose();
  }
}


Future<bool> showFlow({
  required BuildContext context,
  required List<FlowStep> steps,
  bool showProgressIndicator = true,
}) async {
  final controller = FlowController(steps);
  bool completed = false;

  await sheet(
    context: context,
    title: null,
    takeUpScreen: true,
    body: ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<FlowController>(
        builder: (context, controller, _) {
          final currentStep = controller.currentStep;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showProgressIndicator)
                EnhancedFlowIndicator(
                  totalSteps: steps.length,
                  currentStep: controller.currentIndex,
                  onBack: controller.canGoBack ? controller.goBack : null,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStep.title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentStep.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 120, // Account for bottom padding and button
                        ),
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              currentStep.content,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (controller.canGoForward) {
                        await controller.goToNext();
                      } else {
                        Navigator.pop(context);
                        completed = true;
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      'Next',
                      style: AppTypography.bodySemibold.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  controller.dispose();
  return completed;
}