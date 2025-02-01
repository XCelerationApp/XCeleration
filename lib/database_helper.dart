import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/race.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    // deleteDatabase();
    if (_database != null) return _database!;
    _database = await _initDB('races.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create team runners table
    await db.execute('''
      CREATE TABLE team_runners (
        runner_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        school TEXT,
        grade INTEGER,
        bib_number TEXT NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create races table
    await db.execute('''
      CREATE TABLE races (
        race_id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_name TEXT NOT NULL,
        race_date DATE,
        location TEXT,
        distance TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create race runners table with updated structure
    await db.execute('''
      CREATE TABLE race_runners (
        race_runner_id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER NOT NULL,
        bib_number TEXT NOT NULL,
        name TEXT NOT NULL,
        school TEXT,
        grade INTEGER,
        FOREIGN KEY (race_id) REFERENCES races(race_id),
        UNIQUE(race_id, bib_number)
      )
    ''');

    // Create race results table
    await db.execute('''
      CREATE TABLE race_results (
        result_id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER NOT NULL,
        race_runner_id INTEGER NOT NULL,
        place INTEGER,
        is_team_runner BOOLEAN DEFAULT FALSE,
        finish_time TEXT,
        FOREIGN KEY (race_id) REFERENCES races(race_id)
      )
    ''');
  }

  // Team Runners Methods
  Future<int> insertTeamRunner(Map<String, dynamic> runner) async {
    final db = await instance.database;
    return await db.insert('team_runners', runner);
  }

  // Update a team runner
  Future<int> updateTeamRunner(Map<String, dynamic> runner) async {
    final db = await instance.database;
    return await db.update(
      'team_runners',
      runner,
      where: 'runner_id = ?',
      whereArgs: [runner['runner_id']],
    );
  }


  Future<List<Map<String, dynamic>>> getAllTeamRunners() async {
    final db = await instance.database;
    return await db.query('team_runners');
  }

  Future<Map<String, dynamic>?> getTeamRunnerByBib(String bib) async {
    final db = await instance.database;
    final results = await db.query(
      'team_runners',
      where: 'bib_number = ?',
      whereArgs: [bib],
    );
    return results.isNotEmpty ? results.first : null;
  }

  
  // Delete a team runner
  Future<int> deleteTeamRunner(String bib) async {
    final db = await instance.database;
    return await db.delete(
      'team_runners',
      where: 'bib_number = ?',
      whereArgs: [bib],
    );
  }


  // Races Methods
  Future<int> insertRace(Map<String, dynamic> race) async {
    final db = await instance.database;
    return await db.insert('races', race);
  }
  
  Future<int> updateRace(Map<String, dynamic> race) async {
    final db = await instance.database;
    return await db.update(
      'races',
      race,
      where: 'race_id = ?',
      whereArgs: [race['race_id']],
    );
  }

  Future<List<Race>> getAllRaces() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'races',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      DateTime raceDate;
      try {
        raceDate = DateTime.parse(maps[i]['race_date'].trim());
      } catch (e) {
        print('Error parsing date: ${maps[i]['race_date']}');
        raceDate = DateTime.now(); // or handle it in a way that makes sense for your app
      }

      return Race(
        raceId: maps[i]['race_id'],
        raceName: maps[i]['race_name'],
        raceDate: raceDate,
        location: maps[i]['location'],
        distance: maps[i]['distance'],
      );
    });
  }

  Future<Map<String, dynamic>?> getRaceById(int id) async {
    final db = await instance.database;
    final results = await db.query(
      'races',
      where: 'race_id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Race Runners Methods
  Future<int> insertRaceRunner(Map<String, dynamic> runner) async {
    final db = await instance.database;
    return await db.insert(
      'race_runners',
      runner,
      conflictAlgorithm: ConflictAlgorithm.replace, // Replace if bib number exists in race
    );
  }

  Future<List<Map<String, dynamic>>> getRaceRunners(int raceId) async {
    final db = await instance.database;
    return await db.query(
      'race_runners',
      where: 'race_id = ?',
      whereArgs: [raceId],
      orderBy: 'bib_number',
    );
  }

  Future<List<dynamic>> getRaceRunnerByBib(int raceId, String bibNumber, {bool getTeamRunner=false}) async {
    final db = await instance.database;
    final results = await db.query(
      'race_runners',
      where: 'race_id = ? AND bib_number = ?',
      whereArgs: [raceId, bibNumber],
    );

    final runner = results.isNotEmpty ? results.first : null;
    if (runner == null && getTeamRunner) {
      return [await getTeamRunnerByBib(bibNumber), true];
    }
    return [runner, false];
  }

  Future<List<Map<String, dynamic>>> getRaceRunnersByBibs(int raceId, List<String> bibNumbers) async {
    List<Map<String, dynamic>> results = [];
    for (int i = 0; i < bibNumbers.length; i++) {
      final runner = await getRaceRunnerByBib(raceId, bibNumbers[i], getTeamRunner: true);
      if (runner[0] == null) {
        break;
      }
      results.add(runner[0]);
    }
    return results;
  }


  Future<void> updateRaceRunner(Map<String, dynamic> runner) async {
    final db = await instance.database;
    await db.update(
      'race_runners',
      runner,
      where: 'race_runner_id = ?',
      whereArgs: [runner['race_runner_id']],
    );
  }

  Future<void> deleteRaceRunner(int raceId, String bibNumber) async {
    final db = await instance.database;
    await db.delete(
      'race_runners',
      where: 'race_id = ? AND bib_number = ?',
      whereArgs: [raceId, bibNumber],
    );
  }

  Future<void> insertRaceResult(Map<String, dynamic> result) async {
    // Check if the runner exists in team runners or race runners
    bool runnerExists = await _runnerExists(result['race_runner_id']);
    final db = await instance.database;

    if (runnerExists) {
      // Insert into race_results
      await db.insert('race_results', result);
    } else {
      throw Exception('Runner does not exist in either database.');
    }
  }

  Future<bool> _runnerExists(int raceRunnerId) async {
    final db = await instance.database;
    // Check in race runners
    final raceRunnerCheck = await db.query('race_runners',
        where: 'race_runner_id = ?', whereArgs: [raceRunnerId]);

    // Check in team runners
    final teamRunnerCheck = await db.query('team_runners',
        where: 'runner_id = ?', whereArgs: [raceRunnerId]);

    return raceRunnerCheck.isNotEmpty || teamRunnerCheck.isNotEmpty;
  }

  Future<void> insertRaceResults(List<Map<String, dynamic>> results) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var result in results) {
      print(result);
      batch.insert('race_results', result);
    }
    await batch.commit();
    return;
  }

  Future<List<Map<String, dynamic>>> getRaceResults(int raceId) async {
    final db = await instance.database;
    final raceRunners = await db.rawQuery('''
      SELECT 
        rr.race_runner_id AS runner_id, 
        rr.bib_number, 
        rr.name, 
        rr.school, 
        rr.grade, 
        r.place, 
        r.finish_time,
        0 AS is_team_runner
      FROM race_results r
      LEFT JOIN race_runners rr ON rr.race_runner_id = r.race_runner_id
      WHERE rr.race_id = ?
    ''', [raceId]);

    final teamRunners = await db.rawQuery('''
      SELECT 
        sr.runner_id AS runner_id, 
        sr.bib_number, 
        sr.name, 
        sr.school, 
        sr.grade, 
        r.place, 
        r.finish_time,
        1 AS is_team_runner
      FROM race_results r
      LEFT JOIN team_runners sr ON sr.runner_id = r.race_runner_id
      WHERE r.is_team_runner = 1 AND r.race_id = ?
    ''', [raceId]);

    return [...raceRunners, ...teamRunners];
  }

  Future<List<Map<String, dynamic>>> getAllResults() async {
    final db = await instance.database;
    return await db.query('race_results');
  }



  // Cleanup Methods
  Future<void> deleteRace(int raceId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Delete related records first
      await txn.delete('race_results', where: 'race_id = ?', whereArgs: [raceId]);
      await txn.delete('race_runners', where: 'race_id = ?', whereArgs: [raceId]);
      await txn.delete('races', where: 'race_id = ?', whereArgs: [raceId]);
    });
  }

  Future<void> deleteAllRaces() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('race_results');
      await txn.delete('race_runners');
      await txn.delete('races');
    });
  }

  Future<void> deleteAllRaceRunners(int raceId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Delete related race results first (due to foreign key constraint)
      await txn.delete('race_results', where: 'race_id = ?', whereArgs: [raceId]);
      // Then delete all runners for this race
      await txn.delete('race_runners', where: 'race_id = ?', whereArgs: [raceId]);
    });
  }
  
  Future<void> clearTeamRunners() async {
    final db = await instance.database;
    await db.rawUpdate('UPDATE team_runners SET name = \'\', school = \'\', grade = 0, bib_number = 0');
  }


  Future<void> deleteDatabase() async {
    print('deleting database');
    String path = join(await getDatabasesPath(), 'races.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}