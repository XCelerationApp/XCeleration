import 'package:sqflite/sqflite.dart';
import '../../shared/models/database/base_models.dart';
import '../services/database_write_bus.dart';
import 'i_database_connection_provider.dart';
import 'i_team_repository.dart';

class TeamRepository implements ITeamRepository {
  final IDatabaseConnectionProvider _conn;
  final DatabaseWriteBus? _writeBus;

  TeamRepository({
    required IDatabaseConnectionProvider conn,
    DatabaseWriteBus? writeBus,
  })  : _conn = conn,
        _writeBus = writeBus;

  Future<Database> get _db async => _conn.database;

  @override
  Future<int> createTeam(Team team) async {
    if (!team.isValid) throw Exception('Team is not valid');
    if (await getTeamByName(team.name!) != null) {
      throw Exception('Team with name ${team.name} already exists');
    }
    final db = await _db;
    final id = await db.insert('teams', {
      'name': team.name,
      'abbreviation':
          team.abbreviation ?? Team.generateAbbreviation(team.name!),
      'color': team.color?.toARGB32() ?? 0,
      'is_dirty': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });
    _writeBus?.notify();
    return id;
  }

  @override
  Future<Team?> getTeam(int teamId) async {
    final db = await _db;
    final rows =
        await db.query('teams', where: 'team_id = ?', whereArgs: [teamId]);
    return rows.isNotEmpty ? Team.fromMap(rows.first) : null;
  }

  @override
  Future<Team?> getTeamByName(String name) async {
    final db = await _db;
    final rows = await db.query(
      'teams',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isNotEmpty ? Team.fromMap(rows.first) : null;
  }

  @override
  Future<List<Team>> getAllTeams() async {
    final db = await _db;
    final rows = await db.query('teams', orderBy: 'name');
    return rows.map((m) => Team.fromMap(m)).toList();
  }

  @override
  Future<List<Team>> searchTeams(String query) async {
    final db = await _db;
    final rows = await db.query(
      'teams',
      where: 'name LIKE ? OR abbreviation LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name',
    );
    return rows.map((m) => Team.fromMap(m)).toList();
  }

  @override
  Future<void> updateTeam(Team team) async {
    if (!team.isValid) throw Exception('Team is not valid');
    if (await getTeam(team.teamId!) == null) {
      throw Exception('Team with id ${team.teamId} not found');
    }
    final db = await _db;
    final updates = <String, dynamic>{};
    if (team.name != null) updates['name'] = team.name;
    if (team.abbreviation != null) updates['abbreviation'] = team.abbreviation;
    if (team.color != null) updates['color'] = team.color!.toARGB32();
    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      updates['is_dirty'] = 1;
      await db.update('teams', updates,
          where: 'team_id = ?', whereArgs: [team.teamId]);
      _writeBus?.notify();
    }
  }

  @override
  Future<void> deleteTeam(int teamId) async {
    if (await getTeam(teamId) == null) {
      throw Exception('Team with id $teamId not found');
    }
    final db = await _db;
    await db.delete('teams', where: 'team_id = ?', whereArgs: [teamId]);
    _writeBus?.notify();
  }
}
