import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/assistant/race_timer/controller/timing_controller.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

import 'timing_controller_test.mocks.dart';

@GenerateMocks([IAssistantStorageService, IHapticFeedback])
void main() {
  late MockIAssistantStorageService mockStorage;
  late MockIHapticFeedback mockHaptic;
  late TimingController controller;

  final testRace = RaceRecord(
    raceId: 1,
    date: DateTime(2024, 1, 1),
    name: 'Test Race',
    type: DeviceName.raceTimer.toString(),
    stopped: true,
  );

  setUpAll(() {
    // Dummy argument types (used by `any` matcher in stubs)
    provideDummy(TimingDatum(time: '0:00.00'));
    provideDummy(TimingChunk(id: 0, timingData: []));
    // Dummy return types (needed because MockIAssistantStorageService uses throwOnMissingStub)
    provideDummy<Result<List<RaceRecord>>>(const Success([]));
    provideDummy<Result<List<TimingChunk>>>(const Success([]));
    provideDummy<Result<void>>(const Failure(AppError(userMessage: '')));
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    mockStorage = MockIAssistantStorageService();
    mockHaptic = MockIHapticFeedback();

    // Stub haptic methods (fire-and-forget, return immediately)
    when(mockHaptic.vibrate()).thenAnswer((_) => Future.value());
    when(mockHaptic.lightImpact()).thenAnswer((_) => Future.value());

    // Stub the getRaces call made during constructor (_loadLastRace)
    when(mockStorage.getRaces(any)).thenAnswer((_) async => const Success([]));
    // Stub all storage writes used by TimingController and TimingData
    when(mockStorage.updateRaceStatus(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.updateRaceStartTime(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.updateRaceDuration(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.addLoggedTimingDatum(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.saveChunkConflict(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.saveChunk(any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.getChunks(any)).thenAnswer((_) async => const Success([]));
    when(mockStorage.deleteChunks(any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.deleteChunk(any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.updateChunkTimingData(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(mockStorage.deleteRace(any, any))
        .thenAnswer((_) async => const Success(null));

    controller = TimingController(storage: mockStorage, hapticFeedback: mockHaptic);
  });

  tearDown(() {
    controller.dispose();
  });

  /// Sets a loaded race and starts it so that timing methods are usable.
  void loadAndStartRace([RaceRecord? race]) {
    controller.currentRace = race ?? testRace;
    controller.startRace();
  }

  group('TimingController', () {
    group('startRace', () {
      test('starts a brand new race when startTime is null', () {
        controller.currentRace = testRace;

        controller.startRace();

        expect(controller.startTime, isNotNull);
        expect(controller.raceStopped, isFalse);
      });

      test('continues a stopped race without resetting startTime', () {
        controller.currentRace = testRace;
        controller.startRace();
        final firstStart = controller.startTime;
        controller.stopRace();
        expect(controller.raceStopped, isTrue);

        controller.startRace();

        expect(controller.startTime, equals(firstStart));
        expect(controller.raceStopped, isFalse);
      });
    });

    group('stopRace', () {
      test('records raceDuration and marks race stopped when active', () {
        loadAndStartRace();

        controller.stopRace();

        expect(controller.raceStopped, isTrue);
        expect(controller.raceDuration, isNotNull);
      });

      test('is a no-op when startTime is null', () {
        controller.currentRace = testRace;

        controller.stopRace();

        expect(controller.raceDuration, isNull);
      });
    });

    group('logTime', () {
      test('returns error when race has not started', () {
        final error = controller.logTime();

        expect(error, isNotNull);
      });

      test('returns error when race is stopped', () {
        loadAndStartRace();
        controller.stopRace();

        final error = controller.logTime();

        expect(error, isNotNull);
      });

      test('returns null and appends runner record when race is active', () {
        loadAndStartRace();

        final error = controller.logTime();

        expect(error, isNull);
        expect(controller.currentChunk.timingData, hasLength(1));
      });
    });

    group('confirmTimes', () {
      test('returns error when race has not started', () {
        final error = controller.confirmTimes();

        expect(error, isNotNull);
      });

      test('adds a confirmRunner conflict record when race is active', () {
        loadAndStartRace();

        final error = controller.confirmTimes();

        expect(error, isNull);
        expect(controller.currentChunk.hasConflict, isTrue);
        expect(
          controller.currentChunk.conflictRecord?.conflict?.type,
          ConflictType.confirmRunner,
        );
      });
    });

    group('addMissingTime', () {
      test('returns error when startTime is null', () async {
        final error = await controller.addMissingTime();

        expect(error, isNotNull);
      });

      test('adds a missingTime conflict record when race is active', () async {
        loadAndStartRace();

        final error = await controller.addMissingTime();

        expect(error, isNull);
        expect(controller.currentChunk.hasConflict, isTrue);
        expect(
          controller.currentChunk.conflictRecord?.conflict?.type,
          ConflictType.missingTime,
        );
      });
    });

    group('removeExtraTime', () {
      test('returns RemoveExtraTimeError when race has not started', () async {
        final result = await controller.removeExtraTime();

        expect(result, isA<RemoveExtraTimeError>());
      });

      test(
          'returns RemoveExtraTimeConfirmRequired when offBy equals runner count',
          () async {
        loadAndStartRace();
        controller.logTime(); // 1 runner record

        final result =
            await controller.removeExtraTime(); // offBy 1 == 1 record

        expect(result, isA<RemoveExtraTimeConfirmRequired>());
      });

      test('returns RemoveExtraTimeOk when runner count exceeds offBy',
          () async {
        loadAndStartRace();
        controller.logTime();
        controller.logTime(); // 2 runner records, offBy will be 1

        final result = await controller.removeExtraTime();

        expect(result, isA<RemoveExtraTimeOk>());
      });
    });

    group('isLastRecordUndoable', () {
      test('is false when there are no conflict records', () {
        expect(controller.isLastRecordUndoable, isFalse);
      });

      test('is true when a confirmRunner conflict record exists', () {
        loadAndStartRace();
        controller.confirmTimes();

        expect(controller.isLastRecordUndoable, isTrue);
      });
    });

    group('undoDialogTitle and undoDialogContent', () {
      test('reflect conflict strings for non-confirmation conflicts', () async {
        loadAndStartRace();
        await controller.addMissingTime();

        expect(controller.undoDialogTitle, 'Undo Conflict');
        expect(
            controller.undoDialogContent, contains('undo the last conflict'));
      });

      test('reflect confirmation strings for confirmRunner conflicts', () {
        loadAndStartRace();
        controller.confirmTimes();

        expect(controller.undoDialogTitle, 'Undo Confirmation');
        expect(
          controller.undoDialogContent,
          contains('undo the last confirmation'),
        );
      });
    });

    group('doUndoLastConflict', () {
      test('clears the current conflict record', () {
        loadAndStartRace();
        controller.confirmTimes();
        expect(controller.currentChunk.hasConflict, isTrue);

        controller.doUndoLastConflict();

        expect(controller.currentChunk.hasConflict, isFalse);
      });
    });

    group('doClearRaceTimes', () {
      test('clears timing records and calls deleteChunks on storage', () async {
        loadAndStartRace();
        controller.logTime();
        expect(controller.currentChunk.timingData, hasLength(1));

        await controller.doClearRaceTimes();

        expect(controller.currentChunk.timingData, isEmpty);
        verify(mockStorage.deleteChunks(testRace.raceId)).called(1);
      });
    });

    group('deleteCurrentRace', () {
      test('is a no-op when currentRace is null', () async {
        final error = await controller.deleteCurrentRace();

        expect(error, isNull);
        verifyNever(mockStorage.deleteChunks(any));
        verifyNever(mockStorage.deleteRace(any, any));
      });

      test('returns null and clears timing records when a race is loaded',
          () async {
        controller.currentRace = testRace;
        controller.startRace();
        controller.logTime();
        expect(controller.currentChunk.timingData, hasLength(1));

        final error = await controller.deleteCurrentRace();

        expect(error, isNull);
        expect(controller.currentChunk.timingData, isEmpty);
      });

      test('calls deleteChunks and deleteRace on storage', () async {
        controller.currentRace = testRace;

        await controller.deleteCurrentRace();

        verify(mockStorage.deleteChunks(testRace.raceId)).called(1);
        verify(mockStorage.deleteRace(testRace.raceId, testRace.type))
            .called(1);
      });
    });

    group('handleLogButtonPress', () {
      test('returns AppError when race has not started', () async {
        final error = await controller.handleLogButtonPress();

        expect(error, isNotNull);
        verifyNever(mockHaptic.vibrate());
        verifyNever(mockHaptic.lightImpact());
      });

      test('returns null and triggers haptic when race is active', () async {
        loadAndStartRace();

        final error = await controller.handleLogButtonPress();

        expect(error, isNull);
        verify(mockHaptic.vibrate()).called(1);
        verify(mockHaptic.lightImpact()).called(1);
      });
    });

    group('validateDeleteRecord', () {
      test('returns null for an unconfirmed runner time', () {
        loadAndStartRace();
        controller.logTime();

        final record = controller.uiRecords.first;
        final error = controller.validateDeleteRecord(record);

        expect(error, isNull);
      });

      test('returns error for a non-last confirmed record', () {
        loadAndStartRace();
        controller.logTime();
        controller.confirmTimes();
        // The confirmed runnerTime (green) is first; confirmRunner is last.
        final record = controller.uiRecords.first;

        final error = controller.validateDeleteRecord(record);

        expect(error, isNotNull);
      });

      test('returns null for the last conflict record', () {
        loadAndStartRace();
        controller.logTime();
        controller.confirmTimes();
        // The confirmRunner record is the last — deletion is allowed.
        final record = controller.uiRecords.last;

        final error = controller.validateDeleteRecord(record);

        expect(error, isNull);
      });
    });

    group('loadOtherRace', () {
      test('clears existing records and loads the new race', () async {
        loadAndStartRace();
        controller.logTime();
        expect(controller.currentChunk.timingData, hasLength(1));

        final newRace = RaceRecord(
          raceId: 2,
          date: DateTime(2024, 6, 1),
          name: 'New Race',
          type: DeviceName.raceTimer.toString(),
          stopped: true,
        );
        await controller.loadOtherRace(newRace);

        expect(controller.currentChunk.timingData, isEmpty);
        expect(controller.currentRace, equals(newRace));
      });
    });

    group('executeDeleteRecord', () {
      test('removes unconfirmed runner time and returns true', () async {
        loadAndStartRace();
        controller.logTime();

        final record = controller.uiRecords.first;
        final result = await controller.executeDeleteRecord(record);

        expect(result, isTrue);
        expect(controller.currentChunk.timingData, isEmpty);
      });

      test('clears confirmRunner conflict record and returns true', () async {
        loadAndStartRace();
        controller.confirmTimes();

        final record = controller.uiRecords.last;
        final result = await controller.executeDeleteRecord(record);

        expect(result, isTrue);
        expect(controller.currentChunk.hasConflict, isFalse);
      });

      test('reduces missingTime conflict by one and returns true', () async {
        loadAndStartRace();
        await controller.addMissingTime();

        final record = controller.uiRecords.last;
        final result = await controller.executeDeleteRecord(record);

        expect(result, isTrue);
        expect(controller.currentChunk.hasConflict, isFalse);
      });

      test('reduces extraTime conflict by one and returns true', () async {
        loadAndStartRace();
        controller.logTime();
        controller.logTime();
        await controller.removeExtraTime();

        final record = controller.uiRecords.last;
        final result = await controller.executeDeleteRecord(record);

        expect(result, isTrue);
        expect(controller.currentChunk.hasConflict, isFalse);
        expect(controller.currentChunk.timingData, hasLength(2));
      });

      test('returns false for a confirmed runnerTime record', () async {
        loadAndStartRace();
        controller.logTime();
        controller.confirmTimes();

        // First record is a runner time inside a confirmed chunk (Colors.green)
        final record = controller.uiRecords.first;
        final result = await controller.executeDeleteRecord(record);

        expect(result, isFalse);
      });
    });
  });
}
