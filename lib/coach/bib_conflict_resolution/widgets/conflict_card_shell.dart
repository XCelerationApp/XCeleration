import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../mock/conflict_mock_data.dart';
import '../../../core/components/icon_button.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import './duplicate_conflict_card.dart';
import './unknown_bib_card.dart';

/// Wraps every conflict card with the shared progress header.
/// Manages the inner AnimatedSwitcher that transitions between card bodies.
class ConflictCardShell extends StatelessWidget {
  const ConflictCardShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();

    return Column(
      children: [
        _ProgressHeader(controller: controller),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: AppAnimations.standard,
                  switchInCurve: AppAnimations.enter,
                  switchOutCurve: AppAnimations.exit,
                  child: KeyedSubtree(
                    key: ValueKey(controller.stepKey),
                    child: _buildCardBody(controller),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardBody(ConflictResolutionController controller) {
    if (controller.isOnDuplicateStep1) {
      return DuplicateStep1Card(
        conflict: controller.currentConflict as MockDuplicateConflict,
      );
    }
    if (controller.isOnDuplicateStep2) {
      return DuplicateStep2Card(
        conflict: controller.currentConflict as MockDuplicateConflict,
        correctOccurrence: controller.chosenDuplicateOccurrence!,
      );
    }
    return UnknownBibCard(
      conflict: controller.currentConflict as MockUnknownConflict,
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.controller});

  final ConflictResolutionController controller;

  @override
  Widget build(BuildContext context) {
    final resolved = controller.resolvedCount;
    final total = controller.totalConflicts;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (controller.canGoBack)
            CircleIconButton(
              icon: Icons.arrow_back,
              onPressed: controller.goBack,
              size: 40,
              iconSize: 20,
            )
          else
            const SizedBox(width: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$resolved of $total resolved',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.mediumColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                  child: LinearProgressIndicator(
                    value: total > 0 ? resolved / total : 0,
                    backgroundColor: AppColors.lightColor,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
