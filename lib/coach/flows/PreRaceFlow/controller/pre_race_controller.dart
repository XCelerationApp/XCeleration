import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import '../../controller/flow_controller.dart';
import '../../model/flow_model.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/enums.dart';
import '../../../../core/services/device_connection_service.dart';
import '../../../../core/utils/encode_utils.dart';
import '../steps/review_runners/review_runners_step.dart';
import '../steps/share_runners/share_runners_step.dart';
import '../steps/flow_complete/pre_race_flow_complete.dart';

class PreRaceController {
  final MasterRace masterRace;
  late ReviewRunnersStep _reviewRunnersStep;
  late ShareRunnersStep _shareRunnersStep;
  late PreRaceFlowCompleteStep _preRaceFlowCompleteStep;
  int? _lastStepIndex;

  DevicesManager devices = DeviceConnectionService.createDevices(
    DeviceName.coach,
    DeviceType.advertiserDevice,
    data: '',
  );

  PreRaceController({required this.masterRace}) {
    _initializeSteps();
  }

  void _initializeSteps() {
    _reviewRunnersStep = ReviewRunnersStep(
      masterRace: masterRace,
      onNext: () async {
        final encoded =
            await BibEncodeUtils.getEncodedRunnersBibData(masterRace);
        Logger.d(
            'PRE-RACE DEBUG: Encoded runners data length: ${encoded.length}');
        if (encoded == '') {
          Logger.e('Failed to encode runners data');
          return;
        }
        devices.bibRecorder!.data = encoded;
      },
    );
    // Seed initial canProceed so the first render uses a correct value
    _reviewRunnersStep.seedInitialProceed();
    _shareRunnersStep = ShareRunnersStep(devices: devices);
    _preRaceFlowCompleteStep = PreRaceFlowCompleteStep();
  }

  Future<bool> showPreRaceFlow(
      BuildContext context, bool showProgressIndicator) async {
    final int startIndex = _lastStepIndex ?? 0;
    // Ensure initial proceed state is computed before rendering the sheet
    await _reviewRunnersStep.seedInitialProceed();
    return await showFlow(
      context: context,
      showProgressIndicator: showProgressIndicator,
      steps: _getSteps(context),
      initialIndex: startIndex,
      onDismiss: (lastIndex) {
        _lastStepIndex = lastIndex;
      },
    );
  }

  List<FlowStep> _getSteps(BuildContext context) {
    return [
      _reviewRunnersStep,
      _shareRunnersStep,
      _preRaceFlowCompleteStep,
    ];
  }
}
