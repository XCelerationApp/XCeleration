import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/controller/load_results_controller.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/load_results_step.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/enums.dart';

import 'load_results_controller_test.mocks.dart';

// Next on Load Results stays greyed out until the results are in and every
// conflict is resolved. The conflicts open from the card's Start button.

void main() {
  late LoadResultsController controller;
  late LoadResultsStep step;

  setUp(() {
    controller = LoadResultsController(
      masterRace: MockMasterRace(),
      devices: DevicesManager(DeviceName.coach, DeviceType.browserDevice),
      scheduler: MockIPostFrameCallbackScheduler(),
    );
    step = LoadResultsStep(controller: controller);
  });

  test('waits for the results', () {
    expect(step.canProceed!(), isFalse);
    expect(step.blockedReason!(), contains('Waiting'));
  });

  test('stays greyed out while a bib or timing conflict is left', () {
    controller.resultsLoaded = true;
    controller.hasBibConflicts = true;
    expect(step.canProceed!(), isFalse);
    expect(step.blockedReason!(), contains('Resolve the conflicts'));

    controller.hasBibConflicts = false;
    controller.hasTimingConflicts = true;
    expect(step.canProceed!(), isFalse);
  });

  test('opens once every conflict is resolved', () {
    controller.resultsLoaded = true;
    expect(step.canProceed!(), isTrue);
    expect(step.blockedReason!(), isNull);
  });

  test('says what to do once the results are in', () {
    expect(step.description, contains('tap Share Times or Share Bibs'));

    controller.resultsLoaded = true;
    controller.hasTimingConflicts = true;
    expect(step.description, contains('A few need checking'));

    controller.hasTimingConflicts = false;
    expect(step.description, contains('Tap Next to look them over'));
  });
}
