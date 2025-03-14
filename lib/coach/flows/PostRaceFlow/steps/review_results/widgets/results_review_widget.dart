import 'package:flutter/material.dart';
import 'package:xcelerate/coach/merge_conflicts_screen/model/timing_data.dart';
import 'review_header.dart';
import 'results_table.dart';

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
            const ReviewHeader(),
            ResultsTable(timingData: timingData),
          ],
        ),
      ),
    );
  }
}
