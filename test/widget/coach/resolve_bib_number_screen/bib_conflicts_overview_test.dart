import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/resolve_bib_number_screen/widgets/bib_conflicts_overview.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

@GenerateMocks([MasterRace])
import 'bib_conflicts_overview_test.mocks.dart';

RaceRunner _runner(int n) => RaceRunner(
      raceId: 1,
      runner: Runner(runnerId: n, name: 'Runner $n', bibNumber: '$n', grade: 10),
      team: const Team(teamId: 1, name: 'Eagles'),
    );

void main() {
  late MockMasterRace masterRace;

  setUp(() {
    masterRace = MockMasterRace();
    when(masterRace.raceId).thenReturn(1);
  });

  testWidgets(
      'lists unknown and duplicate bibs together, with the right places',
      (tester) async {
    // Finish order: runner 1, an unknown bib 99, then bib 1 again.
    when(masterRace.getRaceRunnerByBib('1'))
        .thenAnswer((_) async => _runner(1));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BibConflictsOverview(
          masterRace: masterRace,
          raceRunners: [_runner(1), '99', '1'],
          onResolved: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // This used to throw a RangeError: the duplicate's place was looked up
    // by its row in the list, which counts the unknown bibs too.
    expect(tester.takeException(), isNull);
    expect(find.text('2 Unfound Bib Numbers'), findsOneWidget);
    expect(find.text('#99'), findsOneWidget);
    expect(find.text('Duplicate Bib Number'), findsOneWidget);
    // The duplicate finished third.
    expect(find.text('3.'), findsOneWidget);
    // Every conflict says which finish it is, unknown bibs included.
    expect(find.text('2.'), findsOneWidget);
  });

  testWidgets('shows the finish time of the place being resolved',
      (tester) async {
    when(masterRace.getRaceRunnerByBib('1'))
        .thenAnswer((_) async => _runner(1));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BibConflictsOverview(
          masterRace: masterRace,
          raceRunners: [_runner(1), '99', '1'],
          onResolved: (_) {},
          timesByPlace: const {1: '15:01.20', 2: '15:04.80', 3: '15:09.10'},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Without the time the coach is asked who finished here with nothing to
    // go on but the bib number, which is the thing that is wrong.
    expect(find.text('15:04.80'), findsOneWidget);
    expect(find.text('15:09.10'), findsOneWidget);
  });

  testWidgets('says so when the Timer has not settled that place yet',
      (tester) async {
    when(masterRace.getRaceRunnerByBib('1'))
        .thenAnswer((_) async => _runner(1));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BibConflictsOverview(
          masterRace: masterRace,
          raceRunners: [_runner(1), '99', '1'],
          onResolved: (_) {},
          // The Timer flagged the stretch these two finished in.
          timesByPlace: const {1: '15:01.20'},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Time not settled yet'), findsNWidgets(2),
        reason: 'better than showing a time that may belong to someone else');
  });
}
