import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/color_utils.dart';

/// A widget that displays a success message when results are loaded successfully
class SuccessMessage extends StatelessWidget {
  const SuccessMessage({super.key});

  static final TextStyle _titleStyle =
      AppTypography.bodySemibold.copyWith(color: AppColors.primaryColor);
  static final TextStyle _bodyStyle = AppTypography.bodyRegular
      .copyWith(color: ColorUtils.withOpacity(AppColors.darkColor, 0.7));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Results Loaded',
          style: _titleStyle,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap Next to check them before saving.',
          style: _bodyStyle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
