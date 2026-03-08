import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_border_radius.dart';

// Utility widget for section headers
class FlowSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final VoidCallback? onToggle;
  final bool isExpanded;
  const FlowSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.onToggle,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final header = Row(
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
              color: (count ?? 0) > 0
                  ? AppColors.selectedRoleColor
                  : AppColors.lightColor,
              borderRadius:
                  BorderRadius.circular(AppBorderRadius.full),
            ),
            child: Text(
              '$count',
              style: AppTypography.caption.copyWith(
                color: (count ?? 0) > 0
                    ? AppColors.primaryColor
                    : AppColors.mediumColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (onToggle != null) ...[
          const Spacer(),
          AnimatedRotation(
            turns: isExpanded ? 0 : -0.5,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: AppColors.mediumColor,
            ),
          ),
        ],
      ],
    );

    if (onToggle != null) {
      return GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: header,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: header,
    );
  }
}
