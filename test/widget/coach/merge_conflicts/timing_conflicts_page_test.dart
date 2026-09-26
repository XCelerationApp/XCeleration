import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/screen/timing_conflicts_page.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

// Timing conflicts open as a full page, like the bib conflicts before them:
// the same Back bar and progress, closing once all are resolved.

const _team = Team(teamId: 1, name: 'Eagles');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(MasterRace.clearAllInstances);

  testWidgets('shows the race and progress, and closes once resolved',
      (tester) async {
    final chunks = [
      TimingChunk(
        id: 0,
        timingData: [
          for (final t in ['0:10.00', '0:11.00', '0:12.00'])
            TimingDatum(time: t)
        ],
        conflictRecord: TimingDatum(
          time: '0:13.00',
          conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
        ),
      ),
    ];
    final runners = [
      for (var i = 1; i <= 2; i++)
        RaceRunner(
          raceId: 1,
          runner: Runner(runnerId: i, name: 'Runner $i', bibNumber: '$i'),
          team: _team,
        ),
    ];
    var closed = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => MergeConflictsController(
                    masterRace: MasterRace.getInstance(1),
                    timingChunks: chunks,
                    raceRunners: runners,
                  ),
                  child: TimingConflictsPage(
                    masterRace: MasterRace.getInstance(1),
                    timingChunks: chunks,
                    raceRunners: runners,
                    raceName: 'County Meet',
                    total: 1,
                  ),
                ),
              ));
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Timing Conflicts'), findsOneWidget);
    expect(find.text('County Meet'), findsOneWidget);
    expect(find.text('0 / 1 resolved'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Resolve Conflict'));
    await tester.tap(find.text('Resolve Conflict'));
    await tester.pumpAndSettle();

    expect(closed, isTrue, reason: 'the page closes once all are resolved');
  });
}
