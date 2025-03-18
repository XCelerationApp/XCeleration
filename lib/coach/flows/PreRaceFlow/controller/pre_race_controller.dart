import '../../controller/flow_controller.dart';
import '../../model/flow_model.dart';
import 'package:flutter/material.dart';
import '../../../../utils/enums.dart';
import '../../../../core/services/device_connection_service.dart';
import '../../../../utils/database_helper.dart';
import '../steps/review_runners/review_runners_step.dart';
import '../steps/share_runners/share_runners_step.dart';

class PreRaceController {
  final int raceId;
  late ReviewRunnersStep _reviewRunnersStep;
  late ShareRunnersStep _shareRunnersStep;

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
      final encoded = await DatabaseHelper.instance.getEncodedRunnersData(raceId);
      devices.bibRecorder!.data = encoded;
    });
    _shareRunnersStep = ShareRunnersStep(devices: devices);
  }

  Future<bool> showPreRaceFlow(BuildContext context, bool showProgressIndicator) {
    return showFlow(
      context: context,
      showProgressIndicator: showProgressIndicator,
      steps: _getSteps(context),
    );
  }

  List<FlowStep> _getSteps(BuildContext context) {
    return [
      _reviewRunnersStep,
      _shareRunnersStep,
    ];
  }
}