import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import '../../../../runners_management_screen/screen/runners_management_screen.dart';


class ReviewRunnersStep extends FlowStep {
  bool _canProceed = false;
  final int raceId;

  ReviewRunnersStep(this.raceId, VoidCallback onNext) : super(
    title: 'Review Runners',
    description: 'Make sure all runner information is correct before the race starts. You can make any last-minute changes here.',
    content: Column(
      children: [
        RunnersManagementScreen(
          raceId: raceId, 
          showHeader: false, 
          onBack: null, 
        )
      ]
    ),
    canProceed: () => true,
    onNext: onNext,
  );

  @override
  Widget get content {
    return Column(
      children: [
        RunnersManagementScreen(
          raceId: raceId, 
          showHeader: false, 
          onBack: null, 
          onContentChanged: () async {
            // Check if we have enough runners
            final hasEnoughRunners = await RunnersManagementScreen.checkMinimumRunnersLoaded(raceId);
            
            // Only update and notify if the state has changed
            if (_canProceed != hasEnoughRunners) {
              _canProceed = hasEnoughRunners;
              // Notify the flow controller that our state has changed
              notifyContentChanged();
            }
          },
        )
      ]
    );
  }

  @override
  bool Function()? get canProceed {
    return () => _canProceed;
  }
}