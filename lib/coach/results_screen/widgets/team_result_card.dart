import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../model/team_record.dart';


class TeamResultCard extends StatelessWidget {
  final TeamRecord team;

  const TeamResultCard({
    super.key,
    required this.team,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (team.place != null)
                  Text(
                    '${team.place}. ${team.school}',
                    style: AppTypography.titleSemibold,
                  ),
                if (team.place == null)
                  Text(
                    team.school,
                    style: AppTypography.titleSemibold,
                  ),
                Text(
                  '${team.score} Points',
                  style: AppTypography.bodyRegular.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Scorers: ${team.scorers.map((r) => r.name).join(', ')},',
              style: AppTypography.bodyRegular,
            ),
            const SizedBox(height: 4),
            if (team.place != null)
              Text(
                'Times: ${team.runners.map((r) => r.formattedFinishTime).join(', ')},',
                style: AppTypography.bodyRegular.copyWith(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}