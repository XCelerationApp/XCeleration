import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/repositories/runner_repository.dart';
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
  // ignore: unused_local_variable
  const _ = Colors.blue; // ensure flutter binding is exercised
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late _InMemoryConnectionProvider connProvider;
  late RunnerRepository repo;

  setUp(() async {
    connProvider = _InMemoryConnectionProvider();
    repo = RunnerRepository(conn: connProvider);
  });

  tearDown(() async {
    await connProvider.close();
  });

  // Inserts a team row directly for roster-related tests.
  Future<int> insertTeam(String name) async {
    final db = await connProvider.database;
    return db.insert('teams', {
      'name': name,
      'abbreviation': name.substring(0, 2).toUpperCase(),
      'color': 0xFF2196F3,
      'is_dirty': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  const validRunner = Runner(name: 'Alice', bibNumber: '100', grade: 11);

  group('RunnerRepository', () {
    group('createRunner', () {
      test('returns auto-assigned id for a valid runner', () async {
        final id = await repo.createRunner(validRunner);
        expect(id, greaterThan(0));
      });

      test('throws when runner name is empty', () async {
        const invalid = Runner(name: '', bibNumber: '100', grade: 11);
        expect(() => repo.createRunner(invalid), throwsException);
      });

      test('throws when grade is out of range', () async {
        const invalid = Runner(name: 'Bob', bibNumber: '101', grade: 8);
        expect(() => repo.createRunner(invalid), throwsException);
      });

      test('throws when bib number already exists', () async {
        await repo.createRunner(validRunner);
        const duplicate = Runner(name: 'Bob', bibNumber: '100', grade: 10);
        expect(() => repo.createRunner(duplicate), throwsException);
      });
    });

    group('getRunner', () {
      test('returns runner for known id', () async {
        final id = await repo.createRunner(validRunner);
        final runner = await repo.getRunner(id);
        expect(runner, isNotNull);
        expect(runner!.name, 'Alice');
        expect(runner.bibNumber, '100');
      });

      test('returns null for unknown id', () async {
        expect(await repo.getRunner(9999), isNull);
      });
    });

    group('getRunnerByBib', () {
      test('returns runner for known bib', () async {
        await repo.createRunner(validRunner);
        final runner = await repo.getRunnerByBib('100');
        expect(runner, isNotNull);
        expect(runner!.name, 'Alice');
      });

      test('returns null for unknown bib', () async {
        expect(await repo.getRunnerByBib('999'), isNull);
      });
    });

    group('getAllRunners', () {
      test('returns empty list when no runners exist', () async {
        expect(await repo.getAllRunners(), isEmpty);
      });

      test('returns runners ordered by name', () async {
        await repo.createRunner(
            const Runner(name: 'Zara', bibNumber: '2', grade: 10));
        await repo.createRunner(
            const Runner(name: 'Alice', bibNumber: '1', grade: 11));
        final runners = await repo.getAllRunners();
        expect(runners.length, 2);
        expect(runners.first.name, 'Alice');
        expect(runners.last.name, 'Zara');
      });
    });

    group('searchRunners', () {
      setUp(() async {
        await repo.createRunner(validRunner);
        await repo
            .createRunner(const Runner(name: 'Bob', bibNumber: '200', grade: 10));
      });

      test('matches runners by name substring', () async {
        final results = await repo.searchRunners('Ali');
        expect(results, hasLength(1));
        expect(results.first.name, 'Alice');
      });

      test('matches runners by bib substring', () async {
        final results = await repo.searchRunners('20');
        expect(results, hasLength(1));
        expect(results.first.bibNumber, '200');
      });

      test('returns empty list when no match', () async {
        expect(await repo.searchRunners('XYZ'), isEmpty);
      });
    });

    group('updateRunner', () {
      test('updates runner fields successfully', () async {
        final id = await repo.createRunner(validRunner);
        await repo.updateRunner(
            Runner(runnerId: id, name: 'Alicia', bibNumber: '100', grade: 12));
        final updated = await repo.getRunner(id);
        expect(updated!.name, 'Alicia');
        expect(updated.grade, 12);
      });

      test('throws when runnerId is null', () async {
        expect(() => repo.updateRunner(validRunner), throwsException);
      });

      test('throws when runner name is empty', () async {
        final id = await repo.createRunner(validRunner);
        expect(
          () => repo.updateRunner(
              Runner(runnerId: id, name: '', bibNumber: '100', grade: 11)),
          throwsException,
        );
      });
    });

    group('removeRunner', () {
      test('removes runner by id', () async {
        final id = await repo.createRunner(validRunner);
        await repo.removeRunner(id);
        expect(await repo.getRunner(id), isNull);
      });

      test('throws when runner does not exist', () async {
        expect(() => repo.removeRunner(9999), throwsException);
      });
    });

    group('deleteRunnerEverywhere', () {
      test('completes without error when runner does not exist', () async {
        await expectLater(repo.deleteRunnerEverywhere(9999), completes);
      });

      test('deletes the runner row', () async {
        final id = await repo.createRunner(validRunner);
        await repo.deleteRunnerEverywhere(id);
        expect(await repo.getRunner(id), isNull);
      });

      test('removes associated team_rosters rows', () async {
        final runnerId = await repo.createRunner(validRunner);
        final teamId = await insertTeam('Eagles');
        await repo.addRunnerToTeam(teamId, runnerId);
        await repo.deleteRunnerEverywhere(runnerId);
        final db = await connProvider.database;
        final rows = await db.query('team_rosters',
            where: 'runner_id = ?', whereArgs: [runnerId]);
        expect(rows, isEmpty);
      });
    });

    group('getRunnersByBibAll', () {
      test('returns runners matching bib', () async {
        await repo.createRunner(validRunner);
        expect(await repo.getRunnersByBibAll('100'), hasLength(1));
      });

      test('returns empty list when bib not found', () async {
        expect(await repo.getRunnersByBibAll('999'), isEmpty);
      });
    });

    group('addRunnerToTeam', () {
      test('adds runner to team successfully', () async {
        final runnerId = await repo.createRunner(validRunner);
        final teamId = await insertTeam('Eagles');
        await repo.addRunnerToTeam(teamId, runnerId);
        expect(await repo.getTeamRunner(teamId, runnerId), isNotNull);
      });

      test('is a no-op when runner is already in the team', () async {
        final runnerId = await repo.createRunner(validRunner);
        final teamId = await insertTeam('Eagles');
        await repo.addRunnerToTeam(teamId, runnerId);
        await expectLater(repo.addRunnerToTeam(teamId, runnerId), completes);
      });
    });

    group('removeRunnerFromTeam', () {
      test('removes runner from team', () async {
        final runnerId = await repo.createRunner(validRunner);
        final teamId = await insertTeam('Eagles');
        await repo.addRunnerToTeam(teamId, runnerId);
        await repo.removeRunnerFromTeam(teamId, runnerId);
        expect(await repo.getTeamRunner(teamId, runnerId), isNull);
      });

      test('throws when runner is not in the team', () async {
        final runnerId = await repo.createRunner(validRunner);
        final teamId = await insertTeam('Eagles');
        expect(
            () => repo.removeRunnerFromTeam(teamId, runnerId), throwsException);
      });
    });

    group('setRunnerTeam', () {
      test('assigns runner to a new team', () async {
        final runnerId = await repo.createRunner(validRunner);
        final teamId = await insertTeam('Eagles');
        await repo.setRunnerTeam(runnerId, teamId);
        final teams = await repo.getRunnerTeams(runnerId);
        expect(teams.any((t) => t.teamId == teamId), isTrue);
      });

      test('throws when runner does not exist', () async {
        final teamId = await insertTeam('Eagles');
        expect(() => repo.setRunnerTeam(9999, teamId), throwsException);
      });

      test('throws when team does not exist', () async {
        final runnerId = await repo.createRunner(validRunner);
        expect(() => repo.setRunnerTeam(runnerId, 9999), throwsException);
      });
    });

    group('getTeamRunner', () {
      test('returns runner when they are in the team', () async {
        final runnerId = await repo.createRunner(validRunner);
        final teamId = await insertTeam('Eagles');
        await repo.addRunnerToTeam(teamId, runnerId);
        expect(await repo.getTeamRunner(teamId, runnerId), isNotNull);
      });

      test('returns null when runner is not in the team', () async {
        final runnerId = await repo.createRunner(validRunner);
        final teamId = await insertTeam('Eagles');
        expect(await repo.getTeamRunner(teamId, runnerId), isNull);
      });
    });

    group('getTeamRunners', () {
      test('returns runners in a team ordered by name', () async {
        final teamId = await insertTeam('Eagles');
        final r1 = await repo
            .createRunner(const Runner(name: 'Zara', bibNumber: '2', grade: 10));
        final r2 = await repo
            .createRunner(const Runner(name: 'Alice', bibNumber: '1', grade: 11));
        await repo.addRunnerToTeam(teamId, r1);
        await repo.addRunnerToTeam(teamId, r2);
        final runners = await repo.getTeamRunners(teamId);
        expect(runners.length, 2);
        expect(runners.first.name, 'Alice');
      });

      test('returns empty list when team has no runners', () async {
        final teamId = await insertTeam('Eagles');
        expect(await repo.getTeamRunners(teamId), isEmpty);
      });
    });

    group('getRunnerTeams', () {
      test('returns all teams a runner belongs to', () async {
        final runnerId = await repo.createRunner(validRunner);
        final t1 = await insertTeam('Eagles');
        final t2 = await insertTeam('Hawks');
        await repo.addRunnerToTeam(t1, runnerId);
        await repo.addRunnerToTeam(t2, runnerId);
        final teams = await repo.getRunnerTeams(runnerId);
        expect(teams.length, 2);
      });

      test('throws when runner does not exist', () async {
        expect(() => repo.getRunnerTeams(9999), throwsException);
      });
    });
  });
}
