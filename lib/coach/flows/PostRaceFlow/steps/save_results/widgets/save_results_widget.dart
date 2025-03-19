import 'package:flutter/material.dart';
import 'package:xcelerate/core/theme/app_colors.dart';
import 'package:xcelerate/core/theme/typography.dart';

class SaveResultsWidget extends StatelessWidget {
  const SaveResultsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.save_outlined, size: 80, color: AppColors.primaryColor),
          const SizedBox(height: 24),
          Text(
            'Save Race Results',
            style: AppTypography.titleSemibold.copyWith(color: AppColors.darkColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Click Next to save the results and complete the race.',
            style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
