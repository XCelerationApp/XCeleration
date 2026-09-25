import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/coach/bib_conflict_resolution/controller/conflict_resolution_controller.dart';
import 'package:xceleration/coach/bib_conflict_resolution/model/bib_conflict.dart';
import 'package:xceleration/coach/bib_conflict_resolution/widgets/nearby_finishers_sheet.dart';
import 'package:xceleration/coach/bib_conflict_resolution/widgets/runner_assignment_list.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Find Runner: saying who really finished at a disputed place, by typing a
// name, and creating the runner if they are not on the roster.

const _eagles = Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG');

RaceRunner _runner(int id, String bib, String name) => RaceRunner(
      raceId: 1,
      runner: Runner(runnerId: id, name: name, bibNumber: bib, grade: 11),
      team: _eagles,
    );

final _john = _runner(1, '101', 'John Smith');
final _ava = _runner(2, '102', 'Ava Johnson');

void main() {
  late ConflictResolutionController controller;
  late List<String> created;
  late List<RaceRunner> assigned;

  Future<void> open(WidgetTester tester) async {
    created = [];
    assigned = [];
    controller = ConflictResolutionController(
      conflicts: const [
        UnknownBibConflict(
            bibNumber: '9567', occurrence: ConflictOccurrence(place: 3)),
      ],
      candidates: [_john, _ava],
      knownBibs: {'101', '102'},
      teams: const ['Eagles'],
      raceName: 'Invitational',
      createRunner: (_) async => Success(_john),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: controller,
          child: RunnerAssignmentList(
            targetBib: '9567',
            onAssign: (runner, _) => assigned.add(runner),
            onCreateNew: created.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(
        find.byKey(const ValueKey('find_runner_search')), text);
    await tester.pumpAndSettle();
  }

  testWidgets('finds a runner from a misspelt name', (tester) async {
    await open(tester);

    await type(tester, 'jonh smtih');

    expect(find.text('John Smith'), findsOneWidget);
    expect(find.text('Ava Johnson'), findsNothing);
  });

  testWidgets('selects a runner, and a second tap unselects them',
      (tester) async {
    await open(tester);

    await tester.tap(find.text('Ava Johnson'));
    await tester.pumpAndSettle();
    expect(find.text('Assign Ava Johnson →'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('Ava Johnson'));
    await tester.pumpAndSettle();
    expect(find.text('Assign Ava Johnson →'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('Clear unselects too', (tester) async {
    await open(tester);
    await tester.tap(find.text('Ava Johnson'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Assign Ava Johnson →'), findsNothing);
  });

  testWidgets('assigns the runner chosen', (tester) async {
    await open(tester);
    await tester.tap(find.text('John Smith'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assign John Smith →'));

    expect(assigned, [_john]);
  });

  testWidgets('offers to create a runner named from what was typed',
      (tester) async {
    await open(tester);

    await type(tester, 'Jane Doe');

    expect(find.textContaining('No runner on the roster matches'),
        findsOneWidget);
    await tester.tap(find.text('Create new runner "Jane Doe"'));
    expect(created, ['Jane Doe']);
  });

  testWidgets('with nothing typed, still offers to create a runner',
      (tester) async {
    await open(tester);

    await tester.tap(find.text('Not on the roster? Create a new runner'));

    expect(created, ['']);
  });

  testWidgets('the nearby sheet can show every finisher', (tester) async {
    const nearby = [
      NearbyFinisher(place: 2, name: 'Two', team: 'Eagles', bibNumber: '2'),
    ];
    final all = [
      for (var p = 1; p <= 12; p++)
        if (p != 3)
          NearbyFinisher(
              place: p, name: 'Runner $p', team: 'Eagles', bibNumber: '$p'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showNearbySheet(context,
                entries: nearby,
                allFinishers: all,
                conflictPosition: 3,
                conflictBib: '9567'),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Runner 12'), findsNothing);

    await tester.tap(find.text('Show all 11 finishers'));
    await tester.pumpAndSettle();

    expect(find.text('Runner 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Runner 12'), 100,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Runner 12'), findsOneWidget);
  });
}
