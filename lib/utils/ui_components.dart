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
  final Widget content;
  final Future<bool> Function()? canProceed;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final StreamController<void> _contentChangeController;

  FlowStep({
    required this.title,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        return Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryColor : Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            if (index < totalSteps - 1)
              Container(
                width: 48,
                height: 2,
                color: isActive ? AppColors.primaryColor : Colors.grey[300],
              ),
          ],
        );
      }),
    );
  }
}

Future<void> showFlow({
  required BuildContext context,
  required List<FlowStep> steps,
  bool dismissible = true,
}) async {
  final controller = FlowController(steps);
  
  return await sheet(
    context: context,
    title: steps[0].title,
    showHeader: false,
    takeUpScreen: true,
    body: StatefulBuilder(
      builder: (context, setState) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                createSheetHeader(
                  controller.currentStep.title,
                  // backArrow: controller.canGoBack,
                  context: context,
                  // onBack: controller.canGoBack ? () => setState(() => controller.goBack()) : null,
                ),
                const SizedBox(height: 16),
                FlowIndicator(
                  totalSteps: steps.length,
                  currentStep: controller.currentIndex,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: controller.currentStep.content,
                  ),
                ),
                // if (controller.canGoForward) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button
                      
                      IconButton(
                        onPressed: controller.canGoBack ? () => setState(() => controller.goBack()) : null,
                        icon: SvgPicture.asset(
                          'assets/icon/circle-arrow-left.svg',
                          width: 48,
                          height: 48,
                          color:  controller.canGoBack ? AppColors.darkColor : Colors.grey,
                        ),
                      ),
                      
                      // Progress indicator line
                      Expanded(
                        child: Container(
                          height: 2,
                          color: Colors.grey[300],
                        ),
                      ),

                      // Forward button
                      FutureBuilder<bool>(
                        future: controller.canProceedToNextStep(),
                        builder: (context, snapshot) {
                          final canProceed = snapshot.data ?? false;
                          return IconButton(
                            onPressed: canProceed
                                ? () async {
                                    await controller.goToNext();
                                    setState(() {});
                                  }
                                : null,
                            icon: SvgPicture.asset(
                              'assets/icon/circle-arrow-right.svg',
                              width: 48,
                              height: 48,
                              color: canProceed ? AppColors.darkColor : Colors.grey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                // ],
                const SizedBox(height: 16),
              ],
            );
          }
        );
      },
    ),
  );
}