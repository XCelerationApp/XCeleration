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
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/assistant/shared/models/bib_record.dart' as db_models;

import 'bib_number_controller_test.mocks.dart';

@GenerateMocks([
  IAssistantStorageService,
  IDemoRaceGenerator,
  IDeviceConnectionFactory,
  TutorialManager,
])
void main() {
  late MockIAssistantStorageService mockStorage;
  late MockIDemoRaceGenerator mockDemoRaceGenerator;
  late MockIDeviceConnectionFactory mockDeviceConnectionFactory;
  late MockTutorialManager mockTutorialManager;

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
      tutorialManager: mockTutorialManager,
      demoRaceGenerator: mockDemoRaceGenerator,
      deviceConnectionFactory: mockDeviceConnectionFactory,
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockStorage = MockIAssistantStorageService();
    mockDemoRaceGenerator = MockIDemoRaceGenerator();
    mockDeviceConnectionFactory = MockIDeviceConnectionFactory();
    mockTutorialManager = MockTutorialManager();

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
    when(mockStorage.saveRunners(any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.getBibRecord(any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.addBibRecord(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.updateBibRecordValue(any, any, any))
        .thenAnswer((_) async => const Success(null));
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
  });
}
