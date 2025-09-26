import 'package:flutter/material.dart';
import 'dart:async';

typedef StepChangedCallback = void Function(int currentIndex);

class FlowStep {
  final String title;
  final String description;
  final Widget content;
  final bool canScroll;
  final bool Function()? canProceed;
  final Future<void> Function()? onNext;
  final VoidCallback? onBack;
  final StreamController<void> _contentChangeController;

  FlowStep({
    required this.title,
    required this.description,
    required this.content,
    this.canScroll = true,
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
