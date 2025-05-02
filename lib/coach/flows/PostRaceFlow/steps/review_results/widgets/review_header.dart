import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Header component for the results review screen
class ReviewHeader extends StatelessWidget {
  const ReviewHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.fact_check_outlined,
            size: 80, color: AppColors.primaryColor),
        const SizedBox(height: 24),
        Text(
          'Review Race Results',
          style:
              AppTypography.titleSemibold.copyWith(color: AppColors.darkColor),
        ),
        const SizedBox(height: 16),
        Text(
          'Make sure all times and placements are correct. When you click next, you will not be able to reload or modify the results.',
          style: AppTypography.bodyRegular
              .copyWith(color: AppColors.darkColor.withOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
