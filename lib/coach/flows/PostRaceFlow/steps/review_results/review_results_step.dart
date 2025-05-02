import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'widgets/results_review_widget.dart';
import '../../../../race_results/model/results_record.dart';

/// A FlowStep implementation for the review results step in the post-race flow
class ReviewResultsStep extends FlowStep {
  List<ResultsRecord> results = [];


  /// Creates a new instance of ReviewResultsStep
  ReviewResultsStep()
    : super(
        title: 'Review Results',
        description: 'Review and verify the race results before saving them.',
        // Use placeholder content that will be overridden by the content getter
        content: SizedBox.shrink(),
      );

  @override
  Widget get content => ResultsReviewWidget(results: results);
}
