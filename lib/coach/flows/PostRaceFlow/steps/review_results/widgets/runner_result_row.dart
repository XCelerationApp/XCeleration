import 'package:flutter/material.dart';
import 'package:xcelerate/assistant/race_timer/model/timing_record.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';

/// A row in the results table showing an individual runner's result
class RunnerResultRow extends StatelessWidget {
  /// The runner record to display
  final RunnerRecord runner;
  
  /// The timing record with placement and time information
  final TimingRecord? timingRecord;
  
  /// Function to format time for display
  final String Function(dynamic elapsedTime) formatTimeDisplay;

  const RunnerResultRow({
    super.key,
    required this.runner,
    this.timingRecord,
    required this.formatTimeDisplay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(timingRecord?.place?.toString() ?? '-'),
          ),
          Expanded(
            flex: 3,
            child: Text('${runner.name} (${runner.bib})'),
          ),
          Expanded(
            flex: 2,
            child: Text(formatTimeDisplay(timingRecord?.elapsedTime ?? 0)),
          ),
        ],
      ),
    );
  }
}
