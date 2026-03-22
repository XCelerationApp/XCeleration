import 'package:flutter/material.dart';
import 'package:xceleration/shared/services/i_race_results_service.dart';
import 'package:xceleration/shared/services/race_results_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../model/results_record.dart';
import '../model/team_record.dart';
import 'collapsible_results_widget.dart';

class HeadToHeadResultsWidget extends StatefulWidget {
  final List<TeamRecord> matchup;
  final IRaceResultsService raceResultsService;

  const HeadToHeadResultsWidget({
    super.key,
    required this.matchup,
    this.raceResultsService = const RaceResultsService(),
  });

  @override
  State<HeadToHeadResultsWidget> createState() =>
      _HeadToHeadResultsWidgetState();
}

class _HeadToHeadResultsWidgetState extends State<HeadToHeadResultsWidget> {
  late TeamRecord teamA;
  late TeamRecord teamB;
  late List<ResultsRecord> allResults;

  @override
  void initState() {
    super.initState();
    _computeResults(widget.matchup);
  }

  @override
  void didUpdateWidget(HeadToHeadResultsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.matchup != oldWidget.matchup) {
      _computeResults(widget.matchup);
    }
  }

  void _computeResults(List<TeamRecord> matchup) {
    teamA = matchup[0];
    teamB = matchup[1];

    // We'll show a selection of top 3 runners combined from both teams
    final raceResults = [...teamA.topSeven, ...teamB.topSeven];
    raceResults.sort((a, b) => a.comparePlaceTo(b));

    // Convert RaceResult objects to ResultsRecord objects for display
    // No dedicated race distance context here; pace/splits not critical for H2H
    allResults = widget.raceResultsService.convertToResultsRecords(raceResults);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matchup.length != 2) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
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
                      teamA.place == 1
                          ? AppColors.primaryColor
                          : Colors.grey.shade600),
                ),
                Container(
                  height: 24,
                  width: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      'VS',
                      style: AppTypography.smallCaption.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildTeamHeader(
                      teamB,
                      teamB.place == 1
                          ? AppColors.primaryColor
                          : Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            CollapsibleIndividualResultsWidget(
              results: allResults,
              initialVisibleCount: 3,
            ),
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
          team.team.abbreviation ?? 'N/A',
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
