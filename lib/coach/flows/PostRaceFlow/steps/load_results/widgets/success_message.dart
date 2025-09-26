import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/color_utils.dart';

/// A widget that displays a success message when results are loaded successfully
class SuccessMessage extends StatelessWidget {
  const SuccessMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Results Loaded Successfully',
          style: AppTypography.bodySemibold
              .copyWith(color: AppColors.primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Click next to save your results and view them in the race results.',
          style: AppTypography.bodyRegular.copyWith(
              color: ColorUtils.withOpacity(AppColors.darkColor, 0.7)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
