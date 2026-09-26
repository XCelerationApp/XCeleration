import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/components/button_components.dart';
import '../model/flow_model.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../flows/widgets/flow_indicator.dart';
import '../pre_race_flow/controller/pre_race_controller.dart';
import '../post_race_flow/controller/post_race_controller.dart';
import 'dart:async';
import '../../../coach/race_screen/controller/race_screen_controller.dart';
import '../../../shared/models/database/race.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../coach/race_screen/services/i_race_service.dart';
import '../../../core/services/service_locator.dart';

/// Controller class for handling all flow-related operations
class MasterFlowController {
  final RaceScreenController raceController;
  late PreRaceController preRaceController;
  late PostRaceController postRaceController;

  late final IRaceService _raceService;

  MasterFlowController({
    required this.raceController,
    PreRaceController? preRaceController,
    PostRaceController? postRaceController,
    IRaceService? raceService,
  }) {
    _raceService = raceService ?? ServiceLocator.get<IRaceService>();
    this.preRaceController =
        preRaceController ??
        PreRaceController(masterRace: raceController.masterRace);
    this.postRaceController =
        postRaceController ??
        PostRaceController(masterRace: raceController.masterRace);
  }

  /// Update the race flow state in the database, notify listeners, and fire
  /// the raceFlowStateChanged event. This is the low-level persistence
  /// operation — higher-level orchestration lives in the methods below.
  Future<void> updateRaceFlowState(
    BuildContext context,
    String newState,
  ) async {
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

    // Setup state: validate completeness before advancing.
    // Pass the already-fetched race and cached teams to avoid extra DB reads.
    if (currentState == Race.FLOW_SETUP) {
      final canAdvance = await _raceService.checkSetupComplete(
        race: race,
        teams: raceController.teamsOrNull ?? [],
        masterRace: raceController.masterRace,
        name: raceController.form.nameController.text.trim(),
        location: raceController.form.locationController.text,
        date: raceController.form.dateController.text,
        distance: raceController.form.distanceController.text,
      );

      if (!context.mounted) return;

      if (!canAdvance) {
        final missing = _getMissingSetupItems();
        if (missing.isEmpty) {
          DialogUtils.showMessageDialog(
            context,
            title: 'A Few Things Left',
            message: 'Check the race details, then try again.',
            doneText: 'Got it',
          );
          return;
        }
        DialogUtils.showChecklistDialog(
          context,
          title: 'A Few Things Left',
          message: 'Finish these before sending the race to volunteers.',
          items: {
            for (final item in _setupItems) item: !missing.contains(item),
          },
        );
        return;
      }

      if (!context.mounted) return;
      await raceController.updateRaceFlowState(
        context,
        Race.FLOW_SETUP_COMPLETED,
      );
      if (!context.mounted) return;
      // Nothing more to do until race day, so the sheet closes. The race
      // screen explains what happens next ("Setup Complete").
      closeRaceSheet(context);
      return;
    }

    // Sending and collecting each start from a short check that everything
    // is ready, then go straight to the page that does the work.
    final sending = currentState == Race.FLOW_SETUP_COMPLETED ||
        currentState == Race.FLOW_PRE_RACE;
    final collecting = currentState == Race.FLOW_PRE_RACE_COMPLETED ||
        currentState == Race.FLOW_POST_RACE;
    if (!sending && !collecting) return;
    if (!context.mounted) return;

    final bool ready;
    if (sending) {
      ready = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Ready to Send the Race?',
        content: '• You are at the race.\n'
            '• Any last-minute roster changes are made.\n'
            '• The Timer and Bib Recorder are next to you, with '
            'XCeleration open.',
        confirmText: 'Send Race',
        cancelText: 'Not Yet',
      );
    } else {
      ready = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Ready to Collect Results?',
        content: '• Every runner has finished.\n'
            '• The Timer and Bib Recorder are next to you, with '
            'XCeleration open.',
        confirmText: 'Collect Results',
        cancelText: 'Not Yet',
      );
    }
    if (!ready || !context.mounted) return;

    final nextState = sending ? Race.FLOW_PRE_RACE : Race.FLOW_POST_RACE;
    if (currentState != nextState) {
      await raceController.updateRaceFlowState(context, nextState);
      if (!context.mounted) return;
    }

    // Navigate using the already-known state — eliminates a redundant DB read.
    await handleFlowNavigation(context, nextState);
  }

  /// Closes the race's sheet once a step is done, back to the races list,
  /// with [message] saying what happens next.
  void closeRaceSheet(BuildContext context, {String? message}) {
    // A snack bar, not a toast: the app's messenger shows it on the races
    // list once the sheet is gone. A toast is tied to the sheet it was
    // opened from, and quietly never appeared once the sheet closed.
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).maybePop();
    if (message != null) {
      messenger?.showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkColor,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  /// Navigate to the appropriate screen based on flow state
  Future<bool> handleFlowNavigation(
    BuildContext context,
    String flowState,
  ) async {
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

    // One page, so no progress bar.
    final bool completed = await preRaceController.showPreRaceFlow(
      contextToUse,
      false,
    );

    // If not completed, just return
    if (!completed) return false;

    if (!contextToUse.mounted) return false;

    // Mark as pre-race-completed instead of moving directly to post-race
    await updateRaceFlowState(context, Race.FLOW_PRE_RACE_COMPLETED);
    if (context.mounted) {
      closeRaceSheet(context,
          message: 'Race sent. After the race, open it and tap Collect '
              'Results.');
    }
    return true;
  }

  /// Post-race setup flow
  /// Shows a flow for post-race data collection and result processing
  Future<bool> _postRaceFlow(BuildContext context) async {
    // Get a more stable context from root navigator
    final navigatorContext = Navigator.of(context, rootNavigator: true).context;

    // Use the navigator context which is more stable during transitions
    final contextToUse = context.mounted ? context : navigatorContext;

    final bool completed = await postRaceController.showPostRaceFlow(
      contextToUse,
      true,
    );

    // If not completed, just return
    if (!completed) return false;

    if (!contextToUse.mounted) return false;

    // Set the race state directly to finished after post-race flow completes
    await updateRaceFlowState(context, Race.FLOW_FINISHED);
    if (context.mounted) {
      // A finished race opens on its results, so they are one tap away.
      closeRaceSheet(context, message: 'Results saved. Open the race to see and share them.');
    }
    return true;
  }

  /// Returns human-readable missing setup items for the Continue dialog.
  /// Everything setup needs, in the order the screen shows it.
  static const _setupItems = [
    'Race name',
    'Location',
    'Race date',
    'Distance',
    'Teams and runners',
  ];

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

  /// Why Next is greyed out on this step, if the step says.
  String? get blockedReason =>
      canProceed ? null : currentStep.blockedReason?.call();

  FlowStep get currentStep => steps[_currentIndex];

  /// Moves to the next step. Throws [FlowStepBlocked] (and stays put) if the
  /// current step's [FlowStep.onNext] refuses.
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

  /// Stops listening to the steps but leaves them working. A race keeps its
  /// flow's steps and shows them again each time the flow opens; disposing
  /// them here left a reopened Load Results step unable to tell the flow its
  /// conflicts were resolved, so Save Results stayed greyed out.
  @override
  void dispose() {
    _contentChangeSubscription?.cancel();
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
      'Original context unmounted during flow transition, using navigator context',
    );
  }

  // Use the navigatorContext which is more stable during transitions
  final contextToUse = context.mounted ? context : navigatorContext;

  if (!contextToUse.mounted) return false;

  await sheet(
    context: contextToUse,
    title: null,
    takeUpScreen: true,
    useRootNavigator: true,
    horizontalPadding: 0,
    body: ChangeNotifierProvider.value(
      value: controller,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicator: rebuilds only on step navigation (currentIndex change)
          if (showProgressIndicator)
            Selector<FlowController, (int, bool)>(
              selector: (_, c) => (c.currentIndex, c.canGoBack),
              builder: (ctx, data, _) {
                final (currentIndex, canGoBack) = data;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: EnhancedFlowIndicator(
                    totalSteps: steps.length,
                    currentStep: currentIndex,
                    onBack: canGoBack
                        ? () => ctx.read<FlowController>().goBack()
                        : null,
                  ),
                );
              },
            ),
          // Title + description: rebuilds on step navigation, and when a
          // step's description changes with its content (Load Results says
          // something different once the results are in).
          Selector<FlowController, (int, String)>(
            selector: (_, c) =>
                (c.currentIndex, steps[c.currentIndex].description),
            builder: (_, data, _) {
              final step = steps[data.$1];
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Content: rebuilds only on step navigation
          Expanded(
            child: Selector<FlowController, int>(
              selector: (_, c) => c.currentIndex,
              builder: (_, index, _) {
                final step = steps[index];
                return step.canScroll
                    ? SingleChildScrollView(child: step.content)
                    : step.content;
              },
            ),
          ),
          // Next button: rebuilds only when canProceed or step changes
          Selector<FlowController, (bool, int, String?)>(
            selector: (_, c) => (c.canProceed, c.currentIndex, c.blockedReason),
            builder: (ctx, data, _) {
              final (canProceed, index, blockedReason) = data;
              final label = steps[index].nextLabel ??
                  (index == steps.length - 1 ? 'Done' : 'Next');
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (blockedReason != null) ...[
                      Text(
                        blockedReason,
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.mediumColor,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    FullWidthButton(
                      text: label,
                      borderRadius: 6,
                      fontSize: 16,
                      textColor: Colors.white,
                      backgroundColor: canProceed
                          ? AppColors.primaryColor
                          : Colors.grey,
                      fontWeight: FontWeight.w600,
                      onPressed: canProceed
                          ? () async {
                              final c = ctx.read<FlowController>();
                              try {
                                final before = c.currentStep.beforeNext;
                                if (before != null) {
                                  await before(ctx);
                                  if (!ctx.mounted) return;
                                }
                                if (c.canGoForward) {
                                  await c.goToNext();
                                } else if (c.isLastStep) {
                                  if (c.currentStep.onNext != null) {
                                    await c.currentStep.onNext!();
                                  }
                                  completed = true;
                                  if (!contextToUse.mounted) return;
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                }
                              } on FlowStepBlocked catch (e) {
                                // Stay on this step and say why.
                                final message = e.message;
                                if (message == null || !ctx.mounted) return;
                                DialogUtils.showErrorDialog(
                                  ctx,
                                  message: message,
                                );
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );

  if (onDismiss != null) {
    onDismiss(controller.currentIndex);
  }
  controller.dispose();
  return completed;
}
