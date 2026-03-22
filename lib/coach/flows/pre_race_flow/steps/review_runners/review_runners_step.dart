import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import '../../../../runners_management_screen/screen/runners_management_screen.dart';
import '../../../../race_screen/services/i_race_service.dart';
import '../../../../../core/services/service_locator.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

class ReviewRunnersStep extends FlowStep {
  bool _canProceed = false;
  final MasterRace masterRace;
  final Future<bool> Function(MasterRace) _checkMinimumRunners;
  late final Widget _cachedContent;

  ReviewRunnersStep({
    required this.masterRace,
    required Future<void> Function() onNext,
    Future<bool> Function(MasterRace)? checkMinimumRunners,
  })  : _checkMinimumRunners =
            checkMinimumRunners ??
                ServiceLocator.get<IRaceService>().checkMinimumRunnersLoaded,
        super(
          title: 'Review Runners',
          description:
              'Make sure all runner information is correct before the race starts. You can make any last-minute changes here.',
          content: const SizedBox.shrink(), // overridden by get content below
          canScroll: false,
          onNext: onNext,
        ) {
    _cachedContent = TeamsAndRunnersManagementWidget(
      masterRace: masterRace,
      showHeader: true,
      onContentChanged: () async {
        checkRunners();
      },
      isViewMode: false,
    );
    // Initialize with the current state
    checkRunners();
  }

  /// Precompute initial canProceed value before the sheet renders
  Future<void> seedInitialProceed() async {
    final hasEnoughRunners = await _checkMinimumRunners(masterRace);
    _canProceed = hasEnoughRunners;
  }

  Future<void> checkRunners() async {
    final hasEnoughRunners = await _checkMinimumRunners(masterRace);
    if (_canProceed != hasEnoughRunners) {
      _canProceed = hasEnoughRunners;
      notifyContentChanged();
    }
  }

  @override
  Widget get content => _cachedContent;

  @override
  bool Function() get canProceed {
    return () => _canProceed;
  }
}
