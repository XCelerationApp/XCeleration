import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'widgets/results_review_widget.dart';

/// A FlowStep implementation for the review results step in the post-race flow
class ReviewResultsStep extends FlowStep {
  final MasterRace masterRace;

  /// Creates a new instance of ReviewResultsStep
  ReviewResultsStep({required this.masterRace})
      : super(
          title: 'Review Results',
          description: 'Review and verify the race results before saving them.',
          // Use placeholder content that will be overridden by the content getter
          content: SizedBox.shrink(),
        );

  @override
  Widget get content => ResultsReviewWidget(masterRace: masterRace);
}
