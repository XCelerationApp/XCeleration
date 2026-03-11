import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../../../core/components/button_components.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Final screen after all conflicts are resolved — shows a summary and a submit CTA.
class ConflictCompletionCard extends StatelessWidget {
  const ConflictCompletionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();

    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.xxl),
            _SuccessIcon(),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'All conflicts resolved',
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Review the summary below, then confirm to submit results.',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.mediumColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            _SummaryCard(controller: controller),
            const SizedBox(height: AppSpacing.xxl),
            FullWidthButton(
              text: 'Confirm & Submit Results',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              text: 'Review resolutions',
              size: ButtonSize.fullWidth,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: AppOpacity.light),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_circle_outline,
        color: Colors.green,
        size: 48,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final ConflictResolutionController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.lightColor.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.lightColor),
      ),
      child: Column(
        children: [
          _SummaryRow(
            icon: Icons.copy_outlined,
            color: Colors.orange,
            label: 'Duplicates resolved',
            value: '${controller.duplicatesResolved}',
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            icon: Icons.person_outline,
            color: AppColors.primaryColor,
            label: 'Runners assigned',
            value: '${controller.runnersAssigned}',
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            icon: Icons.person_add_outlined,
            color: Colors.blue,
            label: 'New runners created',
            value: '${controller.newRunnersCreated}',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(label, style: AppTypography.bodyRegular),
        ),
        Text(
          value,
          style: AppTypography.bodySemibold.copyWith(color: color),
        ),
      ],
    );
  }
}
