import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/race_timer/model/timing_data.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

import 'timing_data_test.mocks.dart';

@GenerateMocks([IAssistantStorageService])
void main() {
  late MockIAssistantStorageService mockStorage;
  late TimingData timingData;

  final testRace = RaceRecord(
    raceId: 1,
    date: DateTime(2024, 1, 1),
    name: 'Test Race',
    type: DeviceName.raceTimer.toString(),
    stopped: true,
  );

  setUpAll(() {
    provideDummy(TimingDatum(time: '0:00.00'));
    provideDummy(TimingChunk(id: 0, timingData: []));
    provideDummy<Result<List<RaceRecord>>>(const Success([]));
    provideDummy<Result<List<TimingChunk>>>(const Success([]));
    provideDummy<Result<void>>(const Failure(AppError(userMessage: '')));
  });

  setUp(() {
    mockStorage = MockIAssistantStorageService();

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
    when(mockStorage.deleteChunk(any, any))
        .thenAnswer((_) async => const Success(null));

    timingData = TimingData(storage: mockStorage);
    timingData.currentRace = testRace;
  });

  tearDown(() {
    timingData.dispose();
  });

  group('TimingData', () {
    group('addRunnerTimeRecord', () {
      test('adds to currentChunk when there is no conflict', () {
        expect(timingData.currentChunk.hasConflict, isFalse);
        final record = TimingDatum(time: '0:10.00');

        timingData.addRunnerTimeRecord(record);

        expect(timingData.currentChunk.timingData.length, 1);
        expect(timingData.currentChunk.timingData.first, record);
        expect(timingData.currentChunk.hasConflict, isFalse);
      });

      test('throws when record has a conflict', () {
        final record = TimingDatum(
          time: '0:11.00',
          conflict: Conflict(type: ConflictType.missingTime),
        );

        expect(() => timingData.addRunnerTimeRecord(record), throwsException);
      });

      test('caches chunk and starts a new one when current chunk has conflict',
          () {
        timingData.addConfirmRecord(TimingDatum(
          time: '0:12.00',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1),
        ));
        expect(timingData.currentChunk.hasConflict, isTrue);

        final record = TimingDatum(time: '0:13.00');
        timingData.addRunnerTimeRecord(record);

        expect(timingData.currentChunk.hasConflict, isFalse);
        expect(timingData.currentChunk.timingData, [record]);
        expect(timingData.hasTimingData, isTrue);
      });
    });

    group('addConfirmRecord', () {
      test('sets confirmRunner conflict when none exists', () {
        final confirm = TimingDatum(
          time: '0:30.00',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1),
        );

        timingData.addConfirmRecord(confirm);

        expect(timingData.currentChunk.hasConflict, isTrue);
        expect(timingData.currentChunk.conflictRecord, confirm);
      });

      test('updates time when same conflict type already exists', () {
        timingData.addConfirmRecord(TimingDatum(
          time: '0:30.00',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1),
        ));

        timingData.addConfirmRecord(TimingDatum(
          time: '0:31.00',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1),
        ));

        expect(timingData.currentChunk.conflictRecord!.time, '0:31.00');
      });

      test('caches and replaces when previous conflict type differs', () {
        timingData.addMissingTimeRecord(TimingDatum(
          time: '0:32.00',
          conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
        ));

        final confirm = TimingDatum(
          time: '0:33.00',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1),
        );
        timingData.addConfirmRecord(confirm);

        expect(timingData.currentChunk.conflictRecord, confirm);
      });
    });

    group('addMissingTimeRecord', () {
      test('sets missingTime conflict when none exists', () {
        final missing = TimingDatum(
          time: '0:40.00',
          conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
        );

        timingData.addMissingTimeRecord(missing);

        expect(timingData.currentChunk.conflictRecord, isNotNull);
        expect(
          timingData.currentChunk.conflictRecord!.conflict!.type,
          ConflictType.missingTime,
        );
        expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 1);
      });

      test('increments offBy when same conflict type already exists', () {
        timingData.addMissingTimeRecord(TimingDatum(
          time: '0:40.00',
          conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
        ));

        timingData.addMissingTimeRecord(TimingDatum(
          time: '0:41.00',
          conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
        ));

        expect(timingData.currentChunk.conflictRecord!.time, '0:41.00');
        expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 2);
      });

      test('reduces extraTime offBy by one when extraTime conflict exists', () {
        timingData.addExtraTimeRecord(TimingDatum(
          time: '0:42.00',
          conflict: Conflict(type: ConflictType.extraTime, offBy: 2),
        ));

        timingData.addMissingTimeRecord(TimingDatum(
          time: '0:43.00',
          conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
        ));

        expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 1);
        expect(timingData.currentChunk.conflictRecord!.time, '0:43.00');
      });
    });

    group('addExtraTimeRecord', () {
      test('sets extraTime conflict when none exists', () {
        final extra = TimingDatum(
          time: '0:50.00',
          conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
        );

        timingData.addExtraTimeRecord(extra);

        expect(timingData.currentChunk.conflictRecord, isNotNull);
        expect(
          timingData.currentChunk.conflictRecord!.conflict!.type,
          ConflictType.extraTime,
        );
        expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 1);
      });

      test('increments offBy when same conflict type already exists', () {
        timingData.addExtraTimeRecord(TimingDatum(
          time: '0:50.00',
          conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
        ));

        timingData.addExtraTimeRecord(TimingDatum(
          time: '0:51.00',
          conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
        ));

        expect(timingData.currentChunk.conflictRecord!.time, '0:51.00');
        expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 2);
      });

      test('reduces missingTime offBy by one when missingTime conflict exists',
          () {
        timingData.addMissingTimeRecord(TimingDatum(
          time: '0:52.00',
          conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
        ));

        timingData.addExtraTimeRecord(TimingDatum(
          time: '0:53.00',
          conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
        ));

        expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 1);
        expect(timingData.currentChunk.conflictRecord!.time, '0:53.00');
      });
    });

    group('reduceCurrentConflictByOne', () {
      test('decrements offBy', () {
        timingData.addExtraTimeRecord(TimingDatum(
          time: '1:00.00',
          conflict: Conflict(type: ConflictType.extraTime, offBy: 2),
        ));

        timingData.reduceCurrentConflictByOne();

        expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 1);
      });

      test('clears conflict when offBy reaches zero', () {
        timingData.addExtraTimeRecord(TimingDatum(
          time: '1:00.00',
          conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
        ));

        timingData.reduceCurrentConflictByOne();

        expect(timingData.currentChunk.conflictRecord, isNull);
      });

      test('updates time when newTime is provided', () {
        timingData.addMissingTimeRecord(TimingDatum(
          time: '1:10.00',
          conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
        ));

        timingData.reduceCurrentConflictByOne(newTime: '1:11.00');

        expect(timingData.currentChunk.conflictRecord!.time, '1:11.00');
        expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 1);
      });
    });

    group('hasTimingData', () {
      test('is false when no data exists', () {
        expect(timingData.hasTimingData, isFalse);
      });

      test('is true when currentChunk has runner records', () {
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));

        expect(timingData.hasTimingData, isTrue);
      });

      test('is true when currentChunk has a conflict record', () {
        timingData.addConfirmRecord(TimingDatum(
          time: '0:01.00',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1),
        ));

        expect(timingData.hasTimingData, isTrue);
      });

      test('is true when there are cached chunks', () {
        timingData.addConfirmRecord(TimingDatum(
          time: '0:10.00',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1),
        ));
        timingData.cacheCurrentChunk();
        timingData.currentChunk = TimingChunk(id: 1, timingData: []);

        expect(timingData.hasTimingData, isTrue);
      });

      test('is false after clearRecords', () {
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));

        timingData.clearRecords();

        expect(timingData.hasTimingData, isFalse);
      });
    });

    group('encodedRecords', () {
      // Three runners, a confirm checkpoint, two more runners, a confirm
      // checkpoint, then two runners still in the current chunk.
      void logRace() {
        for (final t in ['5:01.00', '5:02.00', '5:03.00']) {
          timingData.addRunnerTimeRecord(TimingDatum(time: t));
        }
        timingData.addConfirmRecord(TimingDatum(
            time: '5:04.00',
            conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1)));
        for (final t in ['5:05.00', '5:06.00']) {
          timingData.addRunnerTimeRecord(TimingDatum(time: t));
        }
        timingData.addConfirmRecord(TimingDatum(
            time: '5:07.00',
            conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1)));
        for (final t in ['5:08.00', '5:09.00']) {
          timingData.addRunnerTimeRecord(TimingDatum(time: t));
        }
      }

      List<String> decode(String encoded) => decodeAndDecompress(encoded).split(',');

      test('encodes every record in finish order', () async {
        logRace();

        expect(decode(await timingData.encodedRecords()), [
          '5:01.00', '5:02.00', '5:03.00', 'CR 1 5:04.00',
          '5:05.00', '5:06.00', 'CR 1 5:07.00',
          '5:08.00', '5:09.00',
        ]);
      });

      test('encodes the same records when shared a second time', () async {
        logRace();
        final first = await timingData.encodedRecords();

        final second = await timingData.encodedRecords();

        expect(decode(second), decode(first));
      });

      test('leaves the runner count unchanged', () async {
        logRace();
        final before = timingData.runnerCount;

        await timingData.encodedRecords();

        expect(timingData.runnerCount, before);
      });

      test('appends a closing confirm with the race duration once stopped',
          () async {
        logRace();
        timingData.raceDuration =
            const Duration(minutes: 5, seconds: 10, milliseconds: 560);

        final records = decode(await timingData.encodedRecords());

        expect(records.last, startsWith('CR '));
        // Same format as the logged times, so the coach reads it correctly.
        final time = records.last.split(' ').last;
        expect(TimeFormatter.loadDurationFromString(time),
            const Duration(minutes: 5, seconds: 10, milliseconds: 560));
      });

      test('does not add the closing confirm to the live current chunk',
          () async {
        logRace();
        timingData.raceDuration = const Duration(minutes: 5, seconds: 10);

        await timingData.encodedRecords();

        expect(timingData.currentChunk.hasConflict, isFalse);
      });
    });

    group('cacheCurrentChunk and deleteCurrentChunk', () {
      test('deleteCurrentChunk restores the cached chunk', () {
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:05.00'));
        timingData.addConfirmRecord(TimingDatum(
          time: '0:06.00',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1),
        ));
        expect(timingData.currentChunk.hasConflict, isTrue);
        timingData.cacheCurrentChunk();
        timingData.currentChunk = TimingChunk(id: 1, timingData: []);

        timingData.deleteCurrentChunk();

        expect(timingData.currentChunk.hasConflict, isTrue);
        expect(
          timingData.currentChunk.conflictRecord!.conflict!.type,
          ConflictType.confirmRunner,
        );
      });

      test('deleteCurrentChunk resets to empty chunk when cache is empty', () {
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));

        timingData.deleteCurrentChunk();

        expect(timingData.currentChunk.timingData, isEmpty);
        expect(timingData.currentChunk.hasConflict, isFalse);
      });
    });

    group('storage stays in step with the chunks', () {
      test('deleteCurrentChunk deletes the removed chunk, not the restored one',
          () async {
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:10.00'));
        timingData.addConfirmRecord(TimingDatum(
            time: '0:11.00',
            conflict: Conflict(type: ConflictType.confirmRunner)));
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:12.00'));
        final removedId = timingData.currentChunk.id;

        timingData.deleteCurrentChunk();
        await timingData.pendingWrites;

        verify(mockStorage.deleteChunk(1, removedId)).called(1);
        verifyNever(mockStorage.deleteChunk(1, timingData.currentChunk.id));
      });

      test('a missing time cancelling the last extra time saves a chunk with no '
          'conflict instead of crashing', () async {
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:10.00'));
        timingData.addExtraTimeRecord(TimingDatum(
            time: '0:11.00', conflict: Conflict(type: ConflictType.extraTime)));
        clearInteractions(mockStorage);

        timingData.addMissingTimeRecord(TimingDatum(
            time: '0:12.00', conflict: Conflict(type: ConflictType.missingTime)));

        expect(timingData.currentChunk.hasConflict, isFalse);
        await timingData.pendingWrites;
        final saved =
            verify(mockStorage.saveChunk(1, captureAny)).captured.last as TimingChunk;
        expect(saved.conflictRecord, isNull);
      });

      test('an extra time cancelling the last missing time does not crash', () {
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:10.00'));
        timingData.addMissingTimeRecord(TimingDatum(
            time: '0:11.00', conflict: Conflict(type: ConflictType.missingTime)));

        timingData.addExtraTimeRecord(TimingDatum(
            time: '0:12.00', conflict: Conflict(type: ConflictType.extraTime)));

        expect(timingData.currentChunk.hasConflict, isFalse);
      });
    });

    group('clearRecords', () {
      test('resets chunk, cache, and start/end times', () {
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));
        timingData.addConfirmRecord(TimingDatum(
          time: '0:01.00',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1),
        ));
        timingData.cacheCurrentChunk();
        expect(timingData.hasTimingData, isTrue);

        timingData.clearRecords();

        expect(timingData.currentChunk.timingData, isEmpty);
        expect(timingData.currentChunk.hasConflict, isFalse);
        expect(timingData.startTime, isNull);
        expect(timingData.raceDuration, isNull);
        expect(timingData.hasTimingData, isFalse);
      });
    });

    group('uiRecords', () {
      test('returns runner records from currentChunk with sequential places',
          () {
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:02.00'));

        final records = timingData.uiRecords;

        expect(records.length, 2);
        expect(records[0].time, '0:01.00');
        expect(records[0].place, 1);
        expect(records[1].time, '0:02.00');
        expect(records[1].place, 2);
      });

      test('includes TBD entries for missingTime conflicts', () {
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));
        timingData.addMissingTimeRecord(TimingDatum(
          time: '0:02.00',
          conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
        ));

        final records = timingData.uiRecords;

        // 1 runner + 2 TBD
        expect(records.length, 3);
        expect(records[0].time, '0:01.00');
        expect(records[1].time, 'TBD');
        expect(records[2].time, 'TBD');
      });

      test('combines cached and current chunk records with correct places', () {
        // First chunk: 2 runners + confirm
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:02.00'));
        timingData.addConfirmRecord(TimingDatum(
          time: '0:02.00',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1),
        ));
        timingData.cacheCurrentChunk();

        // New current chunk: 1 runner
        timingData.currentChunk = TimingChunk(id: 1, timingData: []);
        timingData.addRunnerTimeRecord(TimingDatum(time: '0:03.00'));

        final records = timingData.uiRecords;

        // 2 runners + 1 confirm + 1 runner = 4
        expect(records.length, 4);
        expect(records[0].time, '0:01.00');
        expect(records[1].time, '0:02.00');
        expect(records[3].time, '0:03.00');
        expect(records[3].place, 3);
      });
    });
  });
}
