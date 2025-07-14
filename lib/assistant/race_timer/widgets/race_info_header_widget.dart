import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/timing_controller.dart';
import '../../../core/components/race_components.dart';

class RaceInfoHeaderWidget extends StatelessWidget {
  final TimingController controller;
  const RaceInfoHeaderWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    String status;
    Color statusColor;

    if (controller.startTime == null) {
      status = 'Ready to start';
      statusColor = Colors.black54;
    } else if (controller.raceStopped) {
      status = 'Race finished';
      statusColor = Colors.green[700]!;
    } else {
      status = 'Race in progress';
      statusColor = AppColors.primaryColor;
    }

    // Calculate runner count by explicitly counting each type
    final runnerTimeCount = controller.records
        .where((r) => r.conflict == null)
        .length;

    return RaceStatusHeaderWidget(
      status: status,
      statusColor: statusColor,
      runnerCount: controller.records.isNotEmpty ? runnerTimeCount : null,
      recordLabel: 'Runners',
    );
  }
}
