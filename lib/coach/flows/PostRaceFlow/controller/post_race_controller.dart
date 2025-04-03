import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import 'package:xcelerate/coach/flows/PostRaceFlow/steps/load_results/load_results_step.dart';
import 'package:xcelerate/coach/flows/PostRaceFlow/steps/review_results/review_results_step.dart';
import '../../controller/flow_controller.dart';
import '../steps/load_results/controller/load_results_controller.dart';

/// Controller for managing the post-race flow
class PostRaceController {
  final int raceId;
  
  // Controllers
  late final LoadResultsController _loadResultsController;

  // Flow steps
  late final LoadResultsStep _loadResultsStep;
  late final ReviewResultsStep _reviewResultsStep;

  /// Constructor
  PostRaceController({required this.raceId, bool useTestData = false}) {
    _initializeSteps(useTestData);
  }

  /// Initialize the flow steps
  void _initializeSteps([bool useTestData = false]) {
    // Create controllers first so they can be shared between steps
    _loadResultsController = LoadResultsController(raceId: raceId, callback: _updateReviewStep);
    
    // Create steps with the controllers
    _loadResultsStep = LoadResultsStep(
      controller: _loadResultsController,
    );

    _reviewResultsStep = ReviewResultsStep();
  }
  
  /// Update ReviewResultsStep with latest results from LoadResultsController
  void _updateReviewStep() {
    print('Updating ReviewResultsStep with latest results');
    _reviewResultsStep.results = _loadResultsController.results;
  }

  /// Show the post-race flow
  Future<bool> showPostRaceFlow(BuildContext context, bool dismissible) async {
    // Get steps
    final steps = _getSteps();

    // Show the flow
    return await showFlow(
      context: context,
      steps: steps,
      showProgressIndicator: dismissible,
    );
  }

  /// Get the flow steps
  List<FlowStep> _getSteps() {
    return [
      _loadResultsStep,
      _reviewResultsStep,
    ];
  }
}
