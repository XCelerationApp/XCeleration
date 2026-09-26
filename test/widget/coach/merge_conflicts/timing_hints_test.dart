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

// The hints on a timing conflict: the gap under each time, a likely stray
// tap for an extra time, and nothing pointing at where a missed runner was.

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

  testWidgets('a missing time shows the gaps, and points nowhere',
      (tester) async {
    // However much one gap stands out, the runner could be anywhere.
    final controller = build([10, 11, 30], 32, 4);
    await pumpList(tester, controller);

    expect(find.text('+19.0 s'), findsOneWidget);
    expect(find.text('+1.0 s'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsNWidgets(3));
    expect(find.byIcon(Icons.add_circle), findsNothing);
    expect(find.textContaining('biggest gap'), findsNothing);
    expect(find.text('Best Guess'), findsNothing);

    await tester.tap(find.text('How to decide'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ask the runners from 1st to 4th who finished '
        'right in front of them'), findsOneWidget);
    expect(find.textContaining("Don't go by the gaps alone"), findsOneWidget);
    expect(find.textContaining('Put the missing time where it seems most '
        'likely'), findsOneWidget);
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

  testWidgets('an extra time points to a likely double tap, and How to '
      'decide names the places to ask', (tester) async {
    final controller = MergeConflictsController(
      masterRace: MasterRace.getInstance(1),
      timingChunks: [
        TimingChunk(
          id: 0,
          timingData: [
            for (final t in ['0:10.00', '0:15.00', '0:15.30', '0:20.00'])
              TimingDatum(time: t)
          ],
          conflictRecord: TimingDatum(
            time: _t(25),
            conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
          ),
        )
      ],
      raceRunners: [for (var i = 1; i <= 3; i++) _runner(i)],
      scheduler: _NoopScheduler(),
    );
    await pumpList(tester, controller);

    expect(find.textContaining('like a double tap'), findsOneWidget);

    await tester.tap(find.text('How to decide'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ask the runners from 1st to 3rd'),
        findsOneWidget);
    expect(find.textContaining('Remove the second of the two closest'),
        findsOneWidget);
    expect(find.textContaining('Best Guess'), findsNothing);
  });
}
