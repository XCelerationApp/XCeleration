import 'package:flutter/material.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// "Not on the roster? Create a new runner", at the end of a runner list:
/// Find Runner while resolving a bib, and Change Runner when editing results.
class CreateRunnerTile extends StatelessWidget {
  const CreateRunnerTile({super.key, required this.name, required this.onTap});

  /// What was typed, or '' for a runner not yet named.
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(color: AppColors.primaryColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add_outlined,
                color: AppColors.primaryColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                name.isEmpty
                    ? 'Not on the roster? Create a new runner'
                    : 'Create new runner "$name"',
                style: AppTypography.smallBodySemibold
                    .copyWith(color: AppColors.primaryColor),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primaryColor),
          ],
        ),
      ),
    );
  }
}
