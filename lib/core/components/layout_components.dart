import 'package:flutter/material.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';

/// Layout and structural UI components
/// This file contains widgets for organizing and structuring content

/// Reusable search bar widget
class SearchBarWidget extends StatelessWidget {
  final String? hintText;
  final String? value;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool isCompact;

  const SearchBarWidget({
    super.key,
    this.hintText,
    this.value,
    this.onChanged,
    this.onClear,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(isCompact ? AppSpacing.sm : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: AppColors.lightColor),
      ),
      child: TextField(
        controller: value != null ? TextEditingController(text: value) : null,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText ?? 'Search...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value != null && value!.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: isCompact ? AppSpacing.md : AppSpacing.lg,
          ),
        ),
      ),
    );
  }
}

/// Reusable section header widget
class SectionHeaderWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool isCompact;

  const SectionHeaderWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? AppSpacing.md : AppSpacing.lg,
        vertical: isCompact ? AppSpacing.sm : AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: isCompact
                      ? AppTypography.titleMedium
                      : AppTypography.titleLarge,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodyRegular
                        .copyWith(color: AppColors.mediumColor),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
