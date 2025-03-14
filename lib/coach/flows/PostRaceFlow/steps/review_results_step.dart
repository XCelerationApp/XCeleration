import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import 'package:xcelerate/coach/flows/PostRaceFlow/widgets/results_review_widget.dart';
import 'package:xcelerate/coach/merge_conflicts_screen/model/timing_data.dart';

/// A FlowStep implementation for the review results step in the post-race flow
class ReviewResultsStep extends FlowStep {
  // Private field to store timing data
  TimingData? _timingData;
  
  // Getter and setter for timing data
  TimingData? get timingData => _timingData;
  
  set timingData(TimingData? value) {
    _timingData = value;
    notifyContentChanged();
  }

  /// Creates a new instance of ReviewResultsStep
  ReviewResultsStep() : 
    super(
      title: 'Review Results',
      description: 'Review and verify the race results before saving them.',
      content: SingleChildScrollView(
        child: ResultsReviewWidget(timingData: null),
      ),
      canProceed: () async => true,
    );
  
  // Override to rebuild the content with current timing data
  @override
  Widget get content {
    return SingleChildScrollView(
      child: ResultsReviewWidget(timingData: _timingData),
    );
  }
}