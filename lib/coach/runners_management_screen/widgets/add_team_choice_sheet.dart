import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Body widget for the "Add Team" choice sheet.
///
/// Presents two options — Create Team and Import Teams — as tappable rows.
/// The caller is responsible for dismissing the sheet and opening the next flow.
class AddTeamChoiceSheet extends StatelessWidget {
  const AddTeamChoiceSheet({
    super.key,
    required this.onCreateTeam,
    required this.onImportTeams,
  });

  final VoidCallback onCreateTeam;
  final VoidCallback onImportTeams;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChoiceTile(
          icon: Icons.group_add,
          label: 'Create Team',
          onTap: onCreateTeam,
        ),
        Divider(height: 1, thickness: 1, color: AppColors.lightColor),
        _ChoiceTile(
          icon: Icons.download,
          label: 'Import Teams',
          onTap: onImportTeams,
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
