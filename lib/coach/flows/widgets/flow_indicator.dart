import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// Enhanced progress indicator with animations
class EnhancedFlowIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final VoidCallback? onBack;

  const EnhancedFlowIndicator({super.key, 
    required this.totalSteps,
    required this.currentStep,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      // margin: const EdgeInsets.only(top: 8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Back Button (if present)
          if (onBack != null)
            Positioned(
              left: 16,
              top: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 24, color: Colors.black),
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          // Progress Indicator (always centered)
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.35,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps, (index) {
                  final isCurrentStep = index == currentStep;
                  final isCompleted = index < currentStep;
                  return Expanded(
                    flex: isCurrentStep ? 3 : 1,
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.only(
                        right: index < totalSteps - 1 ? 4 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted || isCurrentStep ? AppColors.darkColor : AppColors.lightColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}