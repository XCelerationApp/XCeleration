import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/repositories/race_repository.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late _InMemoryConnectionProvider connProvider;
  late RunnerRepository runnerRepo;
  late RaceRepository repo;

  setUp(() {
    connProvider = _InMemoryConnectionProvider();
    runnerRepo = RunnerRepository(conn: connProvider);
    repo = RaceRepository(conn: connProvider, runnerRepo: runnerRepo);
  });

  tearDown(() async {
    await connProvider.close();
  });

  // Helper to insert a runner row directly.
  Future<int> insertRunner({
    String name = 'Alice',
    String bib = '100',
    int grade = 11,
  }) async {
    final db = await connProvider.database;
    return db.insert('runners', {
      'name': name,
      'bib_number': bib,
      'grade': grade,
      'is_dirty': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Helper to insert a team row directly.
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

  // A valid Race for creation (raceId: 0 satisfies isValid for 'setup' flow).
  Race validRace({String name = 'Test Race'}) => Race(
        raceId: 0,
        raceName: name,
        location: '',
        distance: 0,
        distanceUnit: 'mi',
        flowState: Race.FLOW_SETUP,
      );

  group('RaceRepository', () {
    // =========================================================================
    // RACE CRUD
    // =========================================================================

    group('createRace', () {
      test('returns auto-assigned id for a valid race', () async {
        final id = await repo.createRace(validRace());
        expect(id, greaterThan(0));
      });

      test('throws when race name is empty', () async {
        final invalid = Race(
          raceId: 0,
          raceName: '',
          flowState: Race.FLOW_SETUP,
        );
        expect(() => repo.createRace(invalid), throwsException);
      });

      test('throws when raceId is null (not a valid race)', () async {
        final invalid = Race(raceName: 'Test', flowState: Race.FLOW_SETUP);
        expect(() => repo.createRace(invalid), throwsException);
      });
    });

    group('getRace', () {
      test('returns race for known id', () async {
        final id = await repo.createRace(validRace());
        final race = await repo.getRace(id);
        expect(race, isNotNull);
        expect(race!.raceName, 'Test Race');
      });

      test('returns null for unknown id', () async {
        expect(await repo.getRace(9999), isNull);
      });
    });

    group('getAllRaces', () {
      test('returns empty list when no races exist', () async {
        expect(await repo.getAllRaces(), isEmpty);
      });

      test('returns races ordered by date descending', () async {
        final id1 = await repo.createRace(validRace(name: 'Race A'));
        final id2 = await repo.createRace(validRace(name: 'Race B'));
        final db = await connProvider.database;
        // Set different dates so ordering is deterministic.
        await db.update('races', {'race_date': '2024-01-01'},
            where: 'race_id = ?', whereArgs: [id1]);
        await db.update('races', {'race_date': '2024-06-01'},
            where: 'race_id = ?', whereArgs: [id2]);
        final races = await repo.getAllRaces();
        expect(races.length, 2);
        expect(races.first.raceName, 'Race B');
      });
    });

    group('updateRace', () {
      test('updates race name successfully', () async {
        final id = await repo.createRace(validRace());
        await repo.updateRace(Race(
          raceId: id,
          raceName: 'Updated Race',
          flowState: Race.FLOW_SETUP,
        ));
        final updated = await repo.getRace(id);
        expect(updated!.raceName, 'Updated Race');
      });

      test('throws when raceId is null', () async {
        expect(
          () => repo.updateRace(Race(raceName: 'X', flowState: Race.FLOW_SETUP)),
          throwsException,
        );
      });

      test('throws when race name is empty', () async {
        final id = await repo.createRace(validRace());
        expect(
          () => repo.updateRace(
              Race(raceId: id, raceName: '', flowState: Race.FLOW_SETUP)),
          throwsException,
        );
      });

      test('throws when race does not exist', () async {
        expect(
          () => repo.updateRace(Race(
              raceId: 9999, raceName: 'Ghost', flowState: Race.FLOW_SETUP)),
          throwsException,
        );
      });
    });

    group('deleteRace', () {
      test('removes race by id', () async {
        final id = await repo.createRace(validRace());
        await repo.deleteRace(id);
        expect(await repo.getRace(id), isNull);
      });

      test('throws when race does not exist', () async {
        expect(() => repo.deleteRace(9999), throwsException);
      });
    });

    // =========================================================================
    // RACE TEAM PARTICIPATION
    // =========================================================================

    group('addTeamParticipantToRace', () {
      test('adds a team to a race', () async {
        final raceId = await repo.createRace(validRace());
        final teamId = await insertTeam('Eagles');
        final tp = TeamParticipant(raceId: raceId, teamId: teamId);
        await repo.addTeamParticipantToRace(tp);
        final result = await repo.getRaceTeamParticipant(tp);
        expect(result, isNotNull);
      });

      test('throws when team is already in the race', () async {
        final raceId = await repo.createRace(validRace());
        final teamId = await insertTeam('Eagles');
        final tp = TeamParticipant(raceId: raceId, teamId: teamId);
        await repo.addTeamParticipantToRace(tp);
        expect(() => repo.addTeamParticipantToRace(tp), throwsException);
      });

      test('throws when TeamParticipant is invalid', () async {
        final tp = TeamParticipant(raceId: null, teamId: null);
        expect(() => repo.addTeamParticipantToRace(tp), throwsException);
      });
    });

    group('removeTeamParticipantFromRace', () {
      test('removes a team from a race', () async {
        final raceId = await repo.createRace(validRace());
        final teamId = await insertTeam('Eagles');
        final tp = TeamParticipant(raceId: raceId, teamId: teamId);
        await repo.addTeamParticipantToRace(tp);
        await repo.removeTeamParticipantFromRace(tp);
        expect(await repo.getRaceTeamParticipant(tp), isNull);
      });

      test('throws when team is not in the race', () async {
        final raceId = await repo.createRace(validRace());
        final teamId = await insertTeam('Eagles');
        final tp = TeamParticipant(raceId: raceId, teamId: teamId);
        expect(() => repo.removeTeamParticipantFromRace(tp), throwsException);
      });
    });

    group('getRaceTeamParticipant', () {
      test('returns team when it participates in the race', () async {
        final raceId = await repo.createRace(validRace());
        final teamId = await insertTeam('Eagles');
        final tp = TeamParticipant(raceId: raceId, teamId: teamId);
        await repo.addTeamParticipantToRace(tp);
        final team = await repo.getRaceTeamParticipant(tp);
        expect(team, isNotNull);
        expect(team!.teamId, teamId);
      });

      test('returns null when team does not participate', () async {
        final raceId = await repo.createRace(validRace());
        final teamId = await insertTeam('Eagles');
        final tp = TeamParticipant(raceId: raceId, teamId: teamId);
        expect(await repo.getRaceTeamParticipant(tp), isNull);
      });
    });

    group('getRaceTeams', () {
      test('returns all teams participating in a race', () async {
        final raceId = await repo.createRace(validRace());
        final t1 = await insertTeam('Eagles');
        final t2 = await insertTeam('Hawks');
        await repo.addTeamParticipantToRace(
            TeamParticipant(raceId: raceId, teamId: t1));
        await repo.addTeamParticipantToRace(
            TeamParticipant(raceId: raceId, teamId: t2));
        final teams = await repo.getRaceTeams(raceId);
        expect(teams.length, 2);
      });

      test('throws when race does not exist', () async {
        expect(() => repo.getRaceTeams(9999), throwsException);
      });
    });

    // =========================================================================
    // RACE PARTICIPANTS
    // =========================================================================

    group('addRaceParticipant', () {
      test('adds a runner to a race', () async {
        final raceId = await repo.createRace(validRace());
        final runnerId = await insertRunner();
        final teamId = await insertTeam('Eagles');
        final rp =
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: teamId);
        await repo.addRaceParticipant(rp);
        expect(await repo.getRaceParticipant(rp), isNotNull);
      });

      test('throws when runner is already in the race', () async {
        final raceId = await repo.createRace(validRace());
        final runnerId = await insertRunner();
        final teamId = await insertTeam('Eagles');
        final rp =
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: teamId);
        await repo.addRaceParticipant(rp);
        expect(() => repo.addRaceParticipant(rp), throwsException);
      });

      test('throws when RaceParticipant is invalid', () async {
        final rp = RaceParticipant(raceId: null, runnerId: null, teamId: null);
        expect(() => repo.addRaceParticipant(rp), throwsException);
      });
    });

    group('updateRaceParticipant', () {
      test('updates race participant team', () async {
        final raceId = await repo.createRace(validRace());
        final runnerId = await insertRunner();
        final t1 = await insertTeam('Eagles');
        final t2 = await insertTeam('Hawks');
        final rp =
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: t1);
        await repo.addRaceParticipant(rp);
        final updated =
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: t2);
        await repo.updateRaceParticipant(updated);
        final result = await repo.getRaceParticipant(updated);
        expect(result!.teamId, t2);
      });

      test('throws when race participant does not exist', () async {
        final rp = RaceParticipant(raceId: 1, runnerId: 1, teamId: 1);
        expect(() => repo.updateRaceParticipant(rp), throwsException);
      });
    });

    group('removeRaceParticipant', () {
      test('removes runner from race', () async {
        final raceId = await repo.createRace(validRace());
        final runnerId = await insertRunner();
        final teamId = await insertTeam('Eagles');
        final rp =
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: teamId);
        await repo.addRaceParticipant(rp);
        await repo.removeRaceParticipant(rp);
        expect(await repo.getRaceParticipant(rp), isNull);
      });

      test('throws when runner is not in the race', () async {
        final rp = RaceParticipant(raceId: 1, runnerId: 1, teamId: 1);
        expect(() => repo.removeRaceParticipant(rp), throwsException);
      });
    });

    group('getRaceParticipant', () {
      test('returns participant when they are in the race', () async {
        final raceId = await repo.createRace(validRace());
        final runnerId = await insertRunner();
        final teamId = await insertTeam('Eagles');
        final rp =
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: teamId);
        await repo.addRaceParticipant(rp);
        expect(await repo.getRaceParticipant(rp), isNotNull);
      });

      test('returns null when runner is not in the race', () async {
        final rp = RaceParticipant(raceId: 1, runnerId: 1, teamId: 1);
        expect(await repo.getRaceParticipant(rp), isNull);
      });
    });

    group('getRaceParticipants', () {
      test('returns all participants for a race', () async {
        final raceId = await repo.createRace(validRace());
        final r1 = await insertRunner(name: 'Alice', bib: '1');
        final r2 = await insertRunner(name: 'Bob', bib: '2');
        final teamId = await insertTeam('Eagles');
        await repo.addRaceParticipant(
            RaceParticipant(raceId: raceId, runnerId: r1, teamId: teamId));
        await repo.addRaceParticipant(
            RaceParticipant(raceId: raceId, runnerId: r2, teamId: teamId));
        final participants = await repo.getRaceParticipants(raceId);
        expect(participants.length, 2);
      });

      test('throws when race does not exist', () async {
        expect(() => repo.getRaceParticipants(9999), throwsException);
      });
    });

    group('getRaceParticipantByBib', () {
      test('returns participant for known bib', () async {
        final raceId = await repo.createRace(validRace());
        final runnerId = await insertRunner(bib: '42');
        final teamId = await insertTeam('Eagles');
        await repo.addRaceParticipant(
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: teamId));
        final rp = await repo.getRaceParticipantByBib(raceId, '42');
        expect(rp, isNotNull);
        expect(rp!.runnerId, runnerId);
      });

      test('returns null when bib not in race', () async {
        final raceId = await repo.createRace(validRace());
        expect(await repo.getRaceParticipantByBib(raceId, '99'), isNull);
      });
    });

    group('getRaceParticipantsByBibs', () {
      test('returns participants for matching bibs', () async {
        final raceId = await repo.createRace(validRace());
        final r1 = await insertRunner(name: 'Alice', bib: '1');
        final r2 = await insertRunner(name: 'Bob', bib: '2');
        final teamId = await insertTeam('Eagles');
        await repo.addRaceParticipant(
            RaceParticipant(raceId: raceId, runnerId: r1, teamId: teamId));
        await repo.addRaceParticipant(
            RaceParticipant(raceId: raceId, runnerId: r2, teamId: teamId));
        final participants =
            await repo.getRaceParticipantsByBibs(raceId, ['1', '2', '99']);
        expect(participants.length, 2);
      });
    });

    group('searchRaceParticipants', () {
      late int raceId;
      late int teamId;

      setUp(() async {
        raceId = await repo.createRace(validRace());
        teamId = await insertTeam('Eagles');
        final runnerId = await insertRunner(name: 'Alice', bib: '100');
        await repo.addRaceParticipant(
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: teamId));
      });

      test('finds participant by name', () async {
        final results =
            await repo.searchRaceParticipants(raceId, 'Ali', 'name');
        expect(results, hasLength(1));
      });

      test('finds participant by bib_number', () async {
        final results =
            await repo.searchRaceParticipants(raceId, '10', 'bib_number');
        expect(results, hasLength(1));
      });

      test('finds participant by team_name', () async {
        final results =
            await repo.searchRaceParticipants(raceId, 'Eag', 'team_name');
        expect(results, hasLength(1));
      });

      test('returns empty list when no match', () async {
        final results =
            await repo.searchRaceParticipants(raceId, 'XYZ', 'name');
        expect(results, isEmpty);
      });
    });

    // =========================================================================
    // FLOW STATE
    // =========================================================================

    group('getRaceFlowState', () {
      test("returns race's flow state for known race", () async {
        final id = await repo.createRace(validRace());
        final state = await repo.getRaceFlowState(id);
        expect(state, Race.FLOW_SETUP);
      });

      test("returns 'pre_race' fallback for unknown race", () async {
        final state = await repo.getRaceFlowState(9999);
        expect(state, 'pre_race');
      });
    });

    group('updateRaceFlowState', () {
      // updateRaceFlowState delegates to updateRace(Race(raceId, flowState))
      // which fails validation because raceName is null. This is a known
      // limitation of the current implementation.
      test('throws because partial Race fails isValid check', () async {
        final id = await repo.createRace(validRace());
        expect(
          () => repo.updateRaceFlowState(id, Race.FLOW_PRE_RACE),
          throwsException,
        );
      });
    });

    // =========================================================================
    // CONVENIENCE
    // =========================================================================

    group('updateRaceParticipantTeam', () {
      test('updates team assignment for a race participant', () async {
        final raceId = await repo.createRace(validRace());
        final runnerId = await insertRunner();
        final t1 = await insertTeam('Eagles');
        final t2 = await insertTeam('Hawks');
        await repo.addRaceParticipant(
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: t1));
        await repo.updateRaceParticipantTeam(
            raceId: raceId, runnerId: runnerId, newTeamId: t2);
        final rp = await repo.getRaceParticipant(
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: t2));
        expect(rp!.teamId, t2);
      });
    });

    group('updateRunnerWithTeams', () {
      test('updates runner fields without changing team', () async {
        final runnerId = await runnerRepo
            .createRunner(const Runner(name: 'Alice', bibNumber: '1', grade: 11));
        await repo.updateRunnerWithTeams(
          runner: Runner(runnerId: runnerId, name: 'Alicia', bibNumber: '1', grade: 12),
        );
        final updated = await runnerRepo.getRunner(runnerId);
        expect(updated!.name, 'Alicia');
      });

      test('updates runner and reassigns team when newTeamId is provided',
          () async {
        final runnerId = await runnerRepo
            .createRunner(const Runner(name: 'Alice', bibNumber: '1', grade: 11));
        final raceId = await repo.createRace(validRace());
        final t1 = await insertTeam('Eagles');
        final t2 = await insertTeam('Hawks');
        await runnerRepo.addRunnerToTeam(t1, runnerId);
        await repo.addRaceParticipant(
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: t1));
        await repo.updateRunnerWithTeams(
          runner: Runner(runnerId: runnerId, name: 'Alice', bibNumber: '1', grade: 11),
          newTeamId: t2,
          raceIdForTeamUpdate: raceId,
        );
        final rp = await repo.getRaceParticipant(
            RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: t2));
        expect(rp!.teamId, t2);
      });
    });
  });
}
