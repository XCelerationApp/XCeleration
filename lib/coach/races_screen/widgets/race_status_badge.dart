import 'package:flutter/material.dart';
import '../../../shared/models/database/race.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/typography.dart';

/// Colored pill badge displaying the current flow state of a race.
class RaceStatusBadge extends StatelessWidget {
  const RaceStatusBadge({super.key, required this.flowState});

  final String flowState;

  static String _textFor(String flowState) =>
      {
        Race.FLOW_SETUP: 'Setting up',
        Race.FLOW_SETUP_COMPLETED: 'Ready to Share',
        Race.FLOW_PRE_RACE: 'Sharing Race',
        Race.FLOW_PRE_RACE_COMPLETED: 'Ready for Results',
        Race.FLOW_POST_RACE: 'Processing Results',
        Race.FLOW_FINISHED: 'Race Complete',
      }[flowState] ??
      'Setting up';

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.light),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: color.withValues(alpha: AppOpacity.solid),
          width: 1,
        ),
      ),
      child: Text(
        _textFor(flowState),
        style: AppTypography.smallBodySemibold.copyWith(color: color),
      ),
    );
  }
}
