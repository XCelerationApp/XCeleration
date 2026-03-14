import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/components/button_components.dart';
import '../model/flow_model.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../flows/widgets/flow_indicator.dart';
import '../pre_race_flow/controller/pre_race_controller.dart';
import '../post_race_flow/controller/post_race_controller.dart';
import 'dart:async';
import '../../../coach/race_screen/controller/race_screen_controller.dart';
import '../../../shared/models/database/race.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../coach/race_screen/services/race_service.dart';

/// Controller class for handling all flow-related operations
class MasterFlowController {
  final RaceScreenController raceController;
  late PreRaceController preRaceController;
  late PostRaceController postRaceController;

  MasterFlowController({
    required this.raceController,
    PreRaceController? preRaceController,
    PostRaceController? postRaceController,
  }) {
    this.preRaceController = preRaceController ??
        PreRaceController(masterRace: raceController.masterRace);
    this.postRaceController = postRaceController ??
        PostRaceController(masterRace: raceController.masterRace);
  }

  /// Update the race flow state in the database, notify listeners, and fire
  /// the raceFlowStateChanged event. This is the low-level persistence
  /// operation — higher-level orchestration lives in the methods below.
  Future<void> updateRaceFlowState(
      BuildContext context, String newState) async {
    await raceController.updateRaceFlowState(context, newState);
  }

  /// Mark the current flow as completed by advancing to its completed state.
  Future<void> markCurrentFlowCompleted(BuildContext context) async {
    final race = await raceController.masterRace.race;
    if (!context.mounted) return;

    final completedState = race.completedFlowState;
    await raceController.updateRaceFlowState(context, completedState);

    if (!context.mounted) return;
  }

  /// Advance to the next non-completed flow state and navigate to its screen.
  Future<void> beginNextFlow(BuildContext context) async {
    final race = await raceController.masterRace.race;
    if (!context.mounted) return;

    String nextState = race.nextFlowState;

    // Skip completed states in the sequence
    if (nextState.contains(Race.FLOW_COMPLETED_SUFFIX)) {
      final nextIndex = Race.FLOW_SEQUENCE.indexOf(nextState) + 1;
      if (nextIndex < Race.FLOW_SEQUENCE.length) {
        nextState = Race.FLOW_SEQUENCE[nextIndex];
      }
    }

    await raceController.updateRaceFlowState(context, nextState);

    if (!context.mounted) return;

    await handleFlowNavigation(context, nextState);
  }

  /// Full state-machine entry point called by the UI "Continue" button.
  Future<void> continueRaceFlow(BuildContext context) async {
    if (!context.mounted) return;

    final race = await raceController.masterRace.race;
    if (!context.mounted) return;

    final currentState = race.flowState!;

    // Setup state: validate completeness before advancing
    if (currentState == Race.FLOW_SETUP) {
      final canAdvance = await RaceService.checkSetupComplete(
        masterRace: raceController.masterRace,
        nameController: raceController.form.nameController,
        locationController: raceController.form.locationController,
        dateController: raceController.form.dateController,
        distanceController: raceController.form.distanceController,
      );

      if (!context.mounted) return;

      if (!canAdvance) {
        final missing = _getMissingSetupItems();
        DialogUtils.showMessageDialog(
          context,
          title: 'Setup Incomplete',
          message: missing.isEmpty
              ? 'Please complete all required fields before continuing.'
              : 'Please fill in the following before continuing:\n\n${missing.map((item) => '• $item').join('\n')}',
          doneText: 'Got it',
        );
        return;
      }

      if (!context.mounted) return;
      await raceController.updateRaceFlowState(
          context, Race.FLOW_SETUP_COMPLETED);
      return;
    }

    // Completed states: advance to the next active state
    if (currentState.contains(Race.FLOW_COMPLETED_SUFFIX)) {
      String nextState;

      if (currentState == Race.FLOW_SETUP_COMPLETED) {
        nextState = Race.FLOW_PRE_RACE;
      } else if (currentState == Race.FLOW_PRE_RACE_COMPLETED) {
        nextState = Race.FLOW_POST_RACE;
      } else {
        return; // Unknown completed state
      }

      await raceController.updateRaceFlowState(context, nextState);

      if (!context.mounted) return;
    }

    if (!context.mounted) return;

    // Navigate to the current flow's screen
    final currentRace = await raceController.masterRace.race;
    if (!context.mounted) return;
    await handleFlowNavigation(context, currentRace.flowState!);
  }

