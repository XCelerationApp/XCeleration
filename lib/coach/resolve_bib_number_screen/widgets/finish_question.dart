import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/ordinal.dart';
import '../../bib_conflict_resolution/model/bib_conflict.dart';
import 'nearby_finishers.dart';

/// Asks who finished at one place, with everything known about that finish:
/// when it happened, why it is being asked, and who came in either side.
class FinishQuestion extends StatelessWidget {
  const FinishQuestion({
    super.key,
    required this.occurrence,
    required this.reason,
    this.note,
  });

  final ConflictOccurrence occurrence;

  /// Why this finish has nobody, e.g. that the bib was a typo here.
  final String reason;

  /// Anything else worth saying, such as how many finishes are left.
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who finished ${ordinal(occurrence.place)}?',
          style: AppTypography.titleSemibold,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [?occurrence.time, reason, ?note].join(' · '),
          style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.md),
        NearbyFinishersPanel(nearby: occurrence.nearby),
      ],
    );
  }
}
