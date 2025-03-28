import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import '../../../../race_screen/widgets/runner_record.dart';
import 'widgets/results_review_widget.dart';
import 'package:xcelerate/coach/merge_conflicts/model/timing_data.dart';

/// A FlowStep implementation for the review results step in the post-race flow
class ReviewResultsStep extends FlowStep {
  // Private field to store timing data
  TimingData? _timingData;
  
  // Private field to store runner records
  List<RunnerRecord>? _runnerRecords;
  
  // Getter and setter for timing data
  TimingData? get timingData => _timingData;

  // Getter and setter for runner records
  List<RunnerRecord>? get runnerRecords => _runnerRecords;
  
  set timingData(TimingData? value) {
    _timingData = value;
    notifyContentChanged();
  }

  set runnerRecords(List<RunnerRecord>? value) {
    _runnerRecords = value;
    notifyContentChanged();
  }

  /// Creates a new instance of ReviewResultsStep
  ReviewResultsStep() : 
    super(
      title: 'Review Results',
      description: 'Review and verify the race results before saving them.',
      content: SingleChildScrollView(
        child: ResultsReviewWidget(timingData: null, runnerRecords: null),
      ),
      canProceed: () => true,
    );
  
  // Override to rebuild the content with current timing data
  @override
  Widget get content {
    debugPrint('Timing Data: $_timingData');
    debugPrint('Runner Records: ${_timingData?.runnerRecords}');
    return SingleChildScrollView(
      child: ResultsReviewWidget(timingData: _timingData, runnerRecords: _timingData?.runnerRecords),
    );
  }
}