import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

class ListTitles extends StatelessWidget {
  const ListTitles({super.key});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.smallCaption.copyWith(
      color: AppColors.mediumColor,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(child: Text('NAME', style: style)),
              SizedBox(width: 40, child: Center(child: Text('GR.', style: style))),
              SizedBox(width: 60, child: Center(child: Text('BIB', style: style))),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.lightColor),
      ],
    );
  }
}
