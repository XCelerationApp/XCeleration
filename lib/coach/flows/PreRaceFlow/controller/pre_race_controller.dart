import '../../controller/flow_controller.dart';
import '../../model/flow_model.dart';
import 'package:flutter/material.dart';
import '../../../runners_management_screen/screen/runners_management_screen.dart';
import '../../../../utils/enums.dart';
import '../../../../core/services/device_connection_service.dart';
import '../../../../core/components/device_connection_widget.dart';
import '../../../../utils/database_helper.dart';

class PreRaceController {
  final int raceId;
  PreRaceController({required this.raceId});

  Map<DeviceName, Map<String, dynamic>> otherDevices = DeviceConnectionService.createOtherDeviceList(
      DeviceName.coach,
      DeviceType.advertiserDevice,
      data: '',
    );

  Future<bool> showPreRaceFlow(BuildContext context, bool showProgressIndicator) {
    return showFlow(
      context: context,
      showProgressIndicator: showProgressIndicator,
      steps: _getSteps(),
    );
  }
  List<FlowStep> _getSteps() {
    return [
      FlowStep(
        title: 'Review Runners',
        description: 'Make sure all runner information is correct before the race starts. You can make any last-minute changes here.',
        content: Column(
          children: [
            RunnersManagementScreen(
              raceId: raceId, 
              showHeader: false, 
              onBack: null, 
            )
          ]
        ),
        canProceed: () async => true,
        onNext: () async {
          final encoded = await DatabaseHelper.instance.getEncodedRunnersData(raceId);
          otherDevices[DeviceName.bibRecorder]!['data'] = encoded;
        },
      ),
      FlowStep(
        title: 'Share Runners',
        description: 'Share the runners with the bib recorders phone before starting the race.',
        content: Center(
          child: deviceConnectionWidget(
            DeviceName.coach,
            DeviceType.advertiserDevice,
            otherDevices,
          )
        ),
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Ready to Start!',
        description: 'The race is ready to begin. Click Next once the race is finished to begin the post-race flow.',
        content: SizedBox.shrink(),
        canProceed: () async => true,
      ),
    ];
  }
}