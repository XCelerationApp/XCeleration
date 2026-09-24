import 'package:flutter/material.dart';
import 'dart:async';

typedef StepChangedCallback = void Function(int currentIndex);

/// Thrown from [FlowStep.onNext] to keep the flow on the current step, for
/// example when saving failed. [message] is shown to the user.
class FlowStepBlocked implements Exception {
  const FlowStepBlocked(this.message);

  final String message;

  @override
  String toString() => 'FlowStepBlocked: $message';
}

class FlowStep {
  final String title;
  final String description;
  final Widget content;
  final bool canScroll;
  final bool Function()? canProceed;

  /// Why Next is greyed out, shown under it. Checked whenever [canProceed]
  /// is false.
  final String? Function()? blockedReason;
  /// Runs before moving past this step. Throw [FlowStepBlocked] to stay on
  /// the step.
  final Future<void> Function()? onNext;
  final VoidCallback? onBack;
  final StreamController<void> _contentChangeController;

  FlowStep({
    required this.title,
    required this.description,
    required this.content,
    this.canScroll = true,
    this.canProceed,
    this.blockedReason,
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
