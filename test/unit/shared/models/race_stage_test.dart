import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/shared/models/database/race.dart';
import 'package:xceleration/shared/models/race_stage.dart';

// Every stored flow state maps to one of three steps a coach recognises, and
// every step before the end says what the button does next.

void main() {
  test('each flow state is one of the three steps, in order', () {
    // Setup done is still step 1: the race only reaches step 2 once it has
    // actually been sent to the volunteers.
    expect([
      for (final state in Race.FLOW_SEQUENCE) RaceStage.of(state).step
    ], [
      1, 1, 2, 2, 3, 4,
    ]);
  });

  test('yellow until sent, blue at the race, purple collecting, green done',
      () {
    expect([for (final state in Race.FLOW_SEQUENCE) RaceStage.of(state).color],
        [
          AppColors.statusSetup,
          AppColors.statusSetup,
          AppColors.statusPreRace,
          AppColors.statusPreRace,
          AppColors.statusPostRace,
          AppColors.statusFinished,
        ]);
  });

  test('every unfinished state says what to do next', () {
    for (final state in Race.FLOW_SEQUENCE) {
      final stage = RaceStage.of(state);
      expect(stage.action == null, stage.isFinished, reason: state);
    }
  });

  test('the finished race has no next step', () {
    final stage = RaceStage.of(Race.FLOW_FINISHED);
    expect(stage.isFinished, isTrue);
    expect(stage.action, isNull);
  });

  test('an unknown state is treated as setup rather than shown raw', () {
    expect(RaceStage.of('something-new').label, 'Set up the race');
    expect(RaceStage.of(null).step, 1);
  });
}
