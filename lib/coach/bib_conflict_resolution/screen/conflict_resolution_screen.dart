import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import '../controller/conflict_resolution_controller.dart';
import '../widgets/conflict_card_shell.dart';
import '../widgets/conflict_summary_card.dart';
import '../widgets/conflict_completion_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_animations.dart';

/// Resolving the bib conflicts in a race's finish order.
///
/// Pops with who finished at each place the coach settled, including when
/// they leave part way, or null if they settled nothing.
class ConflictResolutionScreen extends StatelessWidget {
  const ConflictResolutionScreen({super.key, required this.create});

  /// Builds the controller. The screen owns it and disposes of it.
  final ConflictResolutionController Function() create;

  /// Opens the screen and waits for the coach to submit or leave.
  static Future<Map<int, RaceRunner>?> open(
    BuildContext context, {
    required ConflictResolutionController Function() create,
  }) =>
      Navigator.of(context, rootNavigator: true).push<Map<int, RaceRunner>>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ConflictResolutionScreen(create: create),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => create(),
      child: const _ScreenContent(),
    );
  }
}

class _ScreenContent extends StatelessWidget {
  const _ScreenContent();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();

    // Back, the Android back button and the summary's way out all come here.
    // From a conflict it steps back a card; from the summary it leaves with
    // the conflicts already resolved, so none of that work is lost.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (controller.isOnConflict) {
          controller.goBack();
          return;
        }
        final finished = controller.finishedByPlace;
        Navigator.of(context).pop(finished.isEmpty ? null : finished);
      },
      child: _scaffold(controller),
    );
  }

  Widget _scaffold(ConflictResolutionController controller) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: AppAnimations.standard,
          switchInCurve: AppAnimations.enter,
          switchOutCurve: AppAnimations.exit,
          child: KeyedSubtree(
            key: ValueKey(controller.outerStateKey),
            child: _buildOuterContent(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildOuterContent(ConflictResolutionController controller) {
    if (controller.isOnSummary) return const ConflictSummaryCard();
    if (controller.isOnCompletion) return const ConflictCompletionCard();
    return const ConflictCardShell();
  }
}
