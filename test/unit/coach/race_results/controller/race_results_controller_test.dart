import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/race_results/controller/race_results_controller.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/services/i_race_results_service.dart';
import 'package:xceleration/shared/services/race_results_service.dart';

@GenerateMocks([IRaceResultsService, MasterRace])
import 'race_results_controller_test.mocks.dart';

void main() {
  late RaceResultsController controller;
  late MockIRaceResultsService mockService;
  late MockMasterRace mockMasterRace;

  setUpAll(() {
    provideDummy<Result<RaceResultsData>>(
      Failure<RaceResultsData>(const AppError(userMessage: '')),
    );
  });

  setUp(() {
    mockService = MockIRaceResultsService();
    mockMasterRace = MockMasterRace();
    controller = RaceResultsController(service: mockService);
  });

  group('RaceResultsController', () {
    group('loadRaceResults', () {
      test('sets isLoading to true during call then false after completing',
          () async {
        bool wasLoadingDuringCall = false;

        when(mockService.calculateCompleteRaceResults(any))
            .thenAnswer((_) async {
          wasLoadingDuringCall = controller.isLoading;
          return Success(RaceResultsData(
            resultsTitle: 'Test',
            individualResults: [],
            overallTeamResults: [],
            headToHeadTeamResults: [],
          ));
        });

        await controller.loadRaceResults(mockMasterRace);

        expect(wasLoadingDuringCall, isTrue);
        expect(controller.isLoading, isFalse);
      });

      test('sets raceResultsData and clears error on Success', () async {
        final data = RaceResultsData(
          resultsTitle: 'State Meet',
          individualResults: [],
          overallTeamResults: [],
          headToHeadTeamResults: [],
        );

        when(mockService.calculateCompleteRaceResults(any))
            .thenAnswer((_) async => Success(data));

        await controller.loadRaceResults(mockMasterRace);

        expect(controller.raceResultsData, equals(data));
        expect(controller.hasError, isFalse);
        expect(controller.isLoading, isFalse);
      });

      test('sets hasError and error on Failure, raceResultsData remains null',
          () async {
        when(mockService.calculateCompleteRaceResults(any))
            .thenAnswer((_) async => Failure(AppError(
                  userMessage:
                      'Could not calculate race results. Please try again.',
                )));

        await controller.loadRaceResults(mockMasterRace);

        expect(controller.hasError, isTrue);
        expect(controller.error!.userMessage,
            'Could not calculate race results. Please try again.');
        expect(controller.raceResultsData, isNull);
        expect(controller.isLoading, isFalse);
      });

      test('notifies listeners at start and end of loadRaceResults', () async {
        int notifyCount = 0;
        controller.addListener(() => notifyCount++);

        when(mockService.calculateCompleteRaceResults(any))
            .thenAnswer((_) async => Success(RaceResultsData(
                  resultsTitle: 'Test',
                  individualResults: [],
                  overallTeamResults: [],
                  headToHeadTeamResults: [],
                )));

        await controller.loadRaceResults(mockMasterRace);

        expect(notifyCount, 2);
      });
    });
  });
}
