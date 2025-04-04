import 'package:xcelerate/coach/flows/model/flow_model.dart';
import 'package:xcelerate/coach/runners_management_screen/screen/runners_management_screen.dart';
import 'package:flutter/material.dart';

class LoadRunnersStep extends FlowStep {
  final int raceId;
  bool _canProceed = false;

  LoadRunnersStep({required this.raceId})
    : super(
    title: 'Load Runners',
    description:
        'Add runners to your race by entering their information or importing from a previous race. Each team needs at least 5 runners to proceed.',
    content: RunnersManagementScreen(
      raceId: raceId,
      showHeader: false,
      onBack: null,
    ),
    canProceed: () => false,
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
    return RunnersManagementScreen(
      raceId: raceId,
      showHeader: false,
      onBack: null,
      onContentChanged: () async {
        // Check if we have enough runners
        checkRunners();
      },
    );
  }

  @override
  bool Function()? get canProceed {
    return () => _canProceed;
  }
}
