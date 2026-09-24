import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Keeps the phone's screen from locking while a race runs, so a volunteer
/// never has to unlock it between runners. The phone's own setting comes
/// back once the race stops or the screen closes.
class ScreenAwake {
  ScreenAwake._();

  static const _channel = MethodChannel('xceleration/screen_awake');

  static bool _on = false;

  /// Whether the screen is being kept on.
  static bool get isOn => _on;

  static Future<void> set(bool on) async {
    if (_on == on) return;
    _on = on;
    try {
      await _channel.invokeMethod<void>('setAwake', on);
    } on MissingPluginException {
      // Tests and platforms without the native side: nothing to keep awake.
    } catch (e) {
      Logger.e('[ScreenAwake] Could not ${on ? 'keep' : 'stop keeping'} the '
          'screen on: $e');
    }
  }
}
