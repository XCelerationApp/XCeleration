import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/utils/connectivity_utils.dart';
import 'package:xceleration/core/utils/csv_utils.dart';
import 'package:xceleration/core/utils/date_format_utils.dart';

@GenerateMocks([Connectivity])
import 'core_utils_test.mocks.dart';

/// Builds a [DateTime] that is [days] calendar days from today,
/// using noon local time to stay clear of DST boundaries.
DateTime _daysFromNow(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, 12);
}

List<List<dynamic>> _parseCsv(String csv) =>
    const CsvToListConverter().convert(csv);

void main() {
  // ===========================================================================
  // DateFormatUtils
  // ===========================================================================
  group('DateFormatUtils.formatRelativeDate', () {
    test('returns "Today" for today', () {
      expect(DateFormatUtils.formatRelativeDate(_daysFromNow(0)), 'Today');
    });

    test('returns "Tomorrow" for one day ahead', () {
      expect(DateFormatUtils.formatRelativeDate(_daysFromNow(1)), 'Tomorrow');
    });

    test('returns "Yesterday" for one day ago', () {
      expect(DateFormatUtils.formatRelativeDate(_daysFromNow(-1)), 'Yesterday');
    });

    test('returns "In N days" for 2–7 days ahead', () {
      for (var i = 2; i <= 7; i++) {
        expect(
          DateFormatUtils.formatRelativeDate(_daysFromNow(i)),
          'In $i days',
          reason: 'failed for i=$i',
        );
      }
    });

    test('returns "N days ago" for 2–7 days in the past', () {
      for (var i = 2; i <= 7; i++) {
        expect(
          DateFormatUtils.formatRelativeDate(_daysFromNow(-i)),
          '$i days ago',
          reason: 'failed for i=$i',
        );
      }
    });

    test('returns M/D/YYYY for dates more than 7 days in the future', () {
      final date = DateTime(2030, 6, 15);
      expect(DateFormatUtils.formatRelativeDate(date), '6/15/2030');
    });

    test('returns M/D/YYYY for dates more than 7 days in the past', () {
      final date = DateTime(2020, 1, 5);
      expect(DateFormatUtils.formatRelativeDate(date), '1/5/2020');
    });
  });

  // ===========================================================================
  // CsvUtils
  // ===========================================================================
  group('CsvUtils.generateCsvContent', () {
    group('overall mode', () {
      test('produces correct headers', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [],
          individualResults: [],
        );
        final rows = _parseCsv(csv);
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
        final rows = _parseCsv(csv);
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
        final rows = _parseCsv(csv);
        expect(rows[1][0], 'N/A');
        expect(rows[1][2], 'N/A');
        expect(rows[1][3], 'N/A');
        expect(rows[1][4], 'N/A');
      });

      test('defaults null team name to Unknown Team', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [
            {'place': 1, 'score': 25},
          ],
          individualResults: [],
        );
        final rows = _parseCsv(csv);
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
        final rows = _parseCsv(csv);
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
        final rows = _parseCsv(csv);
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
        final rows = _parseCsv(csv);
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
        final rows = _parseCsv(csv);
        expect(rows[1][1], 'N/A');
        expect(rows[1][2], 'N/A');
        expect(rows[1][4], 'N/A');
        expect(rows[1][5], 'N/A');
      });
    });

    group('individual results section', () {
      test('always appends individual results header after team section', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [],
          individualResults: [],
        );
        final rows = _parseCsv(csv);
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
        final rows = _parseCsv(csv);
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
        final rows = _parseCsv(csv);
        final runnerRow = rows[4];
        expect(runnerRow[1], 'Alice');
        expect(runnerRow[2], 10);
        expect(runnerRow[3], 'Eagles');
        expect(runnerRow[4], '16:00');
        expect(runnerRow[5], 42);
      });

      test('defaults null name to Unknown Runner', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: false,
          teamResults: [],
          individualResults: [
            {'grade': 10, 'team': 'Eagles', 'finish_time': '16:00', 'bib_number': '42'},
          ],
        );
        final rows = _parseCsv(csv);
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
        final rows = _parseCsv(csv);
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
        final rows = _parseCsv(csv);
        expect(rows[4][2], 'N/A');
        expect(rows[4][4], 'N/A');
        expect(rows[4][5], 'N/A');
      });

      test('appends individual results in head-to-head mode too', () {
        final csv = CsvUtils.generateCsvContent(
          isHeadToHead: true,
          teamResults: [],
          individualResults: [
            {'name': 'Alice', 'grade': 10, 'team': 'Eagles', 'finish_time': '16:00', 'bib_number': '42'},
          ],
        );
        final rows = _parseCsv(csv);
        expect(rows[2], ['Individual Results']);
        expect(rows[4][1], 'Alice');
      });
    });
  });

  // ===========================================================================
  // ConnectivityUtils
  // ===========================================================================
  group('ConnectivityUtils', () {
    late MockConnectivity mockConnectivity;

    setUp(() {
      mockConnectivity = MockConnectivity();
    });

    group('isOnline', () {
      test('returns true when results contain wifi', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);

        final result =
            await ConnectivityUtils.isOnline(connectivity: mockConnectivity);

        expect(result, isTrue);
      });

      test('returns true when results contain mobile', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);

        final result =
            await ConnectivityUtils.isOnline(connectivity: mockConnectivity);

        expect(result, isTrue);
      });

      test('returns true when results contain multiple connections', () async {
        when(mockConnectivity.checkConnectivity()).thenAnswer(
            (_) async => [ConnectivityResult.wifi, ConnectivityResult.mobile]);

        final result =
            await ConnectivityUtils.isOnline(connectivity: mockConnectivity);

        expect(result, isTrue);
      });

      test('returns false when results contain only none', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.none]);

        final result =
            await ConnectivityUtils.isOnline(connectivity: mockConnectivity);

        expect(result, isFalse);
      });

      test('returns false and does not throw when connectivity throws', () async {
        when(mockConnectivity.checkConnectivity())
            .thenThrow(Exception('platform error'));

        final result =
            await ConnectivityUtils.isOnline(connectivity: mockConnectivity);

        expect(result, isFalse);
      });
    });
  });
}
