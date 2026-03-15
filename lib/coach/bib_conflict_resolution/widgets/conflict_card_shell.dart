import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../mock/conflict_mock_data.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import './duplicate_conflict_card.dart';
import './undo_toast.dart';
import './unknown_bib_card.dart';

/// Wraps every conflict card with the v2 nav bar, gradient progress bar,
/// and UndoToast floating overlay.
class ConflictCardShell extends StatefulWidget {
  const ConflictCardShell({super.key});

  @override
  State<ConflictCardShell> createState() => _ConflictCardShellState();
}

class _ConflictCardShellState extends State<ConflictCardShell> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();

    return Stack(
      children: [
        Column(
          children: [
            _NavBar(controller: controller),
            _ProgressSection(controller: controller),
            Expanded(
              child: AnimatedOpacity(
                opacity: controller.hasPending ? 0.35 : 1.0,
                duration: AppAnimations.fast,
                child: IgnorePointer(
                  ignoring: controller.hasPending,
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
              ),
            ),
          ],
        ),
        if (controller.hasPending)
          Positioned(
            bottom: AppSpacing.xl,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: UndoToast(
              label: controller.pendingLabel,
              onUndo: controller.undoPending,
              onDone: controller.commitPending,
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
    return UnknownBibCard(
      conflict: controller.currentConflict as MockUnknownConflict,
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.controller});

  final ConflictResolutionController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: controller.goBack,
            icon: const Icon(
              Icons.arrow_back,
              size: 16,
              color: AppColors.primaryColor,
            ),
            label: Text(
              'Back',
              style: AppTypography.smallBodySemibold.copyWith(
                color: AppColors.primaryColor,
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Merge Conflicts',
                  style: AppTypography.smallBodySemibold,
                ),
                const SizedBox(height: 2),
                Text(
                  'Varsity Boys · Meet #4',
                  style: AppTypography.smallCaption.copyWith(
                    color: AppColors.mediumColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 52),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.controller});

  final ConflictResolutionController controller;

  @override
  Widget build(BuildContext context) {
    final resolved = controller.resolvedCount;
    final total = controller.totalConflicts;
    final fraction = total > 0 ? resolved / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONFLICTS',
                style: AppTypography.extraSmall.copyWith(
                  color: AppColors.primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$resolved / $total resolved',
                style: AppTypography.extraSmall.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.full),
            child: SizedBox(
              height: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.lightColor),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: AppAnimations.standard,
                      curve: AppAnimations.spring,
                      builder: (context, value, _) => FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryColor,
                                AppColors.primaryGradientEnd,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
