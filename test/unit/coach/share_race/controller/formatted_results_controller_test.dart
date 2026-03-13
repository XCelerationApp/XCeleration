import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/race_results/model/results_record.dart';
import 'package:xceleration/coach/race_results/model/team_record.dart';
import 'package:xceleration/coach/share_race/controller/share_race_controller.dart';
import 'package:xceleration/shared/models/database/race_result.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/services/race_results_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RaceResultsData _emptyData() => const RaceResultsData(
      resultsTitle: 'Test Race',
      individualResults: [],
      overallTeamResults: [],
      headToHeadTeamResults: [],
    );

ResultsRecord _individualRunner({
  required int place,
  required String name,
  required String abbrev,
  Duration? pace,
}) =>
    ResultsRecord(
      place: place,
      name: name,
      team: 'Team',
      teamAbbreviation: abbrev,
      grade: 11,
      bib: '$place',
      raceId: 1,
      runnerId: place,
      finishTime: Duration(minutes: 15 + place, seconds: place * 5 % 60),
      pacePerMile: pace,
    );

RaceResult _raceResult({
  required int id,
  required String name,
  required Team team,
  required int place,
  required Duration finishTime,
}) =>
    RaceResult(
      raceId: 1,
      runner: Runner(runnerId: id, name: name),
      team: team,
      place: place,
      finishTime: finishTime,
    );

/// Builds a [TeamRecord] with [count] runners. Runners have sequential places
/// starting from [startPlace] and finish times starting at [baseMinutes].
TeamRecord _teamRecord({
  required Team team,
  required int count,
  int startPlace = 1,
  int baseMinutes = 15,
}) {
  final runners = List.generate(
    count,
    (i) => _raceResult(
      id: startPlace + i,
      name: '${team.name} Runner ${i + 1}',
      team: team,
      place: startPlace + i,
      finishTime: Duration(minutes: baseMinutes + i, seconds: 30),
    ),
  );
  return TeamRecord(team: team, runners: runners);
}

