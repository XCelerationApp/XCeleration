import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/race_results/model/results_record.dart';
import 'package:xceleration/coach/race_results/model/team_record.dart';
import 'package:xceleration/coach/race_results/widgets/collapsible_results_widget.dart';
import 'package:xceleration/shared/models/database/race_result.dart';
import 'package:xceleration/shared/models/database/team.dart';

ResultsRecord _result(int place, String name, String team, Duration time) {
  return ResultsRecord(
    place: place,
    name: name,
    team: team,
    teamAbbreviation: team,
    grade: 11,
    bib: '$place',
    raceId: 1,
    runnerId: place,
    finishTime: time,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('CollapsibleResultsWidget', () {
    group('with individual results', () {
      testWidgets('renders no-results text when list is empty', (tester) async {
        await tester.pumpWidget(_wrap(
          const CollapsibleResultsWidget(results: []),
        ));

        expect(find.text('No results to display'), findsOneWidget);
      });

      testWidgets('displays place, name, and team columns', (tester) async {
        final results = [
          _result(
              1, 'Alice Smith', 'EA', const Duration(minutes: 18, seconds: 30)),
        ];

        await tester
            .pumpWidget(_wrap(CollapsibleResultsWidget(results: results)));

        expect(find.text('1'), findsOneWidget);
        expect(find.text('Alice Smith'), findsOneWidget);
        expect(find.text('EA'), findsOneWidget);
      });

      testWidgets(
          'shows "See More" button when results exceed initialVisibleCount',
          (tester) async {
        final results = List.generate(
          7,
          (i) => _result(
              i + 1, 'Runner ${i + 1}', 'EA', Duration(minutes: 18 + i)),
        );

        await tester
            .pumpWidget(_wrap(CollapsibleResultsWidget(results: results)));

        expect(find.text('See More'), findsOneWidget);
      });

      testWidgets(
          'does not show "See More" when results fit within initialVisibleCount',
          (tester) async {
        final results = List.generate(
          3,
          (i) => _result(
              i + 1, 'Runner ${i + 1}', 'EA', Duration(minutes: i + 18)),
        );

        await tester
            .pumpWidget(_wrap(CollapsibleResultsWidget(results: results)));

        expect(find.text('See More'), findsNothing);
      });

      testWidgets('tapping "See More" expands list and shows "See Less"',
          (tester) async {
        final results = List.generate(
          7,
          (i) => _result(
              i + 1, 'Runner ${i + 1}', 'EA', Duration(minutes: 18 + i)),
        );

        await tester
            .pumpWidget(_wrap(CollapsibleResultsWidget(results: results)));

        await tester.tap(find.text('See More'));
        await tester.pump();

        expect(find.text('See Less'), findsOneWidget);
        expect(find.text('See More'), findsNothing);
      });

      testWidgets('tapping "See Less" collapses the list', (tester) async {
        final results = List.generate(
          7,
          (i) => _result(
              i + 1, 'Runner ${i + 1}', 'EA', Duration(minutes: 18 + i)),
        );

        await tester
            .pumpWidget(_wrap(CollapsibleResultsWidget(results: results)));

        await tester.tap(find.text('See More'));
        await tester.pump();
        await tester.tap(find.text('See Less'));
        await tester.pump();

        expect(find.text('See More'), findsOneWidget);
      });

      testWidgets('truncates names longer than 18 characters', (tester) async {
        final results = [
          _result(1, 'Bartholomew McAllister', 'EA',
              const Duration(minutes: 18)),
        ];

        await tester
            .pumpWidget(_wrap(CollapsibleResultsWidget(results: results)));

        expect(find.text('Bartholomew McAlli...'), findsOneWidget);
        expect(find.text('Bartholomew McAllister'), findsNothing);
      });
    });

    group('with team results', () {
      TeamRecord buildTeamRecord(String abbrev, int place) {
        final team = Team(teamId: place, name: abbrev, abbreviation: abbrev);
        final runner = RaceResult(
          raceId: 1,
          place: place,
          finishTime: Duration(minutes: 18 + place),
        );
        return TeamRecord(
          team: team,
          runners: List.generate(5, (_) => runner),
          place: place,
        );
      }

      testWidgets('displays team header columns', (tester) async {
        final results = [buildTeamRecord('EA', 1)];

        await tester
            .pumpWidget(_wrap(CollapsibleResultsWidget(results: results)));

        expect(find.text('Team'), findsOneWidget);
        expect(find.text('Scorers'), findsOneWidget);
        expect(find.text('Score'), findsOneWidget);
      });

      testWidgets('displays team abbreviation in result row', (tester) async {
        final results = [buildTeamRecord('EA', 1)];

        await tester
            .pumpWidget(_wrap(CollapsibleResultsWidget(results: results)));

        expect(find.text('EA'), findsWidgets);
      });
    });
  });
}
