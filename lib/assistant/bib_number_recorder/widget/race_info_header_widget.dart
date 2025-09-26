import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/bib_number_controller.dart';
import '../../../core/components/race_components.dart';

class RaceInfoHeaderWidget extends StatelessWidget {
  final BibNumberController controller;

  const RaceInfoHeaderWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    String status;
    Color statusColor;

    if (controller.isRecording) {
      status = 'In progress';
      statusColor = AppColors.primaryColor;
    } else if (controller.bibRecords.isNotEmpty) {
      status = 'Finished';
      statusColor = Colors.green[700]!;
    } else {
      status = 'Ready';
      statusColor = Colors.black54;
    }

    return RaceStatusHeaderWidget(
      status: status,
      statusColor: statusColor,
      runnerCount: controller.runners.length,
      recordCount: controller.countNonEmptyBibNumbers(),
      recordLabel: 'Bibs',
      onRunnersTap: !controller.isRecording
          ? () => controller.showRunnersLoadedSheet(context)
          : null,
      showDropdown: !controller.isRecording,
    );
  }
}
