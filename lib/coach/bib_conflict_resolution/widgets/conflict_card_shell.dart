import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../model/bib_conflict.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import './duplicate_conflict_card.dart';
import './undo_toast.dart';
import '../../../core/components/conflict_page_header.dart';
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
                        const _ErrorBanner(),
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
        // At the top, where the eye already is after tapping the answer.
        if (hasPending)
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: const _UndoToastWrapper(),
          ),
      ],
    );
  }

  /// The card for the conflict being worked on. Chosen by the conflict's own
  /// type rather than the flow step: this shell is still on screen while it
  /// animates out towards the summary, and it rebuilds on the way.
  Widget _buildCardBody(BuildContext context) {
    final conflict =
        context.read<ConflictResolutionController>().currentConflict;
    return switch (conflict) {
      DuplicateBibConflict() => DuplicateStep1Card(conflict: conflict),
      UnknownBibConflict() => UnknownBibCard(conflict: conflict),
    };
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets with scoped subscriptions
// ---------------------------------------------------------------------------

/// Back, the title and the race — only needs `controller.goBack`, a stable
/// method reference, so it never rebuilds on controller notifications.
class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ConflictResolutionController>();
    return ConflictNavBar(
      title: 'Bib Conflicts',
      raceName: controller.raceName,
      onBack: controller.goBack,
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
    return ConflictProgress(resolved: resolved, total: total);
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

/// Says why the last action failed — saving a new runner, typically — and
/// lets the coach dismiss it and try again.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner();

  @override
  Widget build(BuildContext context) {
    final message = context.select<ConflictResolutionController, String?>(
      (c) => c.error?.userMessage,
    );
    return AnimatedSize(
      duration: AppAnimations.fast,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.only(left: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.redColor.withValues(alpha: AppOpacity.faint),
                  border: Border.all(
                    color: AppColors.redColor
                        .withValues(alpha: AppOpacity.strong),
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        message,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.redColor),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: AppColors.redColor,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Dismiss',
                      onPressed: context
                          .read<ConflictResolutionController>()
                          .dismissError,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
