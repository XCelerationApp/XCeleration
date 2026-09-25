import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/bib_conflict_resolution/model/bib_conflict.dart';
import 'package:xceleration/coach/bib_conflict_resolution/utils/ordinal.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/controller/load_results_controller.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/dev/race_simulator.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/base_models.dart';

import 'load_results_controller_test.mocks.dart';

// Resolving bib conflicts through the real screens, opened from the real
// post-race controller, the way a coach would: pick which finish belongs to a
// repeated bib's owner, then pick who each other finish really was from the
// list. The finish order that comes back has to match the answer key — the
// screens can look right and still put a runner at the wrong place.

class _NoopScheduler implements IPostFrameCallbackScheduler {
  @override
  void addPostFrameCallback(VoidCallback callback) {}
}

const _teams = [
  Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG'),
  Team(teamId: 2, name: 'Hawks', abbreviation: 'HAW'),
  Team(teamId: 3, name: 'Owls', abbreviation: 'OWL'),
];

List<RaceRunner> _roster(int n) => [
      for (var i = 1; i <= n; i++)
        RaceRunner(
          raceId: 1,
          runner: Runner(
              runnerId: i, name: 'Runner $i', bibNumber: '${100 + i}', grade: 10),
          team: _teams[i % 3],
        )
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Taps [finder] once it has been scrolled into view.
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Finds [runner] by name, assigns them and lets the undo toast run out.
  Future<void> assign(WidgetTester tester, RaceRunner runner) async {
    await tap(tester, find.text('Find Runner'));
    // Found by typing their name, as a coach would.
    await tester.enterText(
        find.byKey(const ValueKey('find_runner_search')), runner.runner.name!);
    await tester.pumpAndSettle();
    await tap(tester, find.text(runner.runner.name!).last);
    await tap(tester, find.text('Assign ${runner.runner.name} →'));
    // The toast commits the assignment when it runs out.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  for (final scenario in [
    SimulatedScenario.bibCollision,
    SimulatedScenario.bibTypo,
  ]) {
    for (final seed in [1, 2, 3]) {
      testWidgets('${scenario.name}, seed $seed', (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        late BuildContext ctx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (c) {
            ctx = c;
            return const Scaffold();
          }),
        ));

        final roster = _roster(12);
        final byBib = {for (final r in roster) r.runner.bibNumber!: r};
        final masterRace = MockMasterRace();
        when(masterRace.raceId).thenReturn(1);
        when(masterRace.raceRunners).thenAnswer((_) async => roster);
        when(masterRace.teams).thenAnswer((_) async => _teams);
        when(masterRace.race).thenAnswer((_) async => Race(raceName: 'Sim'));
        when(masterRace.getRaceRunnerByBib(any)).thenAnswer(
            (i) async => byBib[i.positionalArguments.first as String]);
        final controller = LoadResultsController(
          masterRace: masterRace,
          devices: DevicesManager(DeviceName.coach, DeviceType.browserDevice),
          scheduler: _NoopScheduler(),
        );

        final race = (await controller.loadSimulatedResults(ctx, scenario,
            simulator: RaceSimulator(random: Random(seed))))!;
        expect(controller.hasBibConflicts, isTrue, reason: race.notes.join('\n'));
        final truth = [for (final f in race.answerKey) f.runner];

        // What the screen will ask about.
        final conflicts = await detectBibConflicts(
          entries: controller.raceRunners!,
          timesByPlace: const {},
          lookupBib: masterRace.getRaceRunnerByBib,
        );

        final done = controller.showBibConflictsSheet(ctx);
        await tester.pumpAndSettle();
        await tap(tester, find.text('Start Resolving'));

        for (final conflict in conflicts) {
          switch (conflict) {
            case DuplicateBibConflict(:final occurrences, :final bibNumber):
              // The finish that is really the bib's owner.
              final owner = occurrences.firstWhere(
                  (o) => truth[o.place - 1].runner.bibNumber == bibNumber);
              await tap(tester, find.text('${ordinal(owner.place)} place'));
              for (final o in occurrences.where((o) => o != owner)) {
                expect(find.text('Who finished ${ordinal(o.place)}?'),
                    findsOneWidget);
                await assign(tester, truth[o.place - 1]);
              }
            case UnknownBibConflict(:final occurrence):
              // In the header and again in the nearby panel.
              expect(find.text(ordinal(occurrence.place)), findsNWidgets(2));
              await assign(tester, truth[occurrence.place - 1]);
          }
        }

        await tap(tester, find.text('Done'));
        await done;

        expect(controller.raceRunners, truth, reason: race.notes.join('\n'));
        expect(controller.hasBibConflicts, isFalse);
      });
    }
  }
}
