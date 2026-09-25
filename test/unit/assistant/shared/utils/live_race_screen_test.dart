import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/assistant/shared/utils/live_race_screen.dart';

// If the phone closes the app mid-race, opening it again goes straight back
// to the Timer or Bib Recorder.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LiveRaceScreen.resetForTest();
  });

  test('remembers the screen with a race running', () async {
    await LiveRaceScreen.mark(LiveRaceScreen.timer);

    expect(await LiveRaceScreen.read(), LiveRaceScreen.timer);
  });

  test('forgets it once the race stops or the screen is left', () async {
    await LiveRaceScreen.mark(LiveRaceScreen.bibRecorder);
    await LiveRaceScreen.mark(null);

    expect(await LiveRaceScreen.read(), isNull);
  });

  test('ignores anything it does not know', () async {
    SharedPreferences.setMockInitialValues(
        {LiveRaceScreen.prefKey: 'somewhere else'});

    expect(await LiveRaceScreen.read(), isNull);
  });

  test('nothing is remembered on a fresh install', () async {
    expect(await LiveRaceScreen.read(), isNull);
  });
}
