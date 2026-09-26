import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../model/bib_conflict.dart';
import '../utils/ordinal.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/components/button_components.dart';
import '../../../core/components/race_components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Entry screen: summarises the conflict counts and lets the recorder start.
class ConflictSummaryCard extends StatelessWidget {
  const ConflictSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();
    final duplicateCount = controller.duplicateCount;
    final unknownCount = controller.unknownCount;
    final allResolved = controller.resolvedCount == controller.totalConflicts;

    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LeaveButton(),
            const SizedBox(height: AppSpacing.lg),
            _Header(duplicateCount: duplicateCount, unknownCount: unknownCount),
            const SizedBox(height: AppSpacing.xl),
            _ConflictTypeCards(
              duplicateCount: duplicateCount,
              unknownCount: unknownCount,
            ),
            const SizedBox(height: AppSpacing.xl),
            // Any conflict can be done first: a bib often needs asking about,
            // and the rest should not wait on it.
            _ConflictList(controller: controller),
            const SizedBox(height: AppSpacing.xxl),
            FullWidthButton(
              text: allResolved
                  ? 'Review Results'
                  : controller.resolvedCount == 0
                  ? 'Start Resolving'
                  : 'Continue Resolving',
              onPressed: controller.startResolving,
            ),
          ],
        ),
      ),
    );
  }
}

/// The way out of the flow. The summary is where it starts, so nothing here
/// goes back to — without this the whole screen is a dead end.
class _LeaveButton extends StatelessWidget {
  const _LeaveButton();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(
        Icons.arrow_back,
        size: AppSpacing.lg,
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.duplicateCount, required this.unknownCount});

  final int duplicateCount;
  final int unknownCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resolve Bib Conflicts', style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '$duplicateCount duplicate ${duplicateCount == 1 ? 'bib' : 'bibs'} · '
          '$unknownCount unknown ${unknownCount == 1 ? 'bib' : 'bibs'}',
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.mediumColor,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Every finish place must be assigned a real, identified runner '
          'before results can be submitted.',
          style: AppTypography.smallBodyRegular.copyWith(
            color: AppColors.mediumColor,
          ),
        ),
      ],
    );
  }
}

class _ConflictTypeCards extends StatelessWidget {
  const _ConflictTypeCards({
    required this.duplicateCount,
    required this.unknownCount,
  });

  final int duplicateCount;
  final int unknownCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (duplicateCount > 0)
          ConflictButton(
            title: 'Duplicate Bibs',
            subtitle:
                '$duplicateCount bib${duplicateCount == 1 ? '' : 's'} recorded at more than one finish place. '
                'You\'ll pick which is correct, then fix the other.',
            icon: Icons.copy_outlined,
            color: Colors.orange,
            onPressed: () {},
            isEnabled: false,
          ),
        if (unknownCount > 0)
          ConflictButton(
            title: 'Unknown Bibs',
            subtitle:
                '$unknownCount bib${unknownCount == 1 ? '' : 's'} not on your roster. '
                'Assign to an existing runner or create a new one.',
            icon: Icons.help_outline,
            color: AppColors.primaryColor,
            onPressed: () {},
            isEnabled: false,
          ),
      ],
    );
  }
}

/// Every conflict in finish order. Tapping one opens it; tapping one already
/// settled opens it again to change the answer.
class _ConflictList extends StatelessWidget {
  const _ConflictList({required this.controller});

  final ConflictResolutionController controller;

  @override
  Widget build(BuildContext context) {
    final conflicts = controller.conflicts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'TAP ONE TO START THERE',
          style: AppTypography.extraSmall.copyWith(
            letterSpacing: 0.5,
            color: AppColors.mediumColor,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < conflicts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ConflictRow(
              conflict: conflicts[i],
              resolved: controller.isResolved(i),
              onTap: () => controller.openConflict(i),
            ),
          ),
      ],
    );
  }
}

class _ConflictRow extends StatelessWidget {
  const _ConflictRow({
    required this.conflict,
    required this.resolved,
    required this.onTap,
  });

  final BibConflict conflict;
  final bool resolved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final places = ConflictResolutionController.placesOf(conflict);
    final (kind, detail) = switch (conflict) {
      DuplicateBibConflict() => (
        'Duplicate bib',
        'Recorded ${places.map(ordinal).join(', ')}',
      ),
      UnknownBibConflict(:final occurrence) => (
        'Unknown bib',
        [ordinal(occurrence.place), ?occurrence.time].join(' · '),
      ),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: resolved
              ? AppColors.statusFinished.withValues(alpha: AppOpacity.faint)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: resolved
                ? AppColors.statusFinished.withValues(alpha: AppOpacity.strong)
                : AppColors.lightColor,
          ),
        ),
        child: Row(
          children: [
            Text(
              '#${conflict.bibNumber}',
              style: AppTypography.bodySemibold.copyWith(
                color: resolved
                    ? AppColors.mediumColor
                    : AppColors.primaryColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind, style: AppTypography.smallBodySemibold),
                  Text(
                    resolved ? 'Resolved · tap to change' : detail,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.mediumColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              resolved ? Icons.check_circle : Icons.chevron_right,
              color: resolved
                  ? AppColors.statusFinished
                  : AppColors.primaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
