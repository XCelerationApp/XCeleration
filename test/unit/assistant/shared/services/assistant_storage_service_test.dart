import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/assistant/shared/models/bib_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/assistant/shared/services/assistant_storage_service.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Clear all data between tests to keep each test hermetic.
  setUp(() async {
    final db = await AssistantStorageService.instance.database;
    await db.delete('bib_records');
    await db.delete('timing_chunks');
    await db.delete('runners');
    await db.delete('race_history');
  });

  group('AssistantStorageService', () {
    // =========================================================================
    // Race Methods
    // =========================================================================
    group('Race Methods', () {
      group('saveNewRace', () {
        test('saves a new race and returns Success', () async {
          final race = RaceRecord(
            raceId: 1,
            date: DateTime(2024, 1, 1),
            name: 'State Meet',
            type: DeviceName.raceTimer.toString(),
          );

          final result =
              await AssistantStorageService.instance.saveNewRace(race);

          expect(result, isA<Success<void>>());
        });

        test('returns Failure when race with same id and type already exists',
            () async {
          final race = RaceRecord(
            raceId: 1,
            date: DateTime(2024, 1, 1),
            name: 'State Meet',
            type: DeviceName.raceTimer.toString(),
          );
          await AssistantStorageService.instance.saveNewRace(race);

          final result =
              await AssistantStorageService.instance.saveNewRace(race);

          expect(result, isA<Failure<void>>());
          expect((result as Failure).error.userMessage, 'Race is already loaded.');
        });

        test('allows two races with same id but different type', () async {
          final timerRace = RaceRecord(
            raceId: 2,
            date: DateTime(2024, 1, 1),
            name: 'Meet',
            type: DeviceName.raceTimer.toString(),
          );
          final bibRace = RaceRecord(
            raceId: 2,
            date: DateTime(2024, 1, 1),
            name: 'Meet',
            type: DeviceName.bibRecorder.toString(),
          );

          final r1 =
              await AssistantStorageService.instance.saveNewRace(timerRace);
          final r2 =
              await AssistantStorageService.instance.saveNewRace(bibRace);

          expect(r1, isA<Success<void>>());
          expect(r2, isA<Success<void>>());
        });
      });

      group('getRace', () {
        test('returns the race when it exists', () async {
          final race = RaceRecord(
            raceId: 3,
            date: DateTime(2024, 1, 1),
            name: 'Invitational',
            type: DeviceName.raceTimer.toString(),
          );
          await AssistantStorageService.instance.saveNewRace(race);

          final result = await AssistantStorageService.instance
              .getRace(3, DeviceName.raceTimer.toString());

          expect(result, isA<Success<RaceRecord?>>());
          expect((result as Success).value?.name, 'Invitational');
        });

        test('returns Success(null) when race does not exist', () async {
          final result = await AssistantStorageService.instance
              .getRace(999, DeviceName.raceTimer.toString());

          expect(result, isA<Success<RaceRecord?>>());
          expect((result as Success).value, isNull);
        });
      });

      group('getRaces', () {
        test('returns all races of the given type', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 4,
              date: DateTime(2024, 1, 1),
              name: 'Race 1',
              type: DeviceName.raceTimer.toString()));
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 5,
              date: DateTime(2024, 1, 2),
              name: 'Race 2',
              type: DeviceName.raceTimer.toString()));

          final result = await AssistantStorageService.instance
              .getRaces(DeviceName.raceTimer.toString());

          expect(result, isA<Success<List<RaceRecord>>>());
          expect((result as Success).value.length, 2);
        });

        test('returns empty list when no races exist for type', () async {
          final result = await AssistantStorageService.instance
              .getRaces(DeviceName.raceTimer.toString());

          expect(result, isA<Success<List<RaceRecord>>>());
          expect((result as Success).value, isEmpty);
        });

        test('filters results by type', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 6,
              date: DateTime(2024, 1, 1),
              name: 'Timer Race',
              type: DeviceName.raceTimer.toString()));
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 7,
              date: DateTime(2024, 1, 1),
              name: 'Bib Race',
              type: DeviceName.bibRecorder.toString()));

          final result = await AssistantStorageService.instance
              .getRaces(DeviceName.raceTimer.toString());

          expect(result, isA<Success<List<RaceRecord>>>());
          final races = (result as Success).value;
          expect(races.every((r) => r.type == DeviceName.raceTimer.toString()),
              isTrue);
        });
      });

      group('getRecentRaces', () {
        test('returns only races within the default 7-day window', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 8,
              date: DateTime.now(),
              name: 'Recent',
              type: DeviceName.raceTimer.toString()));
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 9,
              date: DateTime.now().subtract(const Duration(days: 10)),
              name: 'Old',
              type: DeviceName.raceTimer.toString()));

          final result = await AssistantStorageService.instance
              .getRecentRaces(DeviceName.raceTimer.toString());

          expect(result, isA<Success<List<RaceRecord>>>());
          final races = (result as Success).value;
          expect(races.any((r) => r.name == 'Recent'), isTrue);
          expect(races.any((r) => r.name == 'Old'), isFalse);
        });
      });

      group('updateRace', () {
        test('updates an existing race and returns Success', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 10,
              date: DateTime(2024, 1, 1),
              name: 'Old Name',
              type: DeviceName.raceTimer.toString()));

          final updated = RaceRecord(
              raceId: 10,
              date: DateTime(2024, 1, 1),
              name: 'New Name',
              type: DeviceName.raceTimer.toString());
          final result =
              await AssistantStorageService.instance.updateRace(updated);

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getRace(10, DeviceName.raceTimer.toString());
          expect((fetched as Success).value?.name, 'New Name');
        });
      });

      group('updateRaceDuration', () {
        test('persists the new duration', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 11,
              date: DateTime(2024, 1, 1),
              name: 'Race',
              type: DeviceName.raceTimer.toString()));

          final result =
              await AssistantStorageService.instance.updateRaceDuration(
                  11, DeviceName.raceTimer.toString(), const Duration(minutes: 30));

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getRace(11, DeviceName.raceTimer.toString());
          expect((fetched as Success).value?.duration, const Duration(minutes: 30));
        });

        test('clears duration when null is passed', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 12,
              date: DateTime(2024, 1, 1),
              name: 'Race',
              type: DeviceName.raceTimer.toString(),
              duration: const Duration(minutes: 10)));

          await AssistantStorageService.instance.updateRaceDuration(
              12, DeviceName.raceTimer.toString(), null);

          final fetched = await AssistantStorageService.instance
              .getRace(12, DeviceName.raceTimer.toString());
          expect((fetched as Success).value?.duration, isNull);
        });
      });

      group('updateRaceStartTime', () {
        test('persists the start time', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 13,
              date: DateTime(2024, 1, 1),
              name: 'Race',
              type: DeviceName.raceTimer.toString()));

          final startTime = DateTime(2024, 1, 1, 9, 0);
          final result =
              await AssistantStorageService.instance.updateRaceStartTime(
                  13, DeviceName.raceTimer.toString(), startTime);

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getRace(13, DeviceName.raceTimer.toString());
          expect(
            (fetched as Success).value?.startedAt?.millisecondsSinceEpoch,
            startTime.millisecondsSinceEpoch,
          );
        });
      });

      group('updateRaceStatus', () {
        test('sets stopped to true', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 14,
              date: DateTime(2024, 1, 1),
              name: 'Race',
              type: DeviceName.raceTimer.toString(),
              stopped: false));

          final result = await AssistantStorageService.instance
              .updateRaceStatus(14, DeviceName.raceTimer.toString(), true);

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getRace(14, DeviceName.raceTimer.toString());
          expect((fetched as Success).value?.stopped, isTrue);
        });

        test('sets stopped to false', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 15,
              date: DateTime(2024, 1, 1),
              name: 'Race',
              type: DeviceName.raceTimer.toString(),
              stopped: true));

          await AssistantStorageService.instance
              .updateRaceStatus(15, DeviceName.raceTimer.toString(), false);

          final fetched = await AssistantStorageService.instance
              .getRace(15, DeviceName.raceTimer.toString());
          expect((fetched as Success).value?.stopped, isFalse);
        });
      });

      group('deleteRace', () {
        test('deletes the race and returns Success', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 16,
              date: DateTime(2024, 1, 1),
              name: 'Race',
              type: DeviceName.raceTimer.toString()));

          final result = await AssistantStorageService.instance
              .deleteRace(16, DeviceName.raceTimer.toString());

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getRace(16, DeviceName.raceTimer.toString());
          expect((fetched as Success).value, isNull);
        });

        test('deletes associated timing chunks when race is deleted', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 17,
              date: DateTime(2024, 1, 1),
              name: 'Race',
              type: DeviceName.raceTimer.toString()));
          await AssistantStorageService.instance.saveChunk(
              17, TimingChunk(id: 1, timingData: [TimingDatum(time: '0:01.00')]));

          await AssistantStorageService.instance
              .deleteRace(17, DeviceName.raceTimer.toString());

          final chunks =
              await AssistantStorageService.instance.getChunks(17);
          expect((chunks as Success).value, isEmpty);
        });
      });

      group('deleteOldRaces', () {
        test('deletes races older than specified duration', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 18,
              date: DateTime.now().subtract(const Duration(days: 10)),
              name: 'Old Race',
              type: DeviceName.raceTimer.toString()));

          final result = await AssistantStorageService.instance
              .deleteOldRaces(olderThan: const Duration(days: 7));

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getRace(18, DeviceName.raceTimer.toString());
          expect((fetched as Success).value, isNull);
        });

        test('keeps races newer than specified duration', () async {
          await AssistantStorageService.instance.saveNewRace(RaceRecord(
              raceId: 19,
              date: DateTime.now(),
              name: 'New Race',
              type: DeviceName.raceTimer.toString()));

          await AssistantStorageService.instance
              .deleteOldRaces(olderThan: const Duration(days: 7));

          final fetched = await AssistantStorageService.instance
              .getRace(19, DeviceName.raceTimer.toString());
          expect((fetched as Success).value, isNotNull);
        });
      });
    });

    // =========================================================================
    // Timing Chunk Methods
    // =========================================================================
    group('Timing Chunk Methods', () {
      const kRaceId = 20;
      final kRace = RaceRecord(
        raceId: kRaceId,
        date: DateTime(2024, 1, 1),
        name: 'Chunk Race',
        type: DeviceName.raceTimer.toString(),
      );

      setUp(() async {
        await AssistantStorageService.instance.saveNewRace(kRace);
      });

      group('saveChunk / getChunk', () {
        test('saves a chunk and retrieves it by id', () async {
          final chunk = TimingChunk(
              id: 1,
              timingData: [
                TimingDatum(time: '0:01.00'),
                TimingDatum(time: '0:02.00')
              ]);

          await AssistantStorageService.instance.saveChunk(kRaceId, chunk);
          final result =
              await AssistantStorageService.instance.getChunk(kRaceId, 1);

          expect(result, isA<Success<TimingChunk?>>());
          final retrieved = (result as Success).value;
          expect(retrieved?.id, 1);
          expect(retrieved?.timingData.length, 2);
        });

        test('returns Success(null) when chunk does not exist', () async {
          final result =
              await AssistantStorageService.instance.getChunk(kRaceId, 999);

          expect(result, isA<Success<TimingChunk?>>());
          expect((result as Success).value, isNull);
        });

        test('saves a chunk with a conflict record', () async {
          final conflict = TimingDatum(
              time: '0:01.00',
              conflict: Conflict(type: ConflictType.missingTime, offBy: 1));
          final chunk = TimingChunk(
              id: 2,
              timingData: [TimingDatum(time: '0:01.00')],
              conflictRecord: conflict);

          await AssistantStorageService.instance.saveChunk(kRaceId, chunk);
          final result =
              await AssistantStorageService.instance.getChunk(kRaceId, 2);

          expect((result as Success).value?.conflictRecord, isNotNull);
        });
      });

      group('getChunks', () {
        test('returns all chunks for a race', () async {
          await AssistantStorageService.instance.saveChunk(
              kRaceId, TimingChunk(id: 1, timingData: [TimingDatum(time: '0:01.00')]));
          await AssistantStorageService.instance.saveChunk(
              kRaceId, TimingChunk(id: 2, timingData: [TimingDatum(time: '0:02.00')]));

          final result =
              await AssistantStorageService.instance.getChunks(kRaceId);

          expect(result, isA<Success<List<TimingChunk>>>());
          expect((result as Success).value.length, 2);
        });

        test('returns empty list when no chunks exist', () async {
          final result =
              await AssistantStorageService.instance.getChunks(kRaceId);

          expect(result, isA<Success<List<TimingChunk>>>());
          expect((result as Success).value, isEmpty);
        });
      });

      group('getChunkTimingData', () {
        test('returns raw timing data string for a saved chunk', () async {
          await AssistantStorageService.instance.saveChunk(
              kRaceId, TimingChunk(id: 3, timingData: [TimingDatum(time: '0:01.00')]));

          final result = await AssistantStorageService.instance
              .getChunkTimingData(kRaceId, 3);

          expect(result, isA<Success<String?>>());
          expect((result as Success).value, isNotNull);
          expect((result as Success).value, contains('0:01.00'));
        });

        test('returns Success(null) when chunk does not exist', () async {
          final result = await AssistantStorageService.instance
              .getChunkTimingData(kRaceId, 999);

          expect(result, isA<Success<String?>>());
          expect((result as Success).value, isNull);
        });
      });

      group('deleteChunk', () {
        test('deletes a single chunk by id', () async {
          await AssistantStorageService.instance.saveChunk(
              kRaceId, TimingChunk(id: 4, timingData: [TimingDatum(time: '0:01.00')]));

          final result =
              await AssistantStorageService.instance.deleteChunk(kRaceId, 4);

          expect(result, isA<Success<void>>());
          final fetched =
              await AssistantStorageService.instance.getChunk(kRaceId, 4);
          expect((fetched as Success).value, isNull);
        });
      });

      group('deleteChunks', () {
        test('deletes all chunks for a race', () async {
          await AssistantStorageService.instance.saveChunk(
              kRaceId, TimingChunk(id: 5, timingData: [TimingDatum(time: '0:01.00')]));
          await AssistantStorageService.instance.saveChunk(
              kRaceId, TimingChunk(id: 6, timingData: [TimingDatum(time: '0:02.00')]));

          final result =
              await AssistantStorageService.instance.deleteChunks(kRaceId);

          expect(result, isA<Success<void>>());
          final all =
              await AssistantStorageService.instance.getChunks(kRaceId);
          expect((all as Success).value, isEmpty);
        });
      });

      group('saveChunkConflict', () {
        test('writes the conflict record to an existing chunk', () async {
          await AssistantStorageService.instance.saveChunk(
              kRaceId, TimingChunk(id: 7, timingData: [TimingDatum(time: '0:01.00')]));

          final conflict = TimingDatum(
              time: '0:01.00',
              conflict: Conflict(type: ConflictType.missingTime, offBy: 1));
          final result = await AssistantStorageService.instance
              .saveChunkConflict(kRaceId, 7, conflict);

          expect(result, isA<Success<void>>());
          final retrieved =
              await AssistantStorageService.instance.getChunk(kRaceId, 7);
          expect((retrieved as Success).value?.conflictRecord, isNotNull);
        });
      });

      group('updateChunkTimingData', () {
        // Note: the production implementation passes an un-awaited Future<String>
        // to db.update, causing SQLite to throw a type error. The method always
        // returns Failure as a result of this bug.
        test('returns Failure due to missing await on encodeTimeRecords',
            () async {
          await AssistantStorageService.instance.saveChunk(
              kRaceId, TimingChunk(id: 8, timingData: [TimingDatum(time: '0:01.00')]));

          final result = await AssistantStorageService.instance
              .updateChunkTimingData(
                  kRaceId, 8, [TimingDatum(time: '0:03.00')]);

          expect(result, isA<Failure<void>>());
        });
      });

      group('addLoggedTimingDatum', () {
        test('appends a datum to a chunk with existing timing data', () async {
          await AssistantStorageService.instance.saveChunk(
              kRaceId, TimingChunk(id: 9, timingData: [TimingDatum(time: '0:01.00')]));

          final result = await AssistantStorageService.instance
              .addLoggedTimingDatum(kRaceId, 9, TimingDatum(time: '0:02.00'));

          expect(result, isA<Success<void>>());
          final retrieved =
              await AssistantStorageService.instance.getChunk(kRaceId, 9);
          expect((retrieved as Success).value?.timingData.length, 2);
        });

        test('adds a datum when chunk has no existing timing data', () async {
          await AssistantStorageService.instance
              .saveChunk(kRaceId, TimingChunk(id: 10, timingData: []));

          final result = await AssistantStorageService.instance
              .addLoggedTimingDatum(kRaceId, 10, TimingDatum(time: '0:01.00'));

          expect(result, isA<Success<void>>());
          final retrieved =
              await AssistantStorageService.instance.getChunk(kRaceId, 10);
          expect((retrieved as Success).value?.timingData.length, 1);
        });
      });

      group('Legacy chunk conflict/timing-data methods', () {
        // These methods reference tables that don't exist in the schema
        // (chunk_conflicts, chunk_timing_data). They always return Failure.
        test('updateChunkConflict returns Failure for non-existent table',
            () async {
          final result =
              await AssistantStorageService.instance.updateChunkConflict(
                  '1',
                  TimingDatum(
                      time: '0:01.00',
                      conflict:
                          Conflict(type: ConflictType.missingTime, offBy: 1)));

          expect(result, isA<Failure<void>>());
        });

        test('getChunkConflict returns Failure for non-existent table',
            () async {
          final result =
              await AssistantStorageService.instance.getChunkConflict('1');

          expect(result, isA<Failure<String?>>());
        });

        test('saveChunkTimingData returns Failure for non-existent table',
            () async {
          final result = await AssistantStorageService.instance
              .saveChunkTimingData('1', ['0:01.00']);

          expect(result, isA<Failure<void>>());
        });
      });
    });

    // =========================================================================
    // Runner Methods
    // =========================================================================
    group('Runner Methods', () {
      const kRaceId = 30;
      final kRace = RaceRecord(
        raceId: kRaceId,
        date: DateTime(2024, 1, 1),
        name: 'Runner Race',
        type: DeviceName.raceTimer.toString(),
      );
      final kBase = DateTime(2024, 1, 1);

      setUp(() async {
        await AssistantStorageService.instance.saveNewRace(kRace);
      });

      group('saveRunner / getRunner', () {
        test('saves a runner and retrieves it by bib number', () async {
          final runner = Runner(
              raceId: kRaceId, bibNumber: '101', name: 'Alice', createdAt: kBase);

          await AssistantStorageService.instance.saveRunner(runner);
          final result =
              await AssistantStorageService.instance.getRunner(kRaceId, '101');

          expect(result, isA<Success<Runner?>>());
          expect((result as Success).value?.name, 'Alice');
        });

        test('returns Success(null) when runner does not exist', () async {
          final result = await AssistantStorageService.instance
              .getRunner(kRaceId, '999');

          expect(result, isA<Success<Runner?>>());
          expect((result as Success).value, isNull);
        });

        test('replaces runner on conflict (same race_id + bib_number)', () async {
          final original =
              Runner(raceId: kRaceId, bibNumber: '102', name: 'Bob', createdAt: kBase);
          final replacement =
              Runner(raceId: kRaceId, bibNumber: '102', name: 'Bobby', createdAt: kBase);

          await AssistantStorageService.instance.saveRunner(original);
          await AssistantStorageService.instance.saveRunner(replacement);

          final result =
              await AssistantStorageService.instance.getRunner(kRaceId, '102');
          expect((result as Success).value?.name, 'Bobby');
        });
      });

      group('getRunners', () {
        test('returns all runners for a race in insertion order', () async {
          await AssistantStorageService.instance.saveRunner(
              Runner(raceId: kRaceId, bibNumber: '103', name: 'Carol', createdAt: kBase));
          await AssistantStorageService.instance.saveRunner(Runner(
              raceId: kRaceId,
              bibNumber: '104',
              name: 'Dan',
              createdAt: kBase.add(const Duration(seconds: 1))));

          final result =
              await AssistantStorageService.instance.getRunners(kRaceId);

          expect(result, isA<Success<List<Runner>>>());
          expect((result as Success).value.length, 2);
        });

        test('returns empty list when no runners exist for race', () async {
          final result =
              await AssistantStorageService.instance.getRunners(kRaceId);

          expect(result, isA<Success<List<Runner>>>());
          expect((result as Success).value, isEmpty);
        });
      });

      group('saveRunners', () {
        test('replaces all existing runners for a race', () async {
          await AssistantStorageService.instance.saveRunner(
              Runner(raceId: kRaceId, bibNumber: '105', name: 'Eve', createdAt: kBase));

          final newRunners = [
            Runner(raceId: kRaceId, bibNumber: '106', name: 'Frank', createdAt: kBase),
            Runner(
                raceId: kRaceId,
                bibNumber: '107',
                name: 'Grace',
                createdAt: kBase.add(const Duration(seconds: 1))),
          ];
          final result = await AssistantStorageService.instance
              .saveRunners(kRaceId, newRunners);

          expect(result, isA<Success<void>>());
          final all =
              await AssistantStorageService.instance.getRunners(kRaceId);
          final names = (all as Success).value.map((r) => r.name).toList();
          expect(names, containsAll(['Frank', 'Grace']));
          expect(names, isNot(contains('Eve')));
        });

        test('saves an empty list (clears all runners)', () async {
          await AssistantStorageService.instance.saveRunner(
              Runner(raceId: kRaceId, bibNumber: '108', name: 'Henry', createdAt: kBase));

          await AssistantStorageService.instance.saveRunners(kRaceId, []);

          final all =
              await AssistantStorageService.instance.getRunners(kRaceId);
          expect((all as Success).value, isEmpty);
        });
      });

      group('updateRunner', () {
        test('updates name and team fields', () async {
          await AssistantStorageService.instance.saveRunner(
              Runner(raceId: kRaceId, bibNumber: '109', name: 'Old', createdAt: kBase));

          final updated = Runner(
              raceId: kRaceId,
              bibNumber: '109',
              name: 'New',
              teamAbbreviation: 'XC',
              createdAt: kBase);
          final result =
              await AssistantStorageService.instance.updateRunner(updated);

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getRunner(kRaceId, '109');
          expect((fetched as Success).value?.name, 'New');
          expect((fetched as Success).value?.teamAbbreviation, 'XC');
        });
      });

      group('deleteRunner', () {
        test('removes a single runner by bib number', () async {
          await AssistantStorageService.instance.saveRunner(
              Runner(raceId: kRaceId, bibNumber: '110', name: 'Iris', createdAt: kBase));

          final result = await AssistantStorageService.instance
              .deleteRunner(kRaceId, '110');

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getRunner(kRaceId, '110');
          expect((fetched as Success).value, isNull);
        });
      });

      group('deleteRunners', () {
        test('removes all runners for a race', () async {
          await AssistantStorageService.instance.saveRunner(
              Runner(raceId: kRaceId, bibNumber: '111', createdAt: kBase));
          await AssistantStorageService.instance.saveRunner(
              Runner(raceId: kRaceId, bibNumber: '112', createdAt: kBase));

          final result =
              await AssistantStorageService.instance.deleteRunners(kRaceId);

          expect(result, isA<Success<void>>());
          final all =
              await AssistantStorageService.instance.getRunners(kRaceId);
          expect((all as Success).value, isEmpty);
        });
      });
    });

    // =========================================================================
    // Bib Record Methods
    // =========================================================================
    group('Bib Record Methods', () {
      const kRaceId = 40;
      final kRace = RaceRecord(
        raceId: kRaceId,
        date: DateTime(2024, 1, 1),
        name: 'Bib Race',
        type: DeviceName.bibRecorder.toString(),
      );
      final kBase = DateTime(2024, 1, 1);

      setUp(() async {
        await AssistantStorageService.instance.saveNewRace(kRace);
      });

      group('saveBibRecord / getBibRecord', () {
        test('saves a bib record and retrieves it by bib id', () async {
          final bib = BibRecord(
              raceId: kRaceId, bibId: 1, bibNumber: '201', createdAt: kBase);

          await AssistantStorageService.instance.saveBibRecord(bib);
          final result =
              await AssistantStorageService.instance.getBibRecord(kRaceId, 1);

          expect(result, isA<Success<BibRecord?>>());
          expect((result as Success).value?.bibNumber, '201');
        });

        test('returns Success(null) when bib record does not exist', () async {
          final result = await AssistantStorageService.instance
              .getBibRecord(kRaceId, 999);

          expect(result, isA<Success<BibRecord?>>());
          expect((result as Success).value, isNull);
        });
      });

      group('getBibRecords', () {
        test('returns all bib records for a race', () async {
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 2, bibNumber: '202', createdAt: kBase));
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 3, bibNumber: '203', createdAt: kBase));

          final result =
              await AssistantStorageService.instance.getBibRecords(kRaceId);

          expect(result, isA<Success<List<BibRecord>>>());
          expect((result as Success).value.length, 2);
        });

        test('returns empty list when no bib records exist', () async {
          final result =
              await AssistantStorageService.instance.getBibRecords(kRaceId);

          expect(result, isA<Success<List<BibRecord>>>());
          expect((result as Success).value, isEmpty);
        });
      });

      group('addBibRecord', () {
        test('creates a bib record from components', () async {
          final result = await AssistantStorageService.instance
              .addBibRecord(kRaceId, 4, '204');

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getBibRecord(kRaceId, 4);
          expect((fetched as Success).value?.bibNumber, '204');
        });
      });

      group('removeBibRecord', () {
        test('removes a bib record by race_id and bib_id', () async {
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 5, bibNumber: '205', createdAt: kBase));

          final result = await AssistantStorageService.instance
              .removeBibRecord(kRaceId, 5);

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getBibRecord(kRaceId, 5);
          expect((fetched as Success).value, isNull);
        });
      });

      group('updateBibRecordValue', () {
        test('updates the bib number for a given bib id', () async {
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 6, bibNumber: '206', createdAt: kBase));

          final result = await AssistantStorageService.instance
              .updateBibRecordValue(kRaceId, 6, '260');

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getBibRecord(kRaceId, 6);
          expect((fetched as Success).value?.bibNumber, '260');
        });
      });

      group('updateBibRecord', () {
        test('replaces the full bib record', () async {
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 7, bibNumber: '207', createdAt: kBase));

          final updated = BibRecord(
              raceId: kRaceId,
              bibId: 7,
              bibNumber: '270',
              createdAt: kBase.add(const Duration(hours: 1)));
          final result =
              await AssistantStorageService.instance.updateBibRecord(updated);

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getBibRecord(kRaceId, 7);
          expect((fetched as Success).value?.bibNumber, '270');
        });
      });

      group('deleteBibRecord', () {
        test('deletes a single bib record by id', () async {
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 8, bibNumber: '208', createdAt: kBase));

          final result = await AssistantStorageService.instance
              .deleteBibRecord(kRaceId, 8);

          expect(result, isA<Success<void>>());
          final fetched = await AssistantStorageService.instance
              .getBibRecord(kRaceId, 8);
          expect((fetched as Success).value, isNull);
        });
      });

      group('deleteBibRecords', () {
        test('deletes all bib records for a race', () async {
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 9, bibNumber: '209', createdAt: kBase));
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 10, bibNumber: '210', createdAt: kBase));

          final result =
              await AssistantStorageService.instance.deleteBibRecords(kRaceId);

          expect(result, isA<Success<void>>());
          final all =
              await AssistantStorageService.instance.getBibRecords(kRaceId);
          expect((all as Success).value, isEmpty);
        });
      });

      group('saveBibRecords', () {
        test('replaces all existing bib records for a race', () async {
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 11, bibNumber: '211', createdAt: kBase));

          final newBibs = [
            BibRecord(raceId: kRaceId, bibId: 12, bibNumber: '212', createdAt: kBase),
            BibRecord(raceId: kRaceId, bibId: 13, bibNumber: '213', createdAt: kBase),
          ];
          final result = await AssistantStorageService.instance
              .saveBibRecords(kRaceId, newBibs);

          expect(result, isA<Success<void>>());
          final all =
              await AssistantStorageService.instance.getBibRecords(kRaceId);
          final ids = (all as Success).value.map((b) => b.bibId).toList();
          expect(ids, containsAll([12, 13]));
          expect(ids, isNot(contains(11)));
        });

        test('saves an empty list (clears all bib records)', () async {
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 14, bibNumber: '214', createdAt: kBase));

          await AssistantStorageService.instance.saveBibRecords(kRaceId, []);

          final all =
              await AssistantStorageService.instance.getBibRecords(kRaceId);
          expect((all as Success).value, isEmpty);
        });
      });

      group('getNextBibId', () {
        test('returns 1 when no bib records exist for the race', () async {
          final result =
              await AssistantStorageService.instance.getNextBibId(kRaceId);

          expect(result, isA<Success<int>>());
          expect((result as Success).value, 1);
        });

        test('returns max bib_id + 1 when records exist', () async {
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 15, bibNumber: '215', createdAt: kBase));
          await AssistantStorageService.instance.saveBibRecord(
              BibRecord(raceId: kRaceId, bibId: 20, bibNumber: '216', createdAt: kBase));

          final result =
              await AssistantStorageService.instance.getNextBibId(kRaceId);

          expect(result, isA<Success<int>>());
          expect((result as Success).value, 21);
        });
      });
    });
  });
}
