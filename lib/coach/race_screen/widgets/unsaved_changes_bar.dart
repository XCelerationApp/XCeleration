import 'package:flutter/material.dart';
import '../../../shared/models/database/race.dart';
import '../controller/race_screen_controller.dart';
import '../../../core/components/button_components.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

class UnsavedChangesBar extends StatelessWidget {
  final RaceController controller;

  const UnsavedChangesBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // controller.flowState and controller.form are synchronous — no FutureBuilder needed.
    // The parent Consumer<RaceController> already rebuilds this widget on every notifyListeners().
    final flowState = controller.flowState;
    final bool isSetupFlow = flowState == Race.FLOW_SETUP ||
        flowState == Race.FLOW_SETUP_COMPLETED;

    if (!isSetupFlow) return const SizedBox.shrink();

    final bool showLoadTeams = controller.raceRunners.isEmpty;
    final bool showSaveRow = controller.form.hasUnsavedChanges;

    if (!showLoadTeams && !showSaveRow) return const SizedBox.shrink();

    final bool isViewMode = !controller.canEdit ||
        controller.race.flowState == Race.FLOW_FINISHED ||
        controller.race.flowState == Race.FLOW_POST_RACE;

    return Container(
      color: AppColors.backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, thickness: 1, color: AppColors.lightColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLoadTeams) ...[
                  _LoadTeamsButton(
                    onPressed: () =>
                        controller.loadRunnersManagementScreenWithConfirmation(
                          context,
                          isViewMode: isViewMode,
                        ),
                  ),
                  if (showSaveRow) const SizedBox(height: AppSpacing.sm),
                ],
                if (showSaveRow)
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          text: 'Revert Changes',
                          onPressed: controller.form.revertAll,
                          size: ButtonSize.fullWidth,
                          borderRadius: AppBorderRadius.md,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                            horizontal: AppSpacing.sm,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PrimaryButton(
                          text: 'Save Changes',
                          onPressed: () => controller.saveAllChanges(context),
                          size: ButtonSize.fullWidth,
                          borderRadius: AppBorderRadius.md,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                            horizontal: AppSpacing.sm,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadTeamsButton extends StatelessWidget {
  const _LoadTeamsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor:
              AppColors.primaryColor.withValues(alpha: AppOpacity.light),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.group_rounded,
              color: AppColors.primaryColor,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Load Teams and Runners',
              style: AppTypography.bodySemibold.copyWith(
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
