import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/race_results/edit/edit_results_controller.dart';
import 'package:xceleration/coach/race_results/edit/edit_results_screen.dart';
import 'package:xceleration/shared/models/database/race_result.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Correcting a finished race on screen, the way a coach would: tap a finish,
// fix it, save.

const _eagles = Team(teamId: 1, name: 'Eagles');

RaceRunner _runner(int id, String name) => RaceRunner(
      raceId: 7,
      runner: Runner(runnerId: id, name: name, bibNumber: '${100 + id}', grade: 10),
      team: _eagles,
    );

final _ann = _runner(1, 'Ann');
final _bo = _runner(2, 'Bo');
final _di = _runner(4, 'Di Walker');

void main() {
  List<RaceResult>? saved;
  bool? popped;

  Future<void> open(WidgetTester tester) async {
    saved = null;
    popped = null;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EditResultsScreen(
                    create: () => EditResultsController(
                      raceId: 7,
                      results: [
                        RaceResult(raceId: 7, runner: _ann.runner, team: _eagles,
                            place: 1, finishTime: const Duration(minutes: 15)),
                        RaceResult(raceId: 7, runner: _bo.runner, team: _eagles,
                            place: 2,
                            finishTime: const Duration(minutes: 15, seconds: 20)),
                      ],
                      raceRunners: [_ann, _bo, _di],
                      save: (results) async => saved = results,
                    ),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  List<String> savedNames() => [for (final r in saved!) r.runner!.name!];

  testWidgets('a finish can go to the runner it really was', (tester) async {
    await open(tester);

    await tester.tap(find.text('Bo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change Runner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'walker');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Di Walker'));
    await tester.pumpAndSettle();

    expect(find.text('Di Walker'), findsOneWidget);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(savedNames(), ['Ann', 'Di Walker']);
    expect(popped, isTrue);
  });

  testWidgets('a time out of order is refused on the spot', (tester) async {
    await open(tester);

    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change Time'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '15:30.00');
    await tester.tap(find.text('Save Time'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no later than 2nd place'), findsOneWidget);
  });

  testWidgets('a finish can be taken out, and undone', (tester) async {
    await open(tester);

    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Out of Results'));
    await tester.pumpAndSettle();
    expect(find.text('Ann'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Ann'), findsOneWidget);
  });

  testWidgets('leaving with changes asks first', (tester) async {
    await open(tester);
    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Out of Results'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Discard Changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(popped, isFalse);
    expect(saved, isNull);
  });

  testWidgets('Save is off until something changes', (tester) async {
    await open(tester);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(saved, isNull);
  });
}
