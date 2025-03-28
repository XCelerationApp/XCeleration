import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../model/team_record.dart';

class CollapsibleHeadToHeadResults extends StatelessWidget {
  final List<List<TeamRecord>> headToHeadTeamResults;
  final Map<String, bool> expandedMatchups;
  final Function(String) onToggleMatchup;

  const CollapsibleHeadToHeadResults({
    super.key,
    required this.headToHeadTeamResults,
    required this.expandedMatchups,
    required this.onToggleMatchup,
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
              'Head to Head Results',
              style: AppTypography.titleSemibold,
            ),
            const SizedBox(height: 16),
            if (headToHeadTeamResults.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No head to head results available',
                    style: AppTypography.bodyRegular,
                  ),
                ),
              )
            else
              ...headToHeadTeamResults.map((matchup) => _buildMatchupCard(matchup, context)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchupCard(List<TeamRecord> matchup, BuildContext context) {
    if (matchup.length != 2) return const SizedBox.shrink();
    
    final teamA = matchup[0];
    final teamB = matchup[1];
    final matchupId = '${teamA.school}_vs_${teamB.school}';
    final isExpanded = expandedMatchups[matchupId] ?? false;
    
    // We'll show a selection of top 3 runners combined from both teams
    final allRunners = [...teamA.runners, ...teamB.runners];
    allRunners.sort((a, b) => a.place.compareTo(b.place));
    
    final displayRunners = isExpanded 
        ? allRunners 
        : allRunners.take(3).toList();

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
            // Teams comparison header
            Row(
              children: [
                Expanded(
                  child: _buildTeamHeader(
                    teamA, 
                    teamA.place == 1 ? AppColors.primaryColor : Colors.grey.shade600
                  ),
                ),
                Container(
                  height: 24,
                  width: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildTeamHeader(
                    teamB, 
                    teamB.place == 1 ? AppColors.primaryColor : Colors.grey.shade600
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
                  Expanded(flex: 2, child: Text('Name', style: AppTypography.bodySemibold)),
                  Expanded(flex: 2, child: Text('School', style: AppTypography.bodySemibold)),
                  Expanded(flex: 1, child: Text('Time', style: AppTypography.bodySemibold)),
                ],
              ),
            ),
            
            // Top runners
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
                    flex: 2,
                    child: Text(
                      runner.name,
                      style: AppTypography.bodyRegular,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      runner.school,
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
            if (allRunners.length > 3) ...[
              Container(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => onToggleMatchup(matchupId),
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

  Widget _buildTeamHeader(TeamRecord team, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(15),
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
        const SizedBox(height: 4),
        Text(
          team.school,
          style: AppTypography.headerSemibold,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Score: ${team.score}',
          style: AppTypography.bodyRegular.copyWith(
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
