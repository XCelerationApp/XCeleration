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

// The Undo button on a conflict batch: it shows up once there is a press to
// take back, and taking it back puts the times on screen.

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

  /// A batch of three times for two runners: one of them is a stray tap.
  MergeConflictsController buildController() => MergeConflictsController(
        masterRace: MasterRace.getInstance(1),
        timingChunks: [
          TimingChunk(
            id: 0,
            timingData: [10, 11, 12]
                .map((s) => TimingDatum(time: _t(s)))
                .toList(),
            conflictRecord: TimingDatum(
              time: _t(13),
              conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
            ),
          )
        ],
        raceRunners: [_runner(1), _runner(2)],
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
  }

  testWidgets('is not offered before anything is pressed', (tester) async {
    await pumpList(tester, buildController());

    expect(find.text('Undo'), findsNothing);
    expect(find.text('Resolve Conflict'), findsOneWidget);
  });

  testWidgets('appears once a time has been removed', (tester) async {
    final controller = buildController();
    await pumpList(tester, controller);

    controller.removeExtraTimeRecord(0, 1);
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsOneWidget);
    expect(find.text(_t(11)), findsNothing, reason: 'the time is gone');
  });

  testWidgets('both buttons fit side by side on a phone', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = buildController();
    await pumpList(tester, controller);
    controller.removeExtraTimeRecord(0, 1);
    await tester.pumpAndSettle();

    // A RenderFlex overflow would fail the test here.
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Resolve Conflict'), findsOneWidget);
  });

  testWidgets('tapping it puts the removed time back on screen',
      (tester) async {
    final controller = buildController();
    await pumpList(tester, controller);
    controller.removeExtraTimeRecord(0, 1);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text(_t(11)), findsOneWidget, reason: 'the time is back');
    expect(find.text('Undo'), findsNothing,
        reason: 'nothing left to take back');
  });
}
