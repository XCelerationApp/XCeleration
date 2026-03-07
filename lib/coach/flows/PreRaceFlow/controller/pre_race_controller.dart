import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import '../../controller/flow_controller.dart';
import '../../model/flow_model.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/enums.dart';
import '../../../../core/services/device_connection_service.dart';
import '../../../../core/utils/encode_utils.dart';
import '../steps/review_runners/review_runners_step.dart';
import '../steps/share_race/share_race_step.dart';
import '../steps/flow_complete/pre_race_flow_complete.dart';

/// Function type that matches the [showFlow] top-level function signature,
/// used to allow injection in tests.
typedef ShowFlowFn = Future<bool> Function({
  required BuildContext context,
  required List<FlowStep> steps,
  bool showProgressIndicator,
  int initialIndex,
  StepChangedCallback? onStepChanged,
  void Function(int lastIndex)? onDismiss,
});

class PreRaceController {
  final MasterRace masterRace;
  final DevicesManager devices;
  final Future<String> Function(MasterRace) encodeRaceData;
  final Future<String> Function(MasterRace) encodeBibData;
  final ShowFlowFn _showFlow;

  late ReviewRunnersStep _reviewRunnersStep;
  late ShareRaceStep _shareRaceStep;
  late PreRaceFlowCompleteStep _preRaceFlowCompleteStep;
  int? _lastStepIndex;

  PreRaceController({
    required this.masterRace,
    DevicesManager? devices,
    Future<String> Function(MasterRace)? encodeRaceData,
    Future<String> Function(MasterRace)? encodeBibData,
    ShowFlowFn? showFlowFn,
  })  : devices = devices ??
            DeviceConnectionService.createDevices(
              DeviceName.coach,
              DeviceType.advertiserDevice,
              data: '',
            ),
        encodeRaceData =
            encodeRaceData ?? RaceEncodeUtils.getEncodedRaceData,
        encodeBibData =
            encodeBibData ?? BibEncodeUtils.getEncodedRunnersBibData,
        _showFlow = showFlowFn ?? showFlow {
    _initializeSteps();
  }

  void _initializeSteps() {
    _reviewRunnersStep = ReviewRunnersStep(
      masterRace: masterRace,
      onNext: () async {
        final encodedRaceData = await encodeRaceData(masterRace);
        if (encodedRaceData == '') {
          Logger.e('Failed to encode race data');
          return;
        }
        devices.raceTimer!.data = encodedRaceData;
        final encodedBibData = await encodeBibData(masterRace);
        if (encodedBibData == '') {
          Logger.e('Failed to encode runners data');
          return;
        }
        devices.bibRecorder!.data = '$encodedRaceData---$encodedBibData';
      },
    );
    // Seed initial canProceed so the first render uses a correct value
    _reviewRunnersStep.seedInitialProceed();
    _shareRaceStep = ShareRaceStep(devices: devices);
    _preRaceFlowCompleteStep = PreRaceFlowCompleteStep();
  }

  Future<bool> showPreRaceFlow(
      BuildContext context, bool showProgressIndicator) async {
    final int startIndex = _lastStepIndex ?? 0;
    // Ensure initial proceed state is computed before rendering the sheet
    await _reviewRunnersStep.seedInitialProceed();
    if (!context.mounted) {
      return false;
    }
    return await _showFlow(
      context: context,
      showProgressIndicator: showProgressIndicator,
      steps: _getSteps(),
      initialIndex: startIndex,
      onDismiss: (lastIndex) {
        _lastStepIndex = lastIndex;
      },
    );
  }

  List<FlowStep> _getSteps() {
    return [
      _reviewRunnersStep,
      _shareRaceStep,
      _preRaceFlowCompleteStep,
    ];
  }

  @visibleForTesting
  List<FlowStep> buildSteps() => _getSteps();
}
