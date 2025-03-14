import 'package:flutter/material.dart';
import 'package:xcelerate/core/theme/app_colors.dart';
import 'package:xcelerate/core/theme/typography.dart';
import 'package:xcelerate/coach/merge_conflicts_screen/model/timing_data.dart';
import 'package:xcelerate/assistant/race_timer/timing_screen/model/timing_record.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';

import 'results_table_header.dart';
import 'runner_result_row.dart';
import 'placeholder_row.dart';

/// A table displaying race results with runner information and times
class ResultsTable extends StatelessWidget {
  /// The race timing data to display
  final TimingData? timingData;
  
  /// Maximum number of rows to show before truncating
  final int maxVisibleRows;

  const ResultsTable({
    super.key,
    required this.timingData,
    this.maxVisibleRows = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const ResultsTableHeader(),
          
          if (timingData != null && timingData!.runnerRecords.isNotEmpty) ...[
            // Show actual race results when available
            ...timingData!.runnerRecords.take(maxVisibleRows).map((runner) {
              final record = _getRunnerRecord(runner);
              return RunnerResultRow(
                runner: runner,
                timingRecord: record,
                formatTimeDisplay: _formatTimeDisplay,
              );
            }).toList(),
            
            if (timingData!.runnerRecords.length > maxVisibleRows) ...[
              _buildRemainingRunnersMessage(timingData!.runnerRecords.length - maxVisibleRows),
            ],
          ] else ...[
            // Show placeholder rows if no data available
            for (var i = 1; i <= 3; i++)
              PlaceholderRow(position: i),
          ],
        ],
      ),
    );
  }
  
  /// Get timing record for a runner
  TimingRecord? _getRunnerRecord(RunnerRecord runner) {
    if (timingData == null) return null;
    
    // Find the corresponding record for this runner
    for (var record in timingData!.records) {
      if (record.bib == runner.bib) {
        return record;
      }
    }
    
    return null;
  }
  
  /// Format time value for display
  String _formatTimeDisplay(dynamic elapsedTime) {
    if (elapsedTime is String) {
      return elapsedTime;
    } else if (elapsedTime is double) {
      return elapsedTime.toStringAsFixed(2) + 's';
    } else if (elapsedTime is int) {
      return elapsedTime.toString() + 's';
    } else {
      return '--';
    }
  }
  
  /// Build a message showing how many more runners aren't displayed
  Widget _buildRemainingRunnersMessage(int remainingCount) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '... and $remainingCount more runners',
        style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.6)),
        textAlign: TextAlign.center,
      ),
    );
  }
}
