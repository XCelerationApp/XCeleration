import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_border_radius.dart';

// Utility widget for section headers
class FlowSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final bool countHighlight;
  const FlowSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.countHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Text(title, style: AppTypography.titleSemibold),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: countHighlight
                    ? AppColors.selectedRoleColor
                    : AppColors.lightColor,
                borderRadius:
                    BorderRadius.circular(AppBorderRadius.full),
              ),
              child: Text(
                '$count',
                style: AppTypography.caption.copyWith(
                  color: countHighlight
                      ? AppColors.primaryColor
                      : AppColors.mediumColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
