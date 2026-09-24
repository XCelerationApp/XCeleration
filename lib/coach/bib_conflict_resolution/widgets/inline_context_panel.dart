import 'package:flutter/material.dart';

import '../model/bib_conflict.dart';
import '../utils/ordinal.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Compact, always-visible panel: the finisher just ahead, the disputed
/// finish itself, and the finisher just behind, each with its place.
class InlineContextPanel extends StatelessWidget {
  const InlineContextPanel({
    super.key,
    required this.surroundingFinishers,
    required this.contextPosition,
    required this.conflictBib,
    this.conflictTime,
  });

  /// Non-conflict finishers surrounding the conflict, sorted ascending by position.
  final List<NearbyFinisher> surroundingFinishers;

  /// The disputed finish's place.
  final int contextPosition;

  /// The bib recorded at the disputed finish.
  final String conflictBib;

  /// Null when the Timer has not settled that place.
  final String? conflictTime;

  NearbyFinisher? get _ahead => surroundingFinishers
      .where((e) => e.place < contextPosition)
      .lastOrNull;

  NearbyFinisher? get _behind => surroundingFinishers
      .where((e) => e.place > contextPosition)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final ahead = _ahead;
    final behind = _behind;

    final divider = Divider(
      height: AppSpacing.md * 2,
      thickness: 1,
      color: AppColors.lightColor,
    );

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
          if (ahead != null) ...[
            _Row(
              place: ahead.place,
              name: ahead.name,
              team: ahead.team,
              time: ahead.time,
              bibNumber: ahead.bibNumber,
            ),
            divider,
          ],
          _Row(
            place: contextPosition,
            name: 'Unknown runner',
            time: conflictTime,
            bibNumber: conflictBib,
            highlighted: true,
          ),
          if (behind != null) ...[
            divider,
            _Row(
              place: behind.place,
              name: behind.name,
              team: behind.team,
              time: behind.time,
              bibNumber: behind.bibNumber,
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.place,
    required this.name,
    this.team,
    this.time,
    required this.bibNumber,
    this.highlighted = false,
  });

  final int place;
  final String name;
  final String? team;
  final String? time;
  final String bibNumber;

  /// The disputed finish, set apart from the runners around it.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final muted = AppTypography.caption.copyWith(color: AppColors.mediumColor);
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            ordinal(place),
            style: highlighted
                ? AppTypography.captionBold
                    .copyWith(color: AppColors.primaryColor)
                : muted,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: Text(
            name,
            style: highlighted
                ? AppTypography.smallBodySemibold
                    .copyWith(color: AppColors.primaryColor)
                : AppTypography.smallBodyRegular,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            team ?? '',
            style: muted,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          time ?? '—',
          style: muted.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('#$bibNumber', style: muted),
      ],
    );
  }
}
