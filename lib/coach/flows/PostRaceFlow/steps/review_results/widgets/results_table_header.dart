import 'package:flutter/material.dart';
import 'package:xcelerate/core/theme/app_colors.dart';
import 'package:xcelerate/core/theme/typography.dart';

/// Header row for the results table showing column titles
class ResultsTableHeader extends StatelessWidget {
  const ResultsTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Text('Place', 
                style: AppTypography.bodySemibold.copyWith(color: AppColors.darkColor),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text('Runner', 
                style: AppTypography.bodySemibold.copyWith(color: AppColors.darkColor),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text('Time', 
                style: AppTypography.bodySemibold.copyWith(color: AppColors.darkColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
