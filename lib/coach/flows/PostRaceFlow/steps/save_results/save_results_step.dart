import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import 'widgets/save_results_widget.dart';

/// A FlowStep implementation for the save results step in the post-race flow
class SaveResultsStep extends FlowStep {
  /// Creates a new instance of SaveResultsStep
  SaveResultsStep() : super(
    title: 'Save Results',
    description: 'Save the final race results to complete the race.',
    content: const SingleChildScrollView(
      child: SaveResultsWidget(),
    ),
    canProceed: () => true,
  );
  
  // No additional state needed for this step
}