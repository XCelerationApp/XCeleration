import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/race_results/controller/race_results_controller.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/sync_service.dart';
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

    group('sync stream', () {
      test('reloads results when syncEvents emits race_results table', () async {
        final syncController = StreamController<SyncEvent>.broadcast();
        controller.dispose();
        controller = RaceResultsController(
          service: mockService,
          syncStream: syncController.stream,
        );

        // Prime the controller so it has a stored masterRace
        when(mockService.calculateCompleteRaceResults(any))
            .thenAnswer((_) async => Success(RaceResultsData(
                  resultsTitle: 'Initial',
                  individualResults: [],
                  overallTeamResults: [],
                  headToHeadTeamResults: [],
                )));
        await controller.loadRaceResults(mockMasterRace);
        clearInteractions(mockService);

        // Emit a sync event for race_results
        when(mockService.calculateCompleteRaceResults(any))
            .thenAnswer((_) async => Success(RaceResultsData(
                  resultsTitle: 'Synced',
                  individualResults: [],
                  overallTeamResults: [],
                  headToHeadTeamResults: [],
                )));
        syncController.add(SyncEvent(
          timestamp: DateTime.now(),
          changedTables: {'race_results'},
        ));
        await Future.microtask(() {});
        await Future.microtask(() {});

        verify(mockService.calculateCompleteRaceResults(any)).called(1);
        expect(controller.raceResultsData?.resultsTitle, 'Synced');

        await syncController.close();
      });

      test('does not reload when syncEvents emits without race_results table',
          () async {
        final syncController = StreamController<SyncEvent>.broadcast();
        controller.dispose();
        controller = RaceResultsController(
          service: mockService,
          syncStream: syncController.stream,
        );

        when(mockService.calculateCompleteRaceResults(any))
            .thenAnswer((_) async => Success(RaceResultsData(
                  resultsTitle: 'Initial',
                  individualResults: [],
                  overallTeamResults: [],
                  headToHeadTeamResults: [],
                )));
        await controller.loadRaceResults(mockMasterRace);
        clearInteractions(mockService);

        syncController.add(SyncEvent(
          timestamp: DateTime.now(),
          changedTables: {'races', 'runners'},
        ));
        await Future.microtask(() {});

        verifyNever(mockService.calculateCompleteRaceResults(any));

        await syncController.close();
      });

      test('does not reload before loadRaceResults is called', () async {
        final syncController = StreamController<SyncEvent>.broadcast();
        controller.dispose();
        controller = RaceResultsController(
          service: mockService,
          syncStream: syncController.stream,
        );

        syncController.add(SyncEvent(
          timestamp: DateTime.now(),
          changedTables: {'race_results'},
        ));
        await Future.microtask(() {});

        verifyNever(mockService.calculateCompleteRaceResults(any));

        await syncController.close();
      });
    });

    group('dispose', () {
      test('cancels sync subscription so no reload occurs after dispose',
          () async {
        final syncController = StreamController<SyncEvent>.broadcast();
        controller.dispose();
        controller = RaceResultsController(
          service: mockService,
          syncStream: syncController.stream,
        );

        when(mockService.calculateCompleteRaceResults(any))
            .thenAnswer((_) async => Success(RaceResultsData(
                  resultsTitle: 'Initial',
                  individualResults: [],
                  overallTeamResults: [],
                  headToHeadTeamResults: [],
                )));
        await controller.loadRaceResults(mockMasterRace);
        controller.dispose();
        clearInteractions(mockService);

        syncController.add(SyncEvent(
          timestamp: DateTime.now(),
          changedTables: {'race_results'},
        ));
        await Future.microtask(() {});

        verifyNever(mockService.calculateCompleteRaceResults(any));

        await syncController.close();
      });
    });
  });
}
