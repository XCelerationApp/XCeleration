import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';

class SaveResultsWidget extends StatelessWidget {
  const SaveResultsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.save_alt, size: 64, color: AppColors.primaryColor),
          const SizedBox(height: 24),
          Text(
            'Save Race Results',
            style: AppTypography.titleSemibold.copyWith(color: AppColors.darkColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your race results have been processed and are ready to save. This will finalize the race and allow you to view the results, share with teams, and generate reports.',
            style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Race Results Ready',
                        style: AppTypography.bodySemibold.copyWith(color: AppColors.darkColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All data has been processed and is ready to save.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
