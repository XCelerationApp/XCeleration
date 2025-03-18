import 'package:xcelerate/coach/flows/model/flow_model.dart';
import 'package:xcelerate/coach/runners_management_screen/screen/runners_management_screen.dart';
import 'package:flutter/material.dart';

class LoadRunnersStep extends FlowStep {
  final int raceId;
  bool _canProceed = false;
  
  LoadRunnersStep({required this.raceId}) : super(
    title: 'Load Runners',
    description: 'Add runners to your race by entering their information or importing from a previous race. Each team needs at least 5 runners to proceed.',
    content: RunnersManagementScreen(
      raceId: raceId,
      showHeader: false,
      onBack: null,
    ),
    canProceed: () => false,
  );

  @override
  Widget get content {
    return RunnersManagementScreen(
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
    );
  }

  @override
  bool Function()? get canProceed {
    return () => _canProceed;
  }
}