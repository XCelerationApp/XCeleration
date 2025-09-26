import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import 'head_to_head_results_widget.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/shared/services/race_results_service.dart';

class HeadToHeadResults extends StatelessWidget {
  final RaceResultsData raceResultsData;
  const HeadToHeadResults({
    super.key,
    required this.raceResultsData,
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
            color: ColorUtils.withOpacity(Colors.black, 0.05),
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
            if (raceResultsData.headToHeadTeamResults.isEmpty)
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
              ...raceResultsData.headToHeadTeamResults
                  .map((matchup) => HeadToHeadResultsWidget(matchup: matchup)),
          ],
        ),
      ),
    );
  }
}
