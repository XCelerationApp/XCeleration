import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../controller/bib_number_controller.dart';

class RaceInfoHeaderWidget extends StatelessWidget {
  final BibNumberController controller;

  const RaceInfoHeaderWidget({
    super.key,
    required this.controller
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            controller.isRecording
                ? 'Race in progress'
                : controller.bibRecords.isNotEmpty
                    ? 'Race finished'
                    : 'Ready to start',
            style: AppTypography.bodySemibold.copyWith(
              color: controller.isRecording
                  ? AppColors.primaryColor
                  : controller.bibRecords.isNotEmpty
                      ? Colors.green[700]
                      : Colors.black54,
              fontWeight: controller.isRecording || controller.bibRecords.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (!controller.isRecording)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => controller.showRunnersLoadedSheet(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Runners: ${controller.runners.length}',
                        style: AppTypography.bodySemibold.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Text(
            'Bibs: ${controller.countNonEmptyBibNumbers()}',
            style: AppTypography.bodySemibold.copyWith(
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
