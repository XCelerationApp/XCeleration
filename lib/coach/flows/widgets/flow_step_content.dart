import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';

class FlowStepContent extends StatelessWidget {
  final String title;
  final String description;
  final Widget content;
  final int currentStep;
  final int totalSteps;

  const FlowStepContent({
    super.key,
    required this.title,
    required this.description,
    required this.content,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress indicator at the top
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: List.generate(totalSteps, (index) {
              final isActive = index <= currentStep;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primaryColor
                        : AppColors.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        // Title and description
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleSemibold,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: AppTypography.bodyRegular,
              ),
            ],
          ),
        ),
        // Main content
        Expanded(child: content),
      ],
    );
  }
}
