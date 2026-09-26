import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/coach/runners_management_screen/services/roster_importer.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/repositories/race_repository.dart';
import 'package:xceleration/core/repositories/runner_repository.dart';
import 'package:xceleration/core/repositories/team_repository.dart';
import 'package:xceleration/core/utils/local_schema.dart';
import 'package:xceleration/shared/models/database/base_models.dart';

// A coach imports a spreadsheet of runners into a race. Every runner must
// land on the right team and in the race, teams must not be duplicated, and
// runners the app already knows (by bib) must not be duplicated or quietly
// renamed.

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
  Future<void> openForUser(String userId) async => database;

  @override
  Future<void> deleteUserData(String userId) async => deleteDatabase();
}

Map<String, dynamic> _row(String name, int grade, String bib,
        {String? team}) =>
    {'name': name, 'grade': grade, 'bib': bib, 'team': ?team};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late _InMemoryConnectionProvider conn;
  late RunnerRepository runners;
  late TeamRepository teams;
  late RaceRepository races;
  late int raceId;
  late RosterImporter importer;

  setUp(() async {
    conn = _InMemoryConnectionProvider();
    runners = RunnerRepository(conn: conn);
    teams = TeamRepository(conn: conn);
    races = RaceRepository(conn: conn, runnerRepo: runners);
    raceId = await races.createRace(Race(
      raceId: 0,
      raceName: 'Invitational',
      location: 'Park',
      distance: 5,
      distanceUnit: 'km',
      flowState: Race.FLOW_SETUP,
    ));
    importer = RosterImporter(
        raceId: raceId, runners: runners, teams: teams, races: races);
  });

  tearDown(() async => conn.close());

  /// Each runner in the race as "bib name team".
  Future<List<String>> inRace() async {
    final all = await teams.getAllTeams();
    final names = {for (final t in all) t.teamId: t.name};
    final out = <String>[];
    for (final p in await races.getRaceParticipants(raceId)) {
      final r = await runners.getRunner(p.runnerId!);
      out.add('${r!.bibNumber} ${r.name} ${names[p.teamId]}');
    }
    return out..sort();
  }

  Future<int> makeTeam(String name, String abbreviation) => teams.createTeam(
      Team(name: name, abbreviation: abbreviation, color: const Color(0xFF2196F3)));

  Future<List<String>> raceTeams() async =>
      [for (final t in await races.getRaceTeams(raceId)) t.name ?? '']..sort();

  group('a sheet with a Team column', () {
    test('creates each team, puts it in the race, and its runners on it',
        () async {
      final result = await importer.importRows([
        _row('Ann Lee', 10, '101', team: 'Eagles'),
        _row('Bo Park', 11, '102', team: 'Hawks'),
        _row('Cy Diaz', 12, '103', team: 'Eagles'),
      ]);

      expect(await inRace(), [
        '101 Ann Lee Eagles',
        '102 Bo Park Hawks',
        '103 Cy Diaz Eagles',
      ]);
      expect(await raceTeams(), ['Eagles', 'Hawks']);
      expect(result.added, 3);
      expect(result.teamsCreated, ['Eagles', 'Hawks']);
      expect(result.conflicts, isEmpty);
    });

    test('gives a created team an abbreviation and its runners\' teams',
        () async {
      await importer.importRows([
        _row('Ann Lee', 10, '101', team: 'Redwood High School'),
      ]);

      final team = await teams.getTeamByName('Redwood High School');
      expect(team?.abbreviation, 'RHS');
      final roster = await runners.getTeamRunners(team!.teamId!);
      expect(roster.map((r) => r.name), ['Ann Lee']);
    });

    test('uses a team the coach already has, by name or abbreviation, '
        'ignoring case', () async {
      final eagles = await makeTeam('Eagles', 'EAG');

      final result = await importer.importRows([
        _row('Ann Lee', 10, '101', team: 'eagles'),
        _row('Bo Park', 11, '102', team: 'EAG'),
      ]);

      expect(result.teamsCreated, isEmpty);
      expect((await teams.getAllTeams()).length, 1);
      final participants = await races.getRaceParticipants(raceId);
      expect(participants.map((p) => p.teamId), everyElement(eagles));
    });

    test('does not add a team to the race twice', () async {
      await importer.importRows([_row('Ann Lee', 10, '101', team: 'Eagles')]);
      await importer.importRows([_row('Bo Park', 11, '102', team: 'Eagles')]);

      expect(await raceTeams(), ['Eagles']);
    });
  });

  group('rows without a team', () {
    test('go on the team the import was started from', () async {
      final id = await makeTeam('Owls', 'OWL');
      final owls = await teams.getTeam(id);

      await importer.importRows([_row('Ann Lee', 10, '101')], intoTeam: owls);

      expect(await inRace(), ['101 Ann Lee Owls']);
      expect(await raceTeams(), ['Owls']);
    });

    test('a row\'s own team wins over the one given', () async {
      final id = await makeTeam('Owls', 'OWL');
      final owls = await teams.getTeam(id);

      await importer.importRows([
        _row('Ann Lee', 10, '101', team: 'Eagles'),
        _row('Bo Park', 11, '102'),
      ], intoTeam: owls);

      expect(await inRace(), ['101 Ann Lee Eagles', '102 Bo Park Owls']);
    });

    test('are counted, not added, when no team is given', () async {
      final result = await importer.importRows([_row('Ann Lee', 10, '101')]);

      expect(result.unplaced, 1);
      expect(result.added, 0);
      expect(await inRace(), isEmpty);
      expect(await runners.getRunnerByBib('101'), isNull);
    });
  });

  group('runners the app already has', () {
    test('are not duplicated, and join this race on the sheet\'s team',
        () async {
      await runners.createRunner(
          const Runner(name: 'Ann Lee', bibNumber: '101', grade: 10));

      final result =
          await importer.importRows([_row('Ann Lee', 10, '101', team: 'Eagles')]);

      expect(result.added, 0);
      expect(result.alreadyKnown, 1);
      expect(result.conflicts, isEmpty);
      expect((await runners.getAllRunners()).length, 1);
      expect(await inRace(), ['101 Ann Lee Eagles']);
    });

    test('keep their saved details until the coach chooses the sheet\'s',
        () async {
      await runners.createRunner(
          const Runner(name: 'Ann Lee', bibNumber: '101', grade: 10));

      final result = await importer
          .importRows([_row('Annie Lee', 11, '101', team: 'Eagles')]);

      expect(result.conflicts, hasLength(1));
      expect((await runners.getRunnerByBib('101'))?.name, 'Ann Lee',
          reason: 'nothing is renamed without asking');

      await importer.useSpreadsheetDetails(result.conflicts.single);

      final updated = await runners.getRunnerByBib('101');
      expect(updated?.name, 'Annie Lee');
      expect(updated?.grade, 11);
      expect((await runners.getAllRunners()).length, 1);
    });

    test('already in the race move to the sheet\'s team', () async {
      final hawks = await makeTeam('Hawks', 'HAW');
      final runnerId = await runners.createRunner(
          const Runner(name: 'Ann Lee', bibNumber: '101', grade: 10));
      await races.addRaceParticipant(
          RaceParticipant(raceId: raceId, runnerId: runnerId, teamId: hawks));

      await importer.importRows([_row('Ann Lee', 10, '101', team: 'Eagles')]);

      expect(await inRace(), ['101 Ann Lee Eagles']);
      expect((await races.getRaceParticipants(raceId)).length, 1);
    });
  });

  test('importing the same sheet twice changes nothing the second time',
      () async {
    final sheet = [
      _row('Ann Lee', 10, '101', team: 'Eagles'),
      _row('Bo Park', 11, '102', team: 'Hawks'),
    ];
    await importer.importRows(sheet);
    final before = await inRace();

    final again = await importer.importRows(sheet);

    expect(await inRace(), before);
    expect(again.added, 0);
    expect(again.alreadyKnown, 2);
    expect(again.teamsCreated, isEmpty);
    expect(again.conflicts, isEmpty);
    expect((await teams.getAllTeams()).length, 2);
  });

  test('leaves out rows the database would refuse', () async {
    final result = await importer.importRows([
      _row('Ann Lee', 8, '101', team: 'Eagles'), // grade below 9
      _row('', 10, '102', team: 'Eagles'), // no name
      _row('Bo Park', 10, '', team: 'Eagles'), // no bib
      _row('Cy Diaz', 10, '103', team: 'Eagles'),
    ]);

    expect(result.added, 1);
    expect(await inRace(), ['103 Cy Diaz Eagles']);
  });

  group('abbreviate', () {
    test('takes the first letters of up to three words', () {
      expect(RosterImporter.abbreviate('Redwood High School'), 'RHS');
      expect(RosterImporter.abbreviate('Sir Francis Drake High'), 'SFD');
    });

    test('takes the first three letters of a single word', () {
      expect(RosterImporter.abbreviate('Eagles'), 'EAG');
      expect(RosterImporter.abbreviate('Al'), 'AL');
    });

    test('tells a boys\' team from a girls\' team', () {
      expect(RosterImporter.abbreviate('Archie Williams - Boys'), 'AWB');
      expect(RosterImporter.abbreviate('Archie Williams - Girls'), 'AWG');
      expect(RosterImporter.abbreviate('Drake Boys'), 'DRB');
    });

    test('a dash is not a word', () {
      expect(RosterImporter.abbreviate('Tam - Novato'), 'TN');
    });
  });

  group('splitTeamsByGender', () {
    test('puts boys and girls of a team on separate teams', () {
      final rows = RosterImporter.splitTeamsByGender([
        {'name': 'Ann', 'team': 'Archie Williams', 'gender': 'F'},
        {'name': 'Bo', 'team': 'Archie Williams', 'gender': 'M'},
      ]);

      expect(rows.map((r) => r['team']),
          ['Archie Williams - Girls', 'Archie Williams - Boys']);
    });

    test('leaves a runner with no gender, or no team, where they were', () {
      final rows = RosterImporter.splitTeamsByGender([
        {'name': 'Cy', 'team': 'Drake'},
        {'name': 'Di', 'gender': 'F'},
      ]);

      expect(rows[0]['team'], 'Drake');
      expect(rows[1]['team'], isNull);
    });
  });
}
