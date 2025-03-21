import 'package:flutter/material.dart';
import 'package:xcelerate/coach/merge_conflicts_screen/model/timing_data.dart';
import '../../../../../race_screen/widgets/runner_record.dart' show RunnerRecord;
import 'review_header.dart';
import 'results_table.dart';

class ResultsReviewWidget extends StatelessWidget {
  final TimingData? timingData;
  final List<RunnerRecord>? runnerRecords;

  const ResultsReviewWidget({
    super.key,
    required this.timingData,
    required this.runnerRecords,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ReviewHeader(),
            ResultsTable(timingData: timingData),          ],
        ),
      ),
    );
  }
}
