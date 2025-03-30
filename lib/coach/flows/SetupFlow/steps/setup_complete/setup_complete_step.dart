import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/typography.dart';

class SetupCompleteStep extends FlowStep {
  SetupCompleteStep()
      : super(
          title: 'Setup Complete',
          description:
              'Great job! You\'ve finished setting up your race. Click Next to begin the pre-race preparations.',
          content: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle,
                    size: 120, color: AppColors.primaryColor),
                const SizedBox(height: 32),
                Text(
                  'Race Setup Complete!',
                  style: AppTypography.titleSemibold
                      .copyWith(color: AppColors.darkColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'You\'re ready to start managing your race.',
                  style: AppTypography.bodyRegular
                      .copyWith(color: AppColors.darkColor.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          canProceed: () => true,
        );
}
