import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Keeps the phone's screen from locking while something needs it on: a race
/// running, so a volunteer never unlocks the phone between runners, or a
/// phone-to-phone transfer, which iOS pauses when the phone locks. The
/// phone's own setting comes back once nothing needs the screen on.
class ScreenAwake {
  ScreenAwake._();

  static const _channel = MethodChannel('xceleration/screen_awake');

  /// Why the screen is being kept on, such as 'race' or 'transfer'.
  static final Set<String> _reasons = {};

  static bool _on = false;

  /// Whether the screen is being kept on.
  static bool get isOn => _on;

  /// Keeps the screen on for [reason], or stops when [on] is false. The
  /// screen stays on while any reason still wants it.
  static Future<void> set(bool on, {String reason = 'race'}) async {
    if (on) {
      _reasons.add(reason);
    } else {
      _reasons.remove(reason);
    }
    final wanted = _reasons.isNotEmpty;
    if (_on == wanted) return;
    _on = wanted;
    try {
      await _channel.invokeMethod<void>('setAwake', wanted);
    } on MissingPluginException {
      // Tests and platforms without the native side: nothing to keep awake.
    } catch (e) {
      Logger.e('[ScreenAwake] Could not ${wanted ? 'keep' : 'stop keeping'} '
          'the screen on: $e');
    }
  }
}
