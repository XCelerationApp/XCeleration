import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/race_results/model/results_record.dart';
import 'package:xceleration/coach/share_race/controller/share_race_controller.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/services/race_results_service.dart';

@GenerateMocks([ShareResultsController, MasterRace, BuildContext])
import 'share_race_controller_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RaceResultsData _emptyData() => RaceResultsData(
      resultsTitle: 'Test Race',
      individualResults: [],
      overallTeamResults: [],
      headToHeadTeamResults: [],
    );

ResultsRecord _runner({
  required int place,
  required String name,
  required String team,
  required String abbrev,
  required Duration finishTime,
  Duration? pace,
}) =>
    ResultsRecord(
      place: place,
      name: name,
      team: team,
      teamAbbreviation: abbrev,
      grade: 11,
      bib: '$place',
      raceId: 1,
      runnerId: place,
      finishTime: finishTime,
      pacePerMile: pace,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FormattedResultsController', () {
    group('formattedResultsText', () {
      test('returns individual results section with no runners', () async {
        final controller = FormattedResultsController(raceResultsData: _emptyData());

        final text = await controller.formattedResultsText;

        expect(text, contains('Individual Results'));
        expect(text, contains('Place\tNameTeam\tTime\tPace/mi'));
      });

      test('includes each runner in individual results section', () async {
        final data = RaceResultsData(
          resultsTitle: 'State Meet',
          individualResults: [
            _runner(
              place: 1,
              name: 'Alice',
              team: 'Eagles',
              abbrev: 'EGL',
              finishTime: const Duration(minutes: 16, seconds: 30),
            ),
            _runner(
              place: 2,
              name: 'Bob',
              team: 'Falcons',
              abbrev: 'FAL',
              finishTime: const Duration(minutes: 17, seconds: 0),
            ),
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

      test('does not include head-to-head section when no matchups', () async {
        final controller = FormattedResultsController(raceResultsData: _emptyData());

        final text = await controller.formattedResultsText;

        expect(text, isNot(contains('Head-to-Head Team Results')));
      });

      test('returns same cached value on second call', () async {
        final controller = FormattedResultsController(raceResultsData: _emptyData());

        final first = await controller.formattedResultsText;
        final second = await controller.formattedResultsText;

        expect(identical(first, second), isTrue);
      });
    });

    group('formattedSheetsData', () {
      test('returns individual results section rows', () async {
        final data = RaceResultsData(
          resultsTitle: 'District Meet',
          individualResults: [
            _runner(
              place: 1,
              name: 'Alice',
              team: 'Eagles',
              abbrev: 'EGL',
              finishTime: const Duration(minutes: 16, seconds: 30),
            ),
          ],
          overallTeamResults: [],
          headToHeadTeamResults: [],
        );

        final controller = FormattedResultsController(raceResultsData: data);
        final sheets = await controller.formattedSheetsData;

        // Must contain the section header row and column header row
        expect(
          sheets.any((row) => row.length == 1 && row[0] == 'Individual Results'),
          isTrue,
        );
        expect(
          sheets.any((row) =>
              row.length == 5 &&
              row[0] == 'Place' &&
              row[1] == 'Name' &&
              row[2] == 'Team'),
          isTrue,
        );

        // Find the data row for Alice
        final runnerRow = sheets.firstWhere(
          (row) => row.length >= 2 && row[1] == 'Alice',
          orElse: () => [],
        );
        expect(runnerRow, isNotEmpty);
        expect(runnerRow[0], 1); // place
        expect(runnerRow[2], 'EGL'); // team abbreviation
      });

      test('returns no head-to-head rows when no matchups', () async {
        final controller = FormattedResultsController(raceResultsData: _emptyData());
        final sheets = await controller.formattedSheetsData;

        // None of the rows should contain 'vs'
        for (final row in sheets) {
          for (final cell in row) {
            expect(cell.toString(), isNot(contains(' vs ')));
          }
        }
      });

      test('returns same cached value on second call', () async {
        final controller = FormattedResultsController(raceResultsData: _emptyData());

        final first = await controller.formattedSheetsData;
        final second = await controller.formattedSheetsData;

        expect(identical(first, second), isTrue);
      });
    });
  });

  group('ShareRaceController', () {
    late MockShareResultsController mockShareResultsController;
    late MockMasterRace mockMasterRace;
    late MockBuildContext mockContext;
    late ShareRaceController controller;

    setUp(() {
      mockShareResultsController = MockShareResultsController();
      mockMasterRace = MockMasterRace();
      mockContext = MockBuildContext();

      controller = ShareRaceController(
        raceResultsData: _emptyData(),
        masterRace: mockMasterRace,
        shareResultsController: mockShareResultsController,
      );

      // Default stub: all handle* methods complete normally
      when(mockShareResultsController.handlePlainTextCopy(any))
          .thenAnswer((_) async {});
      when(mockShareResultsController.handleGoogleSheet(any))
          .thenAnswer((_) async {});
      when(mockShareResultsController.handlePdf(any))
          .thenAnswer((_) async {});
    });

    group('shareResults', () {
      test('routes plainText to handlePlainTextCopy', () async {
        await controller.shareResults(mockContext, ResultFormat.plainText);

        verify(mockShareResultsController.handlePlainTextCopy(mockContext)).called(1);
        verifyNever(mockShareResultsController.handleGoogleSheet(any));
        verifyNever(mockShareResultsController.handlePdf(any));
      });

      test('routes googleSheet to handleGoogleSheet', () async {
        await controller.shareResults(mockContext, ResultFormat.googleSheet);

        verify(mockShareResultsController.handleGoogleSheet(mockContext)).called(1);
        verifyNever(mockShareResultsController.handlePlainTextCopy(any));
        verifyNever(mockShareResultsController.handlePdf(any));
      });

      test('routes pdf to handlePdf', () async {
        await controller.shareResults(mockContext, ResultFormat.pdf);

        verify(mockShareResultsController.handlePdf(mockContext)).called(1);
        verifyNever(mockShareResultsController.handlePlainTextCopy(any));
        verifyNever(mockShareResultsController.handleGoogleSheet(any));
      });

      test('calls notifyListeners after delegating', () async {
        int notifyCount = 0;
        controller.addListener(() => notifyCount++);

        await controller.shareResults(mockContext, ResultFormat.plainText);

        expect(notifyCount, 1);
      });
    });
  });
}
