import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/repositories/race_repository.dart';
import 'package:xceleration/core/repositories/runner_repository.dart';
import 'package:xceleration/core/repositories/team_repository.dart';
import 'package:xceleration/core/utils/local_schema.dart';
import 'package:xceleration/shared/models/database/base_models.dart';

// Deleting a join row has to leave a tombstone rather than remove it: a row
// that is simply gone can never be pushed, so the server keeps it and the
// membership comes back on the next device. Every read has to hide the
// tombstone, and the same pair has to be joinable again afterwards.
//
// The bib number, team name and finishing place a tombstone still holds must
// not block those values being used again, which is what the partial unique
// indexes in the schema are for.

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
  Future<void> deleteDatabase() async => _db = null;

  @override
  Future<void> openForUser(String userId) async {
    // The in-memory database is not per user; opening is a no-op.
    await database;
  }

  @override
  Future<void> deleteUserData(String userId) async => deleteDatabase();

}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late _InMemoryConnectionProvider conn;
  late RunnerRepository runners;
  late TeamRepository teams;
  late RaceRepository races;

  setUp(() {
    conn = _InMemoryConnectionProvider();
    runners = RunnerRepository(conn: conn);
    teams = TeamRepository(conn: conn);
    races = RaceRepository(conn: conn, runnerRepo: runners);
  });

  tearDown(() async => conn.close());

  Future<int> addRunner({String bib = '101', String name = 'Alice'}) =>
      runners.createRunner(Runner(name: name, bibNumber: bib, grade: 10));

  Future<int> addTeam({String name = 'Eagles'}) => teams.createTeam(Team(
        name: name,
        abbreviation: name.substring(0, 3).toUpperCase(),
        color: const Color(0xFF1565C0),
      ));

  group('deleting a runner', () {
    test('leaves a tombstone for the server instead of dropping the row',
        () async {
      final id = await addRunner();

      await runners.removeRunner(id);

      final db = await conn.database;
      final row = (await db
              .query('runners', where: 'runner_id = ?', whereArgs: [id]))
          .single;
      expect(row['deleted_at'], isNotNull,
          reason: 'a dropped row can never be pushed');
      expect(row['is_dirty'], 1, reason: 'the deletion still has to sync');
    });

    test('hides them from every way of looking a runner up', () async {
      final id = await addRunner(bib: '101', name: 'Alice');

      await runners.removeRunner(id);

      expect(await runners.getRunner(id), isNull);
      expect(await runners.getRunnerByBib('101'), isNull);
      expect(await runners.getAllRunners(), isEmpty);
      expect(await runners.searchRunners('Alice'), isEmpty);
      expect(await runners.getRunnersByBibAll('101'), isEmpty);
    });

    test('frees the bib number for a new runner', () async {
      final id = await addRunner(bib: '101', name: 'Alice');
      await runners.removeRunner(id);

      final newId = await addRunner(bib: '101', name: 'Bob');

      expect((await runners.getRunnerByBib('101'))!.name, 'Bob');
      expect(await runners.getAllRunners(), hasLength(1));
      expect(newId, isPositive);
    });

    test('tombstones their team and race rows', () async {
      final teamId = await addTeam();
      final runnerId = await addRunner();
      await runners.addRunnerToTeam(teamId, runnerId);
      final raceId = await races.createRace(Race(
        raceId: 0,
        raceName: 'Invitational',
        location: 'Park',
        distance: 5,
        distanceUnit: 'km',
        flowState: Race.FLOW_SETUP,
      ));
      await races.addRaceParticipant(RaceParticipant(
          raceId: raceId, runnerId: runnerId, teamId: teamId));

      await runners.deleteRunnerEverywhere(runnerId);

      final db = await conn.database;
      for (final table in ['team_rosters', 'race_participants']) {
        final rows = await db.query(table);
        expect(rows, hasLength(1), reason: '$table row must be kept');
        expect(rows.first['deleted_at'], isNotNull,
            reason: '$table row must be tombstoned');
        expect(rows.first['is_dirty'], 1);
      }
      expect(await runners.getTeamRunners(teamId), isEmpty);
    });
  });

  group('results that were deleted', () {
    /// A result for [runnerId] in a new race, already deleted.
    Future<void> deletedResult(int runnerId, {int? teamId}) async {
      final db = await conn.database;
      final raceId = await db.insert('races', {'name': 'Invitational'});
      await db.insert('race_results', {
        'race_id': raceId,
        'runner_id': runnerId,
        'team_id': teamId,
        'place': 1,
        'finish_time': 900000,
        'deleted_at': '2026-01-01T00:00:00Z',
      });
    }

    test('do not stop the runner being deleted', () async {
      final id = await addRunner();
      await deletedResult(id);

      await runners.deleteRunnerEverywhere(id);

      expect(await runners.getRunner(id), isNull);
    });

    test('do not stop the team being deleted', () async {
      final runnerId = await addRunner();
      final teamId = await addTeam();
      await deletedResult(runnerId, teamId: teamId);

      await teams.deleteTeam(teamId);

      expect(await teams.getTeam(teamId), isNull);
    });
  });

  test('a runner cannot be moved onto a deleted team', () async {
    final runnerId = await addRunner();
    final teamId = await addTeam();
    await teams.deleteTeam(teamId);

    await expectLater(runners.setRunnerTeam(runnerId, teamId), throwsException);
  });

  group('removing a runner from a team', () {
    test('tombstones the roster row and hides it', () async {
      final teamId = await addTeam();
      final runnerId = await addRunner();
      await runners.addRunnerToTeam(teamId, runnerId);

      await runners.removeRunnerFromTeam(teamId, runnerId);

      expect(await runners.getTeamRunner(teamId, runnerId), isNull);
      expect(await runners.getTeamRunners(teamId), isEmpty);
      expect(await runners.getRunnerTeams(runnerId), isEmpty);

      final db = await conn.database;
      final rows = await db.query('team_rosters');
      expect(rows, hasLength(1));
      expect(rows.first['deleted_at'], isNotNull);
    });

    test('the runner can be put back on the same team', () async {
      final teamId = await addTeam();
      final runnerId = await addRunner();
      await runners.addRunnerToTeam(teamId, runnerId);
      await runners.removeRunnerFromTeam(teamId, runnerId);

      await runners.addRunnerToTeam(teamId, runnerId);

      expect(await runners.getTeamRunner(teamId, runnerId), isNotNull);
      expect(await runners.getTeamRunners(teamId), hasLength(1));
    });
  });

  group('deleting a team', () {
    test('leaves a tombstone and hides it everywhere', () async {
      final teamId = await addTeam(name: 'Eagles');

      await teams.deleteTeam(teamId);

      expect(await teams.getTeam(teamId), isNull);
      expect(await teams.getTeamByName('Eagles'), isNull);
      expect(await teams.getAllTeams(), isEmpty);
      expect(await teams.searchTeams('Eag'), isEmpty);

      final db = await conn.database;
      final row = (await db.query('teams')).single;
      expect(row['deleted_at'], isNotNull);
      expect(row['is_dirty'], 1);
    });

    test('frees the team name for a new team', () async {
      await teams.deleteTeam(await addTeam(name: 'Eagles'));

      await addTeam(name: 'Eagles');

      expect(await teams.getTeamByName('Eagles'), isNotNull);
      expect(await teams.getAllTeams(), hasLength(1));
    });
  });

  group('deleting a race', () {
    test('leaves a tombstone and hides it', () async {
      final raceId = await races.createRace(Race(
        raceId: 0,
        raceName: 'Invitational',
        location: 'Park',
        distance: 5,
        distanceUnit: 'km',
        flowState: Race.FLOW_SETUP,
      ));

      await races.deleteRace(raceId);

      expect(await races.getRace(raceId), isNull);
      expect(await races.getAllRaces(), isEmpty);
      final db = await conn.database;
      final row = (await db.query('races')).single;
      expect(row['deleted_at'], isNotNull);
      expect(row['is_dirty'], 1);
    });
  });

  group('removing a team from a race', () {
    test('tombstones the row and hides it', () async {
      final teamId = await addTeam();
      final raceId = await races.createRace(Race(
        raceId: 0,
        raceName: 'Invitational',
        location: 'Park',
        distance: 5,
        distanceUnit: 'km',
        flowState: Race.FLOW_SETUP,
      ));
      await races.addTeamParticipantToRace(
          TeamParticipant(raceId: raceId, teamId: teamId));

      await races.removeTeamParticipantFromRace(
          TeamParticipant(raceId: raceId, teamId: teamId));

      expect(await races.getRaceTeams(raceId), isEmpty);
      final db = await conn.database;
      final rows = await db.query('race_team_participation');
      expect(rows, hasLength(1));
      expect(rows.first['deleted_at'], isNotNull);
      expect(rows.first['is_dirty'], 1);
    });

    test('the team can be put back in the race', () async {
      final teamId = await addTeam();
      final raceId = await races.createRace(Race(
        raceId: 0,
        raceName: 'Invitational',
        location: 'Park',
        distance: 5,
        distanceUnit: 'km',
        flowState: Race.FLOW_SETUP,
      ));
      await races.addTeamParticipantToRace(
          TeamParticipant(raceId: raceId, teamId: teamId));
      await races.removeTeamParticipantFromRace(
          TeamParticipant(raceId: raceId, teamId: teamId));

      await races.addTeamParticipantToRace(
          TeamParticipant(raceId: raceId, teamId: teamId));

      expect(await races.getRaceTeams(raceId), hasLength(1));
    });
  });
}
