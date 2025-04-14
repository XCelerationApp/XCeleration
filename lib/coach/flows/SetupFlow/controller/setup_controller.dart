import '../steps/setup_complete/setup_complete_step.dart';
import '../steps/load_runners/load_runners_step.dart';
import '../../controller/flow_controller.dart';
import '../../model/flow_model.dart';
import 'package:flutter/material.dart';

class SetupController {
  final int raceId;
  late LoadRunnersStep _loadRunnersStep;
  late SetupCompleteStep _setupCompleteStep;
  int? _lastStepIndex;

  SetupController({required this.raceId}) {
    _initializeSteps();
  }

  void _initializeSteps() {
    _loadRunnersStep = LoadRunnersStep(
      raceId: raceId,
    );
    _setupCompleteStep = SetupCompleteStep();
  }

  Future<bool> showSetupFlow(
      BuildContext context, bool showProgressIndicator) async {
    final steps = _getSteps();
    final int startIndex = _lastStepIndex ?? 0;

    return await showFlow(
      context: context,
      showProgressIndicator: showProgressIndicator,
      steps: steps,
      initialIndex: startIndex,
      onDismiss: (lastIndex) {
        _lastStepIndex = lastIndex;
      },
    );
  }

  List<FlowStep> _getSteps() {
    return [
      _loadRunnersStep,
      _setupCompleteStep,
    ];
  }
}
