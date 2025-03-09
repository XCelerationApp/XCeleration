import 'package:flutter/material.dart';
import '../coach/flows/controller/flow_controller.dart';
import '../utils/flow_widget.dart';

/// Utility class for managing flow logic
class FlowUtils {
  /// Create a default set of flow steps for a given process type
  static Future<List<FlowStep>> createFlowSteps(String flowType, int raceId, List<Widget> contentWidgets) async {
    final steps = <FlowStep>[];
    
    switch (flowType) {
      case 'setup':
        steps.add(FlowStep(
          title: 'Load Runners',
          description: 'Add runners to your race by entering their information or importing from a previous race.',
          content: contentWidgets[0],
          canProceed: () async => true,
        ));
        if (contentWidgets.length > 1) {
          steps.add(FlowStep(
            title: 'Setup Complete',
            description: 'Great job! You\'ve finished setting up your race.',
            content: contentWidgets[1],
            canProceed: () async => true,
          ));
        }
        break;
        
      case 'pre_race':
        steps.add(FlowStep(
          title: 'Review Runners',
          description: 'Make sure all runner information is correct before the race starts.',
          content: contentWidgets[0],
          canProceed: () async => true,
        ));
        if (contentWidgets.length > 1) {
          steps.add(FlowStep(
            title: 'Share Runners',
            description: 'Share the runners with the bib recorders phone before starting the race.',
            content: contentWidgets[1],
            canProceed: () async => true,
          ));
        }
        if (contentWidgets.length > 2) {
          steps.add(FlowStep(
            title: 'Ready to Start',
            description: 'The race is ready to begin. Click Next once the race is finished.',
            content: contentWidgets[2],
            canProceed: () async => true,
          ));
        }
        break;
        
      case 'post_race':
        steps.add(FlowStep(
          title: 'Load Results',
          description: 'Load the results of the race from the assistant devices.',
          content: contentWidgets[0],
          canProceed: () async => true,
        ));
        if (contentWidgets.length > 1) {
          steps.add(FlowStep(
            title: 'Review Results',
            description: 'Review and verify the race results before saving them.',
            content: contentWidgets[1],
            canProceed: () async => true,
          ));
        }
        if (contentWidgets.length > 2) {
          steps.add(FlowStep(
            title: 'Save Results',
            description: 'Save the final race results to complete the race.',
            content: contentWidgets[2],
            canProceed: () async => true,
          ));
        }
        break;
        
      default:
        steps.add(FlowStep(
          title: 'Step 1',
          description: 'Complete this step to proceed.',
          content: contentWidgets.isNotEmpty ? contentWidgets[0] : const SizedBox.shrink(),
          canProceed: () async => true,
        ));
        break;
    }
    
    return steps;
  }
}
