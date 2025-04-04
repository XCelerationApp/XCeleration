import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import '../../../../runners_management_screen/screen/runners_management_screen.dart';

class ReviewRunnersStep extends FlowStep {
  bool _canProceed = false;
  final int raceId;

  ReviewRunnersStep(this.raceId, VoidCallback onNext)
    : super(
    title: 'Review Runners',
    description:
        'Make sure all runner information is correct before the race starts. You can make any last-minute changes here.',
    content: Column(children: [
      RunnersManagementScreen(
        raceId: raceId,
        showHeader: false,
        onBack: null,
      )
    ]),
    canProceed: () => true,
    onNext: onNext,
  ) {
    // Initialize with the current state
    checkRunners();
  }

  Future<void> checkRunners() async {
    final hasEnoughRunners =
        await RunnersManagementScreen.checkMinimumRunnersLoaded(raceId);
    debugPrint('Has enough runners: $hasEnoughRunners');
    if (_canProceed != hasEnoughRunners) {
      _canProceed = hasEnoughRunners;
      notifyContentChanged();
    }
  }

  @override
  Widget get content {
    return Column(children: [
      RunnersManagementScreen(
        raceId: raceId,
        showHeader: false,
        onBack: null,
        onContentChanged: () async {
          checkRunners();
        },
      )
    ]);
  }

  @override
  bool Function()? get canProceed {
    return () => _canProceed;
  }
}
