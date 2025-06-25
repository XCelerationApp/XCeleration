import 'package:xceleration/core/utils/logger.dart';

import '../../../../core/utils/database_helper.dart';
import '../../controller/flow_controller.dart';
import '../../model/flow_model.dart';
import 'package:flutter/material.dart';
import '../../../../utils/enums.dart';
import '../../../../core/services/device_connection_service.dart';
import '../../../../core/utils/encode_utils.dart' as encode_utils;
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
    _reviewRunnersStep = ReviewRunnersStep(
      raceId: raceId,
      onNext: () async {
        // DEBUG: Log runners loaded for this race
        final runners = await DatabaseHelper.instance.getRaceRunners(raceId);
        Logger.d(
            'PRE-RACE DEBUG: Runners for raceId=raceId: count=${runners.length}');
        for (var r in runners) {
          Logger.d(
              'PRE-RACE DEBUG: Runner: bib=${r.bib}, name=${r.name}, school=${r.school}, grade=${r.grade}');
        }
        final encoded = await encode_utils.getEncodedRunnersData(raceId);
        Logger.d(
            'PRE-RACE DEBUG: Encoded runners data length: ${encoded.length}');
        if (encoded == '') {
          Logger.e('Failed to encode runners data');
          return;
        }
        devices.bibRecorder!.data = encoded;
      },
    );
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
