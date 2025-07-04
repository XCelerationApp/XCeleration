import 'package:flutter/material.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class PlaceNumber extends StatelessWidget {
  const PlaceNumber({
    super.key,
    required this.place,
    required this.color,
  });
  final int place;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(color, 0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: ColorUtils.withOpacity(color, 0.4),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          place == 0 ? '?' : '#$place',
          style: AppTypography.smallCaption.copyWith(
            color: ColorUtils.withOpacity(color, 0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class RunnerInfo extends StatelessWidget {
  const RunnerInfo({
    super.key,
    required this.runner,
    required this.accentColor,
  });
  final RunnerRecord runner;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          runner.name,
          style: AppTypography.smallBodySemibold.copyWith(
            color: AppColors.darkColor,
            letterSpacing: -0.1,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (runner.bib.isNotEmpty)
              InfoChip(label: 'Bib ${runner.bib}', color: accentColor),
            if (runner.school.isNotEmpty)
              InfoChip(label: runner.school, color: accentColor),
          ],
        ),
      ],
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    required this.color,
  });
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(color, 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.smallCaption.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
