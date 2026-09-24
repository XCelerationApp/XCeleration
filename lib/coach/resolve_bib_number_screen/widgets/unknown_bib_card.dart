import 'package:flutter/material.dart';

import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../bib_conflict_resolution/model/bib_conflict.dart';
import 'finish_question.dart';

/// Resolving a bib no runner has.
///
/// Somebody crossed the line at this place; the bib written down for them
/// belongs to nobody, so it was mistyped or the runner is not on the roster.
class UnknownBibCard extends StatelessWidget {
  const UnknownBibCard({
    super.key,
    required this.conflict,
    required this.buildAssignment,
  });

  final UnknownBibConflict conflict;

  /// The assign-or-create UI for this finish.
  final WidgetBuilder buildAssignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.selectedRoleColor,
            border: Border.all(
              color:
                  AppColors.primaryColor.withValues(alpha: AppOpacity.strong),
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BIB NOT FOUND',
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
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FinishQuestion(
          occurrence: conflict.occurrence,
          reason: 'No runner has bib #${conflict.bibNumber}',
        ),
        const SizedBox(height: AppSpacing.md),
        buildAssignment(context),
      ],
    );
  }
}
