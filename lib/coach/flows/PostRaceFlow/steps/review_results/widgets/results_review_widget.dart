import 'package:flutter/material.dart';
import 'review_header.dart';
import 'results_table.dart';
import '../../../../../race_results/model/results_record.dart';

/// Widget that displays the review of race results
class ResultsReviewWidget extends StatelessWidget {
  /// The race results to display
  final List<ResultsRecord> results;

  const ResultsReviewWidget({
    super.key,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    // Simple vertical layout without unnecessary nesting
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const ReviewHeader(),
          const SizedBox(height: 16),
          ResultsTable(results: results),
        ],
      ),
    );
  }
}
