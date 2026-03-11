import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/repositories/results_repository.dart';
import 'package:xceleration/core/utils/local_schema.dart';
import 'package:xceleration/shared/models/database/base_models.dart';

class _InMemoryConnectionProvider implements IDatabaseConnectionProvider {
  Database? _db;

  @override
  Future<Database> get database async {
    _db ??= await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final stmt in splitSqlStatements(localSchemaSql)) {
            await db.execute(stmt);
          }
        },
      ),
    );
    return _db!;
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  @override
  Future<void> deleteDatabase() async {
    _db = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late _InMemoryConnectionProvider connProvider;
  late ResultsRepository repo;

  setUp(() {
    connProvider = _InMemoryConnectionProvider();
    repo = ResultsRepository(conn: connProvider);
  });

  tearDown(() async {
    await connProvider.close();
  });

  // Inserts a race row and returns its id.
  Future<int> insertRace({String name = 'Test Race'}) async {
    final db = await connProvider.database;
    return db.insert('races', {
      'name': name,
      'flow_state': Race.FLOW_SETUP,
      'is_dirty': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Inserts a runner row and returns its id.
  Future<int> insertRunner({String name = 'Alice', String bib = '100', int grade = 11}) async {
    final db = await connProvider.database;
    return db.insert('runners', {
      'name': name,
      'bib_number': bib,
      'grade': grade,
      'is_dirty': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Inserts a team row and returns its id.
  Future<int> insertTeam({String name = 'Eagles'}) async {
    final db = await connProvider.database;
    return db.insert('teams', {
      'name': name,
      'abbreviation': name.substring(0, 2).toUpperCase(),
      'color': 0xFF2196F3,
      'is_dirty': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Builds a valid RaceResult backed by real DB ids.
  RaceResult buildResult({
    required int raceId,
    required int runnerId,
    required int teamId,
    int place = 1,
    Duration finishTime = const Duration(minutes: 12, seconds: 34),
  }) {
    return RaceResult(
      raceId: raceId,
      runner: Runner(
        runnerId: runnerId,
        name: 'Alice',
        bibNumber: '100',
        grade: 11,
      ),
      team: Team(
        teamId: teamId,
        name: 'Eagles',
        abbreviation: 'EA',
        color: const Color(0xFF2196F3),
      ),
      place: place,
      finishTime: finishTime,
      isDirty: 1,
    );
  }

  group('ResultsRepository', () {
    // =========================================================================
    // addRaceResult
    // =========================================================================

    group('addRaceResult', () {
      test('inserts a valid result', () async {
        final raceId = await insertRace();
        final runnerId = await insertRunner();
        final teamId = await insertTeam();
        final result = buildResult(raceId: raceId, runnerId: runnerId, teamId: teamId);
        await repo.addRaceResult(result);
        final fetched = await repo.getRaceResult(result);
        expect(fetched, isNotNull);
        expect(fetched!.place, 1);
      });

      test('throws when result for same runner in same race already exists', () async {
        final raceId = await insertRace();
        final runnerId = await insertRunner();
        final teamId = await insertTeam();
        final result = buildResult(raceId: raceId, runnerId: runnerId, teamId: teamId);
        await repo.addRaceResult(result);
        expect(() => repo.addRaceResult(result), throwsException);
      });
    });

    // =========================================================================
    // getRaceResult
    // =========================================================================

    group('getRaceResult', () {
      test('returns result for known raceId + runnerId', () async {
        final raceId = await insertRace();
        final runnerId = await insertRunner();
        final teamId = await insertTeam();
        final result = buildResult(raceId: raceId, runnerId: runnerId, teamId: teamId);
        await repo.addRaceResult(result);
        final fetched = await repo.getRaceResult(result);
        expect(fetched, isNotNull);
        expect(fetched!.raceId, raceId);
      });

      test('returns null when no result exists', () async {
        final raceId = await insertRace();
        final runnerId = await insertRunner();
        final teamId = await insertTeam();
        final query = buildResult(raceId: raceId, runnerId: runnerId, teamId: teamId);
        expect(await repo.getRaceResult(query), isNull);
      });

      test('throws when raceId is null', () async {
        final teamId = await insertTeam();
        final noRaceId = RaceResult(
          raceId: null,
          runner: Runner(runnerId: 1, name: 'Alice', bibNumber: '100', grade: 11),
          team: Team(teamId: teamId, name: 'Eagles', abbreviation: 'EA', color: const Color(0xFF2196F3)),
          place: 1,
          finishTime: const Duration(minutes: 10),
        );
        expect(() => repo.getRaceResult(noRaceId), throwsException);
      });

      test('throws when runner runnerId is null', () async {
        final raceId = await insertRace();
        final teamId = await insertTeam();
        final noRunnerId = RaceResult(
          raceId: raceId,
          runner: const Runner(name: 'Alice', bibNumber: '100', grade: 11),
          team: Team(teamId: teamId, name: 'Eagles', abbreviation: 'EA', color: const Color(0xFF2196F3)),
          place: 1,
          finishTime: const Duration(minutes: 10),
        );
        expect(() => repo.getRaceResult(noRunnerId), throwsException);
      });
    });

    // =========================================================================
    // getRaceResults
    // =========================================================================

    group('getRaceResults', () {
      test('returns results ordered by place', () async {
        final raceId = await insertRace();
        final r1 = await insertRunner(name: 'Alice', bib: '1');
        final r2 = await insertRunner(name: 'Bob', bib: '2');
        final teamId = await insertTeam();
        await repo.addRaceResult(buildResult(
            raceId: raceId, runnerId: r1, teamId: teamId, place: 2,
            finishTime: const Duration(minutes: 13)));
        await repo.addRaceResult(buildResult(
            raceId: raceId, runnerId: r2, teamId: teamId, place: 1,
            finishTime: const Duration(minutes: 12)));
        final results = await repo.getRaceResults(raceId);
        expect(results.length, 2);
        expect(results.first.place, 1);
        expect(results.last.place, 2);
      });

      test('returns empty list when no results for race', () async {
        final raceId = await insertRace();
        expect(await repo.getRaceResults(raceId), isEmpty);
      });
    });

    // =========================================================================
    // saveRaceResults
    // =========================================================================

    group('saveRaceResults', () {
      test('replaces all results for a race', () async {
        final raceId = await insertRace();
        final r1 = await insertRunner(name: 'Alice', bib: '1');
        final r2 = await insertRunner(name: 'Bob', bib: '2');
        final teamId = await insertTeam();
        await repo.addRaceResult(buildResult(
            raceId: raceId, runnerId: r1, teamId: teamId, place: 1));
        // Save a new list replacing old results.
        await repo.saveRaceResults(raceId, [
          buildResult(raceId: raceId, runnerId: r2, teamId: teamId, place: 1),
        ]);
        final results = await repo.getRaceResults(raceId);
        expect(results.length, 1);
        expect(results.first.runner?.runnerId, r2);
      });

      test('clears all results when given an empty list', () async {
        final raceId = await insertRace();
        final runnerId = await insertRunner();
        final teamId = await insertTeam();
        await repo.addRaceResult(
            buildResult(raceId: raceId, runnerId: runnerId, teamId: teamId));
        await repo.saveRaceResults(raceId, []);
        expect(await repo.getRaceResults(raceId), isEmpty);
      });

      test('throws when any result in the list is invalid', () async {
        final raceId = await insertRace();
        // RaceResult with no runner fails isValid.
        final invalid = RaceResult(raceId: raceId, runner: null, team: null);
        expect(() => repo.saveRaceResults(raceId, [invalid]), throwsException);
      });
    });

    // =========================================================================
    // updateRaceResult
    // =========================================================================

    group('updateRaceResult', () {
      test('updates place and finish time', () async {
        final raceId = await insertRace();
        final runnerId = await insertRunner();
        final teamId = await insertTeam();
        final result = buildResult(raceId: raceId, runnerId: runnerId, teamId: teamId, place: 1);
        await repo.addRaceResult(result);
        final updated = buildResult(
            raceId: raceId, runnerId: runnerId, teamId: teamId,
            place: 1, finishTime: const Duration(minutes: 11, seconds: 0));
        await repo.updateRaceResult(updated);
        final fetched = await repo.getRaceResult(updated);
        expect(fetched!.finishTime, const Duration(minutes: 11));
      });

      test('throws when result does not exist', () async {
        final raceId = await insertRace();
        final runnerId = await insertRunner();
        final teamId = await insertTeam();
        final nonExistent = buildResult(
            raceId: raceId, runnerId: runnerId, teamId: teamId);
        expect(() => repo.updateRaceResult(nonExistent), throwsException);
      });

      test('throws when result is invalid', () async {
        final invalid = RaceResult(raceId: 1, runner: null, team: null);
        expect(() => repo.updateRaceResult(invalid), throwsException);
      });
    });

    // =========================================================================
    // deleteRaceResult
    // =========================================================================

    group('deleteRaceResult', () {
      test('removes a result', () async {
        final raceId = await insertRace();
        final runnerId = await insertRunner();
        final teamId = await insertTeam();
        final result = buildResult(raceId: raceId, runnerId: runnerId, teamId: teamId);
        await repo.addRaceResult(result);
        await repo.deleteRaceResult(result);
        expect(await repo.getRaceResult(result), isNull);
      });

      test('throws when result does not exist', () async {
        final raceId = await insertRace();
        final runnerId = await insertRunner();
        final teamId = await insertTeam();
        final nonExistent = buildResult(
            raceId: raceId, runnerId: runnerId, teamId: teamId);
        expect(() => repo.deleteRaceResult(nonExistent), throwsException);
      });

      test('throws when raceId is null', () async {
        final teamId = await insertTeam();
        final noIds = RaceResult(
          raceId: null,
          runner: Runner(runnerId: 1, name: 'Alice', bibNumber: '100', grade: 11),
          team: Team(teamId: teamId, name: 'Eagles', abbreviation: 'EA', color: const Color(0xFF2196F3)),
          place: 1,
          finishTime: const Duration(minutes: 10),
        );
        expect(() => repo.deleteRaceResult(noIds), throwsException);
      });
    });
  });
}
