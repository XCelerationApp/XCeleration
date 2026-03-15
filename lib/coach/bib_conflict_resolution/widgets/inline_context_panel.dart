import 'package:flutter/material.dart';

import '../mock/conflict_mock_data.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Compact, always-visible panel showing the one runner ahead and one runner
/// behind a conflict position. Replaces the collapsible [RaceContextPanel]
/// for the v2 prototype — no tap required.
class InlineContextPanel extends StatelessWidget {
  const InlineContextPanel({
    super.key,
    required this.surroundingFinishers,
    required this.contextPosition,
  });

  /// Non-conflict finishers surrounding the conflict, sorted ascending by position.
  final List<MockFinishEntry> surroundingFinishers;

  /// The earliest finish position involved in the conflict.
  final int contextPosition;

  MockFinishEntry? get _ahead => surroundingFinishers
      .where((e) => e.position < contextPosition)
      .lastOrNull;

  MockFinishEntry? get _behind => surroundingFinishers
      .where((e) => e.position > contextPosition)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final ahead = _ahead;
    final behind = _behind;

    if (ahead == null && behind == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lightColor.withValues(alpha: AppOpacity.light),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: AppColors.lightColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEARBY',
            style: AppTypography.extraSmall.copyWith(
              letterSpacing: 0.5,
              color: AppColors.mediumColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (ahead != null) _RunnerRow(entry: ahead, isAhead: true),
          if (ahead != null && behind != null)
            Divider(
              height: AppSpacing.md * 2,
              thickness: 1,
              color: AppColors.lightColor,
            ),
          if (behind != null) _RunnerRow(entry: behind, isAhead: false),
        ],
      ),
    );
  }
}

class _RunnerRow extends StatelessWidget {
  const _RunnerRow({required this.entry, required this.isAhead});

  final MockFinishEntry entry;
  final bool isAhead;

  Color get _dotColor =>
      isAhead ? AppColors.statusPreRace : AppColors.primaryColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: _dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: Text(
            entry.runnerName,
            style: AppTypography.smallBodyRegular,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            entry.team,
            style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          entry.formattedTime,
          style: AppTypography.caption.copyWith(
            color: AppColors.mediumColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '#${entry.bibNumber}',
          style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
        ),
      ],
    );
  }
}
