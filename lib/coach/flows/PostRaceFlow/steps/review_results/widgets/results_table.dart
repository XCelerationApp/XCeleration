import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/database/race_result.dart';
import '../../../../../race_results/widgets/collapsible_results_widget.dart';

/// A table displaying race results with runner information and times
class ResultsTable extends StatelessWidget {
  /// The race timing data to display
  final List<RaceResult> results;

  /// Maximum number of rows to show before truncating
  final int maxVisibleRows;

  const ResultsTable({
    super.key,
    required this.results,
    this.maxVisibleRows = 10,
  });

  @override
  Widget build(BuildContext context) {
    // Simple container with border that wraps the collapsible results widget
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CollapsibleResultsWidget(results: results),
    );
  }
}
