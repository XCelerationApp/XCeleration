import 'package:flutter/material.dart';

import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/race_stage.dart';

/// The three steps of a race — set up, send to volunteers, collect results —
/// with the ones done and the one the coach is on filled in.
class RaceStepsBar extends StatelessWidget {
  const RaceStepsBar({super.key, required this.stage, required this.color});

  final RaceStage stage;

  /// The colour of the current stage, used for the steps reached so far.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, name) in RaceStage.steps.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _Step(
              name: name,
              reached: i + 1 <= stage.step,
              current: i + 1 == stage.step,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.name,
    required this.reached,
    required this.current,
    required this.color,
  });

  final String name;
  final bool reached;
  final bool current;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: AppAnimations.standard,
          curve: AppAnimations.spring,
          height: AppSpacing.xs,
          decoration: BoxDecoration(
            color: reached ? color : AppColors.lightColor,
            borderRadius: BorderRadius.circular(AppBorderRadius.full),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          name,
          style: (current ? AppTypography.captionBold : AppTypography.caption)
              .copyWith(color: current ? color : AppColors.mediumColor),
        ),
      ],
    );
  }
}
