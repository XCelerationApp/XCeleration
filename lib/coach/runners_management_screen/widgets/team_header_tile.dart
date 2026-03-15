import 'package:flutter/material.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/database/team.dart';
import '../controller/runners_management_controller.dart';

class TeamHeaderTile extends StatelessWidget {
  const TeamHeaderTile({
    super.key,
    required this.team,
    required this.runnerCount,
    required this.controller,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onAddRunner,
    this.isViewMode = false,
  });

  final Team team;
  final int runnerCount;
  final RunnersManagementController controller;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onAddRunner;
  final bool isViewMode;

  @override
  Widget build(BuildContext context) {
    final teamColor = team.color ?? AppColors.primaryColor;

    return GestureDetector(
      onTap: onToggleExpand,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Collapse chevron — lighter, smaller, matches prototype
            AnimatedRotation(
              turns: isExpanded ? 0.25 : 0,
              duration: AppAnimations.standard,
              curve: AppAnimations.spring,
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.mediumColor.withValues(alpha: AppOpacity.solid),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Team name + runner count
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      team.name ?? '',
                      style: AppTypography.smallBodySemibold.copyWith(
                        color: teamColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$runnerCount ${runnerCount == 1 ? 'runner' : 'runners'}',
                    style: AppTypography.smallCaption.copyWith(
                      color: AppColors.mediumColor.withValues(alpha: AppOpacity.solid),
                    ),
                  ),
                ],
              ),
            ),
            if (!isViewMode) ...[
              _AddRunnerChip(
                color: teamColor,
                onTap: onAddRunner,
              ),
              const SizedBox(width: AppSpacing.sm),
              _TeamMenuButton(
                team: team,
                controller: controller,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddRunnerChip extends StatelessWidget {
  const _AddRunnerChip({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppOpacity.light),
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
          border: Border.all(
            color: color.withValues(alpha: AppOpacity.strong),
          ),
        ),
        child: Text(
          '+ Runner',
          style: AppTypography.smallCaption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TeamMenuButton extends StatelessWidget {
  const _TeamMenuButton({
    required this.team,
    required this.controller,
  });

  final Team team;
  final RunnersManagementController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: AppColors.mediumColor.withValues(alpha: AppOpacity.solid),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          controller.showEditTeamSheet(context, team);
        } else if (value == 'delete') {
          controller.confirmAndDeleteTeam(context, team);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: AppColors.statusPreRace),
              const SizedBox(width: AppSpacing.sm),
              Text('Edit team', style: AppTypography.smallBodyRegular),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: AppColors.redColor),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Delete team',
                style: AppTypography.smallBodyRegular.copyWith(
                  color: AppColors.redColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
