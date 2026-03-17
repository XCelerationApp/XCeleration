import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/controller/verifier_controller.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Horizontal bar showing confirmed / wrong / skipped / pending counts.
class VerifierStatsBar extends StatelessWidget {
  const VerifierStatsBar({super.key, required this.controller});

  final VerifierController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          _StatChip(
            label: 'CORRECT',
            count: controller.confirmed,
            color: AppColors.statusFinished,
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatChip(
            label: 'WRONG',
            count: controller.wrong,
            color: AppColors.redColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatChip(
            label: 'SKIPPED',
            count: controller.skipped,
            color: AppColors.mediumColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatChip(
            label: 'PENDING',
            count: controller.pending,
            color: AppColors.primaryColor,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppOpacity.light),
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: AppTypography.titleSemibold.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: AppTypography.labelTiny.copyWith(
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state shown when the Verifier is in-race but no entries have arrived.
class VerifierEmptyState extends StatelessWidget {
  const VerifierEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👀', style: TextStyle(fontSize: 36)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Waiting for finishers',
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Entries from Bib Recorder appear here',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.lightColor,
            ),
          ),
        ],
      ),
    );
  }
}
