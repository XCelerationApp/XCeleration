import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../utils/enums.dart';
import '../controller/timing_controller.dart';

class RaceInfoHeaderWidget extends StatelessWidget {
  final TimingController controller;
  const RaceInfoHeaderWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final hasRace =
        controller.raceStopped == false || (controller.endTime != null && controller.records.isNotEmpty);
    // Calculate runner count by explicitly counting each type
    final runnerTimeCount = controller.records
        .where((r) => r.type == RecordType.runnerTime && r.place != null)
        .length;
    final runnerCount = runnerTimeCount;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            controller.startTime == null
                ? 'Ready to start'
                : controller.raceStopped
                    ? 'Race finished'
                    : 'Race in progress',
            style: AppTypography.bodyRegular.copyWith(
              fontSize: 16,
              color: hasRace
                  ? controller.raceStopped
                      ? Colors.green[700]
                      : AppColors.primaryColor
                  : Colors.black54,
              fontWeight: hasRace ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (controller.records.isNotEmpty)
            Text(
              'Runners: $runnerCount',
              style: AppTypography.bodyRegular.copyWith(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
