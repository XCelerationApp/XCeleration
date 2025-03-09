import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';

class ReviewResultsWidget extends StatelessWidget {
  const ReviewResultsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined, size: 64, color: AppColors.primaryColor),
          const SizedBox(height: 24),
          Text(
            'Review Race Results',
            style: AppTypography.titleSemibold.copyWith(color: AppColors.darkColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Take a moment to review the race results for accuracy before saving them.',
            style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Results Summary',
                  style: AppTypography.bodySemibold.copyWith(color: AppColors.darkColor),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItem('Total Runners', '42'),
                    _buildSummaryItem('Finish Times', '42'),
                    _buildSummaryItem('Teams', '5'),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'All conflicts resolved',
                      style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.titleSemibold.copyWith(
            color: AppColors.primaryColor,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.darkColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
