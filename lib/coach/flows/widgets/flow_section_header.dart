import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';

// Utility widget for section headers
class FlowSectionHeader extends StatelessWidget {
  final String title;
  const FlowSectionHeader({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        title,
        style: AppTypography.titleSemibold.copyWith(
          color: AppColors.primaryColor,
        ),
      ),
    );
  }
}