import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/logger.dart';

/// Which race-day screen has a race running: the Timer or the Bib Recorder.
///
/// Remembered on the phone so that if the phone closes the app mid-race (a
/// crash, low memory, or a swipe by mistake), opening it again goes straight
/// back to that screen instead of the role picker, two taps and a stressful
/// moment away from the finish line.
class LiveRaceScreen {
  LiveRaceScreen._();

  static const prefKey = 'live_race_screen';
  static const timer = 'timer';
  static const bibRecorder = 'bibRecorder';

  static String? _last;
  static bool _checked = false;

  /// Marks [screen] as having a race running, or clears it with null when
  /// the race stops or the volunteer leaves the screen.
  static Future<void> mark(String? screen) async {
    if (_checked && _last == screen) return;
    _checked = true;
    _last = screen;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (screen == null) {
        await prefs.remove(prefKey);
      } else {
        await prefs.setString(prefKey, screen);
      }
    } catch (e) {
      Logger.e('[LiveRaceScreen] $e');
    }
  }

  /// The screen that had a race running when the app last closed, if any.
  static Future<String?> read() async {
    try {
      final screen = (await SharedPreferences.getInstance()).getString(prefKey);
      return screen == timer || screen == bibRecorder ? screen : null;
    } catch (e) {
      Logger.e('[LiveRaceScreen] $e');
      return null;
    }
  }

  /// Forgets what was remembered in memory, for tests.
  static void resetForTest() {
    _last = null;
    _checked = false;
  }
}