  /// Navigate to the appropriate screen based on flow state
  Future<bool> handleFlowNavigation(
      BuildContext context, String flowState) async {
    // For completed states, just return to race screen (already there)
    if (flowState.contains(Race.FLOW_COMPLETED_SUFFIX) ||
        flowState == Race.FLOW_FINISHED) {
      // Make sure we're on the race details tab
      if (raceController.tabController.index != 0) {
        raceController.tabController.animateTo(0);
      }
      return true;
    }

    // For regular states, use the existing flow methods
    switch (flowState) {
      case Race.FLOW_PRE_RACE:
        return _preRaceFlow(context);
      case Race.FLOW_POST_RACE:
        return _postRaceFlow(context);
      default:
        Logger.d('Unknown flow state: $flowState');
        return false;
    }
  }

  /// Pre-race setup flow
  /// Shows a flow for pre-race setup and coordination
  Future<bool> _preRaceFlow(BuildContext context) async {
    // Get a more stable context from root navigator
    final navigatorContext = Navigator.of(context, rootNavigator: true).context;

    // Use the navigator context which is more stable during transitions
    final contextToUse = context.mounted ? context : navigatorContext;

    final bool completed =
        await preRaceController.showPreRaceFlow(contextToUse, true);

    // If not completed, just return
    if (!completed) return false;

    if (!contextToUse.mounted) return false;

    // Mark as pre-race-completed instead of moving directly to post-race
    await updateRaceFlowState(context, Race.FLOW_PRE_RACE_COMPLETED);

    // Return to race screen without starting the next flow automatically
    return true;
  }

  /// Post-race setup flow
  /// Shows a flow for post-race data collection and result processing
  Future<bool> _postRaceFlow(BuildContext context) async {
    // Get a more stable context from root navigator
    final navigatorContext = Navigator.of(context, rootNavigator: true).context;

    // Use the navigator context which is more stable during transitions
    final contextToUse = context.mounted ? context : navigatorContext;

    final bool completed =
        await postRaceController.showPostRaceFlow(contextToUse, true);

    // If not completed, just return
    if (!completed) return false;

    if (!contextToUse.mounted) return false;

    // Set the race state directly to finished after post-race flow completes
    await updateRaceFlowState(context, Race.FLOW_FINISHED);

    // Add a short delay to let the UI settle
    await Future.delayed(const Duration(milliseconds: 500));

    // Return to race results tab
    Logger.d('MasterFlowController: Navigating to results tab');
    raceController.tabController.animateTo(1);
    return true;
  }

  /// Returns human-readable missing setup items for the Continue dialog.
  List<String> _getMissingSetupItems() {
    final missing = <String>[];
    if (raceController.form.nameController.text.trim().isEmpty) {
      missing.add('Race name');
    }
    if (raceController.form.locationController.text.trim().isEmpty) {
      missing.add('Location');
    }
    if (raceController.form.dateController.text.trim().isEmpty) {
      missing.add('Race date');
    }
    if (raceController.form.distanceController.text.trim().isEmpty) {
      missing.add('Distance');
    }
    if (raceController.teamsOrNull?.isEmpty ?? true) {
      missing.add('Teams and runners');
    }
    return missing;
  }
}

class FlowController extends ChangeNotifier {
  int _currentIndex;
  final List<FlowStep> steps;
  StreamSubscription<void>? _contentChangeSubscription;
  final StepChangedCallback? onStepChanged;

  FlowController(this.steps, {int initialIndex = 0, this.onStepChanged})
      : _currentIndex = initialIndex {
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
    if (currentStep.onNext != null) {
      await currentStep.onNext!();
    }
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
  // Store a global navigator key that can be used across the app
  // This provides a more stable context that won't be invalidated during transitions
  final navigatorContext = Navigator.of(context, rootNavigator: true).context;

  final controller = FlowController(
    steps,
    initialIndex: initialIndex,
    onStepChanged: onStepChanged,
  );
  bool completed = false;

  // Check if original context is still valid after the delay
  if (!context.mounted) {
    // Use navigator context as fallback if the original context is gone
    Logger.d(
        'Original context unmounted during flow transition, using navigator context');
  }

  // Use the navigatorContext which is more stable during transitions
  final contextToUse = context.mounted ? context : navigatorContext;

  if (!contextToUse.mounted) return false;

  await sheet(
    context: contextToUse,
    title: null,
    takeUpScreen: true,
    useRootNavigator: true,
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
                  child: currentStep.canScroll
                      ? SingleChildScrollView(
                          child: currentStep.content,
                        )
                      : currentStep.content,
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
                  onPressed: controller.canProceed
                      ? () async {
                          if (controller.canGoForward) {
                            await controller.goToNext();
                          } else if (controller.isLastStep) {
                            // Call onNext for the final step before completing
                            if (controller.currentStep.onNext != null) {
                              await controller.currentStep.onNext!();
                            }
                            // Complete the flow
                            completed = true;
                            if (!contextToUse.mounted) return;
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                        }
                      : null,
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
