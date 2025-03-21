import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';

/// A FlowStep implementation for the share results step in the post-race flow
class ShareResultsStep extends FlowStep {
  /// Creates a new instance of ShareResultsStep
  ShareResultsStep() : super(
    title: 'Share Results',
    description: 'Click Next to share the race results with your team.',
    content: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.yellow[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow[700]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.yellow[700]),
              const SizedBox(width: 8),
              Text(
                'Warning',
                style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Once you click Next, you will not be able to go back to previous steps or edit the race results.',
            style: TextStyle(color: Colors.yellow[700]),
          ),
        ],
      ),
    ),
    canProceed: () => true,
  );
  
  // No additional state needed for this step
}