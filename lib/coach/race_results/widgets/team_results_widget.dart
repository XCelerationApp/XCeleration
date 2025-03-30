import 'package:flutter/material.dart';
import 'package:xcelerate/coach/race_results/widgets/collapsible_results_widget.dart';
import '../../../core/theme/typography.dart';
import '../controller/race_results_controller.dart';

class TeamResultsWidget extends StatelessWidget {
  final RaceResultsController controller;

  const TeamResultsWidget({
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
              'Team Results',
              style: AppTypography.titleSemibold,
            ),
            const SizedBox(height: 16),
            CollapsibleResultsWidget(
                results: controller.overallTeamResults, initialVisibleCount: 3),
          ],
        ),
      ),
    );
  }
}
