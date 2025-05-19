import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../controller/race_results_controller.dart';
import 'collapsible_results_widget.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class IndividualResultsWidget extends StatelessWidget {
  final RaceResultsController controller;
  final int initialVisibleCount;

  const IndividualResultsWidget({
    super.key,
    required this.controller,
    this.initialVisibleCount = 5,
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
            color: ColorUtils.withOpacity(Color.fromRGBO(0, 0, 0, 1.0), 0.05),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Individual Results',
                  style: AppTypography.titleSemibold,
                ),
                Text(
                  '${controller.individualResults.length} Runners',
                  style: AppTypography.bodyRegular.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CollapsibleResultsWidget(
              results: controller.individualResults,
              initialVisibleCount: initialVisibleCount,
            ),
          ],
        ),
      ),
    );
  }
}
