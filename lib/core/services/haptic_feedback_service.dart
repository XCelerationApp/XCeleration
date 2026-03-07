import 'package:flutter/services.dart';

abstract interface class IHapticFeedback {
  Future<void> vibrate();
  Future<void> lightImpact();
}

class HapticFeedbackService implements IHapticFeedback {
  @override
  Future<void> vibrate() => HapticFeedback.vibrate();

  @override
  Future<void> lightImpact() => HapticFeedback.lightImpact();
}
