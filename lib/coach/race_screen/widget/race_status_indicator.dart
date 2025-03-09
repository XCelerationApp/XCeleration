import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';

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
      case 'pre_race':
        return Colors.blue;
      case 'post_race':
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
      case 'pre_race':
        return Icons.timer;
      case 'post_race':
        return Icons.flag;
      case 'finished':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String flowState) {
    switch (flowState) {
      case 'setup':
        return 'Setup';
      case 'pre_race':
        return 'Pre-Race';
      case 'post_race':
        return 'Post-Race';
      case 'finished':
        return 'Finished';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(flowState);
    final statusIcon = _getStatusIcon(flowState);
    final statusText = _getStatusText(flowState);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: AppTypography.bodySmall.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
