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

  testWidgets('Add & Next saves, then clears the form for the next runner',
      (tester) async {
    await pump(tester);
    await tester.enterText(field("Runner's full name"), 'Ann Lee');
    await tester.enterText(find.byType(TextFormField).at(1), '101');
    await tester.tap(find.text('So'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('add_and_next')));
    await tester.pumpAndSettle();

    expect(added.single.runner.name, 'Ann Lee');
    expect(find.text('Added Ann Lee. Next runner:'), findsOneWidget);
    expect(find.text('Ann Lee'), findsNothing, reason: 'the name is cleared');
    expect(find.text('101'), findsNothing, reason: 'the bib is cleared');
    expect(find.text('Please enter a name'), findsNothing,
        reason: 'no errors on the empty form');

    await tester.enterText(field("Runner's full name"), 'Bo Park');
    await tester.enterText(find.byType(TextFormField).at(1), '102');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('add_and_next')));
    await tester.pumpAndSettle();

    expect(added.map((r) => r.runner.name), ['Ann Lee', 'Bo Park']);
    expect(added.last.runner.grade, 10, reason: 'the grade stays picked');
  });

  testWidgets('a failed save keeps what was typed and says so',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AddRunnersToTeamSheet(
            team: const Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG'),
            raceId: 1,
            getRunnerByBib: (_) async => null,
            onSubmit: (_) async => throw Exception('disk full'),
          ),
        ),
      ),
    ));
    await tester.enterText(field("Runner's full name"), 'Ann Lee');
    await tester.enterText(find.byType(TextFormField).at(1), '101');
    await tester.tap(find.text('So'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('add_and_next')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not add the runner'), findsOneWidget);
    expect(find.text('Ann Lee'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });
}
