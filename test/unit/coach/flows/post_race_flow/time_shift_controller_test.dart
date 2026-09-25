import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/controller/load_results_controller.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/dev/race_simulator.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/base_models.dart';

import 'load_results_controller_test.mocks.dart';

// A Timer who started late: the coach moves every time before saving, and
// the saved results carry the moved times.

class _NoopScheduler implements IPostFrameCallbackScheduler {
  @override
  void addPostFrameCallback(VoidCallback callback) {}
}

const _team = Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadResultsController controller;
  late MockMasterRace masterRace;
  late BuildContext ctx;

  Future<void> load(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold();
      }),
    ));
    final roster = [
      for (var i = 1; i <= 8; i++)
        RaceRunner(
          raceId: 1,
          runner: Runner(
              runnerId: i, name: 'Runner $i', bibNumber: '${100 + i}', grade: 10),
          team: _team,
        ),
    ];
    final byBib = {for (final r in roster) r.runner.bibNumber!: r};
    masterRace = MockMasterRace();
    when(masterRace.raceId).thenReturn(1);
    when(masterRace.raceRunners).thenAnswer((_) async => roster);
    when(masterRace.teams).thenAnswer((_) async => const [_team]);
    when(masterRace.race).thenAnswer((_) async => Race(raceName: 'Sim'));
    when(masterRace.getRaceRunnerByBib(any))
        .thenAnswer((i) async => byBib[i.positionalArguments.first as String]);
    when(masterRace.saveResults(any)).thenAnswer((_) async {});
    controller = LoadResultsController(
      masterRace: masterRace,
      devices: DevicesManager(DeviceName.coach, DeviceType.browserDevice),
      scheduler: _NoopScheduler(),
    );
    await controller.loadSimulatedResults(ctx, SimulatedScenario.clean,
        simulator: RaceSimulator(random: Random(1)));
  }

  List<Duration> saved() => [
        for (final r in verify(masterRace.saveResults(captureAny))
            .captured
            .single as List<RaceResult>)
          r.finishTime!,
      ];

  testWidgets('saves every time moved by the seconds the Timer was late',
      (tester) async {
    await load(tester);
    await controller.saveCurrentResults();
    final before = saved();

    await load(tester);
    expect(controller.shiftAllTimes(const Duration(seconds: 5)), isNull);
    await controller.saveCurrentResults();

    expect(saved(), [for (final t in before) t + const Duration(seconds: 5)]);
    expect(controller.timeShift, const Duration(seconds: 5));
  });

  testWidgets('moving back undoes it', (tester) async {
    await load(tester);
    await controller.saveCurrentResults();
    final before = saved();

    await load(tester);
    controller.shiftAllTimes(const Duration(seconds: 5));
    controller.shiftAllTimes(const Duration(seconds: -5));
    await controller.saveCurrentResults();

    expect(saved(), before);
    expect(controller.timeShift, Duration.zero);
  });

  testWidgets('loading the results again starts from no shift',
      (tester) async {
    await load(tester);
    controller.shiftAllTimes(const Duration(seconds: 5));

    await load(tester);

    expect(controller.timeShift, Duration.zero);
  });
}
