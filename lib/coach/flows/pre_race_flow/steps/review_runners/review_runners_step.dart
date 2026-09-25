import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import '../../../../runners_management_screen/screen/runners_management_screen.dart';
import '../../../../race_screen/services/i_race_service.dart';
import '../../../../../core/services/service_locator.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

class ReviewRunnersStep extends FlowStep {
  /// Why the race cannot be sent yet, or null once it can. Starts as a
  /// placeholder until the first check has run.
  String? _notReady = 'Checking the runners…';
  final MasterRace masterRace;
  final Future<String?> Function(MasterRace) _whyNotReady;
  late final Widget _cachedContent;

  ReviewRunnersStep({
    required this.masterRace,
    required Future<void> Function() onNext,
    Future<String?> Function(MasterRace)? whyNotReady,
  })  : _whyNotReady = whyNotReady ??
            ServiceLocator.get<IRaceService>().whyRunnersNotReady,
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
    _notReady = await _whyNotReady(masterRace);
  }

  Future<void> checkRunners() async {
    final notReady = await _whyNotReady(masterRace);
    if (_notReady != notReady) {
      _notReady = notReady;
      notifyContentChanged();
    }
  }

  @override
  Widget get content => _cachedContent;

  @override
  bool Function() get canProceed {
    return () => _notReady == null;
  }

  @override
  String? Function() get blockedReason => () => _notReady;
}
