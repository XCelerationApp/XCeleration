import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/bib_number_recorder/controller/bib_number_controller.dart';
import 'package:xceleration/assistant/bib_number_recorder/model/bib_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart' as runner_models;
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/assistant/shared/services/i_demo_race_generator.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/i_device_connection_factory.dart';
import 'package:xceleration/core/services/i_post_frame_scheduler.dart';
import 'package:xceleration/core/services/i_text_input_factory.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/assistant/shared/models/bib_record.dart' as db_models;
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';

import 'bib_number_controller_test.mocks.dart';

class FakeTextInputFactory implements ITextInputFactory {
  @override
  TextEditingController createController(String text) =>
      TextEditingController(text: text);

  @override
  FocusNode createFocusNode() => FocusNode();
}

@GenerateMocks([
  IAssistantStorageService,
  IDemoRaceGenerator,
  IDeviceConnectionFactory,
  TutorialManager,
  IPostFrameScheduler,
])
void main() {
  late MockIAssistantStorageService mockStorage;
  late MockIDemoRaceGenerator mockDemoRaceGenerator;
  late MockIDeviceConnectionFactory mockDeviceConnectionFactory;
  late MockTutorialManager mockTutorialManager;
  late MockIPostFrameScheduler mockScheduler;

  final testRace = RaceRecord(
    raceId: 1,
    date: DateTime(2024, 1, 1),
    name: 'State Meet',
    type: DeviceName.bibRecorder.toString(),
    stopped: true,
  );

  setUpAll(() {
    provideDummy<Result<List<RaceRecord>>>(const Success([]));
    provideDummy<Result<void>>(const Failure(AppError(userMessage: '')));
    provideDummy<Result<db_models.BibRecord?>>(const Success(null));
    provideDummy<Result<List<db_models.BibRecord>>>(const Success([]));
    provideDummy<Result<List<runner_models.Runner>>>(const Success([]));
  });

  BibNumberController buildController() {
    return BibNumberController(
      storage: mockStorage,
      textInputFactory: FakeTextInputFactory(),
      tutorialManager: mockTutorialManager,
      demoRaceGenerator: mockDemoRaceGenerator,
      deviceConnectionFactory: mockDeviceConnectionFactory,
      scheduler: mockScheduler,
    );
  }

  setUp(() {
    mockStorage = MockIAssistantStorageService();
    mockDemoRaceGenerator = MockIDemoRaceGenerator();
    mockDeviceConnectionFactory = MockIDeviceConnectionFactory();
    mockTutorialManager = MockTutorialManager();
    mockScheduler = MockIPostFrameScheduler();

    // Stubs for async calls made during construction
    when(mockDemoRaceGenerator.ensureDemoRaceExists(any))
        .thenAnswer((_) async => false);
    when(mockStorage.getRaces(any)).thenAnswer((_) async => const Success([]));
    when(mockStorage.getRunners(any)).thenAnswer((_) async => const Success([]));
    when(mockStorage.getBibRecords(any))
        .thenAnswer((_) async => const Success([]));

    // Stubs for storage writes
    when(mockStorage.updateRaceStatus(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.deleteRace(any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.removeBibRecord(any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.saveBibRecords(any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.saveNewRace(any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.saveRunners(any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.getBibRecord(any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.addBibRecord(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.updateBibRecordValue(any, any, any))
        .thenAnswer((_) async => const Success(null));

    // schedulePostFrame is a no-op in unit tests
    when(mockScheduler.schedulePostFrame(any)).thenReturn(null);
  });

  group('BibNumberController', () {
    group('constructor', () {
      test('calls ensureDemoRaceExists on construction', () async {
        final controller = buildController();
        await Future.delayed(Duration.zero);

        verify(mockDemoRaceGenerator
                .ensureDemoRaceExists(DeviceName.bibRecorder.toString()))
            .called(1);

        controller.dispose();
      });

      test('loads races from storage on construction', () async {
        final controller = buildController();
        await Future.delayed(Duration.zero);

        verify(mockStorage.getRaces(DeviceName.bibRecorder.toString()))
            .called(1);

        controller.dispose();
      });

      test('loads race and runners when races are available', () async {
        when(mockStorage.getRaces(any))
            .thenAnswer((_) async => Success([testRace]));

        final controller = buildController();
        await Future.delayed(Duration.zero);

        verify(mockStorage.getRunners(testRace.raceId)).called(1);

        controller.dispose();
      });
    });

    group('isCurrentRaceDemoRace', () {
      test('returns false when no race is loaded', () {
        final controller = buildController();

        expect(controller.isCurrentRaceDemoRace(), isFalse);
        verifyNever(mockDemoRaceGenerator.isDemoRace(any));

        controller.dispose();
      });

      test('delegates to IDemoRaceGenerator when race is loaded', () {
        when(mockDemoRaceGenerator.isDemoRace(any)).thenReturn(true);
        final controller = buildController();
        controller.setCurrentRace(testRace);

        final result = controller.isCurrentRaceDemoRace();

        expect(result, isTrue);
        verify(mockDemoRaceGenerator.isDemoRace(testRace)).called(1);

        controller.dispose();
      });

      test('returns false when generator says race is not demo', () {
        when(mockDemoRaceGenerator.isDemoRace(any)).thenReturn(false);
        final controller = buildController();
        controller.setCurrentRace(testRace);

        expect(controller.isCurrentRaceDemoRace(), isFalse);

        controller.dispose();
      });
    });

    group('raceStopped setter', () {
      test('calls storage.updateRaceStatus with new value', () async {
        final controller = buildController();
        controller.setCurrentRace(testRace);
        controller.setRaceStopped(true);

        controller.raceStopped = false;
        await Future.delayed(Duration.zero);

        verify(mockStorage.updateRaceStatus(
                testRace.raceId, testRace.type, false))
            .called(1);

        controller.dispose();
      });

      test('throws when no race is loaded', () {
        final controller = buildController();

        expect(() => controller.raceStopped = false, throwsException);

        controller.dispose();
      });

      test('does nothing when value is unchanged', () async {
        final controller = buildController();
        controller.setCurrentRace(testRace);
        controller.setRaceStopped(true);

        controller.raceStopped = true;
        await Future.delayed(Duration.zero);

        verifyNever(mockStorage.updateRaceStatus(any, any, any));

        controller.dispose();
      });

      test('removes empty trailing record when stopping race', () async {
        final controller = buildController();
        controller.setCurrentRace(testRace);
        controller.setRaceStopped(false);
        await controller.addBibRecord(BibDatumRecord.blank());

        controller.raceStopped = true;

        expect(controller.bibRecords, isEmpty);

        controller.dispose();
      });
    });

    group('deleteCurrentRace', () {
      test('calls storage.deleteRace and resets state', () async {
        final controller = buildController();
        controller.setCurrentRace(testRace);

        await controller.deleteCurrentRace();

        verify(mockStorage.deleteRace(testRace.raceId, testRace.type))
            .called(1);
        expect(controller.currentRace, isNull);

        controller.dispose();
      });

      test('does nothing when no race is loaded', () async {
        final controller = buildController();

        await controller.deleteCurrentRace();

        verifyNever(mockStorage.deleteRace(any, any));

        controller.dispose();
      });

      test('does not reset state on storage failure', () async {
        when(mockStorage.deleteRace(any, any)).thenAnswer(
          (_) async => const Failure(AppError(userMessage: 'error')),
        );
        final controller = buildController();
        controller.setCurrentRace(testRace);

        await controller.deleteCurrentRace();

        expect(controller.currentRace, equals(testRace));

        controller.dispose();
      });
    });

    group('prepareShareData', () {
      test('returns ShareDataDemoRace when current race is a demo race',
          () async {
        when(mockDemoRaceGenerator.isDemoRace(any)).thenReturn(true);
        final controller = buildController();
        controller.setCurrentRace(testRace);

        final result = await controller.prepareShareData();

        expect(result, isA<ShareDataDemoRace>());

        controller.dispose();
      });

      test('returns ShareDataHasDuplicates when duplicate bibs exist', () async {
        when(mockDemoRaceGenerator.isDemoRace(any)).thenReturn(false);
        final controller = buildController();
        controller.setCurrentRace(testRace);
        await controller.addBibRecord(
            BibDatumRecord(bib: '5', name: '', teamAbbreviation: '', grade: ''));
        await controller.addBibRecord(
            BibDatumRecord(bib: '5', name: '', teamAbbreviation: '', grade: ''));

        final result = await controller.prepareShareData();

        expect(result, isA<ShareDataHasDuplicates>());
        final dupeResult = result as ShareDataHasDuplicates;
        expect(dupeResult.duplicates, contains('5'));
        expect(dupeResult.hasUnknown, isFalse);

        controller.dispose();
      });

      test('returns ShareDataHasUnknown when unknown bibs exist', () async {
        when(mockDemoRaceGenerator.isDemoRace(any)).thenReturn(false);
        final controller = buildController();
        controller.setCurrentRace(testRace);
        await controller.addBibRecord(BibDatumRecord(
          bib: '99',
          name: '',
          teamAbbreviation: '',
          grade: '',
          flags: const BibDatumRecordFlags(
              notInDatabase: true, duplicateBibNumber: false),
        ));

        final result = await controller.prepareShareData();

        expect(result, isA<ShareDataHasUnknown>());

        controller.dispose();
      });

      test('returns ShareDataReady when all records are valid', () async {
        when(mockDemoRaceGenerator.isDemoRace(any)).thenReturn(false);
        final controller = buildController();
        controller.setCurrentRace(testRace);
        await controller.addBibRecord(BibDatumRecord(
          bib: '1',
          name: 'Alice',
          teamAbbreviation: 'EAG',
          grade: '10',
          flags: const BibDatumRecordFlags(
              notInDatabase: false, duplicateBibNumber: false),
        ));

        final result = await controller.prepareShareData();

        expect(result, isA<ShareDataReady>());

        controller.dispose();
      });
    });

    group('_loadLastRace', () {
      test('leaves currentRace null when getRaces returns Failure', () async {
        when(mockStorage.getRaces(any)).thenAnswer(
          (_) async => const Failure(AppError(userMessage: 'error')),
        );

        final controller = buildController();
        await Future.delayed(Duration.zero);

        expect(controller.currentRace, isNull);

        controller.dispose();
      });
    });

    group('validateBibNumber', () {
      test('clears flags for empty input', () async {
        final controller = buildController();
        await controller.addBibRecord(
            BibDatumRecord(bib: '5', name: '', teamAbbreviation: '', grade: ''));

        await controller.validateBibNumber(0, '');

        expect(controller.bibRecords[0].bib, equals(''));
        expect(controller.bibRecords[0].flags.notInDatabase, isFalse);
        expect(controller.bibRecords[0].flags.duplicateBibNumber, isFalse);

        controller.dispose();
      });

      test('marks notInDatabase for non-numeric input', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());

        await controller.validateBibNumber(0, 'abc');

        expect(controller.bibRecords[0].flags.notInDatabase, isTrue);

        controller.dispose();
      });

      test('marks notInDatabase when runner not found', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());

        await controller.validateBibNumber(0, '99');

        expect(controller.bibRecords[0].flags.notInDatabase, isTrue);

        controller.dispose();
      });

      test('populates runner info and clears notInDatabase when runner found',
          () async {
        final controller = buildController();
        controller.runners.add(BibDatum(
          bib: '42',
          name: 'Alice',
          teamAbbreviation: 'EAG',
          grade: '10',
        ));
        await controller.addBibRecord(BibDatumRecord.blank());

        await controller.validateBibNumber(0, '42');

        expect(controller.bibRecords[0].flags.notInDatabase, isFalse);
        expect(controller.bibRecords[0].name, equals('Alice'));

        controller.dispose();
      });

      test('marks duplicateBibNumber for second occurrence of same bib',
          () async {
        final controller = buildController();
        controller.runners.add(BibDatum(
          bib: '7',
          name: 'Bob',
          teamAbbreviation: 'TIG',
          grade: '11',
        ));
        await controller.addBibRecord(
            BibDatumRecord(bib: '7', name: '', teamAbbreviation: '', grade: ''));
        await controller.addBibRecord(
            BibDatumRecord(bib: '7', name: '', teamAbbreviation: '', grade: ''));

        await controller.validateBibNumber(1, '7');

        expect(controller.bibRecords[1].flags.duplicateBibNumber, isTrue);

        controller.dispose();
      });

      test('does nothing for out-of-range index', () async {
        final controller = buildController();

        await expectLater(controller.validateBibNumber(5, '42'), completes);

        controller.dispose();
      });
    });

    group('handleBibNumber', () {
      test('adds a new bib record when no index is provided', () async {
        final controller = buildController();

        await controller.handleBibNumber('42');

        expect(controller.bibRecords.length, equals(1));
        expect(controller.bibRecords.first.bib, equals('42'));

        controller.dispose();
      });

      test('schedules scroll and focus callbacks when adding new record',
          () async {
        final controller = buildController();

        await controller.handleBibNumber('1');

        verify(mockScheduler.schedulePostFrame(any)).called(2);

        controller.dispose();
      });

      test('updates existing record immediately when index is provided',
          () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());

        await controller.handleBibNumber('99', index: 0);

        expect(controller.bibRecords[0].bib, equals('99'));

        controller.dispose();
      });

      test('does not schedule callbacks when updating existing record',
          () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());

        await controller.handleBibNumber('5', index: 0);

        verifyNever(mockScheduler.schedulePostFrame(any));

        controller.dispose();
      });

      test('does not update record when index is out of range', () async {
        final controller = buildController();

        await controller.handleBibNumber('5', index: 99);

        expect(controller.bibRecords, isEmpty);

        controller.dispose();
      });

      test('validates new record after debounce using fakeAsync', () {
        fakeAsync((async) {
          final controller = buildController();
          controller.runners.add(BibDatum(
            bib: '42',
            name: 'Alice',
            teamAbbreviation: 'EAG',
            grade: '10',
          ));

          controller.handleBibNumber('42');
          async.elapse(const Duration(milliseconds: 500));

          expect(controller.bibRecords.first.flags.notInDatabase, isFalse);
          expect(controller.bibRecords.first.name, equals('Alice'));

          controller.dispose();
        });
      });
    });

    group('loadOtherRace', () {
      test('resets state and loads the provided race', () async {
        final otherRace = RaceRecord(
          raceId: 2,
          date: DateTime(2024, 6, 1),
          name: 'Regional Meet',
          type: DeviceName.bibRecorder.toString(),
          stopped: false,
        );
        when(mockStorage.getRunners(otherRace.raceId))
            .thenAnswer((_) async => const Success([]));
        when(mockStorage.getBibRecords(otherRace.raceId))
            .thenAnswer((_) async => const Success([]));

        final controller = buildController();
        controller.setCurrentRace(testRace);

        await controller.loadOtherRace(otherRace);

        expect(controller.currentRace, equals(otherRace));
        verify(mockStorage.getRunners(otherRace.raceId)).called(1);
        verify(mockStorage.getBibRecords(otherRace.raceId)).called(1);

        controller.dispose();
      });
    });

    group('processLoadedRaceData', () {
      final validRunnerJson =
          '{"teams":["EAG"],"r":[["42","Alice",0,"10"]]}';

      test('returns Failure for malformed race data', () async {
        final controller = buildController();

        final result =
            await controller.processLoadedRaceData('not valid json');

        expect(result, isA<Failure<void>>());

        controller.dispose();
      });

      test('returns Failure when runner section is invalid', () async {
        final controller = buildController();
        final data = '${testRace.encode()}---invalid-runner-data';

        final result = await controller.processLoadedRaceData(data);

        expect(result, isA<Failure<void>>());

        controller.dispose();
      });

      test('returns Failure when saveNewRace fails', () async {
        when(mockStorage.saveNewRace(any)).thenAnswer(
          (_) async => const Failure(AppError(userMessage: 'Save failed')),
        );
        final controller = buildController();

        final result =
            await controller.processLoadedRaceData(testRace.encode());

        expect(result, isA<Failure<void>>());
        expect((result as Failure).error.userMessage, 'Save failed');

        controller.dispose();
      });

      test('returns Success and saves runners on happy path with runners',
          () async {
        final controller = buildController();
        final data = '${testRace.encode()}---$validRunnerJson';

        final result = await controller.processLoadedRaceData(data);

        expect(result, isA<Success<void>>());
        verify(mockStorage.saveNewRace(any)).called(1);
        verify(mockStorage.saveRunners(any, argThat(isNotEmpty))).called(1);

        controller.dispose();
      });

      test('returns Success and skips saveRunners on happy path without runners',
          () async {
        final controller = buildController();

        final result =
            await controller.processLoadedRaceData(testRace.encode());

        expect(result, isA<Success<void>>());
        verify(mockStorage.saveNewRace(any)).called(1);
        verifyNever(mockStorage.saveRunners(any, any));

        controller.dispose();
      });
    });

    group('saveBibRecords', () {
      test('saves non-empty records using current race id', () async {
        final controller = buildController();
        controller.setCurrentRace(testRace);
        await controller.addBibRecord(
            BibDatumRecord(bib: '3', name: '', teamAbbreviation: '', grade: ''));

        await controller.saveBibRecords();

        verify(mockStorage.saveBibRecords(testRace.raceId, argThat(isNotEmpty)))
            .called(1);

        controller.dispose();
      });

      test('does nothing when no race is loaded', () async {
        final controller = buildController();
        await controller.addBibRecord(
            BibDatumRecord(bib: '3', name: '', teamAbbreviation: '', grade: ''));

        await controller.saveBibRecords();

        verifyNever(mockStorage.saveBibRecords(any, any));

        controller.dispose();
      });
    });
  });

  group('BibNumberDataController', () {
    group('addBibRecord', () {
      test('adds a record and returns the correct index', () async {
        final controller = buildController();
        final record = BibDatumRecord(
          bib: '42',
          name: 'Alice',
          teamAbbreviation: 'EAG',
          grade: '10',
        );

        final index = await controller.addBibRecord(record);

        expect(index, equals(0));
        expect(controller.bibRecords.length, equals(1));
        expect(controller.bibRecords.first.bib, equals('42'));

        controller.dispose();
      });

      test('adds multiple records with sequential indices', () async {
        final controller = buildController();

        final i0 = await controller.addBibRecord(BibDatumRecord.blank());
        final i1 = await controller.addBibRecord(BibDatumRecord.blank());

        expect(i0, equals(0));
        expect(i1, equals(1));
        expect(controller.bibRecords.length, equals(2));

        controller.dispose();
      });
    });

    group('updateBibRecord', () {
      test('updates the record at the given index', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());
        final updated = BibDatumRecord(
          bib: '99',
          name: 'Bob',
          teamAbbreviation: 'TIG',
          grade: '11',
        );

        controller.updateBibRecord(0, updated);

        expect(controller.bibRecords.first.bib, equals('99'));

        controller.dispose();
      });

      test('does nothing for out-of-range index', () async {
        final controller = buildController();

        expect(
          () => controller.updateBibRecord(5, BibDatumRecord.blank()),
          returnsNormally,
        );

        controller.dispose();
      });
    });

    group('removeBibRecord', () {
      test('removes record and calls storage when race is set', () async {
        final controller = buildController();
        controller.setCurrentRace(testRace);
        await controller.addBibRecord(BibDatumRecord.blank());

        await controller.removeBibRecord(0);

        expect(controller.bibRecords, isEmpty);
        verify(mockStorage.removeBibRecord(testRace.raceId, 0)).called(1);

        controller.dispose();
      });

      test('removes record without storage call when no race is set', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());

        await controller.removeBibRecord(0);

        expect(controller.bibRecords, isEmpty);
        verifyNever(mockStorage.removeBibRecord(any, any));

        controller.dispose();
      });
    });

    group('clearBibRecords', () {
      test('removes all records', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());
        await controller.addBibRecord(BibDatumRecord.blank());

        controller.clearBibRecords();

        expect(controller.bibRecords, isEmpty);
        expect(controller.controllers, isEmpty);
        expect(controller.focusNodes, isEmpty);

        controller.dispose();
      });
    });

    group('checkDuplicateRecords', () {
      test('returns empty list when no duplicates', () async {
        final controller = buildController();
        await controller.addBibRecord(
            BibDatumRecord(bib: '1', name: '', teamAbbreviation: '', grade: ''));
        await controller.addBibRecord(
            BibDatumRecord(bib: '2', name: '', teamAbbreviation: '', grade: ''));

        expect(controller.checkDuplicateRecords(), isEmpty);

        controller.dispose();
      });

      test('returns duplicate bib numbers', () async {
        final controller = buildController();
        await controller.addBibRecord(
            BibDatumRecord(bib: '5', name: '', teamAbbreviation: '', grade: ''));
        await controller.addBibRecord(
            BibDatumRecord(bib: '5', name: '', teamAbbreviation: '', grade: ''));

        expect(controller.checkDuplicateRecords(), contains('5'));

        controller.dispose();
      });

      test('ignores empty bib values', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());
        await controller.addBibRecord(BibDatumRecord.blank());

        expect(controller.checkDuplicateRecords(), isEmpty);

        controller.dispose();
      });
    });

    group('checkUnknownRecords', () {
      test('returns false when all records are known', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord(
          bib: '1',
          name: '',
          teamAbbreviation: '',
          grade: '',
          flags: const BibDatumRecordFlags(
              notInDatabase: false, duplicateBibNumber: false),
        ));

        expect(controller.checkUnknownRecords(), isFalse);

        controller.dispose();
      });

      test('returns true when any record has notInDatabase flag', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord(
          bib: '999',
          name: '',
          teamAbbreviation: '',
          grade: '',
          flags: const BibDatumRecordFlags(
              notInDatabase: true, duplicateBibNumber: false),
        ));

        expect(controller.checkUnknownRecords(), isTrue);

        controller.dispose();
      });
    });

    group('saveBibRecordsToDatabase', () {
      test('saves non-empty bib records to storage', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord(
          bib: '7',
          name: '',
          teamAbbreviation: '',
          grade: '',
        ));

        await controller.saveBibRecordsToDatabase(testRace.raceId);

        verify(mockStorage.saveBibRecords(
                testRace.raceId, argThat(isNotEmpty)))
            .called(1);
      });

      test('skips empty bib records', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());

        await controller.saveBibRecordsToDatabase(testRace.raceId);

        verify(mockStorage.saveBibRecords(any, argThat(isEmpty))).called(1);

        controller.dispose();
      });
    });

    group('setCurrentRace / setRaceStopped', () {
      test('setCurrentRace updates currentRace', () {
        final controller = buildController();

        controller.setCurrentRace(testRace);

        expect(controller.currentRace, equals(testRace));

        controller.dispose();
      });

      test('setCurrentRace accepts null', () {
        final controller = buildController();
        controller.setCurrentRace(testRace);

        controller.setCurrentRace(null);

        expect(controller.currentRace, isNull);

        controller.dispose();
      });

      test('setRaceStopped updates raceStopped', () {
        final controller = buildController();

        controller.setRaceStopped(false);

        expect(controller.raceStopped, isFalse);

        controller.dispose();
      });
    });

    group('cleanEmptyRecords', () {
      test('removes all records with empty bib', () async {
        final controller = buildController();
        await controller.addBibRecord(
            BibDatumRecord(bib: '1', name: '', teamAbbreviation: '', grade: ''));
        await controller.addBibRecord(BibDatumRecord.blank());
        await controller.addBibRecord(
            BibDatumRecord(bib: '2', name: '', teamAbbreviation: '', grade: ''));

        await controller.cleanEmptyRecords();

        expect(
          controller.bibRecords.map((r) => r.bib),
          containsAll(['1', '2']),
        );
        expect(controller.bibRecords.any((r) => r.bib.isEmpty), isFalse);

        controller.dispose();
      });

      test('returns true', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());

        final result = await controller.cleanEmptyRecords();

        expect(result, isTrue);

        controller.dispose();
      });
    });

    group('getBibsAndRunners', () {
      test('returns map of non-empty bibs to records', () async {
        final controller = buildController();
        await controller.addBibRecord(
            BibDatumRecord(bib: '10', name: 'Alice', teamAbbreviation: 'EAG', grade: '10'));
        await controller.addBibRecord(BibDatumRecord.blank());

        final map = controller.getBibsAndRunners();

        expect(map.keys, contains('10'));
        expect(map.keys, isNot(contains('')));
        expect(map['10']!.name, equals('Alice'));

        controller.dispose();
      });

      test('returns empty map when all bibs are empty', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());

        expect(controller.getBibsAndRunners(), isEmpty);

        controller.dispose();
      });

      test('last record wins for duplicate bib keys', () async {
        final controller = buildController();
        await controller.addBibRecord(
            BibDatumRecord(bib: '5', name: 'First', teamAbbreviation: '', grade: ''));
        await controller.addBibRecord(
            BibDatumRecord(bib: '5', name: 'Second', teamAbbreviation: '', grade: ''));

        final map = controller.getBibsAndRunners();

        expect(map['5']!.name, equals('Second'));

        controller.dispose();
      });
    });

    group('stat helpers', () {
      test('hasNonEmptyBibNumbers returns true when at least one non-empty bib',
          () async {
        final controller = buildController();
        await controller.addBibRecord(
            BibDatumRecord(bib: '1', name: '', teamAbbreviation: '', grade: ''));

        expect(controller.hasNonEmptyBibNumbers(), isTrue);

        controller.dispose();
      });

      test('hasNonEmptyBibNumbers returns false when all bibs are empty',
          () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());

        expect(controller.hasNonEmptyBibNumbers(), isFalse);

        controller.dispose();
      });

      test('countNonEmptyBibNumbers returns count of non-empty bibs', () async {
        final controller = buildController();
        await controller.addBibRecord(
            BibDatumRecord(bib: '1', name: '', teamAbbreviation: '', grade: ''));
        await controller.addBibRecord(BibDatumRecord.blank());

        expect(controller.countNonEmptyBibNumbers(), equals(1));

        controller.dispose();
      });

      test('countEmptyBibNumbers returns count of empty bibs', () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord.blank());
        await controller.addBibRecord(
            BibDatumRecord(bib: '1', name: '', teamAbbreviation: '', grade: ''));

        expect(controller.countEmptyBibNumbers(), equals(1));

        controller.dispose();
      });

      test('countDuplicateBibNumbers returns count of duplicate-flagged records',
          () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord(
          bib: '5',
          name: '',
          teamAbbreviation: '',
          grade: '',
          flags: const BibDatumRecordFlags(
              notInDatabase: false, duplicateBibNumber: true),
        ));
        await controller.addBibRecord(BibDatumRecord.blank());

        expect(controller.countDuplicateBibNumbers(), equals(1));

        controller.dispose();
      });

      test('countUnknownBibNumbers returns count of notInDatabase-flagged records',
          () async {
        final controller = buildController();
        await controller.addBibRecord(BibDatumRecord(
          bib: '99',
          name: '',
          teamAbbreviation: '',
          grade: '',
          flags: const BibDatumRecordFlags(
              notInDatabase: true, duplicateBibNumber: false),
        ));
        await controller.addBibRecord(BibDatumRecord.blank());

        expect(controller.countUnknownBibNumbers(), equals(1));

        controller.dispose();
      });
    });
  });
}
