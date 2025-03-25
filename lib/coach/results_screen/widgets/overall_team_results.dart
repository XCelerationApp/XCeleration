import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../model/team_record.dart';
import 'team_result_card.dart';




class OverallTeamResultsWidget extends StatelessWidget {
  final List<TeamRecord> overallTeamResults;

  const OverallTeamResultsWidget({
    super.key,
    required this.overallTeamResults,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Overall Team Results',
          style: AppTypography.titleSemibold,
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: overallTeamResults.length,
          itemBuilder: (context, index) {
            final team = overallTeamResults[index];
            return TeamResultCard(team: team);
          },
        ),
      ],
    );
  }
}