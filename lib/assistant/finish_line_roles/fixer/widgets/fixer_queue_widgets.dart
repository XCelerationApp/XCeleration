import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Animated status pill showing how many entries still need fixing.
class FixerStatusPill extends StatelessWidget {
  const FixerStatusPill({super.key, required this.unresolvedCount});

  final int unresolvedCount;

  @override
  Widget build(BuildContext context) {
    final hasIssues = unresolvedCount > 0;
    final pillColor =
        hasIssues ? AppColors.primaryColor : AppColors.statusFinished;
    return AnimatedContainer(
      duration: AppAnimations.standard,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: pillColor.withValues(alpha: AppOpacity.strong)),
      ),
      child: Text(
        hasIssues
            ? '$unresolvedCount entr${unresolvedCount == 1 ? "y" : "ies"} need attention'
            : 'All entries resolved ✓',
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w700,
          color: pillColor,
        ),
      ),
    );
  }
}

/// Small all-caps section divider label used in the fixer queue list.
class FixerSectionLabel extends StatelessWidget {
  const FixerSectionLabel({super.key, required this.label, this.topPadding = 0});

  final String label;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Text(
        label,
        style: AppTypography.labelTiny.copyWith(
          color: AppColors.mediumColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Empty state shown inside the queue when the race is live but has no flags.
class FixerLiveEmptyState extends StatelessWidget {
  const FixerLiveEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 36)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No issues yet',
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Flagged entries from Verifier appear here',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.lightColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state shown when the Fixer has joined but no entries exist yet.
class FixerEmptyState extends StatelessWidget {
  const FixerEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔧', style: TextStyle(fontSize: 40)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No conflicts to resolve',
            style: AppTypography.smallBodyRegular.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Flagged entries from the Verifier will appear here.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.lightColor,
            ),
          ),
        ],
      ),
    );
  }
}
