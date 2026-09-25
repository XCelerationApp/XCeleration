import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/runners_management_screen/widgets/add_runners_to_team_sheet.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Adding one runner to a team by hand. Whatever is missing has to say so on
// the sheet itself.

void main() {
  late List<RaceRunner> added;

  Future<void> pump(WidgetTester tester) async {
    added = [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AddRunnersToTeamSheet(
            team: const Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG'),
            raceId: 1,
            getRunnerByBib: (_) async => null,
            onSubmit: (runner) async => added.add(runner),
          ),
        ),
      ),
    ));
  }

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  testWidgets('a missing grade is said on the sheet', (tester) async {
    await pump(tester);
    await tester.enterText(field("Runner's full name"), 'Ann Lee');
    await tester.enterText(find.byType(TextFormField).at(1), '101');
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Add Runner'));
    await tester.pumpAndSettle();

    expect(find.text('Please pick a grade'), findsOneWidget);
    expect(added, isEmpty);

    await tester.tap(find.text('Jr'));
    await tester.pumpAndSettle();
    expect(find.text('Please pick a grade'), findsNothing);

    await tester.tap(find.text('Add Runner'));
    await tester.pumpAndSettle();
    expect(added.single.runner.grade, 11);
  });

  testWidgets('a field error clears once the field is filled in',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Add Runner'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a name'), findsOneWidget);

    await tester.enterText(field("Runner's full name"), 'Ann Lee');
    await tester.pumpAndSettle();

    expect(find.text('Please enter a name'), findsNothing);
  });
}
