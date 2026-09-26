import 'package:flutter/material.dart';
import '../theme/app_animations.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';
import '../utils/grade_utils.dart';

/// Fr, So, Jr and Sr as four buttons, for picking a runner's grade. The same
/// in adding and editing a runner.
class GradeSelector extends StatelessWidget {
  const GradeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int? selected;
  final ValueChanged<int> onSelected;

  static const _grades = [9, 10, 11, 12];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _grades.map((grade) {
        final isSelected = selected == grade;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: grade != 12 ? AppSpacing.sm : 0,
            ),
            child: _GradePill(
              label: gradeLabel(grade),
              isSelected: isSelected,
              onTap: () => onSelected(grade),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GradePill extends StatelessWidget {
  const _GradePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : AppColors.borderColor,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.smallBodySemibold.copyWith(
              color: isSelected ? AppColors.primaryColor : AppColors.mediumColor,
            ),
          ),
        ),
      ),
    );
  }
}
