import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/coach/flows/widgets/flow_instructions.dart';

/// A FlowStep implementation for the reconnect step in the post-race flow
class ReconnectStep extends FlowStep {
  /// Creates a new instance of ReconnectStep
  ReconnectStep()
      : super(
          title: 'Collect Results',
          description: 'Get the times and bib numbers from your volunteers\' '
              'phones.',
          content: const FlowInstructions(steps: [
            'Once every runner has finished, the Timer and Bib Recorder '
                'each tap Stop.',
            'They tap Share Times and Share Bibs, and keep their phones '
                'near yours.',
            'Tap Next. Their phones appear on the next page.',
          ]),
        );
}
