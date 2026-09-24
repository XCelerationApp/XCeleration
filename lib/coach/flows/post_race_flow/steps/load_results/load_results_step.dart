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
          description: 'The times and bibs load as each volunteer\'s phone '
              'connects. Fix anything flagged, then save.',
          nextLabel: 'Save Results',
          // Initialize with a placeholder
          content: SizedBox.shrink(),
          onNext: () async {
            // Save results when user clicks next. A failed save must keep the
            // flow here: finishing would mark the race done without results.
            final error = await controller.saveCurrentResults();
            if (error != null) throw FlowStepBlocked(error.userMessage);
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
  bool Function()? get canProceed => () {
        return controller.resultsLoaded &&
            !controller.hasBibConflicts &&
            !controller.hasTimingConflicts;
      };

  @override
  String? Function()? get blockedReason => () {
        if (!controller.resultsLoaded) {
          return 'Waiting for the times and bibs from your volunteers.';
        }
        if (controller.hasBibConflicts || controller.hasTimingConflicts) {
          return 'Resolve the conflicts above, then save.';
        }
        return null;
      };
}
