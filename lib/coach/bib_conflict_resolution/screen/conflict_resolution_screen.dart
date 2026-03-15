import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../widgets/conflict_card_shell.dart';
import '../widgets/conflict_summary_card.dart';
import '../widgets/conflict_completion_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_animations.dart';

class ConflictResolutionScreen extends StatelessWidget {
  const ConflictResolutionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConflictResolutionController(),
      child: const _ScreenContent(),
    );
  }
}

class _ScreenContent extends StatelessWidget {
  const _ScreenContent();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();

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
