import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_status_badge.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Top header row for the race recording screen.
///
/// Shows the race name on the left and a live/not-started badge + entry
/// count on the right.
class RaceHeader extends StatelessWidget {
  const RaceHeader({
    super.key,
    required this.raceName,
    required this.entryCount,
    required this.raceStarted,
  });

  final String raceName;
  final int entryCount;
  final bool raceStarted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  raceName,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.smallBodySemibold.copyWith(
                    color: AppColors.darkColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Row(
            children: [
              raceStarted ? const LiveBadge() : const NotStartedBadge(),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$entryCount',
                style: AppTypography.smallBodySemibold.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
