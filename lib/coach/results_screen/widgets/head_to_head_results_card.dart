import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../model/team_record.dart';
import 'team_comparison_widget.dart';


class HeadToHeadResultsCard extends StatelessWidget {
  final TeamRecord team1;
  final TeamRecord team2;
  const HeadToHeadResultsCard({
    super.key,
    required this.team1,
    required this.team2,
  });


  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Matchup Header
            Text(
              '${team1.school} vs ${team2.school}',
              style: AppTypography.titleSemibold,
            ),
            const SizedBox(height: 8),

            // Team 1 Result
            TeamComparisonWidget(
              rank: '1',
              team: team1,
            ),

            const Divider(color: Colors.grey),

            // Team 2 Result
            TeamComparisonWidget(
              rank: '2',
              team: team2,
            ),
          ],
        ),
      ),
    );
  }
}