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
    final total = RaceStage.steps.length;
    final current = stage.step.clamp(1, total);
    // Amber is too pale to read as text on white.
    final textColor = color.computeLuminance() > 0.5
        ? Color.lerp(color, Colors.black, 0.45)!
        : color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _Step(reached: i + 1 <= stage.step, color: color),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // One line naming where the race is, rather than a label under each
        // segment that wraps on a narrow phone or at a large text size.
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: 'Step $current of $total  ',
              style: AppTypography.captionBold
                  .copyWith(color: AppColors.mediumColor),
            ),
            TextSpan(
              text: stage.label,
              style: AppTypography.bodySemibold.copyWith(color: textColor),
            ),
          ]),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.reached, required this.color});

  final bool reached;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppAnimations.standard,
      curve: AppAnimations.spring,
      height: AppSpacing.xs + 2,
      decoration: BoxDecoration(
        color: reached ? color : AppColors.lightColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
    );
  }
}
