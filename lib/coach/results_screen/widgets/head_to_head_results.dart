import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../model/team_record.dart';
import 'head_to_head_results_card.dart';


class HeadToHeadResults extends StatelessWidget {
  final List<List<TeamRecord>> headToHeadTeamResults;

  const HeadToHeadResults({super.key, required this.headToHeadTeamResults});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Head-to-Head Results',
          style: AppTypography.titleSemibold,
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: headToHeadTeamResults.length,
          itemBuilder: (context, index) {
            final matchup = headToHeadTeamResults[index];
            return HeadToHeadResultsCard(team1: matchup[0], team2: matchup[1]);
          },
        )
      ],
    );
  }
}