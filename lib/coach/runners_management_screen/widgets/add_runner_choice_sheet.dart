import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Body widget for the "Add Runner" choice sheet.
///
/// Presents two options — Add Manually and Import from Spreadsheet —
/// as tappable rows. The caller is responsible for dismissing the sheet
/// and opening the next flow.
class AddRunnerChoiceSheet extends StatelessWidget {
  const AddRunnerChoiceSheet({
    super.key,
    required this.onAddManually,
    required this.onImportFromSpreadsheet,
  });

  final VoidCallback onAddManually;
  final VoidCallback onImportFromSpreadsheet;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose how you want to add runners to this team.',
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.mediumColor,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ChoiceTile(
          icon: Icons.edit_outlined,
          label: 'Add Manually',
          onTap: onAddManually,
        ),
        Divider(height: 1, thickness: 1, color: AppColors.lightColor),
        _ChoiceTile(
          icon: Icons.table_chart_outlined,
          label: 'Import from Spreadsheet',
          onTap: onImportFromSpreadsheet,
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryColor, size: 22),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.darkColor,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: AppColors.mediumColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
