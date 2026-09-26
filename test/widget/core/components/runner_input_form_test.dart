import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/components/runner_input_form.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Giving a runner a bib someone else holds replaces that someone. The coach
// has to be told who, before saving.

const _eagles = Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG');

void main() {
  const alice = Runner(runnerId: 1, name: 'Alice', bibNumber: '101', grade: 10);
  const bob = Runner(runnerId: 2, name: 'Bob Smith', bibNumber: '102', grade: 11);

  Future<void> editAlice(WidgetTester tester,
      {Future<void> Function()? onRemove,
      void Function(RaceRunner)? onSubmit}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RunnerInputForm(
            raceId: 1,
            teamOptions: const [_eagles],
            initialRaceRunner:
                RaceRunner(raceId: 1, runner: alice, team: _eagles),
            submitButtonText: 'Save',
            onSubmit: (r) async => onSubmit?.call(r),
            onRemove: onRemove,
            useSheetLayout: false,
            getRunnerByBib: (bib) async => switch (bib) {
              '101' => alice,
              '102' => bob,
              _ => null,
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('names the runner whose bib it is', (tester) async {
    await editAlice(tester);

    await tester.enterText(find.widgetWithText(TextField, '101'), '102');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text("Bib 102 is Bob Smith's. Saving replaces Bob Smith with "
        'this runner.'), findsOneWidget);
  });

  testWidgets('says nothing for a bib nobody holds', (tester) async {
    await editAlice(tester);

    await tester.enterText(find.widgetWithText(TextField, '101'), '150');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('Saving replaces'), findsNothing);
  });

  testWidgets('has the same fields, in the same order, as Add Runner',
      (tester) async {
    await editAlice(tester);

    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(top('Name') < top('Bib #'), isTrue);
    expect(top('Bib #') < top('Grade'), isTrue);
    expect(top('Grade') < top('Team'), isTrue);
    // The grade as the four buttons, not a number box.
    for (final label in ['Fr', 'So', 'Jr', 'Sr']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('changes the grade with its buttons', (tester) async {
    RaceRunner? saved;
    await editAlice(tester, onSubmit: (r) => saved = r);

    await tester.tap(find.text('Sr'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved?.runner.grade, 12);
  });

  testWidgets('can remove the runner from the race', (tester) async {
    var removed = false;
    await editAlice(tester, onRemove: () async => removed = true);

    await tester.tap(find.byKey(const ValueKey('remove_runner_from_race')));
    await tester.pump();

    expect(removed, isTrue);
  });
}
