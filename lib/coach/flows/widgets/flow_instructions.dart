import 'package:flutter/material.dart';

import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Numbered steps for a flow page that is otherwise only words, so a coach
/// can follow them one at a time.
class FlowInstructions extends StatelessWidget {
  const FlowInstructions({super.key, required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor
                          .withValues(alpha: AppOpacity.light),
                      borderRadius:
                          BorderRadius.circular(AppBorderRadius.full),
                    ),
                    child: Text('${i + 1}',
                        style: AppTypography.smallBodySemibold
                            .copyWith(color: AppColors.primaryColor)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(step,
                          style: AppTypography.bodyRegular
                              .copyWith(color: AppColors.darkColor)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