final _eagles = const Team(teamId: 1, name: 'Eagles', abbreviation: 'EGL');
final _falcons = const Team(teamId: 2, name: 'Falcons', abbreviation: 'FAL');

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FormattedResultsController', () {
    // -----------------------------------------------------------------------
    // _getFormattedText (accessed via formattedResultsText)
    // -----------------------------------------------------------------------
    group('formattedResultsText', () {
      test('individual results section is always present', () async {
        final controller =
            FormattedResultsController(raceResultsData: _emptyData());

        final text = await controller.formattedResultsText;

        expect(text, contains('Individual Results'));
      });

      test('individual results header row is present', () async {
        final controller =
            FormattedResultsController(raceResultsData: _emptyData());

        final text = await controller.formattedResultsText;

        expect(text, contains('Place\tNameTeam\tTime\tPace/mi'));
      });

      test('each runner appears in the individual results section', () async {
        final data = RaceResultsData(
          resultsTitle: 'State Meet',
          individualResults: [
            _individualRunner(place: 1, name: 'Alice', abbrev: 'EGL'),
            _individualRunner(place: 2, name: 'Bob', abbrev: 'FAL'),
          ],
          overallTeamResults: [],
          headToHeadTeamResults: [],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final text = await controller.formattedResultsText;

        expect(text, contains('Alice'));
        expect(text, contains('EGL'));
        expect(text, contains('Bob'));
        expect(text, contains('FAL'));
      });

      test('head-to-head section absent when no matchups', () async {
        final controller =
            FormattedResultsController(raceResultsData: _emptyData());

        final text = await controller.formattedResultsText;

        expect(text, isNot(contains('Head-to-Head Team Results')));
      });

      test('head-to-head section present when matchups exist', () async {
        final team1 = _teamRecord(team: _eagles, count: 5, startPlace: 1);
        final team2 = _teamRecord(team: _falcons, count: 5, startPlace: 6);
        final data = RaceResultsData(
          resultsTitle: 'District Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [
            [team1, team2]
          ],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final text = await controller.formattedResultsText;

        expect(text, contains('Head-to-Head Team Results'));
        expect(text, contains('Eagles vs Falcons'));
      });

      test('head-to-head matchup lists runner names and times', () async {
        final team1 = _teamRecord(team: _eagles, count: 5, startPlace: 1);
        final team2 = _teamRecord(team: _falcons, count: 5, startPlace: 6);
        final data = RaceResultsData(
          resultsTitle: 'District Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [
            [team1, team2]
          ],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final text = await controller.formattedResultsText;

        expect(text, contains('Eagles Runner 1'));
        expect(text, contains('Falcons Runner 1'));
      });

      test('score of 0 is rendered as N/A in head-to-head text', () async {
        // A team with fewer than 5 runners gets score = 0
        final team1 = _teamRecord(team: _eagles, count: 3, startPlace: 1);
        final team2 = _teamRecord(team: _falcons, count: 3, startPlace: 4);

        expect(team1.score, equals(0));

        final data = RaceResultsData(
          resultsTitle: 'Small Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [
            [team1, team2]
          ],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final text = await controller.formattedResultsText;

        // Both teams have score = 0 → both should show N/A
        expect(text, contains('N/A'));
        // The score line should not contain a bare '0'
        final scoreLine =
            text.split('\n').firstWhere((l) => l.startsWith('Score:'));
        expect(scoreLine, isNot(matches(RegExp(r'Score:\s*\t\d'))));
        expect(scoreLine, contains('N/A'));
      });

      test('positive score is rendered as a number in head-to-head text',
          () async {
        final team1 = _teamRecord(team: _eagles, count: 5, startPlace: 1);
        final team2 = _teamRecord(team: _falcons, count: 5, startPlace: 6);

        // score = sum of places for top 5 runners
        expect(team1.score, equals(1 + 2 + 3 + 4 + 5));

        final data = RaceResultsData(
          resultsTitle: 'Full Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [
            [team1, team2]
          ],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final text = await controller.formattedResultsText;

        expect(text, contains('15')); // eagles score
        expect(text, isNot(contains('N/A')));
      });
    });

    // -----------------------------------------------------------------------
    // _getSheetsData (accessed via formattedSheetsData)
    // -----------------------------------------------------------------------
    group('formattedSheetsData', () {
      test('individual results section header row is present', () async {
        final controller =
            FormattedResultsController(raceResultsData: _emptyData());

        final sheets = await controller.formattedSheetsData;

        expect(
          sheets.any((row) => row.length == 1 && row[0] == 'Individual Results'),
          isTrue,
        );
      });

      test('individual results column headers are present', () async {
        final controller =
            FormattedResultsController(raceResultsData: _emptyData());

        final sheets = await controller.formattedSheetsData;

        expect(
          sheets.any((row) =>
              row.length == 5 &&
              row[0] == 'Place' &&
              row[1] == 'Name' &&
              row[2] == 'Team' &&
              row[3] == 'Time' &&
              row[4] == 'Pace/mi'),
          isTrue,
        );
      });

      test('runner data rows are present in individual results', () async {
        final data = RaceResultsData(
          resultsTitle: 'District Meet',
          individualResults: [
            _individualRunner(place: 1, name: 'Alice', abbrev: 'EGL'),
            _individualRunner(place: 2, name: 'Bob', abbrev: 'FAL'),
          ],
          overallTeamResults: [],
          headToHeadTeamResults: [],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final sheets = await controller.formattedSheetsData;

        final aliceRow = sheets.firstWhere(
          (row) => row.length >= 2 && row[1] == 'Alice',
          orElse: () => [],
        );
        expect(aliceRow, isNotEmpty);
        expect(aliceRow[0], equals(1));
        expect(aliceRow[2], equals('EGL'));
      });

      test('no head-to-head rows when matchups list is empty', () async {
        final controller =
            FormattedResultsController(raceResultsData: _emptyData());

        final sheets = await controller.formattedSheetsData;

        for (final row in sheets) {
          for (final cell in row) {
            expect(cell.toString(), isNot(contains(' vs ')));
          }
        }
      });

      test('matchup header row contains team names joined with vs', () async {
        final team1 = _teamRecord(team: _eagles, count: 5, startPlace: 1);
        final team2 = _teamRecord(team: _falcons, count: 5, startPlace: 6);
        final data = RaceResultsData(
          resultsTitle: 'District Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [
            [team1, team2]
          ],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final sheets = await controller.formattedSheetsData;

        final headerRow = sheets.firstWhere(
          (row) => row.isNotEmpty && row[0].toString().contains(' vs '),
          orElse: () => [],
        );
        expect(headerRow, isNotEmpty);
        expect(headerRow[0], equals('Eagles vs Falcons'));
      });

      test('column header row contains team names', () async {
        final team1 = _teamRecord(team: _eagles, count: 5, startPlace: 1);
        final team2 = _teamRecord(team: _falcons, count: 5, startPlace: 6);
        final data = RaceResultsData(
          resultsTitle: 'District Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [
            [team1, team2]
          ],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final sheets = await controller.formattedSheetsData;

        final colHeaders = sheets.firstWhere(
          (row) =>
              row.length == 3 &&
              row[0] == '' &&
              row[1] == 'Eagles' &&
              row[2] == 'Falcons',
          orElse: () => [],
        );
        expect(colHeaders, isNotEmpty);
      });

      test('runner rows contain name and place for both teams', () async {
        final team1 = _teamRecord(team: _eagles, count: 5, startPlace: 1);
        final team2 = _teamRecord(team: _falcons, count: 5, startPlace: 6);
        final data = RaceResultsData(
          resultsTitle: 'District Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [
            [team1, team2]
          ],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final sheets = await controller.formattedSheetsData;

        // First runner row should be '1' in column 0
        final firstRunnerRow = sheets.firstWhere(
          (row) => row.length == 3 && row[0] == '1',
          orElse: () => [],
        );
        expect(firstRunnerRow, isNotEmpty);
        expect(firstRunnerRow[1].toString(), contains('Eagles Runner 1'));
        expect(firstRunnerRow[2].toString(), contains('Falcons Runner 1'));
      });

      test('score summary row is always appended after runner rows', () async {
        final team1 = _teamRecord(team: _eagles, count: 5, startPlace: 1);
        final team2 = _teamRecord(team: _falcons, count: 5, startPlace: 6);
        final data = RaceResultsData(
          resultsTitle: 'District Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [
            [team1, team2]
          ],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final sheets = await controller.formattedSheetsData;

        final summaryRow = sheets.firstWhere(
          (row) => row.length == 3 && row[0] == 'Score',
          orElse: () => [],
        );
        expect(summaryRow, isNotEmpty);
        // Eagles score = 1+2+3+4+5 = 15, Falcons score = 6+7+8+9+10 = 40
        expect(summaryRow[1], equals('15'));
        expect(summaryRow[2], equals('40'));
      });

      test('score of 0 shown as N/A in summary row', () async {
        // Teams with < 5 runners have score = 0
        final team1 = _teamRecord(team: _eagles, count: 3, startPlace: 1);
        final team2 = _teamRecord(team: _falcons, count: 3, startPlace: 4);
        final data = RaceResultsData(
          resultsTitle: 'Small Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [
            [team1, team2]
          ],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final sheets = await controller.formattedSheetsData;

        final summaryRow = sheets.firstWhere(
          (row) => row.length == 3 && row[0] == 'Score',
          orElse: () => [],
        );
        expect(summaryRow, isNotEmpty);
        expect(summaryRow[1], equals('N/A'));
        expect(summaryRow[2], equals('N/A'));
      });

      test('mixed-length rosters: shorter team produces empty cells', () async {
        // team1 has 2 runners, team2 has 4 runners
        final team1 = _teamRecord(team: _eagles, count: 2, startPlace: 1);
        final team2 = _teamRecord(team: _falcons, count: 4, startPlace: 3);
        final data = RaceResultsData(
          resultsTitle: 'Mixed Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [
            [team1, team2]
          ],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final sheets = await controller.formattedSheetsData;

        // There should be 4 runner rows (max of 2 and 4)
        final runnerRows = sheets
            .where((row) =>
                row.length == 3 &&
                row[0] != '' &&
                row[0] != 'Score' &&
                (int.tryParse(row[0].toString()) != null))
            .toList();
        expect(runnerRows.length, equals(4));

        // Rows 3 and 4 (index 2 and 3) should have empty team1 cell
        final row3 = runnerRows[2];
        final row4 = runnerRows[3];
        expect(row3[1], equals(''));
        expect(row4[1], equals(''));

        // But team2 cells for rows 3 and 4 should be non-empty
        expect(row3[2], isNot(equals('')));
        expect(row4[2], isNot(equals('')));
      });

      test('empty row is appended after each matchup as spacing', () async {
        final team1 = _teamRecord(team: _eagles, count: 5, startPlace: 1);
        final team2 = _teamRecord(team: _falcons, count: 5, startPlace: 6);
        final data = RaceResultsData(
          resultsTitle: 'District Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [
            [team1, team2]
          ],
        );
        final controller = FormattedResultsController(raceResultsData: data);

        final sheets = await controller.formattedSheetsData;

        // There should be at least one empty row (spacing between matchup and individual results)
        expect(sheets.any((row) => row.isEmpty), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // Lazy caching
    // -----------------------------------------------------------------------
    group('lazy caching', () {
      test('formattedResultsText returns identical cached value on second call',
          () async {
        final controller =
            FormattedResultsController(raceResultsData: _emptyData());

        final first = await controller.formattedResultsText;
        final second = await controller.formattedResultsText;

        expect(identical(first, second), isTrue);
      });

      test('formattedSheetsData returns identical cached value on second call',
          () async {
        final controller =
            FormattedResultsController(raceResultsData: _emptyData());

        final first = await controller.formattedSheetsData;
        final second = await controller.formattedSheetsData;

        expect(identical(first, second), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // Concurrent call deduplication
    // -----------------------------------------------------------------------
    group('concurrent call deduplication', () {
      test(
          'two simultaneous formattedResultsText calls both resolve to the same value',
          () async {
        final controller =
            FormattedResultsController(raceResultsData: _emptyData());

        // Start both calls without awaiting — they run concurrently
        final future1 = controller.formattedResultsText;
        final future2 = controller.formattedResultsText;

        final results = await Future.wait([future1, future2]);

        expect(results[0], equals(results[1]));
        expect(identical(results[0], results[1]), isTrue);
      });

      test(
          'two simultaneous formattedSheetsData calls both resolve to the same value',
          () async {
        final controller =
            FormattedResultsController(raceResultsData: _emptyData());

        final future1 = controller.formattedSheetsData;
        final future2 = controller.formattedSheetsData;

        final results = await Future.wait([future1, future2]);

        expect(results[0], equals(results[1]));
        expect(identical(results[0], results[1]), isTrue);
      });
    });
  });
}
