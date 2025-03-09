import 'package:flutter/material.dart';
import '../../controller/flow_controller.dart';
import '../../../../utils/database_helper.dart';
import '../../../../utils/flow_widget.dart';
import '../../../../utils/enums.dart';
import '../../../../core/services/device_connection_service.dart';
import '../../../../core/components/device_connection_widget.dart';
import '../../../runners_management_screen/screen/runners_management_screen.dart';

/// Controller for managing the pre-race flow
class PreRaceFlowController extends FlowController {
  Map<DeviceName, Map<String, dynamic>> deviceConnections = {};
  
  PreRaceFlowController({required int raceId}) : super(raceId: raceId) {
    // Initialize device connections
    deviceConnections = DeviceConnectionService.createOtherDeviceList(
      DeviceName.coach,
      DeviceType.advertiserDevice,
      data: '',
    );
  }
  
  /// Start the pre-race flow
  Future<bool> startFlow(BuildContext context) async {
    // Create UI components
    final runnersReviewScreen = RunnersManagementScreen(
      raceId: raceId, 
      showHeader: false, 
      onBack: null,
      onContentChanged: () async {
        await updateDeviceConnectionsWithRunnerData();
      },
    );
    
    final shareRunnersScreen = Center(
      child: deviceConnectionWidget(
        DeviceName.coach,
        DeviceType.advertiserDevice,
        deviceConnections,
      ),
    );
    
    final readyScreen = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_score, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            'Race Ready to Start',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Press Next once the race is finished to begin recording results.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
    
    // Initialize device connections with runner data
    await updateDeviceConnectionsWithRunnerData();
    
    // Create flow steps
    final steps = await createPreRaceFlowSteps(
      runnersReviewScreen,
      shareRunnersScreen,
      readyScreen,
    );
    
    // Show the flow
    final result = await showFlow(
      context: context,
      steps: steps,
      dismissible: true,
    );
    
    // If flow was completed, update the race state
    if (result) {
      await updateFlowStateToPostRace();
    }
    
    return result;
  }
  
  /// Get encoded runners data for sharing with devices
  Future<String> getEncodedRunnersData() async {
    final runners = await DatabaseHelper.instance.getRaceRunners(raceId);
    return runners.map((runner) => [
      runner['bib_number'],
      runner['name'],
      runner['school'],
      runner['grade']
    ].join(',')).join(' ');
  }
  
  /// Update device connections with runner data
  Future<void> updateDeviceConnectionsWithRunnerData() async {
    final encoded = await getEncodedRunnersData();
    deviceConnections[DeviceName.bibRecorder]!['data'] = encoded;
  }
  
  /// Initialize the pre-race flow with UI elements
  Future<List<FlowStep>> createPreRaceFlowSteps(
    Widget runnersReviewScreen,
    Widget shareRunnersScreen,
    Widget readyScreen,
  ) async {
    return [
      FlowStep(
        title: 'Review Runners',
        description: 'Make sure all runner information is correct before the race starts. You can make any last-minute changes here.',
        content: runnersReviewScreen,
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Share Runners',
        description: 'Share the runners with the bib recorders phone before starting the race.',
        content: shareRunnersScreen,
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Ready to Start!',
        description: 'The race is ready to begin. Click Next once the race is finished to begin the post-race flow.',
        content: readyScreen,
        canProceed: () async => true,
      ),
    ];
  }
  
  /// Update the race flow state when pre-race setup is complete
  Future<void> updateFlowStateToPostRace() async {
    await updateRaceFlowState('post_race');
  }
}
