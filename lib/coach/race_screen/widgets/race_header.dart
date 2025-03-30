import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/race_screen_controller.dart';
import '../widgets/flow_notification.dart';

String _getStatusText(String flowState) {
  switch (flowState) {
    case 'setup':
      return 'Setup';
    case 'pre-race':
      return 'Pre-Race';
    case 'post-race':
      return 'Post-Race';
    case 'finished':
      return 'Finished';
    default:
      return 'Unknown';
  }
}

Color _getStatusColor(String flowState) {
  switch (flowState) {
    case 'setup':
      return Colors.amber;
    case 'pre-race':
      return Colors.blue;
    case 'post-race':
      return Colors.purple;
    case 'finished':
      return Colors.green;
    default:
      return Colors.grey;
  }
}

IconData _getStatusIcon(String flowState) {
  switch (flowState) {
    case 'setup':
      return Icons.settings;
    case 'pre-race':
      return Icons.timer;
    case 'post-race':
      return Icons.flag;
    case 'finished':
      return Icons.check_circle;
    default:
      return Icons.help;
  }
}

class RaceHeader extends StatelessWidget {
  final RaceScreenController controller;
  const RaceHeader({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
            child: Text(
          controller.race!.race_name,
          style: TextStyle(
            color: AppColors.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        )),

        // Action button area - updated color
        if (controller.race!.flowState != 'finished')
          FlowNotification(
            flowState: _getStatusText(controller.race!.flowState),
            color: _getStatusColor(controller.race!.flowState),
            icon: _getStatusIcon(controller.race!.flowState),
            continueAction: () => controller.continueRaceFlow(context),
          ),
      ],
    );
  }
}
