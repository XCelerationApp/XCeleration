import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Body widget for the "Add Team" choice sheet.
///
/// Presents three options — Import from Previous Race, Import from Spreadsheet,
/// and Create New Team — as tappable rows with a description subtitle.
/// The caller is responsible for dismissing the sheet and opening the next flow.
class AddTeamChoiceSheet extends StatelessWidget {
  const AddTeamChoiceSheet({
    super.key,
    required this.onImportFromPreviousRace,
    required this.onImportFromSpreadsheet,
    required this.onCreateTeam,
  });

  final VoidCallback onImportFromPreviousRace;
  final VoidCallback onImportFromSpreadsheet;
  final VoidCallback onCreateTeam;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose how you want to add teams to this race.',
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.mediumColor,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ChoiceTile(
          icon: Icons.history,
          label: 'Import from Previous Race',
          onTap: onImportFromPreviousRace,
        ),
        Divider(height: 1, thickness: 1, color: AppColors.lightColor),
        _ChoiceTile(
          icon: Icons.table_chart_outlined,
          label: 'Import from Spreadsheet',
          onTap: onImportFromSpreadsheet,
        ),
        Divider(height: 1, thickness: 1, color: AppColors.lightColor),
        _ChoiceTile(
          icon: Icons.group_add,
          label: 'Create New Team',
          onTap: onCreateTeam,
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
