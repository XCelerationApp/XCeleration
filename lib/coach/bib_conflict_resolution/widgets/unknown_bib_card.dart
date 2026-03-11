import 'package:flutter/material.dart';
import '../mock/conflict_mock_data.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import './runner_assignment_list.dart';

/// Card for a standalone unknown bib — bib was entered but not found in the database.
class UnknownBibCard extends StatelessWidget {
  const UnknownBibCard({super.key, required this.conflict});

  final MockUnknownConflict conflict;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unknown Bib', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Bib #${conflict.enteredBib} isn\'t in the database.',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.lg),
        _EntryInfoCard(conflict: conflict),
        const SizedBox(height: AppSpacing.xl),
        RunnerAssignmentList(targetBib: conflict.enteredBib),
      ],
    );
  }
}

class _EntryInfoCard extends StatelessWidget {
  const _EntryInfoCard({required this.conflict});

  final MockUnknownConflict conflict;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: AppOpacity.faint),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: AppOpacity.light),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${conflict.enteredBib}',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.primaryColor,
                ),
              ),
              Text(
                'Bib entered',
                style: AppTypography.caption.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xxl),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${conflict.position}',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.darkColor,
                ),
              ),
              Text(
                'Finish place',
                style: AppTypography.caption.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xxl),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conflict.formattedTime,
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.darkColor,
                ),
              ),
              Text(
                'Finish time',
                style: AppTypography.caption.copyWith(
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
