import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';

/// Model class for a single step in a flow
class FlowStep {
  final String title;
  final String description;
  final Widget content;
  final Future<bool> Function() canProceed;
  
  FlowStep({
    required this.title,
    required this.description,
    required this.content,
    required this.canProceed,
  });
}

/// Shows a flow widget with the provided steps and returns true if all steps were completed
Future<bool> showFlowWidget({
  required BuildContext context,
  required List<FlowStep> steps,
  bool showProgressIndicator = false,
  bool dismissible = true,
}) async {
  return await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => FlowWidget(
      steps: steps,
      showProgressIndicator: showProgressIndicator,
    ),
  ) ?? false;
}

/// A widget that displays a flow of steps the user must complete
class FlowWidget extends StatefulWidget {
  final List<FlowStep> steps;
  final bool showProgressIndicator;
  
  const FlowWidget({
    Key? key,
    required this.steps,
    this.showProgressIndicator = false,
  }) : super(key: key);
  
  @override
  State<FlowWidget> createState() => _FlowWidgetState();
}

class _FlowWidgetState extends State<FlowWidget> {
  int _currentStep = 0;
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    final currentStep = widget.steps[_currentStep];
    final isLastStep = _currentStep == widget.steps.length - 1;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Progress indicator
                    if (widget.showProgressIndicator) ...[
                      LinearProgressIndicator(
                        value: (_currentStep + 1) / widget.steps.length,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Title
                    Text(
                      currentStep.title,
                      style: AppTypography.titleSemibold.copyWith(
                        color: AppColors.darkColor,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Description
                    Text(
                      currentStep.description,
                      style: AppTypography.bodyRegular.copyWith(
                        color: AppColors.darkColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: currentStep.content,
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.all(16) + EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, -2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    _currentStep > 0 ? TextButton(
                      onPressed: _isLoading ? null : () {
                        setState(() {
                          _currentStep--;
                        });
                      },
                      child: Text(
                        'Back',
                        style: AppTypography.bodySemibold.copyWith(
                          color: AppColors.darkColor.withOpacity(0.7),
                        ),
                      ),
                    ) : const SizedBox(width: 80),
                    
                    // Next button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _isLoading ? null : () async {
                        setState(() {
                          _isLoading = true;
                        });
                        
                        final canProceed = await currentStep.canProceed();
                        
                        setState(() {
                          _isLoading = false;
                        });
                        
                        if (canProceed) {
                          if (isLastStep) {
                            Navigator.pop(context, true);
                          } else {
                            setState(() {
                              _currentStep++;
                            });
                          }
                        }
                      },
                      child: _isLoading 
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isLastStep ? 'Finish' : 'Next',
                            style: AppTypography.bodySemibold.copyWith(color: Colors.white),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
