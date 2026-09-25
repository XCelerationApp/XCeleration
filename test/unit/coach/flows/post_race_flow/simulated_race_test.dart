import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/controller/load_results_controller.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/dev/race_simulator.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/models/ui_chunk.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/shared/models/database/base_models.dart';

import 'load_results_controller_test.mocks.dart';

// End to end on the coach: simulated Timer and Bib Recorder data is loaded
// through the real controller, every conflict is resolved the way a coach
// would (using only what the screens show plus the true times), and the saved
// results must match the answer key exactly.

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

UIChunk _ui(MergeConflictsController c, int id) =>
    c.uiChunks.firstWhere((u) => u.chunkId == id);

/// Resolves every timing conflict as a coach would, knowing the true times.
Future<void> _resolveTiming(
    MergeConflictsController c, List<String> truth) async {
  final truthSet = truth.toSet();
  // Resolving a chunk can reveal its next conflict, so keep going until none
  // are left (with a bound, so a loop that makes no progress fails).
  for (var round = 0; round < 20 && c.hasConflicts; round++) {
    final id = c.uiChunks
        .firstWhere((u) => u.conflict.type != ConflictType.confirmRunner)
        .chunkId;
    var ui = _ui(c, id);
    if (ui.conflict.type == ConflictType.extraTime) {
      // Remove each time that isn't a real finisher's.
      while (true) {
        ui = _ui(c, id);
        final stray = ui.records.indexWhere((r) => !truthSet.contains(r.time));
        if (stray == -1) break;
        c.removeExtraTimeRecord(id, stray);
      }
      await c.resolveExtraTimeConflict(id);
    } else {
      final start = ui.startingPlace - 1;
      final expected = truth.sublist(start, start + ui.records.length);
      // Move a TBD in front of each recorded time that is in the wrong place.
      for (var j = 0; j < expected.length; j++) {
        ui = _ui(c, id);
        final record = ui.records[j];
        if (!record.isUnfilled && record.time != expected[j]) {
          c.insertTbdAt(id, j);
        }
      }
      ui = _ui(c, id);
      for (var j = 0; j < expected.length; j++) {
        if (ui.records[j].isUnfilled) {
          c.updateMissingTimeRecord(id, j, expected[j]);
        }
      }
      await c.resolveMissingTimeConflict(id);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    return ctx;
  }

  for (final scenario in SimulatedScenario.values) {
    for (final size in [8, 13, 30]) {
      for (final seed in [1, 2, 3, 4, 5, 6]) {
        testWidgets('${scenario.name}: $size runners, seed $seed',
            (tester) async {
          final ctx = await pumpContext(tester);
          final roster = _roster(size);
          final byBib = {for (final r in roster) r.runner.bibNumber!: r};
          final masterRace = MockMasterRace();
          when(masterRace.raceId).thenReturn(1);
          when(masterRace.raceRunners).thenAnswer((_) async => roster);
          when(masterRace.getRaceRunnerByBib(any)).thenAnswer(
              (i) async => byBib[i.positionalArguments.first as String]);
          when(masterRace.saveResults(any)).thenAnswer((_) async {});
          final controller = LoadResultsController(
            masterRace: masterRace,
            devices: DevicesManager(DeviceName.coach, DeviceType.browserDevice),
            scheduler: _NoopScheduler(),
          );

          final race = (await controller.loadSimulatedResults(ctx, scenario,
              simulator: RaceSimulator(random: Random(seed))))!;
          expect(controller.error, isNull, reason: race.notes.join('\n'));

          // Bibs: the coach names the real runner behind a mistyped bib, and
          // says which finish a bib typed as another runner's belongs to.
          // Every finish keeps a runner — none is ever dropped.
          final truthRunners = [for (final f in race.answerKey) f.runner];
          if (controller.hasBibConflicts) {
            await controller.applyResolvedRunners(truthRunners);
          }
          expect(controller.error, isNull);
          expect(controller.raceRunners, truthRunners);

          // Timing.
          final truthTimes = [for (final f in race.answerKey) f.time];
          final chunks = controller.timingChunks!;
          final merge = MergeConflictsController(
            masterRace: masterRace,
            timingChunks: chunks,
            raceRunners: truthRunners,
            scheduler: _NoopScheduler(),
            recordedTimes: MergeConflictsController.recordedTimesOf(chunks),
          );
          merge.initState();
          await _resolveTiming(merge, truthTimes);
          expect(merge.hasConflicts, isFalse, reason: race.notes.join('\n'));
          controller.hasTimingConflicts = controller.containsTimingConflicts();

          expect(await controller.saveCurrentResults(), isNull,
              reason: race.notes.join('\n'));
          final saved = verify(masterRace.saveResults(captureAny))
              .captured
              .single as List<RaceResult>;
          expect(saved, hasLength(size));
          for (final f in race.answerKey) {
            final result = saved[f.place - 1];
            expect(result.place, f.place);
            expect(result.runner!.runnerId, f.runner.runner.runnerId);
            expect(result.finishTime,
                TimeFormatter.loadDurationFromString(f.time));
          }
        });
      }
    }
  }
}
