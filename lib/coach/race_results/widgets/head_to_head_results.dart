import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import 'head_to_head_results_widget.dart';
import '../controller/race_results_controller.dart';

class HeadToHeadResults extends StatelessWidget {
  final RaceResultsController controller;
  const HeadToHeadResults({
    super.key,
    required this.controller,
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
            if (controller.headToHeadTeamResults == null ||
                controller.headToHeadTeamResults!.isEmpty)
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
              ...controller.headToHeadTeamResults!
                  .map((matchup) => HeadToHeadResultsWidget(matchup: matchup)),
          ],
        ),
      ),
    );
  }
}
