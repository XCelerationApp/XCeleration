import 'package:flutter/material.dart';
import '../../shared/models/database/race.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';

/// Colored pill badge displaying the current flow state of a race.
///
/// Replaces inline status color/text mapping in [RaceStatusBadge] and
/// [RaceStatusIndicator]. All color values come from [AppColors] status tokens.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.flowState});

  final String flowState;

  static Color _colorFor(String flowState) {
    switch (flowState) {
      case Race.FLOW_SETUP:
      case Race.FLOW_SETUP_COMPLETED:
        return AppColors.statusSetup;
      case Race.FLOW_PRE_RACE:
      case Race.FLOW_PRE_RACE_COMPLETED:
        return AppColors.statusPreRace;
      case Race.FLOW_POST_RACE:
        return AppColors.statusPostRace;
      case Race.FLOW_FINISHED:
        return AppColors.statusFinished;
      default:
        return AppColors.mediumColor;
    }
  }

  static IconData _iconFor(String flowState) {
    switch (flowState) {
      case Race.FLOW_SETUP:
      case Race.FLOW_SETUP_COMPLETED:
        return Icons.settings_outlined;
      case Race.FLOW_PRE_RACE:
      case Race.FLOW_PRE_RACE_COMPLETED:
        return Icons.share_outlined;
      case Race.FLOW_POST_RACE:
        return Icons.bar_chart_outlined;
      case Race.FLOW_FINISHED:
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  static String _labelFor(String flowState) {
    switch (flowState) {
      case Race.FLOW_SETUP:
        return 'Setting Up';
      case Race.FLOW_SETUP_COMPLETED:
        return 'Ready to Share';
      case Race.FLOW_PRE_RACE:
        return 'Sharing Race';
      case Race.FLOW_PRE_RACE_COMPLETED:
        return 'Ready for Results';
      case Race.FLOW_POST_RACE:
        return 'Processing Results';
      case Race.FLOW_FINISHED:
        return 'Race Complete';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(flowState);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.light),
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        border: Border.all(
          color: color.withValues(alpha: AppOpacity.solid),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(flowState), size: AppSpacing.md, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _labelFor(flowState),
            style: AppTypography.smallBodySemibold.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
