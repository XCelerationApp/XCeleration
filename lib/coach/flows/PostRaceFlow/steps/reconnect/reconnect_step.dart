import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';

/// A FlowStep implementation for the reconnect step in the post-race flow
class ReconnectStep extends FlowStep {
  /// Creates a new instance of ReconnectStep
  ReconnectStep()
      : super(
          title: 'Reconnect with Assistants',
          description:
              'Reconnect with your assistants to gather the race results. Proceed when ready.',
          content: SizedBox.shrink(),
        );
}
