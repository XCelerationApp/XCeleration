import '../../controller/flow_controller.dart';
import '../../model/flow_model.dart';
import 'package:flutter/material.dart';
import '../../../../utils/enums.dart';
import '../../../../core/services/device_connection_service.dart';
import '../../../../utils/encode_utils.dart' as encode_utils;
import '../steps/review_runners/review_runners_step.dart';
import '../steps/share_runners/share_runners_step.dart';
import '../steps/flow_complete/pre_race_flow_complete.dart';

class PreRaceController {
  final int raceId;
  late ReviewRunnersStep _reviewRunnersStep;
  late ShareRunnersStep _shareRunnersStep;
  late PreRaceFlowCompleteStep _preRaceFlowCompleteStep;
  int? _lastStepIndex;

  DevicesManager devices = DeviceConnectionService.createDevices(
    DeviceName.coach,
    DeviceType.advertiserDevice,
    data: '',
  );

  PreRaceController({required this.raceId}) {
    _initializeSteps();
  }

  void _initializeSteps() {
    _reviewRunnersStep = ReviewRunnersStep(raceId, () async {
      final encoded =
          await encode_utils.getEncodedRunnersData(raceId);
      devices.bibRecorder!.data = encoded;
    });
    _shareRunnersStep = ShareRunnersStep(devices: devices);
    _preRaceFlowCompleteStep = PreRaceFlowCompleteStep();
  }

  Future<bool> showPreRaceFlow(
      BuildContext context, bool showProgressIndicator) {
    final int startIndex = _lastStepIndex ?? 0;
    return showFlow(
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
