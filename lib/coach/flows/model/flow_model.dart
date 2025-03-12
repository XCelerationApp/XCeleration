import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/sheet_utils.dart';
import '../../../core/theme/typography.dart';
import 'dart:async';
import '../../flows/widgets/flow_indicator.dart';


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
    try {
      return await currentStep.canProceed!();
    } catch (e) {
      print('Error in canProceed: $e');
      return false; // Handle errors gracefully
    }
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

// Updated showFlow function with Provider
Future<bool> showFlow({
  required BuildContext context,
  required List<FlowStep> steps,
  bool showProgressIndicator = true,
}) async {
  final controller = FlowController(steps);
  bool completed = false;

  await sheet(
    context: context,
    title: null,
    takeUpScreen: true,
    body: ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<FlowController>(
        builder: (context, controller, _) {
          final currentStep = controller.currentStep;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showProgressIndicator)
                EnhancedFlowIndicator(
                  totalSteps: steps.length,
                  currentStep: controller.currentIndex,
                  onBack: controller.canGoBack ? controller.goBack : null,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStep.title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentStep.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 120, // Account for bottom padding and button
                        ),
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              currentStep.content,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (controller.canGoForward) {
                        await controller.goToNext();
                      } else {
                        Navigator.pop(context);
                        completed = true;
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      'Next',
                      style: AppTypography.bodySemibold.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  controller.dispose();
  return completed;
}