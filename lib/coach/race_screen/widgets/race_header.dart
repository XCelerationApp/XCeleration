import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/race_screen_controller.dart';
import '../widgets/flow_notification.dart';

String _getStatusText(String flowState) {
  switch (flowState) {
    case 'setup':
      return 'Runner Setup';
    case 'setup-completed':
      return 'Ready to Share';
    case 'pre-race':
      return 'Sharing Runners';
    case 'pre-race-completed':
      return 'Ready for Results';
    case 'post-race':
      return 'Processing Results';
    case 'post-race-completed':
      return 'Ready to Finalize';
    case 'finished':
      return 'Race Complete';
    default:
      print('Flow state: $flowState');
      return 'Unknown';
  }
}

Color _getStatusColor(String flowState) {
  switch (flowState) {
    case 'setup':
      return Colors.amber;
    case 'setup-completed':
      return Colors.amber;
    case 'pre-race':
      return Colors.blue;
    case 'pre-race-completed':
      return Colors.blue;
    case 'post-race':
      return Colors.purple;
    case 'post-race-completed':
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
    case 'setup-completed':
      return Icons.settings;
    case 'pre-race':
      return Icons.timer;
    case 'pre-race-completed':
      return Icons.timer;
    case 'post-race':
      return Icons.flag;
    case 'post-race-completed':
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
