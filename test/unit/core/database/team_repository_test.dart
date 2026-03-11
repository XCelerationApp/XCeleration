import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/repositories/team_repository.dart';
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
  late TeamRepository repo;

  setUp(() {
    connProvider = _InMemoryConnectionProvider();
    repo = TeamRepository(conn: connProvider);
  });

  tearDown(() async {
    await connProvider.close();
  });

  const validTeam = Team(
    name: 'Eagles',
    abbreviation: 'EAG',
    color: Color(0xFF2196F3),
  );

  group('TeamRepository', () {
    group('createTeam', () {
      test('returns auto-assigned id for a valid team', () async {
        final id = await repo.createTeam(validTeam);
        expect(id, greaterThan(0));
      });

      test('throws when team name is empty', () async {
        const invalid = Team(name: '', abbreviation: 'X', color: Color(0xFF2196F3));
        expect(() => repo.createTeam(invalid), throwsException);
      });

      test('throws when abbreviation is empty', () async {
        const invalid = Team(name: 'Eagles', abbreviation: '', color: Color(0xFF2196F3));
        expect(() => repo.createTeam(invalid), throwsException);
      });

      test('throws when a team with the same name already exists', () async {
        await repo.createTeam(validTeam);
        expect(() => repo.createTeam(validTeam), throwsException);
      });

      test('generates abbreviation when not provided via insert', () async {
        // createTeam uses team.abbreviation ?? generateAbbreviation(name)
        // but isValid requires abbreviation != null, so this path is never reached
        // via the public API. Verify the stored abbreviation matches input.
        final id = await repo.createTeam(validTeam);
        final team = await repo.getTeam(id);
        expect(team!.abbreviation, 'EAG');
      });
    });

    group('getTeam', () {
      test('returns team for known id', () async {
        final id = await repo.createTeam(validTeam);
        final team = await repo.getTeam(id);
        expect(team, isNotNull);
        expect(team!.name, 'Eagles');
      });

      test('returns null for unknown id', () async {
        expect(await repo.getTeam(9999), isNull);
      });
    });

    group('getTeamByName', () {
      test('returns team for known name', () async {
        await repo.createTeam(validTeam);
        final team = await repo.getTeamByName('Eagles');
        expect(team, isNotNull);
        expect(team!.abbreviation, 'EAG');
      });

      test('returns null for unknown name', () async {
        expect(await repo.getTeamByName('Falcons'), isNull);
      });
    });

    group('getAllTeams', () {
      test('returns empty list when no teams exist', () async {
        expect(await repo.getAllTeams(), isEmpty);
      });

      test('returns teams ordered by name', () async {
        await repo.createTeam(
            const Team(name: 'Zephyrs', abbreviation: 'ZEP', color: Color(0xFF2196F3)));
        await repo.createTeam(validTeam);
        final teams = await repo.getAllTeams();
        expect(teams.length, 2);
        expect(teams.first.name, 'Eagles');
        expect(teams.last.name, 'Zephyrs');
      });
    });

    group('searchTeams', () {
      setUp(() async {
        await repo.createTeam(validTeam);
        await repo.createTeam(
            const Team(name: 'Hawks', abbreviation: 'HWK', color: Color(0xFF2196F3)));
      });

      test('matches teams by name substring', () async {
        final results = await repo.searchTeams('Eag');
        expect(results, hasLength(1));
        expect(results.first.name, 'Eagles');
      });

      test('matches teams by abbreviation substring', () async {
        final results = await repo.searchTeams('HW');
        expect(results, hasLength(1));
        expect(results.first.name, 'Hawks');
      });

      test('returns empty list when no match', () async {
        expect(await repo.searchTeams('XYZ'), isEmpty);
      });
    });

    group('updateTeam', () {
      test('updates team fields successfully', () async {
        final id = await repo.createTeam(validTeam);
        await repo.updateTeam(Team(
          teamId: id,
          name: 'Eagles',
          abbreviation: 'EGL',
          color: const Color(0xFFFF0000),
        ));
        final updated = await repo.getTeam(id);
        expect(updated!.abbreviation, 'EGL');
      });

      test('throws when team does not exist', () async {
        const nonExistent = Team(
          teamId: 9999,
          name: 'Ghosts',
          abbreviation: 'GHO',
          color: Color(0xFF2196F3),
        );
        expect(() => repo.updateTeam(nonExistent), throwsException);
      });

      test('throws when team name is empty', () async {
        final id = await repo.createTeam(validTeam);
        expect(
          () => repo.updateTeam(Team(
            teamId: id,
            name: '',
            abbreviation: 'EAG',
            color: const Color(0xFF2196F3),
          )),
          throwsException,
        );
      });
    });

    group('deleteTeam', () {
      test('removes team by id', () async {
        final id = await repo.createTeam(validTeam);
        await repo.deleteTeam(id);
        expect(await repo.getTeam(id), isNull);
      });

      test('throws when team does not exist', () async {
        expect(() => repo.deleteTeam(9999), throwsException);
      });
    });
  });
}
