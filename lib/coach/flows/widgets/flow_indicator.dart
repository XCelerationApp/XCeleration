import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// Enhanced progress indicator with animations
class EnhancedFlowIndicator extends StatefulWidget {
  final int totalSteps;
  final int currentStep;
  final VoidCallback? onBack;

  const EnhancedFlowIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.onBack,
  });

  @override
  State<EnhancedFlowIndicator> createState() => _EnhancedFlowIndicatorState();
}

class _EnhancedFlowIndicatorState extends State<EnhancedFlowIndicator> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Back Button (if present)
          if (widget.onBack != null)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      size: 24, color: Colors.black),
                  onPressed: widget.onBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          // Progress Indicator (always centered)
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.35,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.totalSteps, (index) {
                  final isCurrentStep = index == widget.currentStep;
                  final isCompleted = index < widget.currentStep;
                  return Expanded(
                    flex: isCurrentStep ? 3 : 1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      height: 5,
                      margin: EdgeInsets.only(
                        right: index < widget.totalSteps - 1 ? 4 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted || isCurrentStep
                            ? AppColors.darkColor
                            : AppColors.lightColor,
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
