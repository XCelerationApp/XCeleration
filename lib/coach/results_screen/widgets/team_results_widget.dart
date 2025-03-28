import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../model/team_record.dart';

class TeamResultsWidget extends StatelessWidget {
  final List<TeamRecord> teams;
  final Map<String, bool> expandedTeams;
  final Function(String) onToggleTeam;

  const TeamResultsWidget({
    super.key,
    required this.teams,
    required this.expandedTeams,
    required this.onToggleTeam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team Results',
              style: AppTypography.titleSemibold,
            ),
            const SizedBox(height: 16),
            ...teams.map((team) => _buildTeamCard(team, context)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(TeamRecord team, BuildContext context) {
    final isExpanded = expandedTeams[team.school] ?? false;
    final displayRunners = isExpanded 
        ? team.runners 
        : team.runners.take(3).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team header
            Row(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      '${team.place}',
                      style: AppTypography.bodySemibold.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.school,
                        style: AppTypography.headerSemibold,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Score: ${team.score} | Avg: ${_formatAverageTime(team)}',
                        style: AppTypography.bodyRegular.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            // Runner header
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text('Rank', style: AppTypography.bodySemibold)),
                  Expanded(flex: 3, child: Text('Name', style: AppTypography.bodySemibold)),
                  Expanded(flex: 1, child: Text('Time', style: AppTypography.bodySemibold)),
                ],
              ),
            ),
            // Runners
            ...displayRunners.map((runner) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${runner.place}',
                      style: AppTypography.bodyRegular,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      runner.name,
                      style: AppTypography.bodyRegular,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      runner.formattedFinishTime,
                      style: AppTypography.bodyRegular,
                    ),
                  ),
                ],
              ),
            )),
            // Show more button
            if (team.runners.length > 3) ...[
              Container(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => onToggleTeam(team.school),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                  child: Text(
                    isExpanded ? 'See Less' : 'See More',
                    style: AppTypography.smallBodyRegular,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatAverageTime(TeamRecord team) {
    if (team.runners.isEmpty) return '--:--';
    
    int totalMs = 0;
    for (var runner in team.runners) {
      totalMs += runner.finishTime.inMilliseconds;
    }
    final avgTimeMs = totalMs ~/ team.runners.length;
    
    final minutes = (avgTimeMs ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((avgTimeMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    
    return '$minutes:$seconds';
  }
}
