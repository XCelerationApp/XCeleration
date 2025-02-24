import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'sheet_utils.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';

Container buildSectionHeader(String title) {
  return Container(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class FlowStep {
  final String title;
  final String description;
  final Widget content;
  final Future<bool> Function()? canProceed;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final StreamController<void> _contentChangeController;

  FlowStep({
    required this.title,
    required this.description,
    required this.content,
    this.canProceed,
    this.onNext,
    this.onBack,
  }) : _contentChangeController = StreamController<void>.broadcast();

  Stream<void> get onContentChange => _contentChangeController.stream;

  void notifyContentChanged() {
    _contentChangeController.add(null);
    print('notified content changed');
  }

  void dispose() {
    _contentChangeController.close();
  }
}

class FlowController extends ChangeNotifier {
  int _currentIndex = 0;
  final List<FlowStep> steps;
  StreamSubscription<void>? _contentChangeSubscription;

  FlowController(this.steps) {
    _subscribeToCurrentStep();
  }

  void _subscribeToCurrentStep() {
    _contentChangeSubscription?.cancel();
    _contentChangeSubscription = currentStep.onContentChange.listen((_) {
      notifyListeners();
    });
  }

  int get currentIndex => _currentIndex;
  bool get canGoBack => _currentIndex > 0;
  bool get canGoForward => _currentIndex < steps.length - 1;
  
  FlowStep get currentStep => steps[_currentIndex];

  Future<bool> canProceedToNextStep() async {
    if (currentStep.canProceed == null) return true;
    return await currentStep.canProceed!();
  }

  Future<void> goToNext() async {
    if (canGoForward && await canProceedToNextStep()) {
      currentStep.onNext?.call();
      _currentIndex++;
      _subscribeToCurrentStep();
      notifyListeners();
    }
  }

  void goBack() {
    if (canGoBack) {
      currentStep.onBack?.call();
      _currentIndex--;
      _subscribeToCurrentStep();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _contentChangeSubscription?.cancel();
    for (final step in steps) {
      step.dispose();
    }
    super.dispose();
  }
}

class FlowIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;

  const FlowIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = 32.0; // Width of circle
        final lineWidth = (constraints.maxWidth - (itemWidth * totalSteps)) / (totalSteps - 1);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(totalSteps, (index) {
            final isActive = index <= currentStep;
            final isCompleted = index < currentStep;

            return Row(
              children: [
                Container(
                  width: itemWidth,
                  height: itemWidth,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primaryColor : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                      ? SvgPicture.asset(
                          'assets/icon/check.svg',
                          width: 16,
                          height: 16,
                          color: Colors.white,
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                ),
                if (index < totalSteps - 1)
                  Container(
                    width: lineWidth,
                    height: 2,
                    color: isActive ? AppColors.primaryColor : Colors.grey[300],
                  ),
              ],
            );
          }),
        );
      }
    );
  }
}

Future<bool> showFlow({
  required BuildContext context,
  required List<FlowStep> steps,
  bool showProgressIndicator = true,
}) async {
  final controller = FlowController(steps);
  bool completed = false;
  
  await showModalBottomSheet(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final currentStep = controller.currentStep;
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress indicator
                if (showProgressIndicator) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: List.generate(
                        steps.length,
                        (index) => Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: index <= controller.currentIndex 
                                ? AppColors.primaryColor 
                                : Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStep.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentStep.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: currentStep.content,
                    ),
                  ),
                ),

                // Navigation buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (controller.canGoBack)
                        TextButton.icon(
                          onPressed: () {
                            controller.goBack();
                            setState(() {});
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                      const Spacer(),
                      FutureBuilder<bool>(
                        future: currentStep.canProceed?.call() ?? Future.value(true),
                        builder: (context, snapshot) {
                          final canProceed = snapshot.data ?? true;
                          
                          return ElevatedButton(
                            onPressed: canProceed
                              ? () async {
                                  if (controller.canGoForward) {
                                    await controller.goToNext();
                                    setState(() {});
                                  } else {
                                    completed = true;
                                    Navigator.pop(context);
                                  }
                                }
                              : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              minimumSize: const Size(120, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Next',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (controller.canGoForward) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 20),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  
  controller.dispose();
  return completed;
}