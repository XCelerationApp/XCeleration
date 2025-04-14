import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/button_components.dart';
import '../model/flow_model.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/sheet_utils.dart';
import '../../flows/widgets/flow_indicator.dart';
import '../SetupFlow/controller/setup_controller.dart';
import '../PreRaceFlow/controller/pre_race_controller.dart';
import '../PostRaceFlow/controller/post_race_controller.dart';
import 'dart:async';
import '../../../utils/database_helper.dart';
import '../../../coach/race_screen/controller/race_screen_controller.dart';
import '../../../core/services/event_bus.dart';

/// Controller class for handling all flow-related operations
class MasterFlowController {
  final RaceScreenController raceController;
  late SetupController setupController;
  late PreRaceController preRaceController;
  late PostRaceController postRaceController;

  MasterFlowController({required this.raceController}) {
    setupController = SetupController(raceId: raceController.raceId);
    preRaceController = PreRaceController(raceId: raceController.raceId);
    postRaceController = PostRaceController(raceId: raceController.raceId, useTestData: true);
  }

  /// Continue the race flow based on the current state
  Future<void> continueRaceFlow(BuildContext context) async {
    if (raceController.race == null) {
      // If race is null, try to load it
      raceController.race = await DatabaseHelper.instance.getRaceById(raceController.raceId);
      if (raceController.race == null) {
        debugPrint('Error: Race not found');
        return;
      }
    }

    switch (raceController.race!.flowState) {
      case 'setup':
        await _setupFlow(context);
        break;
      case 'pre-race':
        await _preRaceFlow(context);
        break;
      case 'post-race':
        await _postRaceFlow(context);
        break;
    }
  }

  /// Update the race flow state
  Future<void> updateRaceFlowState(String newState) async {
    await DatabaseHelper.instance.updateRaceFlowState(raceController.raceId, newState);
    if (raceController.race != null) {
      raceController.race = raceController.race!.copyWith(flowState: newState);
    }
    
    debugPrint('MasterFlowController: Flow state changed to $newState for race: ${raceController.raceId}');
    
    // Fire event (for components that use the event bus)
    EventBus.instance.fire(EventTypes.raceFlowStateChanged, {
      'raceId': raceController.raceId,
      'newState': newState,
      'race': raceController.race,
    });
  }
  
  /// Navigate to the appropriate screen based on flow state
  Future<bool> handleFlowNavigation(BuildContext context, String flowState) async {
    // For completed states, just return to race screen (already there)
    if (flowState.contains('completed') || flowState == 'finished') {
      // Make sure we're on the race details tab
      if (raceController.tabController.index != 0) {
        raceController.tabController.animateTo(0);
      }
      return true;
    }
    
    // For regular states, use the existing flow methods
    switch (flowState) {
      case 'setup':
        return _setupFlow(context);
      case 'pre-race':
        return _preRaceFlow(context);
      case 'post-race':
        return _postRaceFlow(context);
      default:
        debugPrint('Unknown flow state: $flowState');
        return false;
    }
  }

  /// Setup the race with runners
  /// Shows a flow with the provided steps and handles user progression
  Future<bool> _setupFlow(BuildContext context) async {
    final bool completed = await setupController.showSetupFlow(context, true);
    if (!completed) return false;

    // Mark as setup-completed instead of moving directly to pre-race
    await updateRaceFlowState('setup-completed');

    // Return to race screen without starting the next flow automatically
    return true;
  }

  /// Pre-race setup flow
  /// Shows a flow for pre-race setup and coordination
  Future<bool> _preRaceFlow(BuildContext context) async {
    final bool completed = await preRaceController.showPreRaceFlow(context, true);
    if (!completed) return false;
    
    // Mark as pre-race-completed instead of moving directly to post-race
    await updateRaceFlowState('pre-race-completed');
    
    // Return to race screen without starting the next flow automatically
    return true;
  }

  /// Post-race setup flow
  /// Shows a flow for post-race data collection and result processing
  Future<bool> _postRaceFlow(BuildContext context) async {
    final bool completed = await postRaceController.showPostRaceFlow(context, true);
    if (!completed) return false;

    await updateRaceFlowState('post-race-completed');

    // Add a short delay to let the UI settle
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Check if context is still valid after the delay
    if (!context.mounted) return false;
    
    // Return to race details tab
    if (context.mounted) {
      raceController.tabController.animateTo(0);
    }
    return true;
  }
}

class FlowController extends ChangeNotifier {
  int _currentIndex;
  final List<FlowStep> steps;
  StreamSubscription<void>? _contentChangeSubscription;
  final StepChangedCallback? onStepChanged;

  FlowController(this.steps, {int initialIndex = 0, this.onStepChanged}) : _currentIndex = initialIndex {
    _subscribeToCurrentStep();
  }

  void _subscribeToCurrentStep() {
    _contentChangeSubscription?.cancel();
    _contentChangeSubscription = currentStep.onContentChange.listen((_) {
      notifyListeners();
    });
  }

  int get currentIndex => _currentIndex;
  bool get isLastStep => _currentIndex == steps.length - 1;
  bool get canGoBack => _currentIndex > 0;
  bool get canProceed =>
      currentStep.canProceed == null || currentStep.canProceed!();
  bool get canGoForward => canProceed && !isLastStep;

  FlowStep get currentStep => steps[_currentIndex];

  Future<void> goToNext() async {
    currentStep.onNext?.call();
    _currentIndex++;
    _subscribeToCurrentStep();
    notifyListeners();
    if (onStepChanged != null) onStepChanged!(_currentIndex);
  }

  void goBack() {
    if (canGoBack) {
      currentStep.onBack?.call();
      _currentIndex--;
      _subscribeToCurrentStep();
      notifyListeners();
      if (onStepChanged != null) onStepChanged!(_currentIndex);
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
  int initialIndex = 0,
  StepChangedCallback? onStepChanged,
  void Function(int lastIndex)? onDismiss,
}) async {
  final controller = FlowController(
    steps,
    initialIndex: initialIndex,
    onStepChanged: onStepChanged,
  );
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
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    child: currentStep.content,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                child: FullWidthButton(
                  text: 'Next',
                  borderRadius: 6,
                  fontSize: 16,
                  textColor: Colors.white,
                  backgroundColor: controller.canProceed
                      ? AppColors.primaryColor
                      : Colors.grey,
                  fontWeight: FontWeight.w600,
                  onPressed: () async {
                      if (controller.canGoForward) {
                        await controller.goToNext();
                      } else if (controller.isLastStep) {
                        Navigator.pop(context);
                        completed = true;
                      }
                    },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  if (onDismiss != null) {
    onDismiss(controller.currentIndex);
  }
  controller.dispose();
  return completed;
}
