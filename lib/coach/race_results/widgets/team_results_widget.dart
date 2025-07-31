import 'package:flutter/material.dart';
import 'package:xceleration/coach/race_results/widgets/collapsible_results_widget.dart';
import '../../../core/theme/typography.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/shared/services/race_results_service.dart';

class TeamResultsWidget extends StatelessWidget {
  final RaceResultsData raceResultsData;

  const TeamResultsWidget({
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
              'Team Results',
              style: AppTypography.titleSemibold,
            ),
            const SizedBox(height: 16),
            CollapsibleResultsWidget(
                results: raceResultsData.overallTeamResults, initialVisibleCount: 3),
          ],
        ),
      ),
    );
  }
}
