import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Status badge shown in the race mode header when the race is live.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.liveBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        border: Border.all(color: AppColors.liveBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.redColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm - 2),
          Text(
            'LIVE',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.redColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status badge shown in the race mode header before the race has started.
class NotStartedBadge extends StatelessWidget {
  const NotStartedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Text(
        'Not Started',
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.mediumColor,
        ),
      ),
    );
  }
}
