import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/widgets/chunk_list.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

// The hints on a timing conflict: the gap under each time, where Best Guess
// would put a missing time and why, and Best Guess itself.

class _NoopScheduler implements IPostFrameCallbackScheduler {
  @override
  void addPostFrameCallback(VoidCallback callback) {}
}

const _team = Team(teamId: 1, name: 'Eagles');

RaceRunner _runner(int n) => RaceRunner(
      raceId: 1,
      runner: Runner(runnerId: n, name: 'Runner $n', bibNumber: '$n', grade: 11),
      team: _team,
    );

String _t(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}.00';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(MasterRace.clearAllInstances);

  MergeConflictsController build(List<int> seconds, int end, int runners) =>
      MergeConflictsController(
        masterRace: MasterRace.getInstance(1),
        timingChunks: [
          TimingChunk(
            id: 0,
            timingData:
                seconds.map((s) => TimingDatum(time: _t(s))).toList(),
            conflictRecord: TimingDatum(
              time: _t(end),
              conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
            ),
          )
        ],
        raceRunners: [for (var i = 1; i <= runners; i++) _runner(i)],
        scheduler: _NoopScheduler(),
      );

  Future<void> pumpList(
      WidgetTester tester, MergeConflictsController controller) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChangeNotifierProvider.value(
            value: controller,
            child: const ChunkList(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('says where Best Guess would put the missing time, and '
      'Best Guess fills it', (tester) async {
    final controller = build([10, 11, 30], 32, 4);
    await pumpList(tester, controller);

    expect(
        find.textContaining('Best Guess puts it in the biggest gap (19.0 s, '
            'just before 3rd place), where a guess changes the results the '
            'least'),
        findsOneWidget);
    expect(find.text('+19.0 s'), findsOneWidget);
    expect(find.text('+1.0 s'), findsOneWidget);

    await tester.tap(find.text('Best Guess'));
    await tester.pumpAndSettle();

    expect(controller.uiChunks.single.records.map((r) => r.time),
        [_t(10), _t(11), '20.50', _t(30)]);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('never picks out a + as where the missed runner was',
      (tester) async {
    // However much one gap stands out, the runner could be anywhere.
    final controller = build([10, 11, 30], 32, 4);
    await pumpList(tester, controller);

    expect(find.byIcon(Icons.add_circle_outline), findsNWidgets(3));
    expect(find.byIcon(Icons.add_circle), findsNothing);
  });

  testWidgets('with two missing, Best Guess fills them one at a time',
      (tester) async {
    final controller = MergeConflictsController(
      masterRace: MasterRace.getInstance(1),
      timingChunks: [
        TimingChunk(
          id: 0,
          timingData: [for (final s in [10, 30]) TimingDatum(time: _t(s))],
          conflictRecord: TimingDatum(
            time: _t(40),
            conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
          ),
        )
      ],
      raceRunners: [for (var i = 1; i <= 4; i++) _runner(i)],
      scheduler: _NoopScheduler(),
    );
    await pumpList(tester, controller);
    expect(find.textContaining('Best Guess puts one in the biggest gap'),
        findsOneWidget);

    await tester.tap(find.text('Best Guess'));
    await tester.pumpAndSettle();
    expect(controller.uiChunks.single.records.map((r) => r.time),
        [_t(10), '20.00', _t(30), 'TBD']);

    await tester.tap(find.text('Best Guess'));
    await tester.pumpAndSettle();
    expect(controller.uiChunks.single.records.where((r) => r.isUnfilled),
        isEmpty);
    expect(controller.uiChunks.single.isResolvedLocally, isTrue);
  });

  testWidgets('in the last batch, says the runner may have come after the '
      'last time', (tester) async {
    final controller = MergeConflictsController(
      masterRace: MasterRace.getInstance(1),
      timingChunks: [
        TimingChunk(
          id: 0,
          timingData: [for (final s in [10, 11, 30]) TimingDatum(time: _t(s))],
          conflictRecord: TimingDatum(
            time: 'MISSING_TIMES',
            conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
          ),
        )
      ],
      raceRunners: [for (var i = 1; i <= 4; i++) _runner(i)],
      scheduler: _NoopScheduler(),
    );
    await pumpList(tester, controller);

    expect(find.textContaining('may also have finished after the last time'),
        findsOneWidget);
  });
}
