import 'package:flutter/services.dart';

abstract interface class IHapticFeedback {
  Future<void> vibrate();
  Future<void> lightImpact();
  Future<void> mediumImpact();
  Future<void> selectionClick();
}

class HapticFeedbackService implements IHapticFeedback {
  @override
  Future<void> vibrate() => HapticFeedback.vibrate();

  @override
  Future<void> lightImpact() => HapticFeedback.lightImpact();

  @override
  Future<void> mediumImpact() => HapticFeedback.mediumImpact();

  @override
  Future<void> selectionClick() => HapticFeedback.selectionClick();
}
