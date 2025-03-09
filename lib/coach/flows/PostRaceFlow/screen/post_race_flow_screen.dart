import 'package:flutter/material.dart';
import '../controller/post_race_flow_controller.dart';
import '../widget/load_results_widget.dart';
import '../widget/review_results_widget.dart';
import '../widget/save_results_widget.dart';

class PostRaceFlowScreen extends StatefulWidget {
  final int raceId;
  final Function onComplete;
  
  const PostRaceFlowScreen({
    Key? key,
    required this.raceId,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<PostRaceFlowScreen> createState() => _PostRaceFlowScreenState();
}

class _PostRaceFlowScreenState extends State<PostRaceFlowScreen> {
  late PostRaceFlowController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = PostRaceFlowController(raceId: widget.raceId);
    _startPostRaceFlow();
  }
  
  Future<void> _startPostRaceFlow() async {
    // Create load results screen
    final loadResultsScreen = LoadResultsWidget(
      controller: _controller,
      deviceConnections: _controller.deviceConnections,
      onReloadResults: () {
        setState(() {
          _controller.resetResultsLoading();
        });
      },
    );
    
    // Create review results screen
    final reviewResultsScreen = ReviewResultsWidget();
    
    // Create save results screen
    final saveResultsScreen = SaveResultsWidget();
    
    // Create flow steps
    final steps = await _controller.createPostRaceFlowSteps(
      loadResultsScreen,
      reviewResultsScreen,
      saveResultsScreen,
    );
    
    // Show the flow
    final isCompleted = await _controller.showFlow(
      context: context,
      steps: steps,
    );
    
    if (isCompleted) {
      await _controller.updateFlowStateToFinished();
      widget.onComplete();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(); // This widget doesn't need a UI as it only shows the flow
  }
}
