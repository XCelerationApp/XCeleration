import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/coach/flows/PostRaceFlow/steps/load_results/load_results_step.dart';
import 'package:xceleration/coach/flows/PostRaceFlow/steps/review_results/review_results_step.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import '../../controller/flow_controller.dart';
import '../steps/load_results/controller/load_results_controller.dart';
import '../steps/reconnect/reconnect_step.dart';


/// Controller for managing the post-race flow
class PostRaceController {
  final MasterRace masterRace;

  // Controllers
  late final LoadResultsController _loadResultsController;

  // Flow steps
  late final ReconnectStep _reconnectStep;
  late final LoadResultsStep _loadResultsStep;
  late final ReviewResultsStep _reviewResultsStep;

  // Track flow position
  int? _lastStepIndex;

  /// Constructor
  PostRaceController({required this.masterRace}) {
    _initializeSteps();
  }

  /// Initialize the flow steps
  void _initializeSteps() {
    // Create controllers first so they can be shared between steps
    _loadResultsController =
        LoadResultsController(masterRace: masterRace);

    // Create steps with the controllers
    _reconnectStep = ReconnectStep();
    _loadResultsStep = LoadResultsStep(
      controller: _loadResultsController,
    );

    _reviewResultsStep = ReviewResultsStep(masterRace: masterRace);
  }

  /// Show the post-race flow
  Future<bool> showPostRaceFlow(BuildContext context, bool dismissible) async {
    // Get steps
    final steps = _getSteps();
    final int startIndex = _lastStepIndex ?? 0;

    // Show the flow
    return await showFlow(
      context: context,
      steps: steps,
      showProgressIndicator: dismissible,
      initialIndex: startIndex,
      onDismiss: (lastIndex) {
        _lastStepIndex = lastIndex;
      },
    );
  }

  /// Get the flow steps
  List<FlowStep> _getSteps() {
    return [
      _reconnectStep,
      _loadResultsStep,
      _reviewResultsStep,
    ];
  }
}
