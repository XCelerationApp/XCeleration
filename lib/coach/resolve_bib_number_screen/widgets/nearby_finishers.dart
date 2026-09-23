import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../model/bib_conflict.dart';

/// Who finished either side of a disputed place, so the coach can tell which
/// stretch of the race a finish sits in.
class NearbyFinishersPanel extends StatelessWidget {
  const NearbyFinishersPanel({super.key, required this.nearby});

  final List<NearbyFinisher> nearby;

  @override
  Widget build(BuildContext context) {
    if (nearby.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEARBY',
          style: AppTypography.extraSmall.copyWith(
            letterSpacing: 0.5,
            color: AppColors.mediumColor,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final finisher in nearby)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '${finisher.place}. ${finisher.name}'
              '${finisher.time == null ? '' : ' · ${finisher.time}'}',
              style: AppTypography.caption
                  .copyWith(color: AppColors.mediumColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
