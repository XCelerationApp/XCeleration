import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/timing_controller.dart';
import '../../../core/components/race_components.dart';

class RaceStatusWidget extends StatelessWidget {
  final TimingController controller;
  const RaceStatusWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    String status;
    Color statusColor;

    if (controller.startTime == null) {
      status = 'Ready';
      statusColor = Colors.black54;
    } else if (controller.raceStopped) {
      status = 'Finished';
      statusColor = Colors.green[700]!;
    } else {
      status = 'In progress';
      statusColor = AppColors.primaryColor;
    }

    return RaceStatusHeaderWidget(
      status: status,
      statusColor: statusColor,
      runnerCount: controller.runnerCount,
      recordLabel: 'Runners',
    );
  }
}
