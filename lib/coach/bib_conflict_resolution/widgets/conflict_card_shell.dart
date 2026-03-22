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
    // Only watch the two values that drive the shell's own layout.
    final hasPending = context.select<ConflictResolutionController, bool>(
      (c) => c.hasPending,
    );
    final stepKey = context.select<ConflictResolutionController, String>(
      (c) => c.stepKey,
    );

    return Stack(
      children: [
        Column(
          children: [
            const _NavBar(),
            const _ProgressSection(),
            Expanded(
              child: AnimatedOpacity(
                opacity: hasPending ? 0.35 : 1.0,
                duration: AppAnimations.fast,
                child: IgnorePointer(
                  ignoring: hasPending,
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
                            key: ValueKey(stepKey),
                            child: _buildCardBody(context),
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
        if (hasPending)
          Positioned(
            bottom: AppSpacing.xl,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: const _UndoToastWrapper(),
          ),
      ],
    );
  }

  Widget _buildCardBody(BuildContext context) {
    final controller = context.read<ConflictResolutionController>();
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

// ---------------------------------------------------------------------------
// Sub-widgets with scoped subscriptions
// ---------------------------------------------------------------------------

/// Nav bar — only needs `controller.goBack`, a stable method reference.
/// Uses context.read so it never rebuilds on controller notifications.
class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ConflictResolutionController>();
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

/// Progress bar — only subscribes to resolvedCount and totalConflicts.
class _ProgressSection extends StatelessWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context) {
    final (resolved, total) =
        context.select<ConflictResolutionController, (int, int)>(
      (c) => (c.resolvedCount, c.totalConflicts),
    );
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

/// Reads the controller once via `context.read`. This is safe because:
/// - `_UndoToastWrapper` is only mounted when `hasPending` is `true`
///   (see the `if (hasPending)` guard in `_ConflictCardShellState.build`).
/// - While `hasPending` is `true`, the card body is wrapped in
///   `IgnorePointer(ignoring: hasPending)`, so no user interaction can reach
///   the conflict card widgets that call `prepareAssign` / `prepareCreate`.
/// - Therefore, `pendingLabel` is guaranteed to be stable for the lifetime of
///   this widget — it cannot change without first clearing `hasPending`, which
///   unmounts this widget entirely.
class _UndoToastWrapper extends StatelessWidget {
  const _UndoToastWrapper();

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ConflictResolutionController>();
    return UndoToast(
      label: controller.pendingLabel,
      onUndo: controller.undoPending,
      onDone: controller.commitPending,
    );
  }
}
