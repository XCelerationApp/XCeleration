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

  /// What to do now: connect the phones, then, once the results are in,
  /// sort out any conflicts and go on. It used to keep describing the
  /// phones connecting after the results had loaded.
  @override
  String get description => !controller.resultsLoaded
      ? super.description
      : _hasConflicts
          ? 'The results are in. A few need checking: tap Start below, then '
              'Next.'
          : 'The results are in. Tap Next to look them over before saving.';

  /// Next stays greyed out until every conflict is resolved: the conflicts
  /// are opened from the card's Start button, not by Next. Saving happens on
  /// the next page, once the coach has seen the results.
  bool get _hasConflicts =>
      controller.hasBibConflicts || controller.hasTimingConflicts;

  @override
  bool Function()? get canProceed =>
      () => controller.resultsLoaded && !_hasConflicts;

  @override
  String? Function()? get blockedReason => () => !controller.resultsLoaded
      ? 'Waiting for the times and bibs from your volunteers.'
      : _hasConflicts
          ? 'Resolve the conflicts first: tap Start above.'
          : null;
}
