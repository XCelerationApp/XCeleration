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

// The hints on a timing conflict: the gap under each time, where the app
// thinks the problem is (only when it clearly stands out), and Best Guess.

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

  testWidgets('points to a gap that clearly stands out, and Best Guess '
      'fills it', (tester) async {
    // 10, 11, then nothing until 30: the missed runner came in the 19 s gap.
    final controller = build([10, 11, 30], 32, 4);
    await pumpList(tester, controller);

    expect(find.textContaining('Biggest gap: 19.0 s, just before 3rd place'),
        findsOneWidget);
    expect(find.text('+19.0 s'), findsOneWidget);
    expect(find.text('+1.0 s'), findsOneWidget);

    await tester.tap(find.text('Best Guess'));
    await tester.pumpAndSettle();

    expect(controller.uiChunks.single.records.map((r) => r.time),
        [_t(10), _t(11), '20.50', _t(30)]);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('says so when no gap stands out', (tester) async {
    final controller = build([5, 10, 15], 20, 4);
    await pumpList(tester, controller);

    expect(find.textContaining('No gap stands out'), findsOneWidget);
    expect(find.textContaining('Biggest gap'), findsNothing);
  });
}
