import 'package:flutter/material.dart';
import 'package:xcelerate/coach/merge_conflicts_screen/model/timing_data.dart';
import 'package:xcelerate/core/theme/app_colors.dart';
import 'package:xcelerate/core/theme/typography.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';

class ResultsReviewWidget extends StatelessWidget {
  final TimingData? timingData;

  const ResultsReviewWidget({
    Key? key,
    required this.timingData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fact_check_outlined, size: 80, color: AppColors.primaryColor),
            const SizedBox(height: 24),
            Text(
              'Review Race Results',
              style: AppTypography.titleSemibold.copyWith(color: AppColors.darkColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Make sure all times and placements are correct.',
              style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildResultsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Text('Place', 
                  style: AppTypography.bodySemibold.copyWith(color: AppColors.darkColor),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text('Runner', 
                  style: AppTypography.bodySemibold.copyWith(color: AppColors.darkColor),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text('Time', 
                  style: AppTypography.bodySemibold.copyWith(color: AppColors.darkColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          if (timingData != null && timingData!.runnerRecords.isNotEmpty) ...[
            // Show actual race results when available
            ...timingData!.runnerRecords.map((runner) {
              final record = _getRunnerRecord(runner);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(record?.place.toString() ?? '-'),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('${runner.name} (${runner.bib})'),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(_formatTimeDisplay(record?.elapsedTime ?? 0)),
                    ),
                  ],
                ),
              );
            }).toList(),
            
            if (timingData!.runnerRecords.length > 10) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... and ${timingData!.runnerRecords.length - 10} more runners',
                  style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.6)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ] else ...[
            // Show placeholder rows if no data available
            for (var i = 1; i <= 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(i.toString()),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('Runner $i'),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('${(i * 15.5).toStringAsFixed(2)}s'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
  
  // Helper method to get a runner record from timing data
  dynamic _getRunnerRecord(RunnerRecord runner) {
    if (timingData == null) return null;
    
    // Find the corresponding record for this runner
    for (var record in timingData!.records) {
      if (record.bib == runner.bib) {
        return record;
      }
    }
    return null;
  }
  
  // Helper method to format time for display
  String _formatTimeDisplay(int milliseconds) {
    if (milliseconds <= 0) return '-';
    
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    final remainingMilliseconds = milliseconds % 1000;
    
    if (minutes > 0) {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}.${(remainingMilliseconds ~/ 10).toString().padLeft(2, '0')}';
    } else {
      return '$remainingSeconds.${(remainingMilliseconds ~/ 10).toString().padLeft(2, '0')}';
    }
  }
}
