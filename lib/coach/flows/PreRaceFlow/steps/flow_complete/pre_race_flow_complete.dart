import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';

class PreRaceFlowCompleteStep extends FlowStep {
  PreRaceFlowCompleteStep()
      : super(
          title: 'Pre Race Setup Complete',
          description:
              'Great job! You\'re timing your race. Click Next once the race is finished.',
          content: const SizedBox(),
          canProceed: () => true,
        );
}
