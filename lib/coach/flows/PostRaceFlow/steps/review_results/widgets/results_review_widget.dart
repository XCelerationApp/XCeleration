import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/database/race_result.dart';
import 'review_header.dart';
import 'results_table.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

/// Widget that displays the review of race results
class ResultsReviewWidget extends StatelessWidget {
  /// The race results to display
  final MasterRace masterRace;

  const ResultsReviewWidget({
    super.key,
    required this.masterRace,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: masterRace.results,
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Error loading results: ${snapshot.error}'),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No results available.'),
          );
        }

        final results = snapshot.data! as List<RaceResult>;

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
      },
    );
  }
}
