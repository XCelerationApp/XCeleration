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
import '../../../shared/models/race.dart';
import 'dart:async';
import '../../../utils/database_helper.dart';
import '../../../coach/race_screen/controller/race_screen_controller.dart';
import '../../../utils/enums.dart';
// import '../../share_race/controller/share_race_controller.dart';
// import '../../../utils/time_formatter.dart';
// import '../../race_screen/widgets/runner_record.dart';
// import '../../../assistant/race_timer/timing_screen/model/timing_record.dart';

/// Controller class for handling all flow-related operations
class MasterFlowController {
  final int raceId;
  Race? race;
  late SetupController setupController;
  late PreRaceController preRaceController;
  late PostRaceController postRaceController;

  MasterFlowController({required this.raceId, Race? race}) {
    race = race;
    setupController = SetupController(raceId: raceId);
    preRaceController = PreRaceController(raceId: raceId);
    postRaceController = PostRaceController(raceId: raceId, useTestData: true);
  }

  /// Continue the race flow based on the current state
  Future<void> continueRaceFlow(BuildContext context) async {
    if (race == null) {
      // If race is null, try to load it
      race = await DatabaseHelper.instance.getRaceById(raceId);
      if (race == null) {
        debugPrint('Error: Race not found');
        return;
      }
    }
    
    switch (race!.flowState) {
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
    await DatabaseHelper.instance.updateRaceFlowState(raceId, newState);
    if (race != null) {
      race = race!.copyWith(flowState: newState);
    }
  }

  /// Setup the race with runners
  /// Shows a flow with the provided steps and handles user progression
  Future<bool> _setupFlow(BuildContext context) async {
    final bool completed = await setupController.showSetupFlow(context, true);
    if (!completed) return false;
    await updateRaceFlowState('pre-race');
    return _preRaceFlow(context);
  }

  /// Pre-race setup flow
  /// Shows a flow for pre-race setup and coordination
  Future<bool> _preRaceFlow(BuildContext context) async {
    final bool completed = await preRaceController.showPreRaceFlow(context, true);
    if (!completed) return false;
    await updateRaceFlowState('post-race');
    return _postRaceFlow(context);
  }

  /// Post-race setup flow
  /// Shows a flow for post-race data collection and result processing
  Future<bool> _postRaceFlow(BuildContext context) async {
    final bool completed = await postRaceController.showPostRaceFlow(context, true);
    if (!completed) return false;
    await updateRaceFlowState('finished');
    if (context.mounted) {
      RaceScreenController.showRaceScreen(context, raceId, page: RaceScreenPage.results);
    }
    return true;
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
  bool get isLastStep => _currentIndex == steps.length - 1;
  bool get canGoBack => _currentIndex > 0;
  bool get canProceed => currentStep.canProceed == null || currentStep.canProceed!();
  bool get canGoForward => canProceed && !isLastStep;

  FlowStep get currentStep => steps[_currentIndex];

  Future<void> goToNext() async {
    currentStep.onNext?.call();
    _currentIndex++;
    _subscribeToCurrentStep();
    notifyListeners();
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
                      } else if (controller.isLastStep) {
                        Navigator.pop(context);
                        completed = true;
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: controller.canProceed ? AppColors.primaryColor : Colors.grey,
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