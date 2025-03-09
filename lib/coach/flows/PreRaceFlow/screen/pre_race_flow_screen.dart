import 'package:flutter/material.dart';
import '../controller/pre_race_flow_controller.dart';
import '../../../../core/components/device_connection_widget.dart';
import '../../../../utils/enums.dart';
import '../../../runners_management_screen/screen/runners_management_screen.dart';

class PreRaceFlowScreen extends StatefulWidget {
  final int raceId;
  final Function onComplete;
  
  const PreRaceFlowScreen({
    Key? key,
    required this.raceId,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<PreRaceFlowScreen> createState() => _PreRaceFlowScreenState();
}

class _PreRaceFlowScreenState extends State<PreRaceFlowScreen> {
  late PreRaceFlowController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = PreRaceFlowController(raceId: widget.raceId);
    _startPreRaceFlow();
  }
  
  Future<void> _startPreRaceFlow() async {
    // Create review runners screen
    final runnersReviewScreen = Column(
      children: [
        RunnersManagementScreen(
          raceId: widget.raceId, 
          showHeader: false, 
          onBack: null, 
          onContentChanged: () async {
            await _controller.updateDeviceConnectionsWithRunnerData();
          },
        )
      ]
    );
    
    // Create share runners screen
    final shareRunnersScreen = Center(
      child: deviceConnectionWidget(
        DeviceName.coach,
        DeviceType.advertiserDevice,
        _controller.deviceConnections,
      )
    );
    
    // Create ready screen
    final readyScreen = const SizedBox.shrink();
    
    // Create flow steps
    final steps = await _controller.createPreRaceFlowSteps(
      runnersReviewScreen,
      shareRunnersScreen,
      readyScreen,
    );
    
    // Show the flow
    final isCompleted = await _controller.showFlow(
      context: context,
      steps: steps,
    );
    
    if (isCompleted) {
      await _controller.updateFlowStateToPostRace();
      widget.onComplete();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(); // This widget doesn't need a UI as it only shows the flow
  }
}
