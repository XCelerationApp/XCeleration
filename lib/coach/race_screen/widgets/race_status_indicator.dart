import 'package:flutter/material.dart';
// import '../../../core/theme/typography.dart';

class RaceStatusIndicator extends StatelessWidget {
  final String flowState;

  const RaceStatusIndicator({
    super.key,
    required this.flowState,
  });

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

  // IconData _getStatusIcon(String flowState) {
  //   switch (flowState) {
  //     case 'setup':
  //       return Icons.settings;
  //     case 'pre-race':
  //       return Icons.timer;
  //     case 'post-race':
  //       return Icons.flag;
  //     case 'finished':
  //       return Icons.check_circle;
  //     default:
  //       return Icons.help;
  //   }
  // }

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

  @override
  Widget build(BuildContext context) {
    final flowStateColor = _getStatusColor(flowState);
    // final flowStateIcon = _getStatusIcon(flowState);
    final flowStateText = _getStatusText(flowState);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: flowStateColor.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: flowStateColor.withAlpha((0.5 * 255).round()),
          width: 1,
        ),
      ),
      child: Text(
        flowStateText,
        style: TextStyle(
          color: flowStateColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
