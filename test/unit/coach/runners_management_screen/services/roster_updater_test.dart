import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/coach/runners_management_screen/services/roster_importer.dart';
import 'package:xceleration/coach/runners_management_screen/services/roster_update.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/repositories/race_repository.dart';
import 'package:xceleration/core/repositories/runner_repository.dart';
import 'package:xceleration/core/repositories/team_repository.dart';
import 'package:xceleration/core/utils/local_schema.dart';
import 'package:xceleration/shared/models/database/base_models.dart';

// A coach updates a team from a newer copy of its roster spreadsheet. New
// runners join the team and the race, changed details are saved, and runners
// no longer listed leave the team and this race, but are not deleted.

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
  late Team eagles;
  late RosterUpdater updater;

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
    final importer = RosterImporter(
        raceId: raceId, runners: runners, teams: teams, races: races);
    await importer.importRows([
      _row('Ann Lee', 10, '101', team: 'Eagles'),
      _row('Bo Park', 11, '102', team: 'Eagles'),
      _row('Cy Diaz', 12, '103', team: 'Eagles'),
      _row('Hal Ng', 9, '200', team: 'Hawks'),
    ]);
    eagles = (await teams.getTeamByName('Eagles'))!;
    updater = RosterUpdater(
        raceId: raceId, runners: runners, teams: teams, races: races);
  });

  tearDown(() async => conn.close());

  Future<List<String>> onEagles() async => [
        for (final r in await runners.getTeamRunners(eagles.teamId!))
          '${r.bibNumber} ${r.name} ${r.grade}'
      ]..sort();

  Future<List<String>> inRace() async {
    final out = <String>[];
    for (final p in await races.getRaceParticipants(raceId)) {
      out.add((await runners.getRunner(p.runnerId!))!.bibNumber!);
    }
    return out..sort();
  }

  Future<RosterUpdateResult> update(List<Map<String, dynamic>> rows) async {
    final plan = planRosterUpdate(
      current: await runners.getTeamRunners(eagles.teamId!),
      rows: rows,
    );
    return updater.apply(plan, eagles);
  }

  test('adds, changes and removes to match the sheet', () async {
    final result = await update([
      _row('Ann Lee', 10, '101'),
      _row('Bo Park', 12, '102'), // a year on
      _row('Di Fox', 9, '104'), // new
    ]);

    expect(await onEagles(),
        ['101 Ann Lee 10', '102 Bo Park 12', '104 Di Fox 9']);
    expect(await inRace(), ['101', '102', '104', '200']);
    expect(result.changed, 1);
    expect(result.removed, 1);
    expect(result.imported.added, 1);
  });

  test('a runner taken off the team is kept, with their bib', () async {
    await update([
      _row('Ann Lee', 10, '101'),
      _row('Bo Park', 11, '102'),
    ]);

    final cy = await runners.getRunnerByBib('103');
    expect(cy?.name, 'Cy Diaz');
  });

  test('a new bib that belongs to another runner is left alone', () async {
    final result = await update([
      _row('Ann Lee', 10, '200'), // Hal on the Hawks has 200
      _row('Bo Park', 11, '102'),
      _row('Cy Diaz', 12, '103'),
    ]);

    expect(result.bibTaken.single.before.name, 'Ann Lee');
    expect(result.changed, 0);
    expect(await onEagles(),
        ['101 Ann Lee 10', '102 Bo Park 11', '103 Cy Diaz 12']);
    expect((await runners.getRunnerByBib('200'))?.name, 'Hal Ng');
  });

  test('a Team column naming another team does not move new runners',
      () async {
    await update([
      _row('Ann Lee', 10, '101'),
      _row('Bo Park', 11, '102'),
      _row('Cy Diaz', 12, '103'),
      _row('Di Fox', 9, '104', team: 'Hawks'),
    ]);

    expect(await onEagles(), contains('104 Di Fox 9'));
  });
}
