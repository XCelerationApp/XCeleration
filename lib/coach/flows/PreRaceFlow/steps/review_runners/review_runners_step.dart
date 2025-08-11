import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import '../../../../runners_management_screen/screen/runners_management_screen.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

class ReviewRunnersStep extends FlowStep {
  bool _canProceed = false;
  final MasterRace masterRace;

  ReviewRunnersStep({
    required this.masterRace,
    required VoidCallback onNext,
  }) : super(
          title: 'Review Runners',
          description:
              'Make sure all runner information is correct before the race starts. You can make any last-minute changes here.',
          content: TeamsAndRunnersManagementWidget(
            masterRace: masterRace,
            showHeader: false,
            onBack: null,
            isViewMode: false,
          ),
          canScroll: false,
          canProceed: () => true,
          onNext: onNext,
        ) {
    // Initialize with the current state
    checkRunners();
  }

  Future<void> checkRunners() async {
    final hasEnoughRunners =
        await TeamsAndRunnersManagementWidget.checkMinimumRunnersLoaded(masterRace);
    if (_canProceed != hasEnoughRunners) {
      _canProceed = hasEnoughRunners;
      notifyContentChanged();
    }
  }

  @override
  Widget get content {
    return TeamsAndRunnersManagementWidget(
      masterRace: masterRace,
      showHeader: false,
      onBack: null,
      onContentChanged: () async {
        checkRunners();
      },
      isViewMode: false,
    );
  }

  @override
  bool Function() get canProceed {
    return () => _canProceed;
  }
}
