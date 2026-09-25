import 'package:flutter/material.dart';
import '../../../shared/models/database/race.dart';
import '../controller/race_screen_controller.dart';
import '../../../core/components/button_components.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class UnsavedChangesBar extends StatelessWidget {
  final RaceScreenController controller;

  const UnsavedChangesBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // controller.flowState and controller.form are synchronous — no FutureBuilder needed.
    // The parent Consumer<RaceScreenController> already rebuilds this widget on every notifyListeners().
    final flowState = controller.flowState;
    final bool isSetupFlow = flowState == Race.FLOW_SETUP ||
        flowState == Race.FLOW_SETUP_COMPLETED;

    if (!isSetupFlow) return const SizedBox.shrink();

    // Adding teams is a row in the race details now, beside the other
    // things setup needs, rather than a button floating over them.
    final bool showSaveRow = controller.form.hasUnsavedChanges;

    if (!showSaveRow) return const SizedBox.shrink();

    return Container(
      color: AppColors.backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSaveRow)
            const Divider(height: 1, thickness: 1, color: AppColors.lightColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
