import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/csv_utils.dart';

List<List<dynamic>> _parse(String csv) =>
    const CsvToListConverter().convert(csv);

void main() {
  group('CsvUtils.generateCsvContent', () {
    group('overall mode', () {
      test('produces correct headers', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [],
          individualResults: [],
        );
        final rows = _parse(csv);
        expect(rows.first, ['Place', 'Team', 'Score', 'Scorers', 'Times']);
      });

      test('produces one row per team result', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [
            {'place': 1, 'team': 'Eagles', 'score': 25, 'scorers': 'A,B', 'times': '16:00'},
            {'place': 2, 'team': 'Hawks', 'score': 40, 'scorers': 'C,D', 'times': '16:30'},
          ],
          individualResults: [],
        );
        final rows = _parse(csv);
        // header + 2 team rows + empty separator + "Individual Results" + individual header
        // CsvToListConverter re-parses numeric-looking strings back to ints
        expect(rows[1], [1, 'Eagles', 25, 'A,B', '16:00']);
        expect(rows[2], [2, 'Hawks', 40, 'C,D', '16:30']);
      });

      test('defaults null place, score, scorers, times to N/A', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [
            {'team': 'Eagles'},
          ],
          individualResults: [],
        );
        final rows = _parse(csv);
        expect(rows[1][0], 'N/A'); // place
        expect(rows[1][2], 'N/A'); // score
        expect(rows[1][3], 'N/A'); // scorers
        expect(rows[1][4], 'N/A'); // times
      });

      test('defaults null team name to Unknown Team', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [
            {'place': 1, 'score': 25},
          ],
          individualResults: [],
        );
        final rows = _parse(csv);
        expect(rows[1][1], 'Unknown Team');
      });
    });

    group('head-to-head mode', () {
      test('produces correct headers', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: true,
          teamResults: [],
          individualResults: [],
        );
        final rows = _parse(csv);
        expect(rows.first,
            ['Team 1', 'Score', 'Time', 'Team 2', 'Score', 'Time']);
      });

      test('produces one row per matchup', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: true,
          teamResults: [
            {
              'team1': {'team': 'Eagles', 'score': 15, 'times': '16:00'},
              'team2': {'team': 'Hawks', 'score': 40, 'times': '17:00'},
            },
          ],
          individualResults: [],
        );
        final rows = _parse(csv);
        // CsvToListConverter re-parses numeric-looking strings back to ints
        expect(rows[1],
            ['Eagles', 15, '16:00', 'Hawks', 40, '17:00']);
      });

      test('defaults null team1 and team2 to Unknown Team', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: true,
          teamResults: [
            {'team1': null, 'team2': null},
          ],
          individualResults: [],
        );
        final rows = _parse(csv);
        expect(rows[1][0], 'Unknown Team');
        expect(rows[1][3], 'Unknown Team');
      });

      test('defaults null score and times to N/A', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: true,
          teamResults: [
            {
              'team1': {'team': 'Eagles'},
              'team2': {'team': 'Hawks'},
            },
          ],
          individualResults: [],
        );
        final rows = _parse(csv);
        expect(rows[1][1], 'N/A'); // team1 score
        expect(rows[1][2], 'N/A'); // team1 times
        expect(rows[1][4], 'N/A'); // team2 score
        expect(rows[1][5], 'N/A'); // team2 times
      });
    });

    group('individual results section', () {
      test('always appends individual results header after team section', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [],
          individualResults: [],
        );
        final rows = _parse(csv);
        // row 0: team header, row 1: empty separator, row 2: ['Individual Results'], row 3: individual header
        expect(rows[2], ['Individual Results']);
        expect(rows[3],
            ['Place', 'Name', 'Grade', 'Team', 'Time', 'Bib Number']);
      });

      test('numbers individual results starting from 1', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [],
          individualResults: [
            {'name': 'Alice', 'grade': 10, 'team': 'Eagles', 'finish_time': '16:00', 'bib_number': '42'},
            {'name': 'Bob', 'grade': 11, 'team': 'Hawks', 'finish_time': '16:05', 'bib_number': '7'},
          ],
        );
        final rows = _parse(csv);
        // row 0: team header, row 1: empty, row 2: Individual Results, row 3: individual header
        // row 4: first runner, row 5: second runner
        // CsvToListConverter re-parses numeric-looking strings back to ints
        expect(rows[4][0], 1);
        expect(rows[5][0], 2);
      });

      test('writes all individual result fields correctly', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [],
          individualResults: [
            {'name': 'Alice', 'grade': 10, 'team': 'Eagles', 'finish_time': '16:00', 'bib_number': '42'},
          ],
        );
        final rows = _parse(csv);
        final runnerRow = rows[4];
        expect(runnerRow[1], 'Alice');
        expect(runnerRow[2], 10); // CsvToListConverter re-parses numeric strings
        expect(runnerRow[3], 'Eagles');
        expect(runnerRow[4], '16:00');
        expect(runnerRow[5], 42); // bib_number '42' → int 42
      });

      test('defaults null name to Unknown Runner', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [],
          individualResults: [
            {'grade': 10, 'team': 'Eagles', 'finish_time': '16:00', 'bib_number': '42'},
          ],
        );
        final rows = _parse(csv);
        expect(rows[4][1], 'Unknown Runner');
      });

      test('defaults null team to Unknown Team', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [],
          individualResults: [
            {'name': 'Alice'},
          ],
        );
        final rows = _parse(csv);
        expect(rows[4][3], 'Unknown Team');
      });

      test('defaults null grade, finish_time, bib_number to N/A', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [],
          individualResults: [
            {'name': 'Alice', 'team': 'Eagles'},
          ],
        );
        final rows = _parse(csv);
        expect(rows[4][2], 'N/A'); // grade
        expect(rows[4][4], 'N/A'); // finish_time
        expect(rows[4][5], 'N/A'); // bib_number
      });

      test('appends individual results in head-to-head mode too', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: true,
          teamResults: [],
          individualResults: [
            {'name': 'Alice', 'grade': 10, 'team': 'Eagles', 'finish_time': '16:00', 'bib_number': '42'},
          ],
        );
        final rows = _parse(csv);
        expect(rows[2], ['Individual Results']);
        expect(rows[4][1], 'Alice');
      });
    });
  });
}
