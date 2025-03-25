import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../model/team_record.dart';


class TeamComparisonWidget extends StatelessWidget {
  final String rank;
  final TeamRecord team;
  const TeamComparisonWidget({
    super.key,
    required this.rank,
    required this.team,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$rank. ${team.school}',
              style: AppTypography.bodySemibold,
            ),
            Text(
              '${team.score} Points',
              style: AppTypography.bodyRegular.copyWith(color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Scorers: ${team.scorers.map((r) => r.name).join(', ')},',
          style: AppTypography.bodyRegular,
        ),
        const SizedBox(height: 4),
        Text(
          'Times: ${team.runners.map((r) => r.formattedFinishTime).join(', ')},',
          style: AppTypography.bodyRegular.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}
  