import 'package:flutter/material.dart';

import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/ordinal.dart';
import '../../bib_conflict_resolution/model/bib_conflict.dart';
import 'nearby_finishers.dart';

/// Asks which of the finishes a repeated bib was recorded at belongs to the
/// runner who holds it.
///
/// Every finish is offered, including the earliest. The screen used to treat
/// the first recording as correct and ask only about the later ones, which
/// decided the question rather than putting it.
class DuplicateBibCard extends StatelessWidget {
  const DuplicateBibCard({
    super.key,
    required this.conflict,
    required this.onFinishChosen,
  });

  final DuplicateBibConflict conflict;

  /// The place the coach says is this runner's. Every other place the bib was
  /// recorded at belongs to somebody else.
  final ValueChanged<int> onFinishChosen;

  @override
  Widget build(BuildContext context) {
    final count = conflict.occurrences.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RunnerCard(conflict: conflict),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Bib #${conflict.bibNumber} was recorded $count times. '
          'Which finish belongs to this runner?',
          style:
              AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.md),
        // Two fit side by side; more than that need the room of a column.
        if (count == 2)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final occurrence in conflict.occurrences) ...[
                Expanded(
                  child: _FinishTile(
                    occurrence: occurrence,
                    onChoose: () => onFinishChosen(occurrence.place),
                  ),
                ),
                if (occurrence != conflict.occurrences.last)
                  const SizedBox(width: AppSpacing.md),
              ],
            ],
          )
        else
          for (final occurrence in conflict.occurrences)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _FinishTile(
                occurrence: occurrence,
                wide: true,
                onChoose: () => onFinishChosen(occurrence.place),
              ),
            ),
        const SizedBox(height: AppSpacing.sm),
        _Tip(
          message: count == 2
              ? 'Tap the finish that belongs to this runner. The other one '
                  'needs a runner of its own.'
              : 'Tap the finish that belongs to this runner. The other '
                  '${count - 1} each need a runner of their own.',
        ),
      ],
    );
  }
}

/// The runner the bib belongs to.
class _RunnerCard extends StatelessWidget {
  const _RunnerCard({required this.conflict});

  final DuplicateBibConflict conflict;

  @override
  Widget build(BuildContext context) {
    final runner = conflict.runner.runner;
    final grade = runner.grade;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.selectedRoleColor,
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: AppOpacity.strong),
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DUPLICATE BIB',
            style: AppTypography.extraSmall.copyWith(
              letterSpacing: 0.5,
              color: AppColors.primaryColor,
            ),
          ),
          Text(
            '#${conflict.bibNumber}',
            style: AppTypography.titleSemibold
                .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person,
                    color: AppColors.primaryColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(runner.name ?? 'Unnamed runner',
                        style: AppTypography.smallBodySemibold),
                    Text(
                      [
                        conflict.runner.team.name,
                        if (grade != null) 'Grade $grade',
                      ].whereType<String>().join(' · '),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.mediumColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One finish to choose between.
class _FinishTile extends StatefulWidget {
  const _FinishTile({
    required this.occurrence,
    required this.onChoose,
    this.wide = false,
  });

  final ConflictOccurrence occurrence;
  final VoidCallback onChoose;
  final bool wide;

  @override
  State<_FinishTile> createState() => _FinishTileState();
}

class _FinishTileState extends State<_FinishTile> {
  bool _chosen = false;

  void _choose() {
    if (_chosen) return;
    // Let the tick land before the screen moves on.
    setState(() => _chosen = true);
    Future.delayed(AppAnimations.standard, () {
      if (mounted) widget.onChoose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final occurrence = widget.occurrence;
    return GestureDetector(
      onTap: _choose,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: _chosen
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : Colors.white,
          border: Border.all(
            color: _chosen ? AppColors.primaryColor : AppColors.borderColor,
            width: _chosen ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        child: Column(
          children: [
            Text(
              '${ordinal(occurrence.place)} place',
              style: AppTypography.smallBodyRegular
                  .copyWith(color: AppColors.mediumColor),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              occurrence.time ?? 'Time not settled',
              style: occurrence.time != null
                  ? AppTypography.displaySmall
                  : AppTypography.bodyRegular
                      .copyWith(color: AppColors.mediumColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            NearbyFinishersPanel(nearby: occurrence.nearby),
            if (_chosen) ...[
              const SizedBox(height: AppSpacing.sm),
              const Icon(Icons.check_circle,
                  color: AppColors.primaryColor, size: 28),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          border: Border.all(color: AppColors.borderColor),
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
        child: Text(
          message,
          style:
              AppTypography.caption.copyWith(color: AppColors.mediumColor),
        ),
      );
}
