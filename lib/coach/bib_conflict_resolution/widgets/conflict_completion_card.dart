import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../../../core/components/button_components.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

// TODO(ui): move to AppColors when this value is used in more than one place
const _createIconBg = Color(0xFFE3F2FD);

/// Final screen after all conflicts are resolved — shows a per-resolution log and a submit CTA.
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
            _ResolutionLog(log: controller.resolutionLog),
            const SizedBox(height: AppSpacing.xxl),
            FullWidthButton(
              text: 'Confirm & Submit Results',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              text: 'Go Back & Edit',
              size: ButtonSize.fullWidth,
              onPressed: () => controller.goBack(),
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

class _ResolutionLog extends StatelessWidget {
  const _ResolutionLog({required this.log});

  final List<ResolutionEntry> log;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.lightColor.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.lightColor),
      ),
      child: Column(
        children: [
          for (var i = 0; i < log.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _AnimatedRow(index: i, entry: log[i]),
          ],
        ],
      ),
    );
  }
}

class _AnimatedRow extends StatefulWidget {
  const _AnimatedRow({required this.index, required this.entry});

  final int index;
  final ResolutionEntry entry;

  @override
  State<_AnimatedRow> createState() => _AnimatedRowState();
}

class _AnimatedRowState extends State<_AnimatedRow> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: AppAnimations.reveal,
      curve: AppAnimations.enter,
      child: _ResolutionRow(entry: widget.entry),
    );
  }
}

class _ResolutionRow extends StatelessWidget {
  const _ResolutionRow({required this.entry});

  final ResolutionEntry entry;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        entry.wasCreate ? _createIconBg : AppColors.selectedRoleColor;
    final icon = entry.wasCreate ? Icons.person_add_outlined : Icons.person_outline;
    final actionLabel = entry.wasCreate ? 'Created' : 'Assigned';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
          ),
          child: Icon(
            icon,
            size: 18,
            color: entry.wasCreate
                ? const Color(0xFF1565C0) // blue-800 to contrast on E3F2FD
                : AppColors.primaryColor,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.conflictLabel,
                style: AppTypography.captionBold.copyWith(
                  color: AppColors.darkColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$actionLabel: ${entry.runnerName} · #${entry.bib} · ${entry.team}',
                style: AppTypography.smallCaption.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
