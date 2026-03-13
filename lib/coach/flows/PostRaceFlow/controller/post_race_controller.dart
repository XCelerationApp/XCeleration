import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/coach/flows/PostRaceFlow/steps/load_results/load_results_step.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/enums.dart';

import 'package:xceleration/shared/models/database/master_race.dart';
import '../../controller/flow_controller.dart';
import '../steps/load_results/controller/load_results_controller.dart';
import '../steps/reconnect/reconnect_step.dart';

/// Function type that matches the [showFlow] top-level function signature,
/// used to allow injection in tests.
typedef ShowFlowFn = Future<bool> Function({
  required BuildContext context,
  required List<FlowStep> steps,
  bool showProgressIndicator,
  int initialIndex,
  StepChangedCallback? onStepChanged,
  void Function(int lastIndex)? onDismiss,
});

/// Controller for managing the post-race flow
class PostRaceController {
  final MasterRace masterRace;
  final ShowFlowFn _showFlow;

  // Controllers
  late final LoadResultsController _loadResultsController;

  // Flow steps
  late final ReconnectStep _reconnectStep;
  late final LoadResultsStep _loadResultsStep;

  // Track flow position
  int? _lastStepIndex;

  /// Constructor
  PostRaceController({
    required this.masterRace,
    ShowFlowFn? showFlowFn,
    DevicesManager? devices,
    LoadResultsController? loadResultsController,
  }) : _showFlow = showFlowFn ?? showFlow {
    _initializeSteps(
      devices: devices,
      loadResultsController: loadResultsController,
    );
  }

  /// Initialize the flow steps
  void _initializeSteps({
    DevicesManager? devices,
    LoadResultsController? loadResultsController,
  }) {
    // Create controllers first so they can be shared between steps
    final resolvedDevices = devices ??
        DeviceConnectionService.createDevices(
          DeviceName.coach,
          DeviceType.browserDevice,
        );
    _loadResultsController = loadResultsController ??
        LoadResultsController(
          masterRace: masterRace,
          devices: resolvedDevices,
        );
    _loadResultsController.initialize();

    // Create steps with the controllers
    _reconnectStep = ReconnectStep();
    _loadResultsStep = LoadResultsStep(
      controller: _loadResultsController,
    );
  }

  /// Show the post-race flow
  Future<bool> showPostRaceFlow(BuildContext context, bool dismissible) async {
    // Get steps
    final steps = _getSteps();
    final int startIndex = _lastStepIndex ?? 0;

    // Show the flow
    return await _showFlow(
      context: context,
      steps: steps,
      showProgressIndicator: dismissible,
      initialIndex: startIndex,
      onDismiss: (lastIndex) {
        _lastStepIndex = lastIndex;
      },
    );
  }

  /// Get the flow steps
  List<FlowStep> _getSteps() {
    return [
      _reconnectStep,
      _loadResultsStep,
    ];
  }

  @visibleForTesting
  List<FlowStep> buildSteps() => _getSteps();
}
