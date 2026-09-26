import 'package:flutter/material.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/grade_utils.dart';
import '../../../shared/models/database/race_runner.dart';
import '../utils/bib_suggestions.dart';

/// The runners a mistyped bib most likely was, each with why, so the coach
/// can confirm one instead of working it out. Tapping one assigns them;
/// the banner that follows can undo it.
class SuggestedRunners extends StatelessWidget {
  const SuggestedRunners({
    super.key,
    required this.suggestions,
    required this.onPick,
  });

  final List<RunnerSuggestion> suggestions;
  final ValueChanged<RaceRunner> onPick;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'MOST LIKELY',
          style: AppTypography.extraSmall.copyWith(
            letterSpacing: 0.5,
            color: AppColors.mediumColor,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final s in suggestions)
          _SuggestionTile(suggestion: s, onTap: () => onPick(s.runner)),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion, required this.onTap});

  final RunnerSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final runner = suggestion.runner;
    final grade = runner.runner.grade;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          side: const BorderSide(color: AppColors.lightColor),
        ),
        child: InkWell(
          key: ValueKey('suggested_${runner.runner.bibNumber}'),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  ),
                  child: Text(
                    runner.runner.bibNumber ?? '',
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: AppColors.primaryColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          runner.runner.name ?? '',
                          if (grade != null) gradeLabel(grade),
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: AppTypography.smallBodySemibold,
                      ),
                      Text(
                        [runner.team.name ?? '', ...suggestion.reasons]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.mediumColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Assign',
                  style: AppTypography.smallBodySemibold
                      .copyWith(color: AppColors.primaryColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
