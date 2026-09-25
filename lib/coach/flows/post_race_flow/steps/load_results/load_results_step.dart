import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'widgets/load_results_widget.dart';
import 'controller/load_results_controller.dart';

/// A FlowStep implementation for the load results step in the post-race flow
class LoadResultsStep extends FlowStep {
  /// Controller for managing load results functionality
  final LoadResultsController controller;

  late final Widget _content = LoadResultsWidget(controller: controller);

  /// Creates a new instance of LoadResultsStep
  LoadResultsStep({
    required this.controller,
  }) : super(
          title: 'Load Results',
          description: 'On each volunteer\'s phone, tap Share Times or '
              'Share Bibs. Their results load here as each phone connects, '
              'then tap Next.',
          nextLabel: 'Next',
          // Initialize with a placeholder
          content: SizedBox.shrink(),
          // Next walks the coach through any conflicts, bibs then times, and
          // stays here if some are left. Saving happens on the next page,
          // once the coach has seen the results.
          beforeNext: (context) async {
            if (controller.hasBibConflicts) {
              // Moves on to the timing conflicts itself once bibs are done.
              await controller.showBibConflictsSheet(context);
            } else if (controller.hasTimingConflicts) {
              await controller.showTimingConflictsSheet(context);
            }
            if (controller.hasBibConflicts || controller.hasTimingConflicts) {
              throw const FlowStepBlocked(
                  'Some conflicts still need sorting out. Tap Next to carry on.');
            }
          },
        ) {
    // Listen to controller changes and notify the flow system
    controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  // Notify the flow system when controller state changes
  void _onControllerUpdate() {
    notifyContentChanged();
  }

  @override
  Widget get content => _content;

  @override
  bool Function()? get canProceed => () => controller.resultsLoaded;

  @override
  String? Function()? get blockedReason => () => controller.resultsLoaded
      ? null
      : 'Waiting for the times and bibs from your volunteers.';
}
