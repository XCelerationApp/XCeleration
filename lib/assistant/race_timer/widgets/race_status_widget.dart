import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/timing_controller.dart';
import '../../shared/widgets/race_day_controls.dart';
import 'race_controls_widget.dart';
import 'timer_display_widget.dart';

/// Whether the clock is running, how many finishes are logged, and the
/// clock itself, with Stop kept up here, away from Log Finish.
class RaceStatusWidget extends StatelessWidget {
  final TimingController controller;
  const RaceStatusWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final String status;
    final Color statusColor;
    final running = controller.startTime != null && !controller.raceStopped;

    if (controller.startTime == null) {
      status = 'Ready';
      statusColor = AppColors.mediumColor;
    } else if (controller.raceStopped) {
      status = 'Stopped';
      statusColor = Colors.green.shade700;
    } else {
      status = 'Running';
      statusColor = AppColors.primaryColor;
    }

    final count = controller.runnerCount ?? 0;
    return RaceDayStatusBar(
      status: status,
      color: statusColor,
      count: '$count ${count == 1 ? 'finish' : 'finishes'}',
      onStop: running ? () => confirmStopTimer(context, controller) : null,
      trailing: TimerDisplayWidget(controller: controller),
    );
  }
}
