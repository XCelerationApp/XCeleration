import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/coach/flows/widgets/flow_instructions.dart';

class PreRaceFlowCompleteStep extends FlowStep {
  PreRaceFlowCompleteStep()
      : super(
          title: 'Ready to Race',
          description: 'Your volunteers have the race. After it finishes, '
              'come back to this race and tap Collect Results.',
          content: const FlowInstructions(steps: [
            'The Timer taps Start Race when the gun goes, then Log Finish '
                'as each runner crosses the line.',
            'The Bib Recorder types each runner\'s bib number, in the order '
                'they finish.',
            'When there is a break in the runners, they compare counts.',
          ]),
          canProceed: () => true,
          nextLabel: 'Done',
        );
}
