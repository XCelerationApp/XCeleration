import 'package:flutter/material.dart';
import '../model/flow_model.dart';

/// Controller class for handling all flow-related operations
class FlowController {
  
  /// Setup the race with runners
  /// Shows a flow with the provided steps and handles user progression
  static Future<bool> setupFlow(BuildContext context, List<FlowStep> steps) async {
    return await showFlow(
      context: context,
      showProgressIndicator: true,
      steps: steps,
    );
  }

  /// Pre-race setup flow
  /// Shows a flow for pre-race setup and coordination
  static Future<bool> preRaceFlow(BuildContext context, List<FlowStep> steps) async {
    return await showFlow(
      context: context,
      steps: steps,
    );
  }

  /// Post-race setup flow
  /// Shows a flow for post-race data collection and result processing
  static Future<bool> postRaceFlow(BuildContext context, List<FlowStep> steps) async {
    return await showFlow(
      context: context,
      steps: steps,
    );
  }
}
